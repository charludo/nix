{ inputs, ... }:
{
  imports = [ inputs.musnix.nixosModules.musnix ];

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
}
