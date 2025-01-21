{ config, lib, ... }:

with lib;
let
  cfg = config.zammad;
in
{
  options.zammad = {
    enable = lib.mkEnableOption (lib.mdDoc "enable zammad (ugh)");
  };

  config = mkIf cfg.enable {
    sops.secrets.zammad = {
      mode = "0444";
      path = "/var/lib/zammad/secret";
    };
    services.zammad = {
      enable = true;
      openPorts = true;
      secretKeyBaseFile = config.sops.secrets.zammad.path;
    };
  };
}
