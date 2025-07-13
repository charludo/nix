{
  config,
  lib,
  pkgs,
  ...
}:

with lib;
let
  cfg = config.fail2ban;
in
{
  options.fail2ban = {
    enable = mkEnableOption "fail2ban config";

    doNotBan = mkOption {
      type = types.listOf types.str;
      description = "domains / IPs which are exempt from fail2ban scrutiny";
      default = [ ];
    };

    secrets.cloudflareToken = mkOption {
      type = types.nullOr types.path;
      description = "cloudflare api token";
      default = null;
    };

    secrets.cloudflareZones = mkOption {
      type = types.listOf (
        types.submodule {
          options = {
            name = mkOption {
              type = types.str;
              description = "descriptive name for the cloudflare zone";
            };
            path = mkOption {
              type = types.path;
              description = "path to the cloudflare zone file";
            };
          };
        }
      );
      description = "cloudflare zones from which fail2ban blocks requesters";
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    age.secrets =
      builtins.listToAttrs (
        map (zone: {
          name = zone.name;
          value.rekeyFile = zone.path;
        }) cfg.secrets.cloudflareZones
      )
      // mkIf (cfg.secrets.cloudflareToken != null) {
        fail2ban-cf-token.rekeyFile = cfg.secrets.cloudflareToken;
      };
    services.fail2ban = {
      extraPackages = [ pkgs.curl ];
      enable = true;
      maxretry = 3;
      ignoreIP = cfg.doNotBan;
      bantime = "24h";
      bantime-increment = {
        enable = true;
        multipliers = "1 2 4 8 16 32 64";
        maxtime = "168h";
        overalljails = true;
      };
      jails =
        let
          zoneStrings = concatStringsSep ", " (
            map (zone: ''zone_${zone.name}="$(cat ${zone.path})"'') cfg.secrets.cloudflareZones
          );
          defaultAction =
            if cfg.secrets.cloudflareToken != null then
              ''
                cloudflare-token-multi[cftoken="$(cat ${config.age.secrets.fail2ban-cf-token.path})", ${zoneStrings}]
                        iptables-allports''
            else
              ''iptables-allports'';
        in
        {
          # Misc
          sshd.settings = {
            enabled = mkDefault true;
            filter = "sshd";
            action = "iptables-allports";
            maxretry = 1;
          };
          sshd-ddos.settings = {
            enabled = mkDefault true;
            filter = "sshd-ddos";
            action = "iptables-allports";
            maxretry = 2;
          };
          monit.settings = {
            enabled = mkDefault true;
            filter = "monit";
            action = defaultAction;
            maxretry = 2;
          };
          phpmyadmin-syslog.settings = {
            enabled = mkDefault true;
            filter = "phpmyadmin-syslog";
            action = defaultAction;
            maxretry = 1;
          };
          mysqld-auth.settings = {
            enabled = mkDefault true;
            filter = "mysqld-auth";
            action = defaultAction;
            maxretry = 2;
          };

          # Email
          postfix.settings = {
            enabled = mkDefault true;
            filter = "postfix";
            action = defaultAction;
            maxretry = 3;
          };
          postfix-sasl.settings = {
            enabled = mkDefault true;
            filter = "postfix-sasl";
            action = defaultAction;
            maxretry = 3;
          };
          postfix-ddos.settings = {
            enabled = mkDefault true;
            filter = "postfix-ddos";
            action = defaultAction;
            bantime = 7200;
            maxretry = 3;
          };
          postfix-bruteforce.settings = {
            enabled = mkDefault true;
            filter = "postfix-bruteforce";
            logpath = "/var/log/nginx/access.log";
            action = defaultAction;
            backend = "auto";
            maxretry = 5;
            findtime = 600;
          };
          dovecot.settings = {
            enabled = mkDefault true;
            filter = "dovecot";
            action = defaultAction;
            maxretry = 2;
          };

          # Web requests
          nginx-url-probe.settings = {
            enabled = mkDefault true;
            filter = "nginx-url-probe";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            findtime = 600;
            action = defaultAction;
            maxretry = 5;
          };
          nginx-bruteforce.settings = {
            enabled = mkDefault true;
            filter = "nginx-bruteforce";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            action = defaultAction;
            maxretry = 2;
            findtime = 600;
          };
          nginx-bad-request.settings = {
            enabled = mkDefault true;
            filter = "nginx-bad-request";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            action = defaultAction;
            maxretry = 1;
          };
          nginx-botsearch.settings = {
            enabled = mkDefault true;
            filter = "nginx-botsearch";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            action = defaultAction;
            maxretry = 2;
          };
          nginx-forbidden.settings = {
            enabled = mkDefault true;
            filter = "nginx-forbidden";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            action = defaultAction;
            maxretry = 1;
          };
          php-url-fopen.settings = {
            enabled = mkDefault true;
            filter = "php-url-fopen";
            logpath = "/var/log/nginx/access.log";
            backend = "auto";
            action = defaultAction;
            maxretry = 2;
          };
        };
    };
    environment.etc = {
      # Defines a filter that detects URL probing by reading the Nginx access log
      "fail2ban/filter.d/nginx-url-probe.local".text = pkgs.lib.mkDefault (
        pkgs.lib.mkAfter ''
          [Definition]
          failregex = ^<HOST>.*(GET /(wp-|admin|boaform|phpmyadmin|\.env|\.git)|\.(dll|so|cfm|asp)|(\?|&)(=PHPB8B5F2A0-3C92-11d3-A3A9-4C7B08C10000|=PHPE9568F36-D428-11d2-A769-00AA001ACF42|=PHPE9568F35-D428-11d2-A769-00AA001ACF42|=PHPE9568F34-D428-11d2-A769-00AA001ACF42)|\\x[0-9a-zA-Z]{2})
        ''
      );
      "fail2ban/filter.d/nginx-bruteforce.conf".text = ''
        [Definition]
        failregex = ^<HOST>.*GET.*(matrix/server|\.php|admin|wp\-).* HTTP/\d.\d\" 404.*$
      '';
      "fail2ban/filter.d/postfix-bruteforce.conf".text = ''
        [Definition]
        failregex = warning: [\w\.\-]+\[<HOST>\]: SASL LOGIN authentication failed.*$
        journalmatch = _SYSTEMD_UNIT=postfix.service
      '';
      "fail2ban/filter.d/postfix-ddos.conf".text = ''
        [Definition]
        failregex = lost connection after EHLO from \S+\[<HOST>\]
      '';

      # Action to ban IP from all given cloudflare zones
      "fail2ban/action.d/cloudflare-token-multi.conf" = mkIf (cfg.secrets.cloudflareToken != null) {
        text =
          let
            urlDefinitions = concatStringsSep "\n" (
              map (
                zone:
                "_cf_api_zone_${zone.name} = https://api.cloudflare.com/client/v4/zones/<zone_${zone.name}>/firewall/access_rules/rules"
              ) cfg.secrets.cloudflareZones
            );
            actionDefinitions = concatStringsSep " && \\\n            " (
              map
                (
                  zone: # bash
                  ''
                    curl -s -X POST "<_cf_api_zone_${zone.name}>" \
                                                     <_cf_api_prms> \
                                                     --data '{"mode":"<cfmode>","configuration":{"target":"<cftarget>","value":"<ip>"},"notes":"<notes>"}'')
                cfg.secrets.cloudflareZones
            );

          in
          # bash
          ''
            [Definition]
            actionban = ${actionDefinitions}


            ${urlDefinitions}
            _cf_api_prms = -H "Authorization: Bearer <cftoken>" -H "Content-Type: application/json"

            [Init]
            cftarget = ip
            cfmode = block
            notes = Fail2Ban <name>
          '';
      };
    };

    # Helper for getting nicely formatted fail2ban summary
    environment.systemPackages =
      let
        fail2ban-summary = pkgs.writeShellApplication {
          name = "fail2ban-summary";
          runtimeInputs = with pkgs; [
            fail2ban
            gnused
            jq
          ];
          text = ''
            fail2ban-client banned | sed "s/'/\"/g" | jq -r '.[] | keys[] as $jail | "\(.[$jail] | length) banned IPs in \($jail)"'
          '';
        };
      in
      [ fail2ban-summary ];
  };
}
