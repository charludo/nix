{ config, ... }:
{
  hass.news = {
    baseUrl =
      let
        id = toString config.vm.id;
      in
      "http://192.168.${builtins.substring 0 2 id}.1${builtins.substring 2 2 id}:8123";

    fallbackTarget = config.hass.entities.media_player.living_room;

    feeds = {
      tagesschau = {
        url = "https://www.tagesschau.de/multimedia/sendung/tagesschau_in_100_sekunden/podcast-ts100-audio-100~podcast.xml";
        volumeAdjust = 0.0;
        order = 1;
      };
      wdrAktuell = {
        url = "https://www1.wdr.de/mediathek/audio/wdr-aktuell-news/wdr-aktuell-152.podcast";
        volumeAdjust = 0.15;
        order = 2;
      };
    };
  };
}
