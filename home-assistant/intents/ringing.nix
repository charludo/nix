{ config, lib, ... }:
let
  e = config.hass.entities;
  r = lib.ha.remembrance;
  inherit (r) area callService secondsOf;

  # Jinja: did `Stopp` just end an alarm that wakes up to music?
  musicDismissed = ''
    ${r.jinja}
    {%- set res = action_response -%}
    {%- set ns = namespace(music=false) -%}
    {%- if res.status == 'ok' -%}
      {%- for i in res['items'] if i.kind == 'alarm' and wake_playlist(i.description) -%}
        {%- set ns.music = true -%}
      {%- endfor -%}
    {%- endif -%}
    {%- set music = ns.music -%}
  '';
in
{
  hass.voice.intents = {
    # The one "off": whatever rings (timer, reminder, alarm) is dismissed and
    # the music plays on; with nothing ringing, the speakers go quiet
    # (playback and any announcement). Silent (the quiet is the answer),
    # except for a music wake-up: the playlist keeps playing, so "Wecker
    # beendet" (ducked over it) says the alarm itself is over.
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
            "if" = [
              {
                condition = "template";
                value_template = "{{ res.status != 'ok' }}";
              }
            ];
            "then" = [
              {
                action = "tts_relay.silence";
                data.entity_id = [
                  e.media_player.living_room
                  e.media_player.office
                ];
              }
            ];
          }
          {
            stop = "";
            response_variable = "res";
          }
        ];
        # tts_relay's voice effect, decided per call: "silent" drops the
        # reply, an empty one lets it play.
        card = {
          type = "voice_effect";
          title = "${musicDismissed}{{ '' if music else 'silent' }}";
          content = "";
        };
        speech.text = "${musicDismissed}{{ 'Wecker beendet.' if music else '' }}";
      };
    };

    # Ring again: what is ringing, else what rang last. No duration: the
    # configured snooze delay.
    NochMal = {
      sentences = r.expand { "<dauer>" = r.durationShapes ""; } [
        "In <dauer> noch mal"
        "Erinnere mich in <dauer> noch mal"
        "Noch <dauer>"
        "Schlummern"
        "Später noch mal"
      ];
      lists = { inherit (r.lists) timer_zahl; };
      script = {
        action = callService "snooze" {
          delay = "{{ ${secondsOf ""} }}";
          inherit area;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}
            {%- set i = res['items'][0] -%}
            {%- set secs = i.remaining if i.kind == 'timer' else as_timestamp(i.next_ring) - as_timestamp(now()) -%}
            Okay, in {{ dauer(secs) }} noch mal.
          {%- else -%}Gerade gab es nichts, was ich wiederholen könnte.
          {%- endif -%}
        '';
      };
    };
  };
}
