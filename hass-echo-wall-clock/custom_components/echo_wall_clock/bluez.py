"""BlueZ, over D-Bus and Bluetooth sockets: finding, pairing and reaching clocks.

Home Assistant's own Bluetooth stack is Bluetooth LE only; the clock speaks
Classic Bluetooth, so this talks to BlueZ directly. What the clock needs from
its "Echo":

- a Serial Port (SPP) service record: after it links up, the clock looks for
  one and gives up on us if there is none;
- an RFCOMM connection to its data channel (4), authenticated and encrypted
  with the stored link key, within a few seconds of the link coming up.

No Home Assistant imports here.
"""

from __future__ import annotations

import asyncio
import contextlib
import logging
import os
import socket
import struct
from collections.abc import Callable
from dataclasses import dataclass

from dbus_fast import BusType, Message, MessageType, Variant
from dbus_fast.aio import MessageBus
from dbus_fast.service import ServiceInterface, method

_LOGGER = logging.getLogger(__name__)

BLUEZ = "org.bluez"
GADGET_UUID = "6088d2b3-983a-4eed-9f94-5ad1256816b7"
SPP_UUID = "00001101-0000-1000-8000-00805f9b34fb"
NAME_PREFIX = "EchoWallClk"
DATA_CHANNEL = 4

PROFILE_PATH = "/io/github/charludo/echo_wall_clock/spp"
AGENT_PATH = "/io/github/charludo/echo_wall_clock/agent"

# <linux/bluetooth.h>
SOL_BLUETOOTH = 274
BT_SECURITY = 4
BT_SECURITY_MEDIUM = 2  # authenticated link key, encrypted


class BluezError(Exception):
    """BlueZ said no, or isn't there."""


def sockets_supported() -> bool:
    """Whether this Python can open Bluetooth sockets at all."""
    return hasattr(socket, "AF_BLUETOOTH") and hasattr(socket, "BTPROTO_RFCOMM")


def device_path(adapter: str, address: str) -> str:
    return f"{adapter}/dev_{address.upper().replace(':', '_')}"


@dataclass
class Adapter:
    path: str
    address: str
    name: str
    powered: bool


@dataclass
class Candidate:
    """A clock BlueZ knows about."""

    address: str
    name: str
    adapter: str
    paired: bool
    connected: bool


# --- link ---------------------------------------------------------------------


class RfcommLink:
    """The clock's data channel; see `clock.Link`."""

    def __init__(self, sock: socket.socket) -> None:
        self._sock = sock
        self._loop = asyncio.get_running_loop()

    @classmethod
    async def open(
        cls, address: str, channel: int = DATA_CHANNEL, local: str | None = None
    ) -> RfcommLink:
        def connect() -> socket.socket:
            sock = socket.socket(socket.AF_BLUETOOTH, socket.SOCK_STREAM, socket.BTPROTO_RFCOMM)
            try:
                sock.setsockopt(
                    SOL_BLUETOOTH, BT_SECURITY, struct.pack("BB", BT_SECURITY_MEDIUM, 0)
                )
                if local:
                    sock.bind((local, 0))
                sock.settimeout(8)
                sock.connect((address, channel))
                sock.setblocking(False)
            except OSError:
                sock.close()
                raise
            return sock

        return cls(await asyncio.get_running_loop().run_in_executor(None, connect))

    async def send(self, data: bytes) -> None:
        await self._loop.sock_sendall(self._sock, data)

    async def recv(self) -> bytes:
        return await self._loop.sock_recv(self._sock, 4096)

    def close(self) -> None:
        self._sock.close()


async def open_link(address: str, local: str | None = None, attempts: int = 3) -> RfcommLink:
    """Open the data channel, retrying briefly: the first try right after the
    link comes up is sometimes reset while encryption is still being set up."""
    for attempt in range(attempts):
        try:
            return await RfcommLink.open(address, DATA_CHANNEL, local)
        except OSError as err:
            if attempt == attempts - 1:
                raise
            _LOGGER.debug("RFCOMM attempt %d: %s", attempt + 1, err)
            await asyncio.sleep(0.3)
    raise AssertionError("unreachable")


# --- D-Bus objects we export ---------------------------------------------------


class _Profile(ServiceInterface):
    """An SPP server profile, only so BlueZ publishes the record the clock
    looks for. The clock never connects to it; anything that does is hung up."""

    def __init__(self, on_release: Callable[[], None]) -> None:
        super().__init__("org.bluez.Profile1")
        self._on_release = on_release

    @method()
    def Release(self):  # noqa: N802 - D-Bus names
        self._on_release()

    @method()
    def NewConnection(self, device: "o", fd: "h", properties: "a{sv}"):  # noqa: N802
        os.close(fd)

    @method()
    def RequestDisconnection(self, device: "o"):  # noqa: N802
        pass


