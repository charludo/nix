{
  config,
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
let
  cfg = config.vm;
in
{
  options.vm.certsFor = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule (
        { config, ... }:
        {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "name/subdomain to register";
            };
            port = lib.mkOption {
              type = lib.types.port;
              description = "port on which is being listened for this subdomain";
            };
            address = lib.mkOption {
              type = lib.types.str;
              description = "address on which is being listened for this subdomain";
              default = "127.0.0.1";
            };
            redirectURI = lib.mkOption {
              type = lib.types.str;
              description = "URI used as the proxyPass target in nginx";
              default = "http://${config.address}:${builtins.toString config.port}/";
              defaultText = lib.literalExpression ''http://''${config.address}:''${builtins.toString config.port}/'';
            };
            defaultProxySettings = lib.mkOption {
              type = lib.types.bool;
              description = "keep default proxy settings";
              default = true;
            };
            extraProxySettings = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "additional proxy settings";
              default = [ ];
            };
          };
        }
      )
    );
    description = "Subdomains for which DNS entries should be created and Certificates requested. Name of the attrset is used as the subdomain.";
    default = [ ];
  };

  config = lib.mkIf (cfg.certsFor != [ ]) {
    security.acme.acceptTerms = true;
    security.acme.defaults = {
      email = "acme@${private-settings.domains.ad}";
      server = lib.mkDefault "https://${builtins.head private-settings.caIssuing1.dnsNames}/acme/acme/directory";
      reloadServices = [ "nginx.service" ];
    };
    systemd.services =
      builtins.listToAttrs (
        builtins.map (entry: {
          name = "acme-${entry.name}.${private-settings.domains.ad}";
          value = {
            after = [ "ddclient.service" ];
            requires = [ "ddclient.service" ];
          };
        }) cfg.certsFor
      )
      // {
        ddclient.path = [ pkgs.dig ];
        ddclient.serviceConfig.User = "ddclient";
        ddclient.serviceConfig.Group = "ddclient";
      };

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
      clientMaxBodySize = "10G";
      commonHttpConfig = ''
        proxy_headers_hash_max_size 2048;
        proxy_headers_hash_bucket_size 256;
      '';
    };
    services.nginx.virtualHosts = builtins.listToAttrs (
      builtins.map (entry: {
        name = "${entry.name}.${private-settings.domains.ad}";
        value = {
          forceSSL = true;
          enableACME = true;
          serverAliases = [ entry.name ];
          locations."/" = {
            proxyPass = entry.redirectURI;
            proxyWebsockets = true;
            extraConfig =
              (
                if entry.defaultProxySettings then
                  ''
                    proxy_ssl_server_name on;
                    proxy_pass_header Authorization;
                    proxy_set_header X-Real-IP $remote_addr;
                    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                    proxy_set_header X-Forwarded-Proto $scheme;
                  ''
                else
                  ""
              )
              + lib.concatStringsSep "\n" entry.extraProxySettings;
          };
          extraConfig = ''
            underscores_in_headers on;
          '';
        };
      }) cfg.certsFor
    );

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];
    networking.hosts = {
      "192.168.30.33" = [ (builtins.head private-settings.caIssuing1.dnsNames) ];
      "127.0.0.1" = builtins.map (entry: "${entry.name}.${private-settings.domains.ad}") cfg.certsFor;
    };

    services.ddclient = {
      enable = true;
      interval = "1day";
      protocol = "nsupdate";
      usev4 = "ifv4, ifv4=${
        lib.findFirst (i: config.networking.interfaces ? ${i}) null [
          "ens18"
          "enp6s18"
        ]
      }";
      usev6 = "no";
      domains = builtins.map (entry: "${entry.name}.${private-settings.domains.ad}") cfg.certsFor;
      username = "${lib.getExe' pkgs.dig "nsupdate"}";
      passwordFile = config.age.secrets.dns-update-pw.path;
      server = private-settings.ad.dnsServer;
      zone = private-settings.domains.ad;
      # Has to be used until https://github.com/NixOS/nixpkgs/pull/468051 is merged
      # configFile = "/var/lib/ddclient/changed-conf.conf";
    };
    age.secrets.dns-update-pw = {
      rekeyFile = secrets.dns-update-pw;
      owner = "ddclient";
      group = "ddclient";
    };
    users.users.ddclient.group = "ddclient";
    users.users.ddclient.isNormalUser = true;
    users.groups.ddclient = { };
  };
}
