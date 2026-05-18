{
  services.home-assistant.extraComponents = [
    "zha"
  ];

  services.home-assistant.config = {
    zha = { };

    # Sonoff ZBDongle-E (Silicon Labs EFR32MG21, CP210x UART bridge).
    # Uncomment once the dongle is passed through to the VM and the
    # /dev/serial/by-id path is stable. The path below is the conventional
    # one for CP210x; adjust the serial suffix after `ls /dev/serial/by-id`.
    #
    # zha = {
    #   device = {
    #     path = "/dev/serial/by-id/usb-Itead_Sonoff_Zigbee_3.0_USB_Dongle_Plus_<SERIAL>-if00-port0";
    #     baudrate = 115200;
    #     flow_control = "software";
    #   };
    #   radio_type = "ezsp";
    # };
  };

  # USB passthrough — add to the HA VM (vms/SRV-HOMEASSISTANT.nix) once the
  # dongle is plugged into the Proxmox host. Vendor:product for the
  # ZBDongle-E is 10c4:ea60 (Silicon Labs CP210x). Prefer host=BUS-PORT over
  # vid:pid if you ever have two CP210x devices on the same host.
  #
  # proxmox.qemuExtraConf.usb0 = "host=10c4:ea60,usb3=1";
}
