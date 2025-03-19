{
  config,
  lib,
  pkgs,
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

    secrets.secretsFilePrivate = mkOption {
      type = types.path;
      description = "wireguard secrets file";
    };

    secrets.secretsFilePreshared = mkOption {
      type = types.path;
      description = "wireguard preshared file";
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

    age.secrets.wg-private.rekeyFile = cfg.secrets.secretsFilePrivate;
    age.secrets.wg-preshared.rekeyFile = cfg.secrets.secretsFilePreshared;

    networking.wireguard.interfaces = {
      ${cfg.interface} = {
        ips = [ cfg.ip ];
        listenPort = cfg.port;
        mtu = 1420;

        privateKeyFile = config.age.secrets.wg-private.path;

        peers = [
          {
            endpoint = "${private-settings.domains.vpn}:${builtins.toString cfg.port}";
            publicKey = cfg.secrets.remotePublicKey;
            allowedIPs = [ cfg.allowedIPs ];
            persistentKeepalive = 25;
            presharedKeyFile = config.age.secrets.wg-preshared.path;
          }
        ];

        preSetup = optional (cfg.allowedIPs == "0.0.0.0/0") ''
          ${pkgs.iproute2}/bin/ip route add $(${pkgs.dig}/bin/dig +short ${private-settings.domains.vpn}) via $(${pkgs.iproute2}/bin/ip route show 0.0.0.0/0 | ${pkgs.gawk}/bin/awk '{print $3}')
        '';
        postShutdown = optional (cfg.allowedIPs == "0.0.0.0/0") ''
          ${pkgs.iproute2}/bin/ip route del $(${pkgs.dig}/bin/dig +short ${private-settings.domains.vpn}) via $(${pkgs.iproute2}/bin/ip route show 0.0.0.0/0 | ${pkgs.gawk}/bin/awk '{print $3}')
        '';
      };
    };

    systemd.targets."wireguard-${cfg.interface}".wantedBy = mkIf (!cfg.autoStart) (mkForce [ ]);
  };
}
