{
  config,
  lib,
  private-settings,
  ...
}:

with lib;
let
  inherit (config.networking) hostName;
  isClean = inputs.self ? rev;
  flakeURL = "git+ssh://forgejo@git.${private-settings.domains.home}/charlotte/nix.git";

  cfg = config.autoUpdate;
in
{
  options.autoUpdate = {
    enable = lib.mkEnableOption (lib.mdDoc "enable automatic updates");
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = {
      enable = isClean;
      dates = "hourly";
      flags = [ "--refresh" ];
      flake = "${flakeURL}#${hostName}";
      persistent = true;
      allowReboot = true;
      rebootWindow = {
        lower = "01:00";
        upper = "04:00";
      };
    };
  };
}
