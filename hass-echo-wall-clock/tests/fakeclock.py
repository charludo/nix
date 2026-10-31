"""A stand-in Echo Wall Clock: reads frames, answers Discover, records the rest."""

from __future__ import annotations

import asyncio

from echo_wall_clock import protocol


def discover_response(serial="G0TEST", firmware="102") -> bytes:
    """A Discover.Response shaped like the real clock's (no real token)."""
    capabilities = [
        (11, [(1, "AlexaInterface"), (2, "Alexa.Gadget.StateListener"), (3, "1.0")]),
        (11, [(1, "AlexaInterface"), (2, "Alerts"), (3, "1.1")]),
        (11, [(1, "AlexaInterface"), (2, "Notifications"), (3, "1.0")]),
    ]
    endpoint = [
        (1, serial),
        (2, "EchoWallClk"),
        (3, "AlexaGadgetsEWC"),
        *capabilities,
        (12, [(1, firmware), (2, "00" * 32), (3, "1"), (4, "A0TESTTYPE"), (5, "AlexaGadgetsEWC")]),
    ]
    header = [(1, "Alexa.Discovery"), (2, "Discover.Response")]
    return protocol.encode((1, [(1, header), (2, [(1, endpoint)])]))


class FakeClock:
    """What the clock received, decoded: [(namespace, name, payload fields)]."""

    def __init__(self, answer_discover: bool = True) -> None:
        self.answer_discover = answer_discover
        self.received: list[tuple[str, str, bytes]] = []
        self.links: list[FakeLink] = []
        self.changed = asyncio.Event()

    def link(self) -> FakeLink:
        link = FakeLink(self)
        self.links.append(link)
        return link

    def names(self) -> list[str]:
        return [f"{ns}/{name}" for ns, name, _ in self.received]

    def alerts_sent(self) -> list[tuple[str, str, str]]:
        """(token, kind, time) of every SetAlert."""
        out = []
        for ns, name, message in self.received:
            if (ns, name) == ("Alerts", "SetAlert"):
                body = protocol.decode(protocol.decode(message)[0][1])
                payload = dict(protocol.decode(dict(body)[2]))
                out.append(tuple(payload[n].decode() for n in (1, 2, 3)))
        return out

    def deletes_sent(self) -> list[str]:
        out = []
        for ns, name, message in self.received:
            if (ns, name) == ("Alerts", "DeleteAlert"):
                body = protocol.decode(protocol.decode(message)[0][1])
                out.append(dict(protocol.decode(dict(body)[2]))[1].decode())
        return out

    def time_infos(self) -> list[str]:
        out = []
        for ns, name, message in self.received:
            if (ns, name) == ("Alexa.Gadget.StateListener", "StateUpdate"):
                body = protocol.decode(protocol.decode(message)[0][1])
                state = dict(protocol.decode(dict(protocol.decode(dict(body)[2]))[1]))
                if state[1] == b"timeinfo":
                    out.append(state[2].decode())
        return out


class FakeLink:
    def __init__(self, clock: FakeClock) -> None:
        self.clock = clock
        self.rx = protocol.Framer()
        self.tx = protocol.Framer()
        self.incoming: asyncio.Queue[bytes] = asyncio.Queue()
        self.closed = False
        self.raw: list[bytes] = []

    async def send(self, data: bytes) -> None:
        if self.closed:
            raise ConnectionResetError("closed")
        self.raw.append(data)
        for message in self.rx.feed(data):
            namespace, name = protocol.header(message)
            self.clock.received.append((namespace, name, message))
            self.clock.changed.set()
            if (namespace, name) == ("Alexa.Discovery", "Discover") and self.clock.answer_discover:
                self.incoming.put_nowait(self.tx.frame(discover_response()))

    async def recv(self) -> bytes:
        if self.closed:
            return b""
        return await self.incoming.get()

    def drop(self) -> None:
        """The clock goes away."""
        self.closed = True
        self.incoming.put_nowait(b"")

    def close(self) -> None:
        self.closed = True
        self.incoming.put_nowait(b"")
