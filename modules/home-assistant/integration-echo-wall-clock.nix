{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.echoWallClock;
in
{
  options.hass.echoWallClock.enable = lib.mkEnableOption ''
    the Echo Wall Clock integration: Home Assistant stands in for the clock's
    Echo over Classic Bluetooth (BlueZ). Clocks are added in the UI
  '';

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [ pkgs.ours.hass-echo-wall-clock ];
    services.home-assistant.config.logger.logs."custom_components.echo_wall_clock" = "debug";

    # The clock is Classic Bluetooth, through BlueZ over the system D-Bus
    # (whose policy lets any user talk to it, and BlueZ call back into HA).
    hardware.bluetooth.enable = true;

    # The module only allows Bluetooth sockets for integrations it knows of.
    systemd.services.home-assistant.serviceConfig.RestrictAddressFamilies = [ "AF_BLUETOOTH" ];
  };
}
