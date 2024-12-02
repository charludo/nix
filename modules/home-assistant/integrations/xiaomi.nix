{ pkgs, ... }:
{
  services.home-assistant.extraComponents = [
    "xiaomi_miio"
  ];

  services.home-assistant.customComponents = with pkgs.ours.home-assistant.custom-components; [
    xiaomi_cloud_map_extractor
    xiaomi_miio_fan
  ];

  services.home-assistant.config = {
    xiaomi_miio = { };

    fan = [
      {
        platform = "xiaomi_miio_fan";
        name = "Xiaomi Smart Fan";
        host = "192.168.10.57";
        token = "!secret xiaomi_fan_token";
      }
    ];
  };
}
