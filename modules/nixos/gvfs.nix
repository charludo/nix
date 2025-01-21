{ config, lib, ... }:

with lib;
let
  cfg = config.gvfs;
in
{
  options.gvfs = {
    enable = lib.mkEnableOption (lib.mdDoc "enable Gnome Virtual File System");
  };

  config = mkIf cfg.enable {
    services.gvfs.enable = true;
    services.udisks2.enable = true;
  };
}
