{ config, lib, ... }:
{
  hass.scripts.daily_summary =
    lib.ha.voice.unmuteSatellite
      {
        inherit config;
        fallback = config.hass.news.fallbackTarget;
      }
      {
        alias = "Tägliche Zusammenfassung";
        icon = "mdi:newspaper-variant";
        mode = "restart";
        sequence = config.hass.news.actions.summary;
      };
}
