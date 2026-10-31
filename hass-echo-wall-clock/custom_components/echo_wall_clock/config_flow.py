"""Adding a clock: one BlueZ already knows, or one in pairing mode."""

from __future__ import annotations

import asyncio
from typing import Any

import voluptuous as vol
from homeassistant.config_entries import (
    ConfigFlow,
    ConfigFlowResult,
    OptionsFlow,
)
from homeassistant.core import callback
from homeassistant.helpers.selector import (
    NumberSelector,
    NumberSelectorConfig,
    NumberSelectorMode,
    SelectOptionDict,
    SelectSelector,
    SelectSelectorConfig,
)

from .bluez import Adapter, Bluez, BluezError, Candidate, sockets_supported
from .const import (
    CONF_ADAPTER,
    CONF_ADDRESS,
    CONF_RING_FOR,
    DEFAULT_RING_FOR,
    DOMAIN,
    SCAN_SECONDS,
)

SCAN = "scan"


def _label(candidate: Candidate) -> str:
    return f"{candidate.name or 'Echo Wall Clock'} ({candidate.address})"


class EchoWallClockConfigFlow(ConfigFlow, domain=DOMAIN):
    VERSION = 1

    def __init__(self) -> None:
        self._bluez: Bluez | None = None
        self._adapters: list[Adapter] = []
        self._adapter: Adapter | None = None
        self._candidates: dict[str, Candidate] = {}
        self._chosen: Candidate | None = None
        self._task: asyncio.Task | None = None
        self._progress_shown = False
        self._error: str | None = None

    @staticmethod
    @callback
    def async_get_options_flow(config_entry) -> OptionsFlow:
        return EchoWallClockOptionsFlow()

    @callback
    def async_remove(self) -> None:
        if self._task and not self._task.done():
            self._task.cancel()
        if self._bluez:
            self._bluez.close()

    async def _then(self, step_id: str) -> ConfigFlowResult:
        """After a background task: through "progress done" if progress was
        shown (it must follow one), straight on if the task was already done."""
        if self._progress_shown:
            self._progress_shown = False
            return self.async_show_progress_done(next_step_id=step_id)
        return await getattr(self, f"async_step_{step_id}")()

    def _unconfigured(self, candidates: list[Candidate]) -> dict[str, Candidate]:
        configured = {e.unique_id for e in self._async_current_entries(include_ignore=False)}
        return {c.address: c for c in candidates if c.address.upper() not in configured}

    # --- start: which adapter, which clock ------------------------------------

    async def async_step_user(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if not sockets_supported():
            return self.async_abort(reason="no_bluetooth_sockets")
        if self._bluez is None:
            self._bluez = Bluez()
            try:
                await self._bluez.connect()
                self._adapters = [a for a in await self._bluez.adapters() if a.powered]
            except BluezError:
                return self.async_abort(reason="no_bluez")
        if not self._adapters:
            return self.async_abort(reason="no_adapter")
        if len(self._adapters) == 1:
            self._adapter = self._adapters[0]
            return await self.async_step_known()
        return await self.async_step_adapter()

    async def async_step_adapter(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            self._adapter = next(a for a in self._adapters if a.path == user_input[CONF_ADAPTER])
            return await self.async_step_known()
        options = [
            SelectOptionDict(value=a.path, label=f"{a.name} ({a.address})") for a in self._adapters
        ]
        return self.async_show_form(
            step_id="adapter",
            data_schema=vol.Schema(
                {vol.Required(CONF_ADAPTER): SelectSelector(SelectSelectorConfig(options=options))}
            ),
        )

    async def async_step_known(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        """Clocks this adapter has paired before; or look for a new one."""
        if user_input is not None:
            if user_input[CONF_ADDRESS] == SCAN:
                return await self.async_step_prepare()
            self._chosen = self._candidates[user_input[CONF_ADDRESS]]
            return await self._create()
        try:
            known = await self._bluez.clocks()
        except BluezError:
            return self.async_abort(reason="no_bluez")
        self._candidates = self._unconfigured(
            [c for c in known if c.paired and c.adapter == self._adapter.path]
        )
        if not self._candidates:
            return await self.async_step_prepare()
        options = [
            SelectOptionDict(value=c.address, label=_label(c)) for c in self._candidates.values()
        ]
        options.append(SelectOptionDict(value=SCAN, label=SCAN))
        return self.async_show_form(
            step_id="known",
            data_schema=vol.Schema(
                {
                    vol.Required(CONF_ADDRESS): SelectSelector(
                        SelectSelectorConfig(options=options, translation_key="known")
                    )
                }
            ),
        )

    # --- a new clock: scan, pick, pair ----------------------------------------

    async def async_step_prepare(
        self, user_input: dict[str, Any] | None = None
    ) -> ConfigFlowResult:
        if user_input is not None:
            return await self.async_step_scan()
        return self.async_show_form(
            step_id="prepare",
            errors={"base": self._error} if self._error else None,
        )

    async def async_step_scan(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if self._task is None:
            self._task = self.hass.async_create_task(
                self._bluez.discover(self._adapter.path, SCAN_SECONDS)
            )
        if not self._task.done():
            self._progress_shown = True
            return self.async_show_progress(
                step_id="scan", progress_action="scan", progress_task=self._task
            )
        task, self._task = self._task, None
        try:
            found = task.result()
        except BluezError:
            self._error = "scan_failed"
            return await self._then("prepare")
        self._candidates = self._unconfigured(found)
        if not self._candidates:
            self._error = "none_found"
            return await self._then("prepare")
        self._error = None
        return await self._then("pick")

    async def async_step_pick(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is not None or len(self._candidates) == 1:
            address = user_input[CONF_ADDRESS] if user_input else next(iter(self._candidates))
            self._chosen = self._candidates[address]
            return await self.async_step_pair()
        options = [
            SelectOptionDict(value=c.address, label=_label(c)) for c in self._candidates.values()
        ]
        return self.async_show_form(
            step_id="pick",
            data_schema=vol.Schema(
                {vol.Required(CONF_ADDRESS): SelectSelector(SelectSelectorConfig(options=options))}
            ),
        )

    async def async_step_pair(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if self._task is None:
            self._task = self.hass.async_create_task(
                self._bluez.pair(self._adapter.path, self._chosen.address)
            )
        if not self._task.done():
            self._progress_shown = True
            return self.async_show_progress(
                step_id="pair", progress_action="pair", progress_task=self._task
            )
        task, self._task = self._task, None
        try:
            task.result()
        except BluezError:
            self._error = "pair_failed"
            return await self._then("prepare")
        return await self._then("finish")

    async def async_step_finish(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        return await self._create()

    async def _create(self) -> ConfigFlowResult:
        address = self._chosen.address.upper()
        await self.async_set_unique_id(address)
        self._abort_if_unique_id_configured()
        return self.async_create_entry(
            title=self._chosen.name or "Echo Wall Clock",
            data={CONF_ADDRESS: address, CONF_ADAPTER: self._adapter.path},
        )


class EchoWallClockOptionsFlow(OptionsFlow):
    async def async_step_init(self, user_input: dict[str, Any] | None = None) -> ConfigFlowResult:
        if user_input is not None:
            return self.async_create_entry(data={CONF_RING_FOR: int(user_input[CONF_RING_FOR])})
        current = self.config_entry.options.get(CONF_RING_FOR, DEFAULT_RING_FOR)
        return self.async_show_form(
            step_id="init",
            data_schema=vol.Schema(
                {
                    vol.Required(CONF_RING_FOR, default=current): NumberSelector(
                        NumberSelectorConfig(
                            min=10,
                            max=3600,
                            step=10,
                            unit_of_measurement="s",
                            mode=NumberSelectorMode.BOX,
                        )
                    )
                }
            ),
        )
