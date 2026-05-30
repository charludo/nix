{ pkgs, ... }:
{
  services.music-assistant.providers = [
    "jellyfin"
    "audiobookshelf"

    # Sonos speakers are surfaced via HA's Sonos integration (which
    # owns `sonos.snapshot` / `sonos.restore`; tts_relay depends on
    # those). MA's `hass_players` provider wraps the HA-side entities
    # so it can still queue tracks to them — enabling MA's own `sonos`
    # provider would just duplicate every speaker as `<name>_2`.
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
