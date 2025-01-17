{ inputs, outputs, config, lib, modulesPath, ... }:
{
  _module.args.defaultUser = "paki";
  imports = [
    inputs.nixos-generators.nixosModules.all-formats
    (modulesPath + "/profiles/qemu-guest.nix")
    (modulesPath + "/virtualisation/proxmox-image.nix")

    ../hosts/common/global
    ../hosts/common/optional/nvim.nix

    ../users/paki/user.nix
  ];

  vm.enable = true;
  proxmox.qemuConf = {
    boot = lib.mkDefault "order=virtio0";
    scsihw = lib.mkDefault "virtio-scsi-single";
    virtio0 = lib.mkDefault "vm_datastore:vm-${builtins.toString config.vm.id}-disk-0";
    ostype = lib.mkDefault "l26";
    cores = config.vm.hardware.cores;
    memory = config.vm.hardware.memory;
    bios = lib.mkDefault "ovmf";
    name = config.vm.name;
    additionalSpace = config.vm.hardware.storage;
    bootSize = lib.mkDefault "256M";
    net0 = lib.mkDefault "virtio=00:00:00:00:00:00,bridge=VLAN${builtins.substring 0 2 (toString config.vm.id)},firewall=1";
  };
  proxmox.cloudInit.enable = false;
  proxmox.partitionTableType = lib.mkDefault "efi";
  proxmox.qemuExtraConf = {
    agent = 1;
    ide2 = lib.mkForce "none,media=cdrom";
    kvm = 1;
  };
  virtualisation.diskSize = "auto";

  networking = {
    hostName = config.vm.name;
    interfaces = {
      ens18.ipv4.addresses = [{
        address = config.vm.networking.address;
        prefixLength = config.vm.networking.prefixLength;
      }];
    };
    defaultGateway = config.vm.networking.gateway;
    nameservers = config.vm.networking.nameservers;
    firewall = {
      allowedTCPPorts = config.vm.networking.openPorts.tcp;
      allowedUDPPorts = config.vm.networking.openPorts.udp;
    };
    useDHCP = lib.mkDefault true;
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  nixpkgs.hostPlatform = "x86_64-linux";
  services.qemuGuest.enable = true;

  # Overwriting parts of hosts/common/global
  sops.defaultSopsFile = lib.mkForce ../hosts/common/secrets.sops.yaml;
  sops.secrets.nas = lib.mkForce (lib.mkIf (config.enableNas or config.enableNasBackup) { sopsFile = ../hosts/common/secrets.sops.yaml; });
  programs.ssh = lib.mkForce {
    knownHosts = lib.filterAttrs
      (_: v: v.publicKeyFile != null)
      (builtins.mapAttrs
        (name: _: {
          publicKeyFile = (if (lib.pathExists ./keys/ssh_host_${name}_ed25519_key.pub) then ./keys/ssh_host_${name}_ed25519_key.pub else null);
          extraHostNames = (lib.optional (name == config.vm.name) "localhost");
        })
        outputs.nixosConfigurations);
  };

  # Hardware config is always identical
  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/f222513b-ded1-49fa-b591-20ce86a2fe7f";
    fsType = "ext4";
  };
  fileSystems."/boot" = lib.mkForce {
    device = "/dev/disk/by-uuid/12CE-A600";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };
  swapDevices = [ ];
}

