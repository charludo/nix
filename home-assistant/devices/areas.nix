{ config, lib, ... }:
let
  a = lib.mapAttrs (_: v: v.name) config.hass.entities.area;
in
{
  hass.devices = {
    media_players = {
      alle = { };
      living_room.area = a.wohnzimmer;
      office.area = a.buro;
      lg_c4.area = a.wohnzimmer;
    };

    vacuums.botty.area = a.wohnzimmer;
    fans.xiaomi_smart_fan.area = a.wohnzimmer;
    images.botty_live_map.area = a.wohnzimmer;
    suns.sun = { };
    weathers.openweathermap = { };

    sensors = {
      rain_rate.area = a.terrasse;
      cumulative_rain_8h.area = a.terrasse;
      cumulative_rain_24h.area = a.terrasse;
      zigbee_min_battery = { };
      botty_current_clean_area.area = a.wohnzimmer;
      botty_aktuelle_reinigungsdauer.area = a.wohnzimmer;
      botty_aktueller_reinigungsbereich.area = a.wohnzimmer;
      botty_restkapazitat_der_hauptburste.area = a.wohnzimmer;
      botty_restkapazitat_der_seitenburste.area = a.wohnzimmer;
      botty_filter_restkapazitat.area = a.wohnzimmer;
      botty_bis_sensorreinigung_verbleibend.area = a.wohnzimmer;
      tursensor_last_changed.area = a.wohnzimmer;
      openweathermap_gefuhlte_temperatur = { };
      openweathermap_temperatur = { };
      openweathermap_windgeschwindigkeit = { };
      openweathermap_bewolkung = { };
      openweathermap_regenintensitat = { };
      openweathermap_windboengeschwindigkeit = { };
      openweathermap_forecast_daily = { };
      openweathermap_forecast_hourly = { };
      sun_next_dawn = { };
      sun_next_dusk = { };
    };
  };
}
