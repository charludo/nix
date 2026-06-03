{
  config,
  lib,
  pkgs,
  ...
}:
let
  e = config.hass.entities;

  reminderPath = config.hass.voice.sounds.reminder;
  reminderUrl = if reminderPath == null then null else "/local/sounds/${baseNameOf reminderPath}";
  reminderDurationMs =
    if reminderPath == null then
      0
    else
      lib.toInt (
        lib.strings.removeSuffix "\n" (
          builtins.readFile (
            pkgs.runCommand "chime-duration-${baseNameOf reminderPath}"
              {
                nativeBuildInputs = [ pkgs.ffmpeg-headless ];
              }
              ''
                ffprobe -v error -show_entries format=duration -of csv=p=0 ${reminderPath} \
                  | awk '{ printf "%d", $1 * 1000 - 50 }' > $out
              ''
          )
        )
      );

  playOnAll = mediaUrl: {
    repeat = {
      for_each = [
        e.media_player.living_room
        e.media_player.office
      ];
      sequence = [
        {
          action = "media_player.play_media";
          target.entity_id = "{{ repeat.item }}";
          data = {
            announce = true;
            media_content_id = mediaUrl;
            media_content_type = "music";
            extra.volume = "{{ [(state_attr(repeat.item, 'volume_level') | float(0.3) * 100 + 15) | int, 100] | min }}";
          };
        }
      ];
    };
  };
in
{
  hass.devices.input_booleans.broadcast_open = {
    name = "Broadcast form open";
    icon = "mdi:bullhorn";
  };

  services.home-assistant.config.input_text.broadcast_message = {
    name = "Broadcast";
    icon = "mdi:bullhorn";
    max = 200;
    initial = "";
  };

  hass.scripts.broadcast_announce = {
    alias = "Broadcast announce";
    icon = "mdi:bullhorn";
    mode = "queued";
    fields = {
      sender = {
        name = "Absender";
        selector.text = { };
      };
      message = {
        name = "Nachricht";
        required = true;
        selector.text.multiline = true;
      };
    };
    sequence =
      lib.optionals (reminderUrl != null) [
        (playOnAll reminderUrl)
        { delay.milliseconds = reminderDurationMs; }
      ]
      ++ [
        (playOnAll "media-source://tts/tts.piper?message={{ ((sender | default('Jemand', true)) ~ ' sagt: ' ~ message) | urlencode }}")
        {
          action = "input_text.set_value";
          target.entity_id = "input_text.broadcast_message";
          data.value = "";
        }
        {
          action = "input_boolean.turn_off";
          target.entity_id = e.input_boolean.broadcast_open;
        }
      ];
  };
}
