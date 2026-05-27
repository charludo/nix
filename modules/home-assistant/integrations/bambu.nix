{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass.bambu;
in
{
  options.hass.bambu = {
    enable = lib.mkEnableOption "Bambu Lab printer integration (greghesp/ha-bambulab). The integration ships its custom frontend cards alongside the Python component, so no separate Lovelace module is needed.";
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.custom-components.bambu_lab
      pkgs.ours.home-assistant.custom-components.custom_icons
    ];
    # `stream` is core HA but not pulled in by default — Lovelace's
    # picture-glance camera_view=live needs the HLS playlist endpoint
    # this integration provides. Without it the frontend gets a
    # broken URL and shows the red exclamation.
    services.home-assistant.extraComponents = [
      "stream"
      # `ffmpeg` is declared in ha-bambulab's manifest deps, but on Nix
      # the integration ships fine without HA auto-loading it. Loading
      # it explicitly ensures the ffmpeg binary path is registered and
      # the camera proxy can spawn the decoder.
      "ffmpeg"
    ];
    # Force-load custom_icons at startup. Its `async_setup()` registers
    # the icon-serving frontend handler unconditionally (no config entry
    # required), so just having `custom_icons:` in configuration.yaml is
    # enough — and saves the UI add-integration dance.
    services.home-assistant.config.custom_icons = { };
    services.home-assistant.config.ffmpeg = { };
    services.home-assistant.config.stream = {
      ll_hls = true;
      segment_duration = 2;
      part_duration = 0.2;
    };
    # ha-bambulab's pybambu imports `paho.mqtt.client` directly, but its
    # manifest.json doesn't list paho-mqtt under `requirements`, so
    # nothing else pulls it into HA's Python env. Without this the
    # config flow blows up with "No module named 'paho'".
    services.home-assistant.extraPackages = python3Packages: [
      python3Packages.paho-mqtt
    ];

    # SVG icons (filament-N, humidity-index-N, humidity-level-{dark,light}-N)
    # served via thomasloven's custom_icons component, which reads from
    # ${configDir}/custom_icons/. Symlink in our nix-packaged copy.
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/custom_icons - - - - ${../config/assets/bambu_icons}"
    ];
  };
}
