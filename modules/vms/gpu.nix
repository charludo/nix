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
        libva-utils
        nvtopPackages.intel
      ];

      proxmox.qemuExtraConf.hostpci0 = "0000:00:02,pcie=1";
      proxmox.qemuExtraConf.hostpci1 = "0000:00:1f,pcie=1";

      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-ocl
          intel-media-driver
          intel-compute-runtime
          vpl-gpu-rt
        ];
      };
      hardware.enableAllFirmware = true;
      hardware.intel-gpu-tools.enable = true;
      hardware.firmware = [ pkgs.linux-firmware ];
      boot.kernelPackages = pkgs.linuxPackages_latest;
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
    })
  ];
}
