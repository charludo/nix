{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.eid;
in
{
  options.eid = {
    enable = lib.mkEnableOption (lib.mdDoc "enable usage of the Belgian EID");
  };

  config = mkIf cfg.enable {
    services.pcscd.enable = true;
    environment.systemPackages = [ pkgs.eid-mw ];
  };
}
