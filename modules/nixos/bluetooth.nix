{ config, lib, ... }:

with lib;
let
  cfg = config.bluetooth;
in
{
  options.bluetooth = {
    enable = lib.mkEnableOption "bluetooth config, incl. for keyboard";
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Experimental = true;
          FastConnectable = true;
          ReconnectAttempts = 7;
          ReconnectIntervals = "1, 2, 3";
        };
        Policy.AutoEnable = true;
      };
    };

    services.blueman.enable = true;
    boot.kernelParams = [ "hid_apple.fnmode=2" ];
  };
}
