{ config, ... }:
let
  e = config.hass.entities;

  mkVolumeToggle = name: entity: {
    alias = "Sonos ${name} toggle";
    icon = "mdi:volume-off";
    sequence = [
      {
        action = "media_player.volume_mute";
        target.entity_id = entity;
        data.is_volume_muted = "{{ not state_attr('${entity}', 'is_volume_muted') }}";
      }
    ];
  };
in
{
  hass.scripts = {
    sonos_play_pause = {
      alias = "Sonos play pause";
      icon = "mdi:music-note";
      sequence = [
        {
          action = "media_player.media_play_pause";
          target.entity_id = e.media_player.alle;
        }
      ];
    };

    sonos_wohnzimmer_toggle = mkVolumeToggle "Wohnzimmer" e.media_player.living_room;
    sonos_buro_toggle = mkVolumeToggle "Büro" e.media_player.office;

    sonos_reset = {
      alias = "Sonos reset";
      mode = "single";
      sequence = [
        {
          action = "media_player.media_stop";
          target.entity_id = [
            e.media_player.alle
            e.media_player.living_room
            e.media_player.office
          ];
        }
        {
          action = "media_player.turn_off";
          target.entity_id = e.media_player.alle;
        }
        { delay.seconds = 1; }
        {
          action = "media_player.turn_on";
          target.entity_id = e.media_player.alle;
        }
      ];
    };

    media_seek = {
      alias = "Media Seek";
      icon = "mdi:fast-forward-15";
      mode = "queued";
      sequence = [
        {
          condition = "template";
          value_template = "{{ (state_attr(media_player, 'media_position')) != none }}";
        }
        {
          action = "media_player.media_play_pause";
          target.entity_id = "{{ media_player }}";
        }
        { delay.milliseconds = 500; }
        {
          action = "media_player.media_seek";
          target.entity_id = "{{ media_player }}";
          data.seek_position = ''{{ state_attr(media_player, "media_position")|int + seek_amount }}'';
        }
      ];
    };
  };
}
