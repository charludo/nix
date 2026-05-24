{
  services.home-assistant.extraComponents = [
    "zha"
  ];

  services.home-assistant.config = {
    zha = {
      usb_path = "/dev/serial/by-id/usb-ITEAD_SONOFF_Zigbee_3.0_USB_Dongle_Plus_V2_20230807081647-if00";
      database_path = "zigbee.db";
    };
  };
}
