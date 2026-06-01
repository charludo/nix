{ config, lib, ... }:
let
  e = config.hass.entities;

  silent = lib.ha.voice.silentAction;

  # area_slug → target media_player for the volume intents, derived
  # from the tts_relay routes plus each target's declared area in
  # hass.devices.media_players. The conversation framework injects the
  # calling satellite's area as `preferred_area_id`, so the script can
  # look up the right speaker without knowing anything satellite-side.
  # Targets whose area isn't declared in Nix are dropped silently — the
  # zha-reconciler would push that area assignment if it were set.
  mediaPlayers = config.hass.devices.media_players;
  areaToTarget = lib.listToAttrs (
    lib.filter (p: p != null) (
      map (
        r:
        let
          slug = lib.removePrefix "media_player." r.target;
          area = mediaPlayers.${slug}.area or null;
        in
        if area == null then null else lib.nameValuePair (lib.ha.mkSlug area) r.target
      ) (config.hass.ttsRelay or [ ])
    )
  );

  # Build the volume intent's action: load the area→target map as a
  # script variable, then call media_player.volume_set with whatever
  # `computeVolume` evaluates to, but only when preferred_area_id maps
  # to a known target. Outside the satellite path (chat, non-routed
  # assist) `preferred_area_id` is unset, the lookup returns none, and
  # the `if` short-circuits — the intent stays a no-op.
  volumeAction = computeVolume: [
    { variables.area_to_target = areaToTarget; }
    {
      "if" = [
        {
          condition = "template";
          value_template = ''{{ area_to_target.get(preferred_area_id | default("")) is not none }}'';
        }
      ];
      "then" = [
        {
          action = "media_player.volume_set";
          target.entity_id = "{{ area_to_target[preferred_area_id] }}";
          data.volume_level = computeVolume;
        }
      ];
    }
  ];

  # Half a step on the user-visible 1–10 scale. Jinja expressions used
  # by Musik_Lauter / Musik_Leiser to read the target's current volume
  # off its state and shift by ±0.05, clamped to [0, 1].
  relativeVolume = op: ''
    {%- set t = area_to_target[preferred_area_id] -%}
    {%- set cur = (state_attr(t, 'volume_level') or 0.5) | float -%}
    {{ ${op} }}
  '';
in
{
  hass.voice.intents = {
    # Volume intents route to "the speaker for this satellite" via
    # `preferred_area_id`, which the conversation framework derives
    # from the calling satellite's area. The Nix-side area→target map
    # comes from the tts_relay routes (see `areaToTarget` above), so
    # adding a satellite just means setting its area + adding a
    # ttsRelay route — no per-intent edits. Chat-path and non-area
    # satellites short-circuit the action and the intent is a no-op.
    Musik_Lautstaerke = silent {
      sentences = [ "Lautstärke {level}" ];
      lists.level.range = {
        from = 1;
        to = 10;
      };
      script.action = volumeAction "{{ (level | int) / 10 }}";
    };

    Musik_Lauter = silent {
      sentences = [
        "Lauter"
        "Lautstärke (hoch|höher|hoeher)"
      ];
      script.action = volumeAction (relativeVolume "[1.0, cur + 0.05] | min");
    };

    Musik_Leiser = silent {
      sentences = [
        "Leiser"
        "Lautstärke (runter|niedriger)"
      ];
      script.action = volumeAction (relativeVolume "[0.0, cur - 0.05] | max");
    };

    # Hard mute: kill normal playback (media_stop) AND any in-flight
    # Sonos audioClip announce (cancelAudioClip via cloud websocket).
    # Both layers matter because the announce path is independent of
    # the queue/volume — pausing the queue or muting the speaker does
    # nothing to a running announce. tts_relay.silence wraps both.
    Stille_Alle = silent {
      sentences = [
        "[Halt die ](Klappe|Fresse)[ halten]"
        "Sei (still|ruhig)[ jetzt]"
        "Stille"
        "Ruhe"
        "Aus"
      ];
      script.action = [
        {
          action = "tts_relay.silence";
          data.entity_id = [
            e.media_player.living_room
            e.media_player.office
          ];
        }
      ];
    };
  };
}
