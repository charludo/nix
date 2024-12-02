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
    enable = lib.mkEnableOption "Bambu Lab printer integration (greghesp/ha-bambulab)";
  };

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.custom-components.bambu_lab
      pkgs.ours.home-assistant.custom-components.custom_icons
    ];
    services.home-assistant.extraComponents = [
      "stream"
      "ffmpeg"
    ];
    services.home-assistant.config.custom_icons = { };
    services.home-assistant.config.ffmpeg = { };
    services.home-assistant.config.stream = {
      ll_hls = true;
      segment_duration = 2;
      part_duration = 0.2;
    };
    services.home-assistant.extraPackages = python3Packages: [
      python3Packages.paho-mqtt
    ];

    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/custom_icons - - - - ${../../home-assistant/assets/bambu_icons}"
    ];
  };
}
