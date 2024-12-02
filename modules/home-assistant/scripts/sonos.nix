{ ... }:
{
  hass.scripts = {
    sonos_play_pause = {
      alias = "Sonos play pause";
      icon = "mdi:music-note";
      sequence = [
        {
          action = "media_player.media_play_pause";
          data = { };
          target.entity_id = "media_player.alle";
        }
      ];
    };

    sonos_wohnzimmer_toggle = {
      alias = "Sonos Wohnzimmer toggle";
      icon = "mdi:volume-off";
      sequence = [
        {
          action = "media_player.volume_mute";
          target.entity_id = "media_player.living_room";
          data.is_volume_muted = "{{ not state_attr('media_player.living_room', 'is_volume_muted') }}";
        }
      ];
    };

    sonos_buro_toggle = {
      alias = "Sonos Büro toggle";
      icon = "mdi:volume-off";
      sequence = [
        {
          action = "media_player.volume_mute";
          target.entity_id = "media_player.office";
          data.is_volume_muted = "{{ not state_attr('media_player.office', 'is_volume_muted') }}";
        }
      ];
    };

    sonos_reset = {
      alias = "Sonos reset";
      mode = "single";
      sequence = [
        {
          action = "media_player.media_stop";
          target.entity_id = [
            "media_player.alle"
            "media_player.living_room"
            "media_player.office"
          ];
        }
        {
          action = "media_player.turn_off";
          target.entity_id = "media_player.alle";
        }
        { delay = "00:00:01"; }
        {
          action = "media_player.turn_on";
          target.entity_id = "media_player.alle";
        }
      ];
    };

    media_seek = {
      alias = "Media Seek";
      description = "From: https://github.com/RafhaanShah/Home-Assistant-Config/blob/b09199c4d9425c8af2b9356a65c8e853864176f5/scripts/media/media_seek.yaml";
      icon = "mdi:fast-forward-15";
      mode = "queued";
      sequence = [
        {
          condition = "and";
          conditions = [
            {
              condition = "template";
              value_template = "{{ (state_attr(media_player, 'media_position')) != none }}";
            }
          ];
        }
        {
          data.entity_id = "{{ media_player }}";
          action = "media_player.media_play_pause";
        }
        { delay.milliseconds = 500; }
        {
          data = {
            entity_id = "{{ media_player }}";
            seek_position = "{{ state_attr(media_player, \"media_position\")|int + seek_amount }}";
          };
          action = "media_player.media_seek";
        }
      ];
    };
  };
}
