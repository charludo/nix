{ config, pkgs, lib, inputs, ... }:
let
  inherit (inputs.private-settings) gsv;

  mailAccounts = config.mailserver.loginAccounts;
  htpasswd = pkgs.writeText "radicale.users" (lib.concatStrings
    (lib.flip lib.mapAttrsToList mailAccounts (mail: user:
      mail + ":" + user.hashedPassword + "\n"
    ))
  );
in
{
  services.radicale = {
    enable = true;
    settings.auth = {
      type = "htpasswd";
      htpasswd_filename = builtins.toString htpasswd;
      htpasswd_encryption = "bcrypt";
    };
    settings.web = {
      type = "radicale_infcloud";
      infcloud_config = ''
        globalInterfaceLanguage = "de_DE";
                        globalTimeZone = "Europe/Berlin";
      '';
    };
  };

  systemd.services.radicale.environment.PYTHONPATH =
    let
      python = pkgs.python312.withPackages (pkgs: with pkgs; [
        radicale_infcloud
        pytz
        setuptools
      ]);
    in
    "${python}/${pkgs.python312.sitePackages}";

  services.nginx = {
    virtualHosts = {
      "dav.${gsv.domain}" = {
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
      "calendar.${gsv.domain}" = {
        forceSSL = true;
        enableACME = true;
        locations."/" = {
          extraConfig = ''
            return 301 https://dav.${gsv.domain}/.web/infcloud/;
          '';
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];
}