class _Agent(ServiceInterface):
    """Accepts the pairing it is there for (the clock has no display or buttons)."""

    def __init__(self) -> None:
        super().__init__("org.bluez.Agent1")

    @method()
    def Release(self):  # noqa: N802
        pass

    @method()
    def RequestPinCode(self, device: "o") -> "s":  # noqa: N802
        return "0000"

    @method()
    def DisplayPinCode(self, device: "o", pincode: "s"):  # noqa: N802
        pass

    @method()
    def RequestPasskey(self, device: "o") -> "u":  # noqa: N802
        return 0

    @method()
    def DisplayPasskey(self, device: "o", passkey: "u", entered: "q"):  # noqa: N802
        pass

    @method()
    def RequestConfirmation(self, device: "o", passkey: "u"):  # noqa: N802
        pass

    @method()
    def RequestAuthorization(self, device: "o"):  # noqa: N802
        pass

    @method()
    def AuthorizeService(self, device: "o", uuid: "s"):  # noqa: N802
        pass

    @method()
    def Cancel(self):  # noqa: N802
        pass


# --- BlueZ ------------------------------------------------------------------------


class Bluez:
    """A system bus connection and what we do with BlueZ over it."""

    def __init__(self) -> None:
        self._bus: MessageBus | None = None
        self._profile_registered = False
        self._on_profile_lost: Callable[[], None] | None = None

    async def connect(self) -> None:
        try:
            self._bus = await MessageBus(bus_type=BusType.SYSTEM, negotiate_unix_fd=True).connect()
        except (OSError, ValueError) as err:
            raise BluezError(f"no system D-Bus: {err}") from err

    def close(self) -> None:
        if self._bus is not None:
            self._bus.disconnect()
            self._bus = None

    @property
    def bus(self) -> MessageBus:
        if self._bus is None:
            raise BluezError("not connected")
        return self._bus

    async def _call(
        self, path: str, interface: str, member: str, signature: str = "", body: list | None = None
    ):
        reply = await self.bus.call(
            Message(
                destination=BLUEZ,
                path=path,
                interface=interface,
                member=member,
                signature=signature,
                body=body or [],
            )
        )
        if reply.message_type == MessageType.ERROR:
            raise BluezError(f"{member}: {reply.error_name}: {' '.join(map(str, reply.body))}")
        return reply.body

    async def _objects(self) -> dict[str, dict[str, dict[str, Variant]]]:
        (objects,) = await self._call(
            "/", "org.freedesktop.DBus.ObjectManager", "GetManagedObjects"
        )
        return objects

    async def _set(self, path: str, interface: str, name: str, value: Variant) -> None:
        await self._call(
            path, "org.freedesktop.DBus.Properties", "Set", "ssv", [interface, name, value]
        )

    async def _get(self, path: str, interface: str, name: str):
        (value,) = await self._call(
            path, "org.freedesktop.DBus.Properties", "Get", "ss", [interface, name]
        )
        return value.value

    # adapters and devices

    async def adapters(self) -> list[Adapter]:
        found = []
        for path, interfaces in (await self._objects()).items():
            props = interfaces.get("org.bluez.Adapter1")
            if props is None:
                continue
            found.append(
                Adapter(
                    path=path,
                    address=props["Address"].value,
                    name=props.get("Alias", props.get("Name", Variant("s", path))).value,
                    powered=props.get("Powered", Variant("b", False)).value,
                )
            )
        return sorted(found, key=lambda a: a.path)

    async def clocks(self) -> list[Candidate]:
        found = []
        for _path, interfaces in (await self._objects()).items():
            props = interfaces.get("org.bluez.Device1")
            if props is None:
                continue
            name = props.get("Name", props.get("Alias", Variant("s", ""))).value
            uuids = [u.lower() for u in props.get("UUIDs", Variant("as", [])).value]
            if GADGET_UUID not in uuids and not name.startswith(NAME_PREFIX):
                continue
            found.append(
                Candidate(
                    address=props["Address"].value,
                    name=name,
                    adapter=props["Adapter"].value,
                    paired=props.get("Paired", Variant("b", False)).value,
                    connected=props.get("Connected", Variant("b", False)).value,
                )
            )
        return sorted(found, key=lambda c: c.address)

    async def discover(self, adapter: str, seconds: float) -> list[Candidate]:
        """Look for clocks in pairing mode (Classic Bluetooth inquiry)."""
        await self._call(
            adapter,
            "org.bluez.Adapter1",
            "SetDiscoveryFilter",
            "a{sv}",
            [{"Transport": Variant("s", "bredr")}],
        )
        await self._call(adapter, "org.bluez.Adapter1", "StartDiscovery")
        try:
            await asyncio.sleep(seconds)
        finally:
            with contextlib.suppress(BluezError):
                await self._call(adapter, "org.bluez.Adapter1", "StopDiscovery")
        return [c for c in await self.clocks() if c.adapter == adapter]

    async def pair(self, adapter: str, address: str) -> None:
        """Pair and trust, with an agent that accepts (the clock can't confirm)."""
        path = device_path(adapter, address)
        agent = _Agent()
        self.bus.export(AGENT_PATH, agent)
        await self._call(
            "/org/bluez",
            "org.bluez.AgentManager1",
            "RegisterAgent",
            "os",
            [AGENT_PATH, "NoInputNoOutput"],
        )
        try:
            if not await self._get(path, "org.bluez.Device1", "Paired"):
                await self._call(path, "org.bluez.Device1", "Pair")
            await self._set(path, "org.bluez.Device1", "Trusted", Variant("b", True))
        finally:
            with contextlib.suppress(BluezError):
                await self._call(
                    "/org/bluez", "org.bluez.AgentManager1", "UnregisterAgent", "o", [AGENT_PATH]
                )
            self.bus.unexport(AGENT_PATH, agent)

    async def remove(self, adapter: str, address: str) -> None:
        await self._call(
            adapter, "org.bluez.Adapter1", "RemoveDevice", "o", [device_path(adapter, address)]
        )

    async def is_connected(self, adapter: str, address: str) -> bool:
        try:
            return bool(
                await self._get(device_path(adapter, address), "org.bluez.Device1", "Connected")
            )
        except BluezError:
            return False

    def watch_connected(
        self, adapter: str, address: str, callback: Callable[[bool], None]
    ) -> Callable[[], None]:
        """Call back with the link state whenever it changes; returns an unsubscribe."""
        path = device_path(adapter, address)
        rule = (
            "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',"
            f"member='PropertiesChanged',path='{path}'"
        )

        def handler(message: Message) -> None:
            if (
                message.message_type != MessageType.SIGNAL
                or message.path != path
                or message.member != "PropertiesChanged"
                or not message.body
                or message.body[0] != "org.bluez.Device1"
            ):
                return
            changed = message.body[1]
            if "Connected" in changed:
                callback(bool(changed["Connected"].value))

        self.bus.add_message_handler(handler)
        adding = asyncio.ensure_future(self._match(rule, True))

        def unsubscribe() -> None:
            adding.cancel()
            if self._bus is not None:
                self._bus.remove_message_handler(handler)
                asyncio.ensure_future(self._match(rule, False))

        return unsubscribe

    async def _match(self, rule: str, add: bool) -> None:
        with contextlib.suppress(Exception):
            await self.bus.call(
                Message(
                    destination="org.freedesktop.DBus",
                    path="/org/freedesktop/DBus",
                    interface="org.freedesktop.DBus",
                    member="AddMatch" if add else "RemoveMatch",
                    signature="s",
                    body=[rule],
                )
            )

    # the SPP record

    async def register_profile(self, on_lost: Callable[[], None]) -> None:
        """Publish the SPP record. `on_lost` runs if BlueZ drops it (e.g. when
        bluetoothd restarts); register again then."""
        if self._profile_registered:
            return

        def released() -> None:
            self._profile_registered = False
            on_lost()

        self._on_profile_lost = on_lost
        profile = _Profile(released)
        with contextlib.suppress(ValueError):
            self.bus.unexport(PROFILE_PATH)
        self.bus.export(PROFILE_PATH, profile)
        await self._call(
            "/org/bluez",
            "org.bluez.ProfileManager1",
            "RegisterProfile",
            "osa{sv}",
            [
                PROFILE_PATH,
                SPP_UUID,
                {
                    "Name": Variant("s", "Serial Port"),
                    "Role": Variant("s", "server"),
                    "RequireAuthentication": Variant("b", True),
                    "RequireAuthorization": Variant("b", False),
                    "AutoConnect": Variant("b", False),
                },
            ],
        )
        self._profile_registered = True

    async def unregister_profile(self) -> None:
        if not self._profile_registered:
            return
        self._profile_registered = False
        with contextlib.suppress(BluezError):
            await self._call(
                "/org/bluez", "org.bluez.ProfileManager1", "UnregisterProfile", "o", [PROFILE_PATH]
            )
        with contextlib.suppress(ValueError):
            self.bus.unexport(PROFILE_PATH)
