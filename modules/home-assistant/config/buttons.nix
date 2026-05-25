{ config, ... }:
let
  e = config.hass.entities;
in
{
  hass.buttons = {
    ${e.zigbee.button_sofa} = {
      single = [
        {
          action = "light.toggle";
          target.entity_id = e.light.strahler.light;
        }
      ];
      double = [
        {
          action = "fan.toggle";
          target.entity_id = e.fan.xiaomi_smart_fan;
        }
      ];
      long = [
        {
          action = "script.turn_on";
          target.entity_id = e.script.daily_summary;
        }
      ];
    };

    ${e.zigbee.button_gewachshaus} = {
      single = [
        {
          action = "switch.toggle";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
      ];
      double = [
        {
          action = "switch.turn_on";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
        { delay.minutes = 5; }
        {
          action = "switch.turn_off";
          target.entity_id = e.switch.steckdose_wasserpumpe.switch;
        }
      ];
    };

    ${e.zigbee.button_buro} = {
      single = [
        {
          action = "media_player.volume_mute";
          target.entity_id = [
            e.media_player.office
            e.media_player.living_room
          ];
          data.is_volume_muted = true;
        }
        { delay.seconds = 1; }
        {
          action = "media_player.media_pause";
          target.entity_id = e.media_player.alle;
        }
      ];
      double = [
        {
          action = "media_player.media_next_track";
          target.entity_id = e.media_player.alle;
        }
        {
          action = "media_player.media_play";
          target.entity_id = e.media_player.alle;
        }
        { delay.seconds = 1; }
        {
          action = "media_player.volume_mute";
          target.entity_id = e.media_player.office;
          data.is_volume_muted = false;
        }
      ];
      long = [
        {
          action = "script.turn_on";
          target.entity_id = e.script.sonos_reset;
        }
      ];
    };
  };
}
