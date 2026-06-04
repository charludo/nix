{ pkgs, ... }:
{
  services.home-assistant.extraComponents = [
    "xiaomi_miio"
  ];

  services.home-assistant.extraPackages =
    python3Packages:
    let
      p = pkgs.ours.home-assistant.custom-components.mkVacuumParsers python3Packages;
    in
    with python3Packages;
    [
      python-miio
      vacuum-map-parser-base
      vacuum-map-parser-roborock
      p.vacuum-map-parser-dreame
      p.vacuum-map-parser-ijai
      p.vacuum-map-parser-roidmi
      p.vacuum-map-parser-viomi
      p.vacuum-map-parser-xiaomi
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
