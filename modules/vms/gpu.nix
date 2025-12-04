{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vm;
in
{
  options.vm.hardware.gpu.enable = lib.mkEnableOption "Intel GPU support for VMs";
  options.vm.runOnGPUHost = lib.mkEnableOption "run on GPU host, but do not require GPU passthrough";

  config = lib.mkMerge [
    (lib.mkIf (cfg.runOnGPUHost || cfg.hardware.gpu.enable) {
      proxmox.qemuConf = {
        scsihw = "virtio-scsi-pci";
        virtio0 = "vm_datastore_local_gpu:vm-${builtins.toString config.vm.id}-disk-0";
      };
      proxmox.qemuExtraConf = {
        balloon = "0";
        machine = "q35";
      };

      boot.kernelModules = lib.mkForce [ "kvm-intel" ];

      vm.networking.interface = "enp6s18";
      snow.vm.proxmoxHost = "proxmox-gpu";
    })

    (lib.mkIf cfg.hardware.gpu.enable {
      environment.systemPackages = with pkgs; [
        pciutils
        clinfo
        intel-gpu-tools
      ];

      proxmox.qemuExtraConf.hostpci0 = "0000:00:02,pcie=1";

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
          vpl-gpu-rt
        ];
      };
      hardware.enableAllFirmware = true;
      hardware.firmware = [ pkgs.linux-firmware ];
      boot.kernelPackages = pkgs.linuxPackages_latest;
    })
  ];
}
