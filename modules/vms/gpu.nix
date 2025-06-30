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
  options.vm.hardware.gpu.enable = lib.mkEnableOption "enable Intel GPU support for VMs";
  options.vm.runOnGPUHost = lib.mkEnableOption "run on GPU host, but do not require GPU passthrough";

  config = lib.mkMerge [
    (lib.mkIf (cfg.runOnGPUHost || cfg.hardware.gpu.enable) {
      proxmox.qemuConf = {
        scsihw = "virtio-scsi-pci";
        virtio0 = "vm_datastore_local_gpu:vm-${builtins.toString config.vm.id}-disk-0";
      };
      proxmox.qemuExtraConf = {
        cpu = "host";
        balloon = "1";
        machine = "q35";
      };

      vm.networking.interface = "enp6s18";
      snow.vm.proxmoxHost = "proxmox-gpu";
    })

    (lib.mkIf cfg.hardware.gpu.enable {
      proxmox.qemuExtraConf.hostpci0 = "0000:00:02,pcie=1";

      nixpkgs.config.packageOverrides = pkgs: {
        vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
      };
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-ocl
          intel-media-driver
          intel-vaapi-driver
          vaapiVdpau
          libvdpau-va-gl
          intel-compute-runtime
          vpl-gpu-rt
        ];
      };
      hardware.firmware = [ pkgs.linux-firmware ];
      boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.blacklistedKernelModules = [ "i915" ];
      boot.kernelParams = [
        "i915.enable_guc=2"
        "module_blacklist=i915"
        "xe.force_probe=7d51"
        "i915.force_probe=!7d51"
      ];
    })
  ];
}
