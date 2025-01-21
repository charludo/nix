{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.printers;
in
{
  options.printers = {
    enable = lib.mkEnableOption (lib.mdDoc "enable printer config");
  };

  config = mkIf cfg.enable {
    services.printing.enable = true;
    services.printing.drivers = [ pkgs.brlaser ];

    services.avahi = {
      enable = true;
      nssmdns4 = true;
      openFirewall = true;
    };

    hardware.printers = {
      ensurePrinters = [
        {
          name = "Drucker";
          location = "Home";
          description = "Brother HL-L2375DW";
          deviceUri = "ipp://192.168.50.100";
          model = "drv:///brlaser.drv/brl2375w.ppd";
          ppdOptions = {
            PageSize = "A4";
            Duplex = "DuplexNoTumble";
          };
        }
      ];
      ensureDefaultPrinter = "Drucker";
    };
  };
}
