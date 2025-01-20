{ outputs, lib, private-settings, secrets, ... }:
let
  inherit (private-settings) gsv;
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

    ./services
  ] ++ (builtins.attrValues outputs.nixosModules);

  # Override options set in the above imports
  nix.settings.trusted-users = lib.mkForce [ "root" ];
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";
  sops.defaultSopsFile = lib.mkForce secrets.gsv;

  # Make sure we can get on the system via ssh
  users.users."${gsv.user}".openssh.authorizedKeys.keys = [ publicKey ];
  services.openssh.ports = [ gsv.port ];
  console.keyMap = "us-acentos";

  # Networking config
  networking = {
    hostName = hostName;
    hostId = gsv.hostId;
    useDHCP = false;
    enableIPv6 = false;
    interfaces.${gsv.interface}.ipv4.addresses = [
      { address = gsv.ip; prefixLength = gsv.prefixLength; }
    ];
    defaultGateway = {
      address = gsv.gateway;
      interface = gsv.interface;
    };
    firewall = {
      allowedTCPPorts = [ 80 443 ];
    };
  };

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

  system.stateVersion = "23.11";
}

