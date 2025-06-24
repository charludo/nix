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
    enable = lib.mkEnableOption (lib.mdDoc "Whether to enable tailscale");

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
        ${pkgs.systemd}/bin/systemctl start tailscaled.service

        echo "Bringing up tailscale..."
        ${pkgs.tailscale}/bin/tailscale up --accept-routes --ssh
      '')
      (pkgs.writeShellScriptBin "tailscale-down" ''
        set -euo pipefail

        echo "Bringing down tailscale..."
        ${pkgs.tailscale}/bin/tailscale down

        echo "Stopping tailscaled.service..."
        ${pkgs.systemd}/bin/systemctl stop tailscaled.service
      '')
    ];
  };
}
