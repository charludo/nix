{
  config,
  lib,
  pkgs,
  ...
}:
let
  e = config.hass.entities;
  speakers = [
    e.media_player.living_room
    e.media_player.office
  ];

  # `/local/sounds/<basename>` for the configured reminder chime;
  # served by the bulk sounds symlink in assets.nix. Null-tolerant so
  # the script still works (just without the chime) if no reminder is
  # configured.
  reminderPath = config.hass.voice.sounds.reminder or null;
  reminderUrl = if reminderPath == null then null else "/local/sounds/${baseNameOf reminderPath}";

  # Build-time ffprobe to derive the chime's actual duration in ms.
  # Change the asset and the delay updates automatically. The +50 ms
  # slop covers Sonos audioClip-ack jitter.
  reminderDurationMs =
    if reminderPath == null then
      0
    else
      let
        probed =
          pkgs.runCommand "chime-duration-${baseNameOf reminderPath}"
            {
              nativeBuildInputs = [ pkgs.ffmpeg-headless ];
            }
            ''
              ffprobe -v error -show_entries format=duration -of csv=p=0 ${reminderPath} \
                | awk '{ printf "%d", $1 * 1000 - 50 }' > $out
            '';
      in
      lib.toInt (lib.strings.removeSuffix "\n" (builtins.readFile probed));

  # Per-speaker volume bump common to chime and TTS. Sonos's announce
  # path restores the speaker's prior volume after the clip; the +15
  # only affects this announcement.
  boostedVolume = "{{ [(state_attr(repeat.item, 'volume_level') | float(0.3) * 100 + 15) | int, 100] | min }}";

  playOnAll = mediaUrl: {
    repeat = {
      for_each = speakers;
      sequence = [
        {
          action = "media_player.play_media";
          target.entity_id = "{{ repeat.item }}";
          data = {
            announce = true;
            media_content_id = mediaUrl;
            media_content_type = "music";
            extra.volume = boostedVolume;
          };
        }
      ];
    };
  };
in
{
  # ---------------------------------------------------------------------------
  # Broadcast: TTS-announce a typed message on every Sonos
  # ---------------------------------------------------------------------------
  # Dashboard UX (see view-home.nix, Alarme grid): the Broadcast button
  # toggles `input_boolean.broadcast_open`. While open, a conditional
  # section reveals the message text field and a Send button. Send
  # calls this script with the current user's name (sourced client-side
  # via the button-card's `hass.user.name` template — no UUIDs in Nix)
  # and the typed message. The script broadcasts, then clears the
  # input_text and toggles the input_boolean off, collapsing the form
  # again.
  #
  # On Run:
  #   1. Configured "reminder" chime plays on every speaker (skipped
  #      when no reminder is configured).
  #   2. After the chime's actual length (ffprobed at build time),
  #      TTS plays on every speaker via Piper, prefixed with
  #      "<sender> sagt: ".
  #   3. Input form is reset (input_text cleared, input_boolean off).
  #
  # Per-speaker announce so the +15 volume boost applies to each
  # speaker's own current level. tts.speak isn't used because it
  # doesn't forward `extra.volume` to play_media.

  services.home-assistant.config.input_boolean.broadcast_open = {
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
        required = false;
        selector.text = { };
      };
      message = {
        name = "Nachricht";
        required = true;
        selector.text.multiline = true;
      };
    };
    sequence = (lib.optional (reminderUrl != null) (playOnAll reminderUrl)) ++ [
      { delay.milliseconds = reminderDurationMs; }
      (playOnAll "media-source://tts/tts.piper?message={{ ((sender | default('Jemand', true)) ~ ' sagt: ' ~ message) | urlencode }}")
      {
        action = "input_text.set_value";
        target.entity_id = "input_text.broadcast_message";
        data.value = "";
      }
      {
        action = "input_boolean.turn_off";
        target.entity_id = "input_boolean.broadcast_open";
      }
    ];
  };
}
