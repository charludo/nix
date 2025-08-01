{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.staticHosting;
in
{
  options.staticHosting = {
    enable = lib.mkEnableOption "hosting of static sites";

    siteConfigs = mkOption {
      type = lib.types.anything;
      description = ''
        A list of sets representing sites to host, each consisting of:
        - a name
        - a domain/url
        - an ssh public key corresponding to the private key used by
          the forgejo automation to publish the built site
        - whether to enable SSL
      '';
    };
  };

  config = mkIf cfg.enable {
    users.users = builtins.listToAttrs (
      map (site: {
        name = site.name;
        value = {
          home = "/var/www/${site.name}";
          group = "sftponly";
          isNormalUser = false;
          isSystemUser = true;
          openssh.authorizedKeys.keys = [ site.pubkey ];
          createHome = false;
          shell = pkgs.shadow;
          useDefaultShell = false;
        };
      }) cfg.siteConfigs
    );

    users.groups.sftponly = { };

    services.openssh.extraConfig = ''
      Match Group sftponly
        X11Forwarding no
        AllowTcpForwarding no
        ChrootDirectory /var/www/%u
        ForceCommand internal-sftp -d %u
    '';

    systemd.tmpfiles.rules = builtins.concatLists (
      map (site: [
        "d /var/www/${site.name} 0755 root root -"
        "d /var/www/${site.name}/public 0755 ${site.name} sftponly -"
      ]) cfg.siteConfigs
    );

    services.nginx = {
      enable = true;
      recommendedGzipSettings = true;
      recommendedOptimisation = true;
      recommendedProxySettings = true;
    };
    services.nginx.virtualHosts = builtins.listToAttrs (
      map (site: {
        name = site.url;
        value = {
          forceSSL = site.enableSSL;
          enableACME = site.enableSSL;
          locations."~* \.(jpg|jpeg|png|gif|ico|webp|css|js|woff2?|ttf|eot|svg)$" = {
            root = "/var/www/${site.name}/public";
            tryFiles = "$uri $uri/ =404";

            extraConfig = ''
              access_log off;
              expires 30d;
              add_header Cache-Control "public, max-age=2592000, immutable";
            '';
          };
          locations."~* \.html$" = {
            root = "/var/www/${site.name}/public";
            tryFiles = "$uri $uri/ =404";

            extraConfig = ''
              add_header Cache-Control "no-cache, no-store, must-revalidate, proxy-revalidate";
              add_header Pragma "no-cache";
              add_header Expires 0;
            '';
          };
          locations."/" = {
            root = "/var/www/${site.name}/public";
          };
          extraConfig = ''
            error_page 404 /notfound;
          '';
        };
      }) cfg.siteConfigs
    );
  };
}
