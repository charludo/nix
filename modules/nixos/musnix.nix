{ config, lib, ... }:

with lib;
let
  cfg = config.musnix;
in
{
  options.musnix = {
    enable = lib.mkEnableOption (lib.mdDoc "enable musnix optimizations");
  };

  config = mkIf cfg.enable {
    musnix = {
      enable = true;
      alsaSeq.enable = false;

      rtcqs.enable = true;
      kernel.realtime = true;

      rtirq = {
        resetAll = 1;
        prioLow = 0;
        enable = true;
        nameList = "rtc0 snd";
      };
    };
  };
}
