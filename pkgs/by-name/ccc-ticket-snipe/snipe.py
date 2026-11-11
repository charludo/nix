#!/usr/bin/env python3
"""Long-running single-shot request to the CCC ticket shop at presale start.

Picks a random arrival time inside a window around the target on start, keeps NTP
offset and network latency measurements fresh while waiting, then sends one GET
timed to arrive at that time. If the response is still the closed shop page, a
second GET (same session) goes out on a separately warmed connection. Redirects
are followed, also to other hosts (e.g. a queue), with one cookie jar per host.
Everything needed to take over the session in a browser (cookies, headers, full
HTML) is written to stdout; during the time-critical phase it is buffered in
memory and flushed afterwards.
"""

import argparse
import datetime as dt
import email.utils
import http.client
import json
import os
import random
import re
import select
import socket
import ssl
import statistics
import struct
import sys
import time
from urllib.parse import urljoin, urlsplit

NTP_SERVERS = [
    "ptbtime1.ptb.de",
    "ptbtime2.ptb.de",
    "ptbtime3.ptb.de",
    "0.de.pool.ntp.org",
    "1.de.pool.ntp.org",
    "2.de.pool.ntp.org",
]
NTP_EPOCH = 2208988800
UA = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
S = 1_000_000_000
MS = 1_000_000
# Preparation (session, baseline, second connection) starts this long before arrival
PREP_S = 30
# Used when there was no chance to measure the latency
DEFAULT_ONE_WAY = 15 * MS
# A warm connection the server dropped only shows up when reading the response
DROPPED = (
    http.client.RemoteDisconnected,
    http.client.IncompleteRead,
    ConnectionResetError,
    ConnectionAbortedError,
    BrokenPipeError,
    ssl.SSLEOFError,
    ssl.SSLZeroReturnError,
)

# While a list, log lines are collected here instead of written (time-critical phase)
LOG_BUF = None
LOG_CLOCK = None


def log(msg, stamp=True):
    if LOG_BUF is None:
        print(msg, flush=True)
    else:
        t = LOG_CLOCK.now_ns() if stamp and LOG_CLOCK else None
        LOG_BUF.append((t, msg))


def buffer_logs():
    global LOG_BUF
    if LOG_BUF is None:
        LOG_BUF = []


def flush_logs():
    global LOG_BUF
    buf, LOG_BUF = LOG_BUF, None
    if not buf:
        return
    print(f"---- {len(buf)} buffered lines from the time-critical phase ----")
    for t, msg in buf:
        print(msg if t is None else f"[{fmt(t)}] {msg}")
    print("---- end of buffered lines ----", flush=True)


def fmt(t_ns):
    return (
        dt.datetime.fromtimestamp(t_ns / S)
        .astimezone()
        .isoformat(timespec="milliseconds")
    )


