{
  outputs,
  config,
  lib,
  ...
}:
let
  cfg = config.vm;
in
{
  options.vm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "enable vm-specific (hardware) config. For use with proxmox";
    };

    id = lib.mkOption { type = lib.types.int; };
    name = lib.mkOption {
      type = lib.types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
    };

    hardware = {
      cores = lib.mkOption { type = lib.types.ints.positive; };
      memory = lib.mkOption { type = lib.types.ints.positive; };
      storage = lib.mkOption { type = lib.types.str; };
    };

    runOnSecondHost = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    networking = {
      address = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1${
          builtins.substring 2 2 (toString config.vm.id)
        }";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
      };
      bridge = lib.mkOption { type = lib.types.str; };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.30.5"
          "192.168.30.6"
          "192.168.30.13"
          "1.1.1.1"
        ];
      };
      openPorts = {
        tcp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
        udp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    proxmox.qemuConf = {
      boot = lib.mkDefault "order=virtio0";
      scsihw = lib.mkDefault "virtio-scsi-single";
      virtio0 = lib.mkDefault "vm_datastore:vm-${builtins.toString config.vm.id}-disk-0";
      ostype = lib.mkDefault "l26";
      cores = config.vm.hardware.cores;
      memory = config.vm.hardware.memory;
      bios = lib.mkDefault "ovmf";
      name = config.vm.name;
      additionalSpace = "1G";
      bootSize = lib.mkDefault "256M";
      net0 = lib.mkDefault "virtio=00:00:00:00:00:00,bridge=VLAN${
        builtins.substring 0 2 (toString config.vm.id)
      },firewall=1";
      agent = true;
    };
    proxmox.cloudInit.enable = false;
    proxmox.partitionTableType = lib.mkDefault "efi";
    proxmox.qemuExtraConf = {
      ide2 = lib.mkForce "none,media=cdrom";
      kvm = 1;
    };
    virtualisation.diskSize = "auto";

    nvim.enable = true;

    snow = {
      tags =
        [ "vm" ]
        ++ (lib.optionals (!config.nas.backup.enable) [ "stateless" ])
        ++ (lib.optionals (builtins.substring 0 2 config.networking.hostName == "CL") [ "client-vm" ]);
      useRemoteSudo = lib.mkDefault true;
      buildOnTarget = lib.mkDefault false;
      targetHost = lib.mkDefault "paki@${config.vm.networking.address}";
      buildHost = lib.mkDefault null;

      vm = {
        id = cfg.id;
        ip = cfg.networking.address;
        proxmoxHost = lib.mkDefault (if cfg.runOnSecondHost then "proxmox2" else "proxmox");
        proxmoxImageStore = lib.mkDefault "${config.nas.backup.location}/proxmox_images/template/iso";
        resizeDiskBy = cfg.hardware.storage;
      };
    };

    networking = {
      hostName = config.vm.name;
      interfaces = {
        ens18.ipv4.addresses = [
          {
            address = config.vm.networking.address;
            prefixLength = config.vm.networking.prefixLength;
          }
        ];
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

    # Overwriting parts of hosts/common
    programs.ssh = lib.mkForce {
      knownHosts = lib.filterAttrs (_: v: v.publicKeyFile != null) (
        builtins.mapAttrs (name: _: {
          publicKeyFile = (
            if (lib.pathExists ./keys/ssh_host_${name}_ed25519_key.pub) then
              ./keys/ssh_host_${name}_ed25519_key.pub
            else
              null
          );
          extraHostNames = (lib.optional (name == config.vm.name) "localhost");
        }) outputs.nixosConfigurations
      );
    };

    # Hardware config is always identical
    boot.initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
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
      options = [
        "fmask=0022"
        "dmask=0022"
      ];
    };
    swapDevices = [ ];
  };
}
