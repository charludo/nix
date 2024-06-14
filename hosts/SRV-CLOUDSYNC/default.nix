{ pkgs, inputs, ... }:
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

  environment.systemPackages = [ pkgs.rsync ];

  systemd = {
    timers."cloudsync-daily" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
        Unit = "cloudsync.service";
      };
    };

    services."cloudsync" = {
      requires = [ "media-NAS.mount" ];
      script = ''
        [ "$(stat -f -c %T /media/NAS)" == "smb2" ] && ${pkgs.rsync}/bin/rsync --progress -e '${pkgs.openssh}/bin/ssh -p 23 -i /etc/ssh/ssh_host_ed25519_key' --recursive /media/NAS/CloudSync ${inputs.private-settings.domains.cloudsync}:pakiplace
      '';
      serviceConfig = {
        Type = "oneshot";
        User = "root";
      };
    };
  };

  system.stateVersion = "23.11";
}
