{ ... }:
{
  hass.scripts = {
    lg_menu = {
      alias = "LG Menu";
      icon = "phu:apple-tv-gen2-remote";
      sequence = [
        {
          action = "webostv.button";
          target.entity_id = "media_player.lg_webos_smart_tv";
          data.button = "MENU";
        }
      ];
    };
  };
}
