{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  cfg = config.vm;
in
{
  imports = [
    ./client.nix
    ./certs.nix
    ./gpu.nix
  ];

  options.vm = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "enable vm-specific (hardware) config. For use with proxmox";
    };

    id = lib.mkOption {
      type = lib.types.int;
      description = "id of the vm. For use with proxmox";
    };
    name = lib.mkOption {
      type = lib.types.strMatching "^$|^[[:alnum:]]([[:alnum:]_-]{0,61}[[:alnum:]])?$";
      description = "name of the vm. For use with proxmox";
    };

    hardware = {
      cores = lib.mkOption {
        type = lib.types.ints.positive;
        description = "number of CPU cores of the vm. For use with proxmox";
      };
      memory = lib.mkOption {
        type = lib.types.ints.positive;
        description = "amount of memory the VM will have. For use with proxmox";
      };
      storage = lib.mkOption {
        type = lib.types.str;
        description = "disk size of the VM. For use with proxmox";
      };
    };

    networking = {
      interface = lib.mkOption {
        type = lib.types.str;
        default = "ens18";
        description = "network interface name. For use with proxmox";
      };
      address = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1${
          builtins.substring 2 2 (toString config.vm.id)
        }";
        defaultText = lib.literalExpression ''
          192.168.''${builtins.substring 0 2 (toString config.vm.id)}.1''${
            builtins.substring 2 2 (toString config.vm.id)
          }
        '';
        description = "IPv4 address computed from the VM ID";
      };
      gateway = lib.mkOption {
        type = lib.types.str;
        default = "192.168.${builtins.substring 0 2 (toString config.vm.id)}.1";
        defaultText = lib.literalExpression "192.168.\${builtins.substring 0 2 (toString config.vm.id)}.1";
        description = "gateway the VM should use";
      };
      prefixLength = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "prefix length the VM should use";
      };
      bridge = lib.mkOption {
        type = lib.types.str;
        description = "bridge the VM should use";
      };
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "192.168.30.5"
          "192.168.30.6"
          "192.168.30.13"
        ]
        ++ private-settings.upstreamDNS.ips;
        defaultText = lib.literalExpression ''
          [
            "192.168.30.5"
            "192.168.30.6"
            "192.168.30.13"
          ] ++ private-settings.upstreamDNS.ips'';
        description = "DNS servers to be used by the VM";
      };
      openPorts = {
        tcp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = "ports to open for TCP traffic";
        };
        udp = lib.mkOption {
          type = lib.types.listOf lib.types.int;
          default = [ ];
          description = "ports to open for UDP traffic";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    proxmox.qemuConf = {
      scsihw = lib.mkDefault "virtio-scsi-single";
      virtio0 = lib.mkDefault "vm_datastore:vm-${builtins.toString config.vm.id}-disk-0";
      boot = "order=virtio0";
      ostype = "l26";
      cores = config.vm.hardware.cores;
      memory = config.vm.hardware.memory;
      bios = "ovmf";
      name = config.vm.name;
      additionalSpace = "1G";
      bootSize = "256M";
      net0 = "virtio=00:00:00:00:00:00,bridge=VLAN${
        builtins.substring 0 2 (toString config.vm.id)
      },firewall=1";
      agent = true;
    };

    proxmox.cloudInit.enable = false;
    proxmox.partitionTableType = lib.mkDefault "efi";
    proxmox.qemuExtraConf = {
      cpu = "host";
      ide2 = lib.mkForce "none,media=cdrom";
      kvm = 1;
    };
    virtualisation.diskSize = "auto";

    nvim.enable = true;

    snow = {
      enable = true;
      tags = [
        "vm"
      ]
      ++ (lib.optionals (!config.nas.backup.enable) [ "stateless" ])
      ++ (lib.optionals (builtins.substring 0 2 config.networking.hostName == "CL") [ "client-vm" ]);
      useRemoteSudo = lib.mkDefault true;
      askSudoPassword = lib.mkDefault false;
      buildOnTarget = lib.mkDefault false;
      targetHost = lib.mkDefault "paki@${config.vm.networking.address}";
      buildHost = lib.mkDefault "gsv";

      vm = {
        id = cfg.id;
        ip = cfg.networking.address;
        proxmoxHost = lib.mkDefault "proxmox";
        proxmoxImageStore = lib.mkDefault "${config.nas.backup.location}/proxmox_images/template/iso";
        resizeDiskTo = cfg.hardware.storage;
      };
    };

    fish.enable = true;
    environment.shells = with pkgs; [
      fish
      bash
    ];

    networking = {
      hostName = config.vm.name;
      interfaces.${cfg.networking.interface}.ipv4.addresses = [
        {
          address = config.vm.networking.address;
          prefixLength = config.vm.networking.prefixLength;
        }
      ];
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
    programs.ssh.knownHosts = lib.mkForce { };

    security.pki.certificateFiles = [ private-settings.caIssuing1.root ];

    nix.gc = {
      automatic = true;
      dates = "monthly";
      options = "-d";
    };
    nix.settings = {
      extra-substituters = [ "https://cache.${private-settings.domains.blog}" ];
      extra-trusted-public-keys = [
        "cache.${private-settings.domains.blog}-1:uh2KzANysUoaMiEesTO2IkE2h/ycuJKE3Jx8yz4XYJI="
      ];
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
    boot.kernel.sysctl."vm.swappiness" = 0;
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
