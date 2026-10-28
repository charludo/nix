"""A real Home Assistant core per test, with this integration as a custom
component, and a real Radicale as CalDAV server. Needs Home Assistant,
caldav and radicale installed (see the repo's test env)."""

import os
import socket
import subprocess
import time
from pathlib import Path

import pytest
from homeassistant import loader
from homeassistant.auth import auth_manager_from_config
from homeassistant.bootstrap import async_load_base_functionality
from homeassistant.config_entries import ConfigEntries
from homeassistant.core import HomeAssistant
from homeassistant.setup import async_setup_component

PKG_DIR = Path(__file__).resolve().parent.parent / "custom_components" / "remembrance"


async def start_hass(config_dir: Path) -> HomeAssistant:
    custom = config_dir / "custom_components"
    custom.mkdir(exist_ok=True)
    if not (custom / "remembrance").exists():
        (custom / "remembrance").symlink_to(PKG_DIR)
    hass = HomeAssistant(str(config_dir))
    hass.config.skip_pip = True
    await hass.config.async_set_time_zone("Europe/Berlin")
    loader.async_setup(hass)
    hass.config_entries = ConfigEntries(hass, {})
    assert await async_load_base_functionality(hass)
    # For http, which the calendar platform needs.
    hass.auth = await auth_manager_from_config(hass, [], [])
    assert await async_setup_component(hass, "homeassistant", {})
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        port = sock.getsockname()[1]
    assert await async_setup_component(
        hass, "http", {"http": {"server_host": "127.0.0.1", "server_port": port}}
    )
    return hass


async def setup(hass: HomeAssistant, config: dict) -> None:
    assert await async_setup_component(hass, "remembrance", {"remembrance": config})
    await hass.async_block_till_done()


@pytest.fixture
async def hass(tmp_path):
    hass = await start_hass(tmp_path)
    yield hass
    await hass.async_stop(force=True)


class Radicale:
    """A throwaway Radicale with one calendar, and a client to look at it."""

    def __init__(self, root: Path) -> None:
        import caldav

        root.mkdir(parents=True, exist_ok=True)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            port = sock.getsockname()[1]
        config = root / "radicale.conf"
        config.write_text(
            f"[server]\nhosts = 127.0.0.1:{port}\n[auth]\ntype = none\n"
            f"[storage]\nfilesystem_folder = {root}/collections\n"
        )
        self.process = subprocess.Popen(
            ["radicale", "--config", str(config)],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            env={**os.environ, "HOME": str(root)},
        )
        self.url = f"http://127.0.0.1:{port}/"
        for _ in range(100):
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                    break
            except OSError:
                time.sleep(0.05)
        client = caldav.DAVClient(self.url, username="test", password="x")
        self.calendar = client.principal().make_calendar(name="HA")
        self.calendar_url = str(self.calendar.url)

    def config(self) -> dict:
        return {
            "url": self.calendar_url,
            "username": "test",
            "password": "x",
        }

    def events(self) -> list[str]:
        return [e.data for e in self.calendar.events()]

    def put(self, ics: str) -> str:
        return str(self.calendar.save_event(ics).url)

    def stop(self) -> None:
        self.process.terminate()
        self.process.wait()


@pytest.fixture
def radicale(tmp_path):
    server = Radicale(tmp_path / "dav")
    yield server
    server.stop()
