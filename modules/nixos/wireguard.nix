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

  ip = lib.getExe' pkgs.iproute2 "ip";
  dig = lib.getExe pkgs.dig;
  awk = lib.getExe' pkgs.gawk "awk";
  resolvconf = lib.getExe' config.networking.resolvconf.package "resolvconf";
in
{
  options.wireguard = {
    enable = lib.mkEnableOption "wireguard tunnel to home <3";

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

    dns = mkOption {
      type = types.listOf types.str;
      description = "additional DNS servers to use when connected to the wireguard network";
      default = [ ];
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
      description = "the public key of the remote endpoint";
    };

    endpoint = mkOption {
      type = types.str;
      description = "the URL or IP of the remote endpoint";
      default = private-settings.domains.vpn;
      defaultText = "(populated from git submodule)";
    };
  };

  config = mkIf cfg.enable {
    networking.firewall = {
      allowedUDPPorts = [ cfg.port ];
      checkReversePath = "loose";
    };

    networking.resolvconf.extraConfig = mkIf (cfg.dns != [ ]) ''
      interface_order='lo lo[0-9]* ${cfg.interface}'
    '';

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
            endpoint = "${cfg.endpoint}:${toString cfg.port}";
            publicKey = cfg.secrets.remotePublicKey;
            allowedIPs = [ cfg.allowedIPs ];
            persistentKeepalive = 25;
            presharedKeyFile = config.age.secrets.wg-preshared.path;
          }
        ];

        preSetup = optional (cfg.allowedIPs == "0.0.0.0/0") ''
          ${ip} route replace $(${dig} +short ${cfg.endpoint}) via $(${ip} route show 0.0.0.0/0 | ${awk} '{print $3}')
        '';
        postShutdown = optional (cfg.allowedIPs == "0.0.0.0/0") ''
          ${ip} route del $(${dig} +short ${cfg.endpoint}) via $(${ip} route show 0.0.0.0/0 | ${awk} '{print $3}')
        '';

        postSetup = optional (cfg.dns != [ ]) ''
          printf "${
            concatStringsSep "\n" (map (entry: "nameserver ${entry}") cfg.dns)
          }\n" | ${resolvconf} -a ${cfg.interface} -m 0
        '';
        preShutdown = optional (cfg.dns != [ ]) ''
          ${resolvconf} -d ${cfg.interface} || true
        '';
      };
    };

    systemd.targets."wireguard-${cfg.interface}".wantedBy = mkIf (!cfg.autoStart) (mkForce [ ]);
  };
}
