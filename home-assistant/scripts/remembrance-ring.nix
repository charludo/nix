{
  config,
  lib,
  pkgs,
  ...
}:
let
  e = config.hass.entities;
  inherit (config.hass.voice) sounds ttsEntity;

  soundUrl = path: "/local/sounds/${baseNameOf path}";

  # Alarms with a "Musik: <playlist>" line in their description wake up to
  # that playlist instead of the chime (`wake_playlist`), on the Sonos's
  # Music Assistant player.
  musicPlayer = {
    ${e.media_player.living_room} = e.media_player.living_room_2;
    ${e.media_player.office} = e.media_player.office_2;
  };
  playlistOf = "${lib.ha.remembrance.jinja}{{ wake_playlist(description | default(\"\", true)) }}";
  # "Sanft" alarms (set as "Weck mich …") get louder every round; others
  # ring at one volume from the start.
  gentleOf = "${lib.ha.remembrance.jinja}{{ wake_gentle(description | default(\"\", true)) }}";
  # Timers and reminders play at the speaker's TTS announcement volume
  # (tts_relay), whatever it is set to now; music ducks under it.
  announceVolumes = lib.listToAttrs (
    map (r: lib.nameValuePair r.target r.volume) (lib.filter (r: r.volume != null) config.hass.ttsRelay)
  );
  announceVolume = "{{ ((${builtins.toJSON announceVolumes}.get(target) or 0.3) * 100) | round | int }}";
  # "Sanft": louder with time (seconds since the first round), whatever the
  # rounds' rhythm: chime +5 and music +0.03 every 10 s.
  elapsed = "((round | int(1)) - 1) * ${toString config.hass.remembrance.settings.ring.alarm.interval}";
  musicVolume = "{{ ([0.10 + 0.003 * ${elapsed}, 0.40] | min) if gentle else 0.30 }}";
  chimeVolume = "{{ ([20 + 0.5 * ${elapsed}, 50] | min) | round | int if gentle else 40 }}";
  musicRound = [
    {
      "if" = [
        {
          condition = "template";
          value_template = "{{ round | int(1) == 1 or gentle }}";
        }
      ];
      "then" = [
        {
          action = "media_player.volume_set";
          target.entity_id = "{{ target }}";
          data.volume_level = musicVolume;
        }
      ];
    }
    {
      "if" = [
        {
          condition = "template";
          value_template = "{{ round | int(1) == 1 }}";
        }
      ];
      "then" = [
        {
          action = "music_assistant.play_media";
          target.entity_id = "{{ player }}";
          data = {
            media_id = "{{ playlist }}";
            media_type = "playlist";
            enqueue = "replace";
          };
        }
      ];
    }
  ];
  sound = {
    inherit (sounds) timer;
    inherit (sounds) reminder;
    alarm = sounds.alarmclock;
  };

  # What a reminder says (twice), from the item remembrance passes: what
  # about, how long until it starts, where. Rendered for every kind, but
  # only reminders have `offset` (an undefined one aborts the script).
  text = ''
    ${lib.ha.remembrance.jinja}
    {%- if kind == 'reminder' -%}
      {%- set o = offset | default(0) | float(0) -%}
      Hier ist deine Erinnerung: {{ label }}{{ ' in ' ~ dauer(o) if o >= 60 else "" }}.
      {%- if location %} Ort: {{ location }}.{% endif -%}
    {%- endif -%}
  '';
  # After the second time: when the next reminder of the same occurrence
  # comes (`next_offset`: seconds before the start; this one rang `offset`
  # before it), if any.
  again = ''
    ${lib.ha.remembrance.jinja}
    {%- if kind == 'reminder' and next_offset is defined and next_offset is not none and next_offset != "" -%}
      {%- set wait = offset | default(0) | float(0) - next_offset | float(0) -%}
      {%- if wait > 0 -%}
        Ich erinnere dich {{ 'in ' ~ dauer(wait) if wait < 3600 else zeitpunkt((now() + timedelta(seconds=wait)).isoformat()) }} erneut.
      {%- endif -%}
    {%- endif -%}
  '';

  playSound = kind: extra: {
    action = "media_player.play_media";
    target.entity_id = "{{ target }}";
    data = {
      announce = true;
      media_content_id = soundUrl sound.${kind};
      media_content_type = "music";
    }
    // lib.optionalAttrs (extra != { }) { inherit extra; };
  };

  # Reminders: chime, the text; 5 s after the text has been said
  # (estimated: Pocket TTS says ~18 characters a second) the same again,
  # then when it comes next. Stops early if dismissed in between.
  reminderTwice =
    let
      volume.volume = announceVolume;
    in
    [
      {
        repeat.count = 2;
        repeat.sequence = [
          (playSound "reminder" volume)
          # A breather between the chime and the text.
          { delay.milliseconds = lib.ha.soundDurationMs pkgs sound.reminder + 1000; }
          {
            action = "media_player.play_media";
            target.entity_id = "{{ target }}";
            data = {
              announce = true;
              media_content_id = "media-source://tts/${ttsEntity}?message={{ (text ~ (' ' ~ again if repeat.last and again else '')) | urlencode }}";
              media_content_type = "music";
              extra = volume;
            };
          }
          {
            "if" = [
              {
                condition = "template";
                value_template = "{{ repeat.first }}";
              }
            ];
            "then" = [
              { delay.seconds = "{{ (1.5 + (text | length) / 18 + 5) | round(1) }}"; }
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = "{{ id not in state_attr('binary_sensor.remembrance_ringing', 'items') | default([], true) | map(attribute='id') | list }}";
                  }
                ];
                "then" = [ { stop = "dismissed"; } ];
              }
            ];
          }
        ];
      }
    ];

  # The speakers of the given areas; none given, or none of them has a
  # speaker: all speakers.
  speakersOf = areas: ''
    {%- set area_to_target = ${builtins.toJSON (lib.ha.voice.satelliteAreaToTarget config)} -%}
    {%- set ns = namespace(speakers=[]) -%}
    {%- for area in ${areas} if area in area_to_target -%}
      {%- set ns.speakers = ns.speakers + [area_to_target[area]] -%}
    {%- endfor -%}
    {{ (ns.speakers or area_to_target.values() | list) | unique | list }}
  '';
