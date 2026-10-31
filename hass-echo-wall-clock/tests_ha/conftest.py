"""A real Home Assistant core per test, with this integration as a custom
component and BlueZ replaced by a simulated world of adapters and clocks."""

import asyncio
import sys
from pathlib import Path

import pytest
from homeassistant import loader
from homeassistant.bootstrap import async_load_base_functionality
from homeassistant.config_entries import ConfigEntries
from homeassistant.core import HomeAssistant
from homeassistant.setup import async_setup_component

ROOT = Path(__file__).resolve().parent.parent
PKG_DIR = ROOT / "custom_components" / "echo_wall_clock"


async def start_hass(config_dir: Path) -> HomeAssistant:
    custom = config_dir / "custom_components"
    custom.mkdir(exist_ok=True)
    if not (custom / "echo_wall_clock").exists():
        (custom / "echo_wall_clock").symlink_to(PKG_DIR)
    hass = HomeAssistant(str(config_dir))
    hass.config.skip_pip = True
    await hass.config.async_set_time_zone("Europe/Berlin")
    loader.async_setup(hass)
    hass.config_entries = ConfigEntries(hass, {})
    assert await async_load_base_functionality(hass)
    assert await async_setup_component(hass, "homeassistant", {})
    return hass


@pytest.fixture
async def hass(tmp_path, monkeypatch):
    hass = await start_hass(tmp_path)
    # The integration's modules import from the config dir, which HA has
    # put on sys.path by now; swap BlueZ out for the simulated world.
    import bluez_stub

    bluez_stub.install(monkeypatch)
    yield hass
    await hass.async_stop(force=True)
    for name in [m for m in sys.modules if m.startswith("custom_components")]:
        del sys.modules[name]


@pytest.fixture
def world(hass):
    import bluez_stub

    return bluez_stub.WORLD


async def until(check, timeout=3.0):
    end = asyncio.get_running_loop().time() + timeout
    while not check():
        assert asyncio.get_running_loop().time() < end, "timed out"
        await asyncio.sleep(0.02)
