{ config, pkgs, inputs, ... }:
{
  _module.args.defaultUser = "paki";
  imports =
    [
      ./hardware-configuration.nix
      ../common/optional/vmify.nix

      ../common/global
      ../common/optional/nvim.nix

      ../../users/paki/user.nix
    ];

  enableNas = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "SRV-CLOUDSYNC";
    interfaces = {
      ens18.ipv4.addresses = [{
        address = "192.168.30.31";
        prefixLength = 24;
      }];
    };
    defaultGateway = "192.168.30.1";
    nameservers = [ "192.168.30.5" "192.168.30.13" "1.1.1.1" ];
  };

  services.qemuGuest.enable = true;

  sops.secrets.borg = { };
  services.borgbackup.jobs.remoteBackup = {
    paths = [ "/media/NAS/CloudSync" ];
    exclude = [ "'**/node_modules'" "'**/.venv'" "'**/.cache'" ];
    doInit = false;
    repo = "${inputs.private-settings.domains.cloudsync}:pakiplace";
    encryption = {
      mode = "repokey";
      passCommand = "cat ${config.sops.secrets.borg.path}";
    };
    environment = { BORG_RSH = "ssh -p 23 -i /etc/ssh/ssh_host_ed25519_key"; };
    compression = "auto,lzma";
    startAt = "03:15";
  };

  system.stateVersion = "23.11";
}
