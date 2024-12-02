# Home Assistant — Nix Migration Plan

## Goal

Fully Nix-defined Home Assistant VM on Proxmox, replacing the HASS OS Raspberry Pi installation. The immediate target is a VM that:

1. Runs the `home-assistant` service with ZHA (Zigbee Home Automation) via USB passthrough
2. Declares all Zigbee devices in Nix and derives entity IDs automatically from their MAC addresses
3. Renders the main dashboard (`lovelace.the_future`) entirely from Nix, with no hand-edited YAML

## Architecture

```
modules/home-assistant/
  default.nix        # NixOS module: HASS service defaults, lovelacePackages
  devices.nix        # options.homeAssistant.devices + entity derivation logic

lib/
  home-assistant.nix # Card builder functions (mkStyles, mkToggleCard, mkActionCard, …)
  default.nix        # exports lib.ha = import ./home-assistant.nix

vms/
  SRV-HOMEASSISTANT.nix  # VM config + devices + lovelace dashboard
```

## Key Decisions

- **No temp files.** All config goes through NixOS module options. `services.home-assistant.config` serialises to `configuration.yaml` in the Nix store; `lovelaceConfig` similarly. No hand-managed YAML.
- **ZHA via USB passthrough.** No Zigbee2MQTT. The Zigbee coordinator USB device passes through from Proxmox to the VM; the existing `zigbee.db` (device pairings) migrates from the Pi.
- **Custom cards via nixpkgs.** `pkgs.home-assistant-custom-lovelace-modules` bundles all required HACS cards (button-card, mushroom, mini-graph, swipe-card, my-slider-v2, …). No HACS runtime.
- **Dashboard is the default lovelace view.** The "the_future" dashboard becomes the single `services.home-assistant.lovelaceConfig`. Multiple named dashboards can be added later.

## Device Entity Derivation

Zigbee device MAC addresses → entity IDs:

```
MAC: 00:15:8d:00:09:45:19:da
  → Zigbee ID: 0x00158d0009451da  (colons stripped, 0x prefix)
  → sensor.0x00158d0009451da_temperature
  → sensor.0x00158d0009451da_humidity
```

Devices are declared with `homeAssistant.devices.<name>` (in the VM config). The `homeAssistant.entities` attrset is derived automatically and used to reference entity IDs in the dashboard config without hardcoding strings.

## Library Functions (`lib/home-assistant.nix`)

The `custom:button-card` styles format is extremely verbose JSON (`[{key: val}, {key: val}]` arrays). The lib converts Nix attrsets to this format:

```nix
ha.mkStyles { card = { "background-color" = "var(--yellow)"; height = "84px"; }; }
# → { card = [{"background-color": "var(--yellow)"}, {"height": "84px"}]; }
```

Higher-level helpers: `mkToggleCard`, `mkActionCard`, `mkTempTile`, `mkMiniGraph`, `mkConditional`, `mkNavCard`, `mkTitleCard`.

## Migration Steps

1. ~~Deploy VM, confirm HASS reachable at `192.168.24.13:8123`~~
2. ~~ZHA integration auto-discovers USB coordinator; migrate `zigbee.db` from Pi~~
3. ~~Confirm Zigbee devices appear with expected entity IDs~~
4. ~~Lovelace dashboard renders; confirm visual parity with `hass/homeassistant/data/.storage/lovelace.the_future`~~
5. Port automations (`automations.yaml`) to `services.home-assistant.config.automation`
6. Port scripts (`scripts.yaml`) to `services.home-assistant.config.script`
7. Port remaining integrations (Xiaomi fan, LG TV shell commands, Xiaomi cloud map extractor)
8. Decommission Raspberry Pi

## Credentials (TODO — needs agenix)

The following secrets from the HASS backup need to be managed via agenix before production use:

- Xiaomi Mi Fan: `host` + `token`
- Xiaomi Cloud Map Extractor: `host`, `token`, `username`, `password`
- (Trusted proxies and IP ban settings are non-secret)
