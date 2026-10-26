{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.vm.hardware.npu;

  # openvino-genai (Whisper on the NPU) fails to build in nixpkgs 2026.4.0;
  # fixed upstream in openvino.genai 8fd47ed3b4 (#4531). The check only needs
  # the OpenVINO runtime.
  python = pkgs.python3.withPackages (p: [
    p.numpy
    p.openvino
  ]);

  # Run as root after passing the NPU through: `sudo npu-check`.
  npu-check = pkgs.writeShellApplication {
    name = "npu-check";
    runtimeInputs = [
      pkgs.pciutils
      pkgs.systemd
      pkgs.intel-npu-driver.validation
      python
    ];
    text = ''
      # Level Zero loader, NPU driver and its graph compiler live here.
      export LD_LIBRARY_PATH=${pkgs.addDriverRunpath.driverLink}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

      ok() { printf '  \e[32mok\e[0m   %s\n' "$1"; }
      bad() { printf '  \e[31mFAIL\e[0m %s\n' "$1"; failed=1; }
      failed=0

      echo "PCI device (class 1200, processing accelerator)"
      if dev=$(lspci -nnk -d ::1200 | grep -A3 -i "8086"); [ -n "$dev" ]; then
        ok "$(head -1 <<<"$dev")"
        if grep -q "Kernel driver in use: intel_vpu" <<<"$dev"; then ok "bound to intel_vpu"; else bad "not bound to intel_vpu"; fi
      else
        bad "no Intel NPU on the PCI bus (passthrough missing?)"
      fi

      echo "Kernel driver and firmware"
      if [ -d /sys/module/intel_vpu ]; then ok "intel_vpu loaded (force_snoop=$(cat /sys/module/intel_vpu/parameters/force_snoop))"; else bad "intel_vpu not loaded"; fi
      fw=$(journalctl -k -b --no-pager | grep -E 'intel_vpu .*Firmware: ' | tail -1 || true)
      if [ -n "$fw" ]; then ok "firmware loaded: ''${fw##*Firmware: }"; else bad "intel_vpu loaded no firmware in this boot"; fi
      if journalctl -k -b --no-pager | grep -q 'Initialized intel_vpu'; then ok "intel_vpu initialized the NPU"; else bad "intel_vpu did not initialize the NPU"; fi
      while read -r l; do bad "$l"; done < <(journalctl -k -b --no-pager | grep -iE 'intel_vpu|ivpu' | grep -iE 'error|fail|timeout' | tail -3 || true)

      echo "Device node"
      if [ -e /dev/accel/accel0 ]; then ok "$(stat -c '/dev/accel/accel0 %U:%G %a' /dev/accel/accel0)"; else bad "/dev/accel/accel0 missing"; fi

      echo "Intel driver self-tests"
      if npu-kmd-test --gtest_filter='Device.*' >/tmp/npu-kmd-test.log 2>&1; then ok "npu-kmd-test Device.*"; else bad "npu-kmd-test Device.* (see /tmp/npu-kmd-test.log)"; fi
      if npu-umd-test --config none --gtest_filter='*Device*' >/tmp/npu-umd-test.log 2>&1; then ok "npu-umd-test (generic scope, *Device*)"; else bad "npu-umd-test (see /tmp/npu-umd-test.log)"; fi

      echo "OpenVINO"
      python3 - <<'PY' || failed=1
      import sys, time
      import numpy as np
      import openvino as ov
      import openvino.opset13 as ops

      core = ov.Core()
      print("  devices:", core.available_devices)
      if "NPU" not in core.available_devices:
          print("  \033[31mFAIL\033[0m OpenVINO sees no NPU")
          sys.exit(1)
      print("  \033[32mok\033[0m  ", core.get_property("NPU", "FULL_DEVICE_NAME"))

      # A small matmul compiled for the NPU, checked against the CPU.
      x = ops.parameter([1, 256], np.float32)
      w = ops.constant(np.random.default_rng(0).standard_normal((256, 256)).astype(np.float32))
      model = ov.Model([ops.matmul(x, w, False, False)], [x])
      inp = np.random.default_rng(1).standard_normal((1, 256)).astype(np.float32)
      t = time.perf_counter()
      npu = core.compile_model(model, "NPU")([inp])[0]
      cpu = core.compile_model(model, "CPU")([inp])[0]
      err = float(np.max(np.abs(npu - cpu)) / (np.max(np.abs(cpu)) + 1e-9))
      status = "\033[32mok\033[0m  " if err < 0.05 else "\033[31mFAIL\033[0m"
      print(f"  {status} matmul on NPU matches CPU (rel. error {err:.4f}, {1000 * (time.perf_counter() - t):.0f} ms incl. compile)")
      if err >= 0.05:
          sys.exit(1)

      PY

      if [ "$failed" = 0 ]; then
        echo "NPU ready."
      else
        echo "NPU not ready, see FAIL lines above."
        exit 1
      fi
    '';
  };
in
{
  options.vm.hardware.npu = {
    enable = lib.mkEnableOption "Intel NPU passthrough support for VMs";

    pciAddress = lib.mkOption {
      type = lib.types.str;
      default = "0000:00:0b.0";
      description = ''
        Host PCI address of the NPU (Intel Core Ultra: usually 00:0b.0). Only
        used for the image's initial Proxmox config; an existing VM needs
        `qm set <id> --hostpci2 <address>,pcie=1` on the host.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.vm.runOnGPUHost || config.vm.hardware.gpu.enable;
        message = "vm.hardware.npu needs the VM on the GPU host (vm.runOnGPUHost): the NPU sits in that machine, and PCIe passthrough needs its q35 machine type.";
      }
    ];

    image.modules.proxmox.proxmox.qemuExtraConf.hostpci2 = "${cfg.pciAddress},pcie=1"; # gpu.nix uses hostpci0 and 1

    # Firmware, the user-space driver (Level Zero) and Intel's validation tool.
    hardware.cpu.intel.npu.enable = true;
    # nixpkgs' driver lacks the graph compiler it loads to build NPU code, and
    # OpenVINO dlopens the Level Zero loader by name: both go next to the
    # driver in /run/opengl-driver/lib. Clients need that on LD_LIBRARY_PATH.
    hardware.graphics.extraPackages = [
      pkgs.ours.intel-npu-compiler
      pkgs.level-zero
    ];

    # Without it the firmware boot times out in a VM (-110): the hypervisor's
    # cache configuration breaks coherency for the NPU's buffers. Needs
    # kernel >= 6.11. https://github.com/intel/linux-npu-driver/issues/46
    boot.extraModprobeConfig = "options intel_vpu force_snoop=1";

    environment.systemPackages = [
      pkgs.pciutils
      npu-check
    ];
  };
}
