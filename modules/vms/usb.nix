{ config, lib, ... }:
let
  cfg = config.vm.hardware.usb;
in
{
  options.vm.hardware.usb = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.strMatching "[0-9a-f]{4}:[0-9a-f]{4}";
            example = "1a86:55d4";
            description = "Vendor and product ID (`lsusb` on the host).";
          };
          usb3 = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Attach to the VM's USB 3 controller.";
          };
        };
      }
    );
    default = [ ];
    description = "Host USB devices passed through to the VM, as usb0, usb1, ... in list order.";
  };

  config = lib.mkIf (cfg != [ ]) {
    image.modules.proxmox.proxmox.qemuExtraConf = lib.listToAttrs (
      lib.imap0 (
        i: device:
        lib.nameValuePair "usb${toString i}" (
          "host=${device.id}" + lib.optionalString device.usb3 ",usb3=1"
        )
      ) cfg
    );
  };
}
