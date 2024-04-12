# Shamelessly stolen from:  https://github.com/Misterio77/nix-config/blob/main/hosts/common/global/auto-upgrade.nix
{ config, inputs, pkgs, lib, ... }:
let
  inherit (config.networking) hostName;
  isClean = inputs.self ? rev;
  flakeURL = "github:charludo/nix";
in
{
  system.autoUpgrade = {
    enable = isClean;
    dates = "hourly";
    flags = [ "--refresh" ];
    flake = "${flakeURL}#${hostName}";
  };

  # Only run if current config (self) is older than the new one.
  systemd.services.nixos-upgrade = lib.mkIf config.system.autoUpgrade.enable {
    serviceConfig.ExecCondition = lib.getExe (
      pkgs.writeShellScriptBin "check-date" ''
        lastModified() {
          nix flake metadata "$1" --refresh --json | ${lib.getExe pkgs.jq} '.lastModified'
        }
        test "$(lastModified "${flakeURL}")"  -gt "$(lastModified "self")"
      ''
    );
  };
}
