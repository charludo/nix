{
  config,
  pkgs,
  private-settings,
  ...
}:
let
  inherit (private-settings) domains;
in
{
  sops.secrets.fail2ban-cf-token = { };
  sops.secrets.fail2ban-cf-zone = { };
  sops.secrets.fail2ban-cf-zone-2 = { };
  services.fail2ban = {
    extraPackages = [ pkgs.curl ];
    enable = true;
    maxretry = 3;
    ignoreIP = [ domains.vpn ];
    bantime = "24h";
    bantime-increment = {
      enable = true;
      multipliers = "1 2 4 8 16 32 64";
      maxtime = "168h";
      overalljails = true;
    };
    jails =
      let
        defaultAction = ''
          cloudflare-token-multi[cftoken="$(cat ${config.sops.secrets.fail2ban-cf-token.path})", cfzone="$(cat ${config.sops.secrets.fail2ban-cf-zone.path})", cfzone2="$(cat ${config.sops.secrets.fail2ban-cf-zone-2.path})"]
                  iptables-allports'';
      in
      {
        # Misc
        sshd.settings = {
          enabled = true;
          filter = "sshd";
          action = "iptables-allports";
          maxretry = 1;
        };
        sshd-ddos.settings = {
          enabled = true;
          filter = "sshd-ddos";
          action = "iptables-allports";
          maxretry = 2;
        };
        monit.settings = {
          enabled = true;
          filter = "monit";
          action = defaultAction;
          maxretry = 2;
        };
        phpmyadmin-syslog.settings = {
          enabled = true;
          filter = "phpmyadmin-syslog";
          action = defaultAction;
          maxretry = 1;
        };
        mysqld-auth.settings = {
          enabled = true;
          filter = "mysqld-auth";
          action = defaultAction;
          maxretry = 2;
        };

        # Email
        postfix.settings = {
          enabled = true;
          filter = "postfix";
          action = defaultAction;
          maxretry = 3;
        };
        postfix-sasl.settings = {
          enabled = true;
          filter = "postfix-sasl";
          action = defaultAction;
          maxretry = 3;
        };
        postfix-ddos.settings = {
          enabled = true;
          filter = "postfix-ddos";
          action = defaultAction;
          bantime = 7200;
          maxretry = 3;
        };
        postfix-bruteforce.settings = {
          enabled = true;
          filter = "postfix-bruteforce";
          logpath = "/var/log/nginx/access.log";
          action = defaultAction;
          backend = "auto";
          maxretry = 5;
          findtime = 600;
        };
        dovecot.settings = {
          enabled = true;
          filter = "dovecot";
          action = defaultAction;
          maxretry = 2;
        };

        # Web requests
        nginx-url-probe.settings = {
          enabled = true;
          filter = "nginx-url-probe";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          findtime = 600;
          action = defaultAction;
          maxretry = 5;
        };
        nginx-bruteforce.settings = {
          enabled = true;
          filter = "nginx-bruteforce";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          action = defaultAction;
          maxretry = 2;
          findtime = 600;
        };
        nginx-bad-request.settings = {
          enabled = true;
          filter = "nginx-bad-request";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          action = defaultAction;
          maxretry = 1;
        };
        nginx-botsearch.settings = {
          enabled = true;
          filter = "nginx-botsearch";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          action = defaultAction;
          maxretry = 2;
        };
        nginx-forbidden.settings = {
          enabled = true;
          filter = "nginx-forbidden";
          logpath = "/var/log/nginx/access.log";
          backend = "auto";
          action = defaultAction;
          maxretry = 1;
        };
        php-url-fopen.settings = {
          enabled = true;
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

    # Action to ban IP from 2 cloudflare zones
    "fail2ban/action.d/cloudflare-token-multi.conf".text = # bash
      ''
        [Definition]
        actionban = curl -s -X POST "<_cf_api_url_2>" \
                      <_cf_api_prms> \
                      --data '{"mode":"<cfmode>","configuration":{"target":"<cftarget>","value":"<ip>"},"notes":"<notes>"}' && \
                    curl -s -X POST "<_cf_api_url>" \
                      <_cf_api_prms> \
                      --data '{"mode":"<cfmode>","configuration":{"target":"<cftarget>","value":"<ip>"},"notes":"<notes>"}'


        _cf_api_url = https://api.cloudflare.com/client/v4/zones/<cfzone>/firewall/access_rules/rules
        _cf_api_url_2 = https://api.cloudflare.com/client/v4/zones/<cfzone2>/firewall/access_rules/rules
        _cf_api_prms = -H "Authorization: Bearer <cftoken>" -H "Content-Type: application/json"

        [Init]
        cftarget = ip
        cfmode = block
        notes = Fail2Ban <name>
      '';
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
}
