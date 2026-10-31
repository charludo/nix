"""BlueZ, simulated: what `bluez.Bluez` and `bluez.open_link` would do, against
a `World` the tests control."""

from __future__ import annotations

import importlib
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tests"))

ADAPTER = "/org/bluez/hci0"
ADDRESS = "F8:54:B8:00:00:01"

WORLD: World | None = None


class World:
    """Adapters, clocks and links, as the integration sees them through BlueZ."""

    def __init__(self, bluez) -> None:
        self.bluez = bluez
        self.adapters = [bluez.Adapter(ADAPTER, "00:1A:7D:DA:71:01", "hci0", True)]
        self.known = [bluez.Candidate(ADDRESS, "EchoWallClk0BE", ADAPTER, True, False)]
        self.in_pairing_mode: list = []
        self.connected: dict[str, bool] = {}
        self.watchers: dict[str, list] = {}
        self.clocks: dict = {}
        self.paired: list[str] = []
        self.profile = False
        self.fail_pairing = False

    def clock(self, address: str = ADDRESS):
        from fakeclock import FakeClock

        return self.clocks.setdefault(address, FakeClock())

    def link_up(self, address: str = ADDRESS) -> None:
        self.connected[address] = True
        for callback in self.watchers.get(address, []):
            callback(True)

    def link_down(self, address: str = ADDRESS) -> None:
        self.connected[address] = False
        for link in self.clock(address).links:
            link.drop()
        for callback in self.watchers.get(address, []):
            callback(False)


def install(monkeypatch) -> World:
    global WORLD
    # The stand-in clock speaks the integration's own protocol module.
    protocol = importlib.import_module("custom_components.echo_wall_clock.protocol")
    sys.modules["echo_wall_clock"] = importlib.import_module("custom_components.echo_wall_clock")
    sys.modules["echo_wall_clock.protocol"] = protocol
    bluez = importlib.import_module("custom_components.echo_wall_clock.bluez")
    world = WORLD = World(bluez)

    class FakeBluez:
        def __init__(self) -> None:
            self.closed = False

        async def connect(self) -> None:
            pass

        def close(self) -> None:
            self.closed = True

        async def adapters(self):
            return list(world.adapters)

        async def clocks(self):
            return list(world.known)

        async def discover(self, adapter, seconds):
            return [c for c in world.in_pairing_mode if c.adapter == adapter]

        async def pair(self, adapter, address):
            if world.fail_pairing:
                raise bluez.BluezError("pairing failed")
            world.paired.append(address)

        async def is_connected(self, adapter, address):
            return world.connected.get(address, False)

        def watch_connected(self, adapter, address, callback):
            world.watchers.setdefault(address, []).append(callback)
            return lambda: world.watchers[address].remove(callback)

        async def register_profile(self, on_lost):
            world.profile = True

        async def unregister_profile(self):
            world.profile = False

    async def open_link(address, local=None, attempts=3):
        if not world.connected.get(address):
            raise ConnectionRefusedError("not linked")
        return world.clock(address).link()

    for module in ("runtime", "config_flow"):
        target = importlib.import_module(f"custom_components.echo_wall_clock.{module}")
        monkeypatch.setattr(target, "Bluez", FakeBluez)
    runtime = importlib.import_module("custom_components.echo_wall_clock.runtime")
    monkeypatch.setattr(runtime, "open_link", open_link)
    monkeypatch.setattr(runtime, "POLL_INTERVAL", runtime.POLL_INTERVAL / 30)
    clock = importlib.import_module("custom_components.echo_wall_clock.clock")
    monkeypatch.setattr(clock, "SETTLE", 0)
    monkeypatch.setattr(clock, "DISCOVER_TIMEOUT", 0.3)
    for module in ("", ".config_flow"):
        target = importlib.import_module(f"custom_components.echo_wall_clock{module}")
        monkeypatch.setattr(target, "sockets_supported", lambda: True)
    return world