def sntp(addr, timeout=1.0):
    """Return (offset_ns, delay_ns) of local wall clock vs. server."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        t0, p0 = time.time_ns(), time.perf_counter_ns()
        tx = struct.pack("!II", t0 // S + NTP_EPOCH, (t0 % S) * 2**32 // S)
        s.sendto(b"\x23" + 39 * b"\0" + tx, addr)
        data, _ = s.recvfrom(48)
        t3 = t0 + (time.perf_counter_ns() - p0)
    finally:
        s.close()

    # The server echoes our transmit timestamp as its originate timestamp
    if len(data) < 48 or data[24:32] != tx:
        raise OSError("bogus NTP reply")
    li, mode, stratum = data[0] >> 6, data[0] & 7, data[1]
    if li == 3 or mode != 4 or not 1 <= stratum <= 15:
        raise OSError(f"unusable NTP reply (li={li} mode={mode} stratum={stratum})")

    def ts(off):
        sec, frac = struct.unpack("!II", data[off : off + 8])
        return (sec - NTP_EPOCH) * S + frac * S // 2**32

    t1, t2 = ts(32), ts(40)
    return ((t1 - t0) + (t2 - t3)) // 2, (t3 - t0) - (t2 - t1)


class Clock:
    """True time = perf_counter + base; immune to wall clock steps between syncs."""

    def __init__(self):
        self.offset = 0
        self.base = time.time_ns() - time.perf_counter_ns()

    def sync(self, budget_s=10.0, rounds=2, gap_s=2.1):
        """Query every NTP server `rounds` times, at least gap_s apart (ntpd's default
        rate limit drops faster clients), giving up on further queries after budget_s."""
        deadline = time.monotonic() + budget_s
        addrs = {}
        for srv in NTP_SERVERS:
            if time.monotonic() > deadline:
                break
            try:
                addrs[srv] = socket.getaddrinfo(
                    srv, 123, socket.AF_INET, socket.SOCK_DGRAM
                )[0][4]
            except OSError:
                pass
        samples = {srv: [] for srv in addrs}
        round_start = None
        for _ in range(rounds):
            if round_start is not None:
                wait = round_start + gap_s - time.monotonic()
                if time.monotonic() + max(wait, 0) > deadline:
                    break
                time.sleep(max(wait, 0))
            round_start = time.monotonic()
            for srv, addr in addrs.items():
                if time.monotonic() > deadline:
                    break
                try:
                    samples[srv].append(sntp(addr))
                except OSError:
                    pass
        # Lowest delay wins per server
        per_server = [min(s, key=lambda x: x[1]) for s in samples.values() if s]
        if not per_server:
            log("NTP: WARNING no server reachable, keeping previous offset")
            return False
        offsets = [o for o, _ in per_server]
        self.offset = int(statistics.median(offsets))
        self.base = time.time_ns() + self.offset - time.perf_counter_ns()
        log(
            f"NTP: system clock offset {self.offset / MS:+.2f} ms "
            f"(spread {(max(offsets) - min(offsets)) / MS:.2f} ms over {len(offsets)} servers)"
        )
        return True

    def drifted(self, limit_ns=20 * MS):
        """True if the wall clock moved relative to our mapping (suspend, clock step)."""
        return abs(time.time_ns() + self.offset - self.now_ns()) > limit_ns

    def now_ns(self):
        return time.perf_counter_ns() + self.base

    def sleep_until(self, t_ns, spin_ns=20 * MS):
        while (left := t_ns - self.now_ns()) > spin_ns:
            time.sleep(min((left - spin_ns) / S, 1.0))
        while self.now_ns() < t_ns:
            pass


def resolve(host, port):
    return socket.getaddrinfo(host, port, socket.AF_INET, socket.SOCK_STREAM)[0][4][0]


class Conn:
    def __init__(self, ip, host, port, ua, cookies, clock):
        self.ip, self.host, self.port, self.ua = ip, host, port, ua
        # Shared between connections to the same host so all carry the same session
        self.cookies = cookies
        self.clock = clock
        # True time (ns) after which blocking socket operations give up
        self.deadline = None
        self.ctx = ssl.create_default_context()
        self.ctx.set_alpn_protocols(["http/1.1"])
        self.sock = None

    def origin(self):
        return f"https://{self.host}" + ("" if self.port == 443 else f":{self.port}")

    def timeout(self):
        if self.deadline is None:
            return 60
        left = (self.deadline - self.clock.now_ns()) / S
        if left <= 0:
            raise TimeoutError("deadline reached")
        return left

    def connect(self):
        ip = self.ip or resolve(self.host, self.port)
        raw = socket.create_connection((ip, self.port), timeout=self.timeout())
        raw.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        self.sock = self.ctx.wrap_socket(raw, server_hostname=self.host)

    def close(self):
        if self.sock:
            self.sock.close()
            self.sock = None

    def alive(self):
        """False if the server closed the idle connection."""
        if self.sock is None:
            return False
        try:
            readable, _, _ = select.select([self.sock], [], [], 0)
            if not readable and not self.sock.pending():
                return True
            # Readable can also mean TLS records without application data (TLS 1.3
            # session tickets); a non-blocking read consumes those and tells them apart
            self.sock.setblocking(False)
            try:
                self.sock.recv(1)  # EOF or unsolicited data: unusable either way
                return False
            except (ssl.SSLWantReadError, BlockingIOError):
                return True
            finally:
                self.sock.setblocking(True)
        except (OSError, ValueError):
            return False

    def build(self, method, path):
        lines = [
            f"{method} {path} HTTP/1.1",
            f"Host: {self.host}" + ("" if self.port == 443 else f":{self.port}"),
            f"User-Agent: {self.ua}",
            "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language: de,en;q=0.7",
            "Connection: keep-alive",
        ]
        if self.cookies:
            lines.append(
                "Cookie: " + "; ".join(f"{k}={v}" for k, v in self.cookies.items())
            )
        return ("\r\n".join(lines) + "\r\n\r\n").encode()

    def set_cookie(self, header):
        pair, *attrs = header.split(";")
        name, _, value = pair.partition("=")
        name = name.strip()
        attrs = {
            k.strip().lower(): v.strip()
            for k, _, v in (a.partition("=") for a in attrs)
        }
        expired = False
        if "max-age" in attrs:  # takes precedence over Expires
            age = attrs["max-age"]
            expired = age.lstrip("-").isdigit() and int(age) <= 0
        elif "expires" in attrs:
            try:
                expires = email.utils.parsedate_to_datetime(attrs["expires"])
                if expires.tzinfo is None:  # "-0000" means UTC, not local time
                    expires = expires.replace(tzinfo=dt.timezone.utc)
                expired = expires.timestamp() < time.time()
            except (TypeError, ValueError):
                pass
        if expired:
            self.cookies.pop(name, None)
        else:
            self.cookies[name] = value.strip()

    def read(self, method):
        self.sock.settimeout(self.timeout())
        r = http.client.HTTPResponse(self.sock, method=method)
        r.begin()
        body = r.read()
        for k, v in r.getheaders():
            if k.lower() == "set-cookie":
                self.set_cookie(v)
        if r.will_close:
            self.close()
        return r, body

    def roundtrip(self, method, path):
        if self.sock is None:
            self.connect()
        self.sock.settimeout(self.timeout())
        self.sock.sendall(self.build(method, path))
        return self.read(method)


class Hosts:
    """Cookie jars and connections per host, for redirects to other hosts (a queue)."""

    def __init__(self, ua, clock):
        self.ua, self.clock = ua, clock
        self.jars = {}
        self.conns = {}

    def jar(self, host):
        return self.jars.setdefault(host, {})

    def conn(self, host, port):
        if (host, port) not in self.conns:
            self.conns[host, port] = Conn(
                None, host, port, self.ua, self.jar(host), self.clock
            )
        return self.conns[host, port]


def send(conn, clock, data):
    """Send a prepared request on the warm connection, or a fresh one if it is gone."""
    if conn.sock is not None:
        try:
            t = clock.now_ns()
            conn.sock.sendall(data)
            return t
        except OSError as e:
            log(f"send on warm connection failed ({e!r}), reconnecting")
            conn.close()
    conn.connect()
    t = clock.now_ns()
    conn.sock.sendall(data)
    return t


def exchange(conn, clock, data, on_sent):
    """Send and read one response; resend once on a fresh connection if the warm
    one turns out to have been dropped by the server."""
    t = send(conn, clock, data)
    on_sent(t)
    try:
        r, body = conn.read("GET")
    except DROPPED as e:
        log(f"warm connection was dead ({e!r}), resending on a fresh one")
        conn.close()
        t = send(conn, clock, data)
        on_sent(t)
        r, body = conn.read("GET")
    return t, r, body


def tcp_rtt_ns(clock, ip, port, n, deadline):
    """TCP handshake times; never blocks past deadline (true time, ns)."""
    rtts = []
    for i in range(n):
        left = (deadline - clock.now_ns()) / S
        if left < 0.05:
            log(f"RTT: out of time after {i} probes")
            break
        try:
            p0 = time.perf_counter_ns()
            socket.create_connection((ip, port), timeout=min(5, left)).close()
            rtts.append(time.perf_counter_ns() - p0)
        except OSError as e:
            log(f"RTT: probe failed: {e!r}")
        if i < n - 1:
            time.sleep(max(0, min(0.2, (deadline - clock.now_ns()) / S)))
    return rtts


def dump_html(label, body, prefix):
    log(f"{label}: ---- HTML begin ({len(body)} bytes) ----")
    for line in body.decode("utf-8", "replace").splitlines():
        log(f"{prefix}{line}", stamp=False)
    log(f"{label}: ---- HTML end ----")


def dump_response(label, r, body, prefix):
    log(f"{label}: HTTP {r.status} {r.reason}")
    for k, v in r.getheaders():
        log(f"{label}: header {k}: {v}")
    dump_html(label, body, prefix)


def follow(conn, hosts, cur, r, body, label=None, prefix="HTML| ", max_hops=6):
    """Follow redirects (also to other hosts) from an already read response; dump each
    hop if labelled. Returns (hops, conn of the final hop, final path, final body)."""
    hops = []
    for i in range(max_hops + 1):
        url = conn.origin() + cur
        hops.append(f"{r.status} {url}")
        if label:
            dump_response(f"{label} {url}", r, body, prefix)
        loc = r.getheader("Location")
        if not (300 <= r.status < 400 and loc):
            break
        if i == max_hops:
            hops.append(f"-> {loc} (too many redirects, not followed)")
            break
        nxt = urlsplit(urljoin(url, loc))
        if nxt.scheme != "https":
            hops.append(f"-> {loc} (not https, not followed)")
            break
        if (nxt.hostname, nxt.port or 443) != (conn.host, conn.port):
            log(f"{label or 'redirect'}: CROSS-HOST redirect {url} -> {loc}")
            conn = hosts.conn(nxt.hostname, nxt.port or 443)
        cur = (nxt.path or "/") + (f"?{nxt.query}" if nxt.query else "")
        r, body = conn.roundtrip("GET", cur)
    return hops, conn, cur, body


def settled_fetch(conn, hosts, path, tries=3):
    """GET until no cookie changes (e.g. the one-time /intro/ gate), so the result
    matches what a request carrying the same cookies will see."""
    for _ in range(tries):
        before = json.dumps(hosts.jars, sort_keys=True)
        r, body = conn.roundtrip("GET", path)
        hops, fconn, cur, body = follow(conn, hosts, path, r, body)
        if json.dumps(hosts.jars, sort_keys=True) == before:
            break
    return hops, fconn, cur, body


def fingerprint(host, cur, body):
    # Masked CSRF tokens, nonces, session/hash-like tokens, data-now and asset
    # version stamps change on every request
    body = re.sub(rb'(name="csrfmiddlewaretoken" value=")[^"]*', rb"\1", body)
    body = re.sub(rb'(nonce=")[^"]*', rb"\1", body)
    body = re.sub(rb"[A-Za-z0-9+/_=-]{20,}", b"T", body)
    return host, cur, re.sub(rb"\d+", b"0", body)


def describe_diff(a, b):
    """Where two fingerprints differ, for evaluating the closed-page detection later."""
    if a[:2] != b[:2]:
        return f"url {a[0]}{a[1]} vs {b[0]}{b[1]}"
    x, y = a[2], b[2]
    i = next((i for i, (p, q) in enumerate(zip(x, y)) if p != q), min(len(x), len(y)))
    lo = max(0, i - 100)
    return (
        f"bodies ({len(x)} vs {len(y)} bytes masked) differ at {i}: "
        f"{x[lo : i + 100]!r} vs {y[lo : i + 100]!r}"
    )


def browser_js(cookies, url):
    # Refuses to navigate if any cookie did not stick, instead of silently
    # continuing with a new session
    return (
        "((c,u)=>{for(const[k,v]of Object.entries(c))"
        "document.cookie=`${k}=${v}; path=/; secure; max-age=2592000`;"
        "const have=document.cookie.split('; ');"
        "const miss=Object.entries(c).filter(([k,v])=>!have.includes(`${k}=${v}`)).map(([k])=>k);"
        "if(miss.length)alert('cookies not set (clear site data, retry): '+miss.join(', '));"
        "else if(u)location.href=u;else alert('cookies set')})"
        f"({json.dumps(cookies)},{json.dumps(url)})"
    )


def write_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f)


def main():
    global LOG_CLOCK
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--url", default="https://tickets.events.ccc.de/40c3/")
    ap.add_argument(
        "--at", default="2026-11-08T11:00:00+01:00", help="ISO time the shop opens"
    )
    ap.add_argument(
        "--in", dest="in_s", type=float, help="test mode: target = now + N seconds"
    )
    ap.add_argument(
        "--min-offset-ms",
        type=float,
        default=-48.0,
        help="arrive uniformly in [min, max] ms relative to target (negative: before)",
    )
    ap.add_argument("--max-offset-ms", type=float, default=52.0)
    ap.add_argument(
        "--second-at-ms",
        type=float,
        default=60.0,
        help="if the first response is the closed shop page, send a second request "
        "on another warm connection, arriving no earlier than N ms after target",
    )
    ap.add_argument(
        "--late-window",
        type=float,
        default=600,
        help="if started up to N s late, fire immediately",
    )
    ap.add_argument("--user-agent", default=UA)
    ap.add_argument("--state-dir", default=os.environ.get("STATE_DIRECTORY", "."))
    a = ap.parse_args()
    if not a.min_offset_ms <= a.max_offset_ms:
        ap.error("need --min-offset-ms <= --max-offset-ms")

    u = urlsplit(a.url)
    host, port, path = u.hostname, u.port or 443, u.path or "/"
    offset_ms = random.SystemRandom().uniform(a.min_offset_ms, a.max_offset_ms)

    clock = LOG_CLOCK = Clock()
    if a.in_s is not None:
        target = clock.now_ns() + int(a.in_s * S)
    else:
        target = int(dt.datetime.fromisoformat(a.at).timestamp() * S)
    arrive = target + int(offset_ms * MS)

    def rel(t):
        return f"T{(t - target) / MS:+.3f} ms"

    marker = os.path.join(a.state_dir, f"fired-{target // S}.json")
    if os.path.exists(marker):
        with open(marker) as f:
            log(f"already fired for this target, not firing again. Result: {f.read()}")
        return

    log(
        f"target {fmt(target)}, random offset {offset_ms:+.3f} ms -> arrival {fmt(arrive)}, url {a.url}"
    )
    # Unsynced wall clock: good enough to decide whether there is time to prepare
    left = (arrive - clock.now_ns()) / S
    if -left > a.late_window:
        log(
            f"target passed {-left:.0f}s ago (> late window {a.late_window:.0f}s), doing nothing"
        )
        return

    hosts = Hosts(a.user_agent, clock)
    one_way, ip, baseline, pre_body = None, None, None, None
    conn = conn2 = None
    if left <= PREP_S:
        # Typically a restart after a crash close to (or past) T: every second counts,
        # so no NTP sync, no session warmup and no baseline (hence no second shot)
        log(f"only {left:.1f}s to arrival, skipping preparation")
        ip = resolve(host, port)
        conn = Conn(ip, host, port, a.user_agent, hosts.jar(host), clock)
        conn.deadline = arrive - DEFAULT_ONE_WAY
        try:
            conn.connect()
        except OSError as e:
            log(f"connect failed ({e!r}), will retry at fire time")
        conn.deadline = None
    else:
        clock.sync()
        # Waiting phase: refresh NTP + latency periodically, more often as T approaches.
        # Nothing here may run into the preparation phase.
        last_ntp, last_rtt = time.monotonic(), 0
        prep_start = arrive - (PREP_S + 1) * S
        while (left := (arrive - clock.now_ns()) / S) > PREP_S:
            ntp_every = 600 if left > 900 else 60
            rtt_every = 300 if left > 900 else 60
            spare = (prep_start - clock.now_ns()) / S
            if (
                spare > 3
                and (time.monotonic() - last_ntp > ntp_every or clock.drifted())
                and clock.sync(budget_s=min(10, spare - 2))
            ):
                last_ntp = time.monotonic()
            spare = (prep_start - clock.now_ns()) / S
            if spare > 3 and time.monotonic() - last_rtt > rtt_every:
                try:
                    ip = resolve(host, port)
                    rtts = tcp_rtt_ns(clock, ip, port, 3, prep_start - 1 * S)
                    if rtts:
                        one_way = int(statistics.median(rtts) / 2)
                        log(
                            f"RTT: {host} ({ip}) {[round(x / MS, 1) for x in rtts]} ms -> one-way {one_way / MS:.2f} ms"
                        )
                        last_rtt = time.monotonic()
                except OSError as e:
                    log(f"RTT: failed: {e!r}")
            left = (arrive - clock.now_ns()) / S
            if int(left) % 300 < 5 or left < 120:
                log(f"waiting, {left:.0f}s to go")
            time.sleep(min(5, max(0, left - PREP_S)))

        # Preparation: fresh session, latency, pre-sale baseline, second connection.
        # Nothing here may block past arrive - 3 s.
        prep_deadline = arrive - 3 * S
        ip = ip or resolve(host, port)
        conn = Conn(ip, host, port, a.user_agent, hosts.jar(host), clock)
        conn2 = Conn(ip, host, port, a.user_agent, hosts.jar(host), clock)
        conn.deadline = conn2.deadline = prep_deadline
        for c in hosts.conns.values():
            c.deadline = prep_deadline
        try:
            hops, fconn, cur, body = settled_fetch(conn, hosts, path)
            baseline, pre_body = fingerprint(fconn.host, cur, body), body
            log(f"warmup: {' | '.join(hops)} cookies={hosts.jars}")
            rtts = tcp_rtt_ns(clock, ip, port, 3, prep_deadline)
            if rtts:
                one_way = int(statistics.median(rtts) / 2)
                log(
                    f"RTT final: {[round(x / MS, 1) for x in rtts]} ms -> one-way {one_way / MS:.2f} ms"
                )
            if arrive - clock.now_ns() > 16 * S:
                # Baseline with the same cookies the shot carries; also refreshes keep-alive
                clock.sleep_until(arrive - 15 * S)
                for c in hosts.conns.values():
                    c.deadline = prep_deadline
                hops, fconn, cur, body = settled_fetch(conn, hosts, path)
                baseline, pre_body = fingerprint(fconn.host, cur, body), body
                log(f"pre-sale baseline: {' | '.join(hops)} cookies={hosts.jars}")
        except (OSError, http.client.HTTPException) as e:
            log(f"warmup failed ({e!r}), will reconnect before firing")
            conn.close()
        try:
            for c in hosts.conns.values():
                c.deadline = prep_deadline
            r, body = conn2.roundtrip("GET", path)
            hops, _, _, _ = follow(conn2, hosts, path, r, body)
            log(f"second connection warm: {' | '.join(hops)}")
        except (OSError, http.client.HTTPException) as e:
            log(f"warming second connection failed ({e!r})")
            conn2.close()
        for c in [conn, conn2, *hosts.conns.values()]:
            c.deadline = None
        if baseline:
            with open(os.path.join(a.state_dir, f"pre-{target // S}.html"), "wb") as f:
                f.write(pre_body)
            dump_html("pre-sale page", pre_body, "PREHTML| ")

    one_way = one_way if one_way is not None else DEFAULT_ONE_WAY
    send_at = arrive - one_way

    if conn2 is not None:
        # Replace connections the server dropped while idle, without delaying the shot
        clock.sleep_until(arrive - 1 * S)
        buffer_logs()
        for name, c in (("first", conn), ("second", conn2)):
            c.deadline = send_at
            try:
                if not c.alive():
                    log(f"{name} connection not alive, reconnecting")
                    c.close()
                    c.connect()
            except OSError as e:
                log(f"reconnecting {name} connection failed ({e!r})")
                c.close()
            finally:
                c.deadline = None
    buffer_logs()

    data = conn.build("GET", path)
    result = {
        "target": fmt(target),
        "offset_ms": offset_ms,
        "one_way_ms": one_way / MS,
        "hops": [],
    }

    def mark_sent(t):
        # The marker exists as soon as anything went out, so a crash never refires
        if "sent" not in result:
            result["sent"] = fmt(t)
            write_json(marker, result)
        log(
            f"FIRED: sent at {rel(t)} (scheduled {rel(send_at)}), "
            f"expected arrival {rel(t + one_way)}"
        )

    clock.sleep_until(send_at)
    try:
        _, r, body = exchange(conn, clock, data, mark_sent)
        result["first_response"] = rel(clock.now_ns())
        log(f"first response read at {result['first_response']}")
        result["hops"], fconn, cur, body = follow(
            conn, hosts, path, r, body, "response"
        )
        fp = fingerprint(fconn.host, cur, body)
        if baseline and fp == baseline:
            log("SECOND: first response is still the closed shop page")
            # Arriving too early again would only fetch the closed page once more
            clock.sleep_until(target + int(a.second_at_ms * MS) - one_way)

            def mark_second(t):
                result["second"] = {"sent": fmt(t)}
                log(f"SECOND: sent at {rel(t)}")

            _, r, body = exchange(conn2, clock, conn2.build("GET", path), mark_second)
            result["second"]["response"] = rel(clock.now_ns())
            log(f"SECOND: response read at {result['second']['response']}")
            hops, fconn, cur, body = follow(
                conn2, hosts, path, r, body, "second", "SECONDHTML| "
            )
            fp = fingerprint(fconn.host, cur, body)
            result["second"] |= {"hops": hops, "still_closed": fp == baseline}
        elif baseline:
            log(f"first response is not the closed page: {describe_diff(baseline, fp)}")
        else:
            log("no baseline, closed-page detection skipped")
        result["final_url"] = fconn.origin() + cur
        with open(os.path.join(a.state_dir, f"page-{target // S}.html"), "wb") as f:
            f.write(body)
    except Exception as e:  # noqa: BLE001 - must never refire, just report
        if "sent" not in result:
            raise  # nothing went out: let systemd restart us, which fires immediately
        result["error"] = repr(e)
        log(f"reading response failed: {e!r}")
    finally:
        flush_logs()
    result["cookies"] = hosts.jars

    write_json(marker, result)
    log(f"RESULT: {json.dumps(result)}")
    for h, jar in hosts.jars.items():
        for k, v in jar.items():
            log(f"COOKIE: {h}: {k}={v}")
    # Scripts cannot overwrite HttpOnly cookies, so this needs a page on each host
    # that sets none (robots.txt) in a fresh private window. The final host goes last,
    # its snippet navigates to the final URL.
    final = urlsplit(result.get("final_url", a.url))
    order = sorted(hosts.jars, key=lambda h: h == final.hostname)
    for h in order:
        if not hosts.jars[h] and h != final.hostname:
            continue
        url = result.get("final_url", a.url) if h == final.hostname else None
        log(
            f"BROWSER: in the same fresh private window open https://{h}/robots.txt , "
            f"then paste the BROWSERJS {h} line into the devtools console"
        )
        log(f"BROWSERJS {h}: {browser_js(hosts.jars[h], url)}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    finally:
        flush_logs()
