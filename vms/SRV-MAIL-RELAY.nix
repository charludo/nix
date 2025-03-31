{
  config,
  lib,
  pkgs,
  inputs,
  private-settings,
  secrets,
  ...
}:
let
  inherit (private-settings) mailRelay;
in
{
  imports = [
    inputs.mailserver.nixosModules.mailserver
  ];

  vm = {
    id = 200;
    name = "SRV-MAIL-RELAY";

    hardware.cores = 2;
    hardware.memory = 4096;
    hardware.storage = "16G";

    networking = {
      address = "10.10.30.100";
      gateway = "10.10.30.1";
      nameservers = [ "1.1.1.1" ];
      prefixLength = 24;
      openPorts.tcp = [
        80
        443
      ];
    };
  };

  proxmox.qemuConf = {
    boot = "order=sata0";
    virtio0 = "local-zfs:vm-${builtins.toString config.vm.id}-disk-0";
    net0 = "virtio=00:00:00:00:00:00,bridge=vmbr0,firewall=1,tag=30";
  };

  snow = {
    tags = lib.mkForce [ ];

    vm = {
      proxmoxHost = "10.10.50.12";
      proxmoxImageStore = null;
    };
  };

  environment.systemPackages = [
    pkgs.dig
    pkgs.openssl
  ];

  mailserver = {
    enable = true;
    fqdn = mailRelay.mailDomain;
    domains = [ mailRelay.mailDomain ];
    messageSizeLimit = 209715200;
    certificateScheme = "acme";
    fullTextSearch = {
      enable = true;
      autoIndex = true;
      enforced = "body";
    };
    loginAccounts = mailRelay.loginAccounts;
    localDnsResolver = false;
    dmarcReporting.enable = false;
    dkimSigning = false;
  };

  services.roundcube = {
    enable = true;
    hostName = mailRelay.mailDomain;
    configureNginx = true;
    extraConfig = ''
      $config['smtp_server'] = "tls://${config.mailserver.fqdn}";
      $config['smtp_user'] = "%u";
      $config['smtp_pass'] = "%p";
    '';
  };

  fail2ban.enable = true;
  services.fail2ban.jails.postfix.settings.maxretry = lib.mkForce 10;

  age.secrets.cloudflare.rekeyFile = secrets.mail-relay-cloudflare;
  security.acme = {
    acceptTerms = true;
    defaults = {
      email = mailRelay.acme;
      dnsProvider = "cloudflare";
      dnsResolver = "1.1.1.1:53";
      environmentFile = config.age.secrets.cloudflare.path;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."${mailRelay.mailDomain}" = {
      forceSSL = false;
      enableACME = false;
    };
  };

  system.stateVersion = "23.11";
}