in
{
  # Called by remembrance once per ring round, with the item's fields as
  # variables plus `round` (from 1). Rings on the Sonos of each of its
  # `areas` at once (none: everywhere). Timers and alarms only ring (the
  # chime, or an alarm's music), every round; reminders also say what rang.
  hass.scripts.remembrance_ring = {
    alias = "Remembrance ring";
    icon = "mdi:bell-ring";
    mode = "parallel";
    fields = {
      kind.selector.select.options = [
        "timer"
        "reminder"
        "alarm"
      ];
      label.selector.text = { };
      areas.selector.area.multiple = true;
      location.selector.text = { };
      duration.selector.number.mode = "box";
      offset.selector.number.mode = "box";
      next_offset.selector.number.mode = "box";
      round.selector.number.mode = "box";
    };
    sequence = [
      {
        variables = {
          speakers = speakersOf "(areas if areas is sequence and areas is not string else [])";
          inherit text again;
          playlist = playlistOf;
          gentle = gentleOf;
        };
      }
      {
        repeat.for_each = "{{ speakers }}";
        repeat.sequence = [
          {
            action = "script.turn_on";
            target.entity_id = "script.remembrance_ring_speaker";
            data.variables = {
              target = "{{ repeat.item }}";
              id = "{{ id }}";
              kind = "{{ kind }}";
              round = "{{ round | int(1) }}";
              text = "{{ text }}";
              again = "{{ again }}";
              playlist = "{{ playlist }}";
              gentle = "{{ gentle }}";
            };
          }
        ];
      }
    ];
  };

  # One ring round on one speaker (`target`), from remembrance_ring.
  hass.scripts.remembrance_ring_speaker = {
    alias = "Remembrance ring (one speaker)";
    icon = "mdi:bell-ring";
    mode = "parallel";
    sequence = [
      {
        variables.player = "{{ ${builtins.toJSON musicPlayer}.get(target, target) }}";
      }
      {
        action = "media_player.volume_mute";
        target.entity_id = "{{ target }}";
        data.is_volume_muted = false;
      }
      {
        choose = [
          {
            conditions = [
              {
                condition = "template";
                value_template = "{{ kind == 'alarm' }}";
              }
            ];
            sequence = [
              {
                choose = [
                  {
                    conditions = [
                      {
                        condition = "template";
                        value_template = "{{ playlist != '' }}";
                      }
                    ];
                    sequence = musicRound;
                  }
                ];
                default = [ (playSound "alarm" { volume = chimeVolume; }) ];
              }
            ];
          }
          {
            conditions = [
              {
                condition = "template";
                value_template = "{{ kind == 'reminder' }}";
              }
            ];
            sequence = reminderTwice;
          }
        ];
        default = [ (playSound "timer" { volume = announceVolume; }) ];
      }
    ];
  };

  # Snoozed during a music wake-up: pause the music; the next ring starts
  # the playlist again, quietly.
  hass.automations.remembrance_snooze_music = {
    alias = "Remembrance: pause wake-up music on snooze";
    mode = "queued";
    trigger = [
      {
        platform = "event";
        event_type = "remembrance_snoozed";
        event_data.kind = "alarm";
      }
    ];
    action = [
      { variables.description = "{{ trigger.event.data.description }}"; }
      {
        variables = {
          playlist = playlistOf;
          speakers = speakersOf "(trigger.event.data.areas | default([]))";
        };
      }
      {
        condition = "template";
        value_template = "{{ playlist != '' }}";
      }
      {
        action = "media_player.media_pause";
        # The speakers' Music Assistant players.
        target.entity_id = ''
          {%- set ns = namespace(players=[]) -%}
          {%- for speaker in speakers -%}
            {%- set ns.players = ns.players + [${builtins.toJSON musicPlayer}.get(speaker, speaker)] -%}
          {%- endfor -%}
          {{ ns.players }}
        '';
      }
    ];
  };
}
