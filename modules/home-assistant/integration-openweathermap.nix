{ lib, config, ... }:
let
  cfg = config.hass.openweathermap;
in
{
  options.hass.openweathermap.enable = lib.mkEnableOption "OpenWeatherMap weather integration";

  config = lib.mkIf cfg.enable {
    services.home-assistant.extraComponents = [
      "openweathermap"
    ];
  };
}
