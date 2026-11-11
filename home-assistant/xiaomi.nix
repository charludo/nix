{ pkgs, ... }:
{
  services.home-assistant.extraComponents = [
    "xiaomi_miio"
  ];

  services.home-assistant.extraPackages =
    python3Packages: with python3Packages; [
      python-miio
      vacuum-map-parser-base
      vacuum-map-parser-roborock
      vacuum-map-parser-dreame
      vacuum-map-parser-ijai
      vacuum-map-parser-roidmi
      vacuum-map-parser-viomi
      vacuum-map-parser-xiaomi
    ];

  services.home-assistant.customComponents = [
    pkgs.ours.home-assistant.custom-components.xiaomi_cloud_map_extractor
    pkgs.home-assistant-custom-components.xiaomi_miio_fan
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
