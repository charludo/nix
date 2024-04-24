{ inputs, outputs, config, lib, pkgs, ... }:
let
  inherit (inputs.private-settings) gsv loginAccounts contact monitAdminPassword;
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

  system.stateVersion = "23.11";
}

