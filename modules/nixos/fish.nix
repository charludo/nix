{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.fish;
in
{
  options.fish = {
    enable = lib.mkEnableOption (lib.mdDoc "enable fish shell and make user default");
  };

  config = mkIf cfg.enable {
    programs.fish.enable = true;
    users.defaultUserShell = pkgs.fish;
  };
}
