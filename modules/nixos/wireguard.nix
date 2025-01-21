{
  config,
  lib,
  private-settings,
  ...
}:

with lib;
let
  cfg = config.wireguard;
in
{
  options.wireguard = {
    enable = lib.mkEnableOption (lib.mdDoc "enable wireguard tunnel to home <3");

    autoStart = lib.mkOption {
      type = types.bool;
      description = "whether to auto-start the tunnel upon boot";
      default = false;
    };

    interface = mkOption {
      type = types.str;
      description = "what the connection should be named";
      default = "wg0";
    };

    allowedIPs = mkOption {
      type = types.str;
      description = "the target IPs which will be routed via the tunnel, in CIDR notation";
      default = "0.0.0.0/0";
    };

    port = mkOption {
      type = types.port;
      description = "the port the endpoint listens on for this tunnel";
    };

    ip = mkOption {
      type = types.str;
      description = "the ip the endpoint will have in the tunneled network, in CIDR notation";
    };

    secrets.secretsFile = mkOption {
      type = types.path;
      description = "wireguard secrets file";
    };

    secrets.remotePublicKey = mkOption {
      type = types.str;
      description = "the public key of the remote server";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [ cfg.port ];
      checkReversePath = "loose";
    };

    sops.secrets.wg-private = {
      sopsFile = cfg.secrets.secretsFile;
    };
    sops.secrets.wg-preshared = {
      sopsFile = cfg.secrets.secretsFile;
    };

    networking.wireguard.interfaces = {
      ${cfg.interface} = {
        ips = [ cfg.ip ];
        listenPort = cfg.port;
        mtu = 1420;

        privateKeyFile = config.sops.secrets.wg-private.path;

        peers = [
          {
            endpoint = "${private-settings.domains.vpn}:${builtins.toString cfg.port}";
            publicKey = cfg.secrets.remotePublicKey;
            allowedIPs = [ cfg.allowedIPs ];
            persistentKeepalive = 25;
            presharedKeyFile = config.sops.secrets.wg-preshared.path;
          }
        ];
      };
    };

    systemd.targets."wireguard-${cfg.interface}".wantedBy = mkIf (!cfg.autoStart) (mkForce [ ]);
  };
}
