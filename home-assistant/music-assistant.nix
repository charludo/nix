{ pkgs, ... }:
{
  services.music-assistant.providers = [
    "jellyfin"
    "audiobookshelf"

    "hass_players"
    "universal_group"

    "chromecast"
    "sendspin"
    "dlna"
  ];

  services.home-assistant.extraComponents = [ "music_assistant" ];
  services.home-assistant.customComponents = [ pkgs.home-assistant-custom-components.ingress ];
  services.home-assistant.config.ingress.music_assistant = {
    title = "Music Assistant";
    icon = "mdi:music";
    url = "http://127.0.0.1:8095";
    work_mode = "ingress";
  };
}
