{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.tailscale;
in
{
  options.tailscale = {
    enable = lib.mkEnableOption "whether to enable tailscale";

    autoStart = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to autostart the tailscaled client daemon";
    };
  };

  config = mkIf cfg.enable {
    services.tailscale.enable = true;
    systemd.services.tailscaled.wantedBy = lib.mkIf (!cfg.autoStart) (lib.mkForce [ ]);

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "tailscale-up" ''
        set -euo pipefail

        echo "Starting tailscaled.service..."
        ${lib.getExe' pkgs.systemd "systemctl"} start tailscaled.service

        echo "Bringing up tailscale..."
        ${lib.getExe pkgs.tailscale} up --accept-routes --ssh
      '')
      (pkgs.writeShellScriptBin "tailscale-down" ''
        set -euo pipefail

        echo "Bringing down tailscale..."
        ${lib.getExe pkgs.tailscale} down

        echo "Stopping tailscaled.service..."
        ${lib.getExe' pkgs.systemd "systemctl"} stop tailscaled.service
      '')
    ];
  };
}
