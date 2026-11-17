{ config, lib, ... }:
let
  e = config.hass.entities;
  r = lib.ha.remembrance;
  inherit (r) area callService;

  # Snooze what rings (or rang) of `kind`; `verb`: "Okay, ich <verb> dich …",
  # `none`: the answer when nothing of that kind rang.
  snooze = kind: verb: none: sentences: {
    inherit sentences;
    lists.remembrance_text.wildcard = true;
    script = {
      action = callService "snooze" {
        inherit kind area;
        delay_text = "{{ text }}";
      };
      speech.text = ''
        ${r.jinja}
        {%- set res = action_response -%}
        {%- if res.status == 'ok' -%}
          {%- set delay = res.parsed.delay | float(0) -%}
          Okay, ich ${verb} dich {{ 'in ' ~ dauer(delay) if delay < 3600 else zeitpunkt(res.parsed.at) }} noch mal.
        {%- elif res.reason == 'in the past' -%}Dieser Zeitpunkt ist schon vorbei.
        {%- elif res.status == 'no_match' -%}${none}
        ${r.notUnderstood}
        {%- else -%}Das hat nicht geklappt.
        {%- endif -%}
      '';
    };
  };
in
{
  hass.voice.intents = {
    # The one "off", for everything at once: whatever rings (timer,
    # reminder, alarm) is dismissed, a ring round already playing is cut off
    # (else its chime and text play to the end, a few seconds after the
    # "Aus"), playback stops (music, wake-up music too, news), and the
    # speakers go quiet (announcements, TTS). Silent: the quiet is the answer.
    Stopp = {
      sentences = [
        "Stopp"
        "Stop"
        "Ist gut"
        "(Timer|Wecker) aus"
        "Ruhe"
        "Aus"
        "Sei (still|ruhig)[ jetzt]"
        "[Halt die ](Klappe|Fresse)[ halten]"
      ];
      script = {
        action = [
          {
            action = "remembrance.dismiss";
            data = { inherit area; };
            response_variable = "res";
          }
          {
            action = "script.turn_off";
            target.entity_id = [
              "script.remembrance_ring"
              "script.remembrance_ring_speaker"
            ];
          }
          # Playback itself: Music Assistant's players (music, wake-up
          # music), which a stop on the Sonos alone may only pause. News
          # plays on the Sonos, which the silence below stops.
          {
            action = "media_player.media_stop";
            target.entity_id = [
              e.media_player.living_room_2
              e.media_player.office_2
            ];
            continue_on_error = true;
          }
          {
            action = "tts_relay.silence";
            data.entity_id = [
              e.media_player.living_room
              e.media_player.office
            ];
          }
        ];
        # tts_relay's voice effect: "silent" drops the reply.
        card = {
          type = "voice_effect";
          title = "silent";
          content = "";
        };
        speech.text = "";
      };
    };

    # Ring again, by kind (timers don't snooze): what is ringing, else what
    # rang last. When as said, read with Duckling ("10 Minuten", "in 10
    # Minuten", "morgen um 17 Uhr"); the answer says when it rings again.
    WeckerSchlummern = snooze "alarm" "wecke" "Gerade hat kein Wecker geklingelt." [
      "[noch] {remembrance_text:text} schlummern"
      "Weck mich in {remembrance_text:text} noch mal"
    ];
    ErinnerungNochMal = snooze "reminder" "erinnere" "Gerade gab es keine Erinnerung." [
      "Erinnere mich {remembrance_text:text} noch mal"
    ];
  };
}
