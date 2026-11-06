{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.labelprinter;
in
{
  options.hass.labelprinter.enable = lib.mkEnableOption ''
    the Brother P-touch label printer integration with its label editor panel.
    Printers are paired and added in the UI
  '';

  config = lib.mkIf cfg.enable {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.custom-components.brother_ptouch
    ];

    # Classic Bluetooth SPP, through BlueZ over the system D-Bus.
    hardware.bluetooth.enable = true;

    # The module only allows Bluetooth sockets for integrations it knows of.
    systemd.services.home-assistant.serviceConfig.RestrictAddressFamilies = [ "AF_BLUETOOTH" ];
  };
}
