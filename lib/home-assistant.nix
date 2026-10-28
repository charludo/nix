{ lib }:
rec {
  # ---------------------------------------------------------------------------
  # Measure the duration of a sound asset in milliseconds, minus a
  # 50 ms head-room so chained "play chime → delay → TTS" steps don't
  # overlap. Returns 0 for `null` (caller is opting out of the chime).
  # Build-time `ffprobe` invocation via runCommand — the path must be
  # in the Nix store (or auto-imported as such).
  soundDurationMs =
    pkgs: path:
    if path == null then
      0
    else
      lib.toInt (
        lib.strings.removeSuffix "\n" (
          builtins.readFile (
            pkgs.runCommand "chime-duration-${baseNameOf path}"
              {
                nativeBuildInputs = [ pkgs.ffmpeg-headless ];
              }
              ''
                ffprobe -v error -show_entries format=duration -of csv=p=0 ${path} \
                  | awk '{ printf "%d", $1 * 1000 - 50 }' > $out
              ''
          )
        )
      );

  # ---------------------------------------------------------------------------
  # Voice intent helpers (satellite vs. chat response differentiation)
  # ---------------------------------------------------------------------------
  #
  # Wraps a `hass.voice.intents.<X>` body so the voice satellite path
  # plays a configured sound (acknowledge) or nothing (silent) instead
  # of relaying the TTS speech onto Sonos. The chat UI still receives
  # the full speech text because the helper only annotates the intent
  # response with a marker card; the speech itself is untouched.
  #
  # Mechanism: the helper adds `script.card = { type = "voice_effect";
  # title = <effect>; content = ""; }` to the intent body. tts_relay
  # reads `response.card.voice_effect.title` from the pipeline's
  # INTENT_END event and, on the subsequent TTS_END, either substitutes
  # the configured sound URL (acknowledge/timer/reminder/alarmclock) or
  # drops the audio entirely (silent). HA's chat UI ignores unknown
  # card types, so the marker is invisible there.
  voice =
    let
      _voiceEffectCard = name: {
        type = "voice_effect";
        title = name;
        content = "";
      };

      mkEffect =
        name: body:
        body
        // {
          script = (body.script or { }) // {
            card = _voiceEffectCard name;
          };
        };

      # area_slug → media_player target for whichever satellite the
      # voice command is spoken on. Walks `hass.ttsRelay` routes,
      # drops ones whose declared media_player has no area set, and
      # keys the survivors by area slug. Internal — the helpers below
      # call this themselves.
      satelliteAreaToTarget =
        config:
        lib.listToAttrs (
          lib.filter (p: p != null) (
            map (
              r:
              let
                slug = lib.removePrefix "media_player." r.target;
                area = config.hass.devices.media_players.${slug}.area or null;
              in
              if area == null then null else lib.nameValuePair (mkSlug area) r.target
            ) (config.hass.ttsRelay or [ ])
          )
        );
    in
    {
      inherit satelliteAreaToTarget;

      # Voice path: play the "acknowledge" sound on the target Sonos
      # instead of speaking the TTS. Use for intents whose only output
      # is a confirmation ("Licht eingeschaltet", "Pausiert", ...).
      acknowledgeAction = mkEffect "acknowledge";

      # Voice path: emit nothing. Use for intents whose action already
      # produces audible feedback (music starting on the same target
      # Sonos), where a spoken confirmation would just talk over it.
      silentAction = mkEffect "silent";

      # One-step action sequence flipping `is_volume_muted` on the
      # given media_player. Drop-in for `script.action` /  `sequence`
      # at any intent or script site.
      muteAction = entity: muted: [
        {
          action = "media_player.volume_mute";
          target.entity_id = entity;
          data.is_volume_muted = muted;
        }
      ];

      # Body wrapper that prepends a satellite-resolution + unmute
      # pair of steps. Loads an `area_to_target` script variable from
      # the host's tts_relay routes, then flips `is_volume_muted` off
      # on the resolved speaker. The `area_to_target` variable stays
      # in scope for the rest of the sequence, so downstream steps
      # can resolve "the satellite's speaker (or a fallback)" via a
      # Jinja lookup.
      #
      # `fallback` (entity_id string, optional) controls what happens
      # when `preferred_area_id` doesn't map to a known target — chat
      # path, automation, non-routed satellite. With no fallback the
      # unmute step is gated by an `if` and silently no-ops; with one,
      # the unmute fires unconditionally against
      # `area_to_target.get(…) or fallback` — same Jinja shape the
      # downstream play step uses, so the unmuted speaker is always
      # the one playback lands on.
      #
      # Composable with silentAction / acknowledgeAction. Dispatches
      # on the body's shape: voice intents get the steps prepended to
      # `script.action`, HA scripts get them prepended to `sequence`.
      unmuteSatellite =
        {
          config,
          fallback ? null,
        }:
        body:
        let
          unmuteStep = target: {
            action = "media_player.volume_mute";
            target.entity_id = target;
            data.is_volume_muted = false;
          };
          unmute =
            if fallback == null then
              {
                "if" = [
                  {
                    condition = "template";
                    value_template = ''{{ area_to_target.get(preferred_area_id | default("")) is not none }}'';
                  }
                ];
                "then" = [ (unmuteStep "{{ area_to_target[preferred_area_id] }}") ];
              }
            else
              unmuteStep ''{{ area_to_target.get(preferred_area_id | default("")) or "${fallback}" }}'';
          steps = [
            { variables.area_to_target = satelliteAreaToTarget config; }
            unmute
          ];
        in
        if body ? sequence then
          body // { sequence = steps ++ body.sequence; }
        else
          body
          // {
            script = (body.script or { }) // {
              action = steps ++ ((body.script or { }).action or [ ]);
            };
          };
    };

  # ---------------------------------------------------------------------------
  # Slug helper (shared with areas and devices)
  # ---------------------------------------------------------------------------

  # Mirrors Home Assistant's `homeassistant.util.slugify`:
  #   1. transliterate German umlauts → ASCII
  #   2. lowercase
  #   3. replace any run of non-[a-z0-9] with a single "_"
  #   4. strip leading/trailing "_"
  # Keep this in sync with the `slugify()` in ha-reconciler/ha_reconciler.py
  # so dashboard entity_ids and the entity_ids the reconciler renames to match.
  mkSlug =
    name:
    let
      transliterated =
        lib.replaceStrings
          [
            "ä"
            "ö"
            "ü"
            "Ä"
            "Ö"
            "Ü"
            "ß"
          ]
          [
            "a"
            "o"
            "u"
            "a"
            "o"
            "u"
            "ss"
          ]
          name;
      lowered = lib.toLower transliterated;
      pieces = builtins.filter (p: builtins.isString p && p != "") (builtins.split "[^a-z0-9]+" lowered);
    in
    lib.concatStringsSep "_" pieces;

  # CamelCase version of `mkSlug` for places (intent names, etc.) that
  # use no underscores and want each piece capitalised.
  mkTitleSlug =
    name:
    lib.concatMapStrings (
      p: if p == "" then "" else (lib.toUpper (builtins.substring 0 1 p)) + (builtins.substring 1 (-1) p)
    ) (lib.splitString "_" (mkSlug name));
}
