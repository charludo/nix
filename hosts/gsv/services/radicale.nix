{
  config,
  pkgs,
  lib,
  private-settings,
  ...
}:
let
  inherit (private-settings) domains radicale;

  mailAccounts = config.mailserver.accounts;
  htpasswd = pkgs.writeText "radicale.users" (
    lib.concatStrings (
      lib.flip lib.mapAttrsToList mailAccounts (mail: user: mail + ":" + user.hashedPassword + "\n")
      ++ lib.mapAttrsToList (name: hash: name + ":" + hash + "\n") radicale.extraLogins
    )
  );
in
{
  services.radicale = {
    enable = true;
    settings.auth = {
      type = "htpasswd";
      htpasswd_filename = toString htpasswd;
      htpasswd_encryption = "bcrypt";
    };
    settings.web.type = "internal";
    rights = {
      root = {
        user = ".+";
        collection = "";
        permissions = "R";
      };
      principal = {
        user = ".+";
        collection = "{user}";
        permissions = "RW";
      };
      calendars = {
        user = ".+";
        collection = "{user}/[^/]+";
        permissions = "rw";
      };
    }
    // lib.mapAttrs' (
      path: members:
      lib.nameValuePair "shared ${path}" {
        user = "^(${lib.concatMapStringsSep "|" lib.escapeRegex members})$";
        collection = lib.escapeRegex path;
        permissions = "rw";
      }
    ) radicale.shared;
  };

  services.nginx = {
    virtualHosts = {
      "dav.${domains.personal}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          proxyPass = "http://localhost:5232/";
          extraConfig = ''
            proxy_set_header  X-Script-Name /;
            proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_pass_header Authorization;
          '';
        };
      };
      "calendar.${domains.personal}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          extraConfig = ''
            return 301 https://dav.${domains.personal}/.web/;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
