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
    ];
    # ha-bambulab's pybambu imports `paho.mqtt.client` directly, but its
    # manifest.json doesn't list paho-mqtt under `requirements`, so
    # nothing else pulls it into HA's Python env. Without this the
    # config flow blows up with "No module named 'paho'".
    services.home-assistant.extraPackages = python3Packages: [
      python3Packages.paho-mqtt
    ];
  };
}
