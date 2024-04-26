{ inputs, outputs, config, lib, pkgs, ... }:
let
  inherit (inputs.private-settings) gsv loginAccounts contact monitAdminPassword domains;
  hostName = "gsv";
  publicKey = builtins.readFile ../../users/charlotte/ssh.pub;
in
{
  imports = [
    ./hardware-configuration.nix

    ../common/global/locale.nix
    ../common/global/nix.nix
    ../common/global/openssh.nix
    ../common/global/sops.nix

    ../common/optional/monit.nix

    inputs.mailserver.nixosModule
  ] ++ (builtins.attrValues outputs.nixosModules);

  # Override options set in the above imports
  nix.settings.trusted-users = lib.mkForce [ "root" ];
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  sops.defaultSopsFile = lib.mkForce ./gsv-secrets.sops.yaml;

  # Make sure we can get on the system via ssh
  users.users."${gsv.user}".openssh.authorizedKeys.keys = [ publicKey ];
  services.openssh.ports = [ gsv.port ];
  console.keyMap = "us-acentos";

  # Networking config
  networking.hostName = hostName;
  networking.hostId = gsv.hostId;
  networking.useDHCP = false;
  networking.enableIPv6 = false;
  networking.interfaces.${gsv.interface}.ipv4.addresses = [{
    address = gsv.ip;
    prefixLength = gsv.prefixLength;
  }];
  networking.defaultGateway = gsv.gateway;
  networking.nameservers = gsv.dns;
  services.resolved.enable = true;

  # Boot partition is mirrored over all ZFS mirrors
  fileSystems."/boot-1".options = [ "nofail" ];
  fileSystems."/boot-2".options = [ "nofail" ];
  fileSystems."/boot-3".options = [ "nofail" ];
  boot.supportedFilesystems = [ "zfs" ];

  # Set up GRUB
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub = {
    enable = true;
    copyKernels = true;
    mirroredBoots = [
      { path = "/boot-1"; devices = [ "/dev/disk/by-id/${gsv.nvme0n1}" ]; }
      { path = "/boot-2"; devices = [ "/dev/disk/by-id/${gsv.nvme1n1}" ]; }
      { path = "/boot-3"; devices = [ "/dev/disk/by-id/${gsv.nvme2n1}" ]; }
    ];
  };

  # Start an SSH server in initrd via which we can unlock the drives
  boot.initrd.availableKernelModules = [ gsv.interfaceDriver ];
  boot.kernelParams = [ "ip=${gsv.ip}::${gsv.gateway}:${gsv.netmask}:${hostName}-initrd:${gsv.interface}:off:${builtins.head gsv.dns}" ];
  boot.initrd.network = {
    enable = true;
    ssh = {
      enable = true;
      port = gsv.port-boot;
      hostKeys = [
        /boot-1/initrd-ssh-key
        /boot-2/initrd-ssh-key
        /boot-3/initrd-ssh-key
      ];
      authorizedKeys = [ publicKey ];
    };
    postCommands = ''
      cat <<EOF > /root/.profile
      if pgrep -x "zfs" > /dev/null
      then
        zfs load-key -a
        killall zfs
      else
        echo "zfs not running -- maybe the pool is taking some time to load for some unforseen reason."
      fi
      EOF
    '';
  };

  # SSL certificate
  sops.secrets.cloudflare = { };
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = contact.acme;
      dnsProvider = "cloudflare";
      dnsResolver = gsv.dnsResolver;
    };
  };

  mailserver = {
    enable = true;
    fqdn = "mail.${gsv.domain}";
    domains = [ gsv.domain ];
    messageSizeLimit = 209715200;
    certificateScheme = "acme";
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      indexAttachments = true;
      enforced = "body";
    };
    loginAccounts = loginAccounts;
  };

  services.roundcube = {
    enable = true;
    hostName = "mail.${gsv.domain}";
    configureNginx = true;
    dicts = with pkgs.aspellDicts; [ de en ];
    extraConfig = ''
      $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  services.nginx = {
    enable = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    appendHttpConfig =
      let
        cloudflareIPs = builtins.fetchurl {
          url = "https://www.cloudflare.com/ips-v4";
          sha256 = "0ywy9sg7spafi3gm9q5wb59lbiq0swvf0q3iazl0maq1pj1nsb7h";
        };
        setRealIpFromConfig =
          lib.concatMapStrings (ip: "set_real_ip_from ${ip};\n")
            (lib.strings.splitString "\n" (builtins.readFile "${cloudflareIPs}"));
      in
      ''
        ${setRealIpFromConfig}
        real_ip_header CF-Connecting-IP;
      '';
    # virtualHosts."some.site" = { default = true; enableACME = true; addSSL = true; locations."/".proxyPass = "http://127.0.0.1:9955/"; };
  };

  # Monitoring
  services.smartd.enable = true;
  monitConfig = {
    alertAddress = contact.monitoring;
    adminPassword = monitAdminPassword;
    adminInterface.enable = true;

    sshd.enable = true;
    smartd.enable = true;
    zfs.enable = true;

    postfix.enable = true;
    dovecot.enable = true;
    rspamd.enable = true;
  };

  # fail2ban
  sops.secrets.fail2ban-cf-token = { };
  sops.secrets.fail2ban-cf-zone = { };
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
        defaultAction = ''cloudflare-token[cftoken="$(cat ${config.sops.secrets.fail2ban-cf-token.path})", cfzone="$(cat ${config.sops.secrets.fail2ban-cf-zone.path})"]
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
        ngingx-botsearch.settings = {
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
    "fail2ban/filter.d/nginx-url-probe.local".text = pkgs.lib.mkDefault (pkgs.lib.mkAfter ''
      [Definition]
      failregex = ^<HOST>.*(GET /(wp-|admin|boaform|phpmyadmin|\.env|\.git)|\.(dll|so|cfm|asp)|(\?|&)(=PHPB8B5F2A0-3C92-11d3-A3A9-4C7B08C10000|=PHPE9568F36-D428-11d2-A769-00AA001ACF42|=PHPE9568F35-D428-11d2-A769-00AA001ACF42|=PHPE9568F34-D428-11d2-A769-00AA001ACF42)|\\x[0-9a-zA-Z]{2})
    '');
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
  };

  # Helper for getting nicely formatted fail2ban summary
  environment.systemPackages =
    let
      fail2ban-summary = pkgs.writeShellApplication {
        name = "fail2ban-summary";
        runtimeInputs = with pkgs; [ fail2ban gnused jq ];
        text = ''
          fail2ban-client banned | sed "s/'/\"/g" | jq -r '.[] | keys[] as $jail | "\(.[$jail] | length) banned IPs in \($jail)"'
        '';
      };
    in
    [ fail2ban-summary ];

  system.stateVersion = "23.11";
}

