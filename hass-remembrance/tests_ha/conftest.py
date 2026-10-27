"""A real Home Assistant core per test, with this integration as a custom
component. Needs Home Assistant installed (see the repo's test env)."""

from pathlib import Path

import pytest
from homeassistant import loader
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
    loader.async_setup(hass)
    hass.config_entries = ConfigEntries(hass, {})
    assert await async_load_base_functionality(hass)
    assert await async_setup_component(hass, "homeassistant", {})
    return hass


async def setup(hass: HomeAssistant, config: dict) -> None:
    assert await async_setup_component(hass, "remembrance", {"remembrance": config})
    await hass.async_block_till_done()


@pytest.fixture
async def hass(tmp_path):
    hass = await start_hass(tmp_path)
    yield hass
    await hass.async_stop(force=True)
