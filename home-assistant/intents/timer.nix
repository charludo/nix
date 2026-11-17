{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  # `label`: a timer's name as said ("Nudel", "60 Minuten", "Eine Stunde");
  # `text`: a duration as said. Both read by remembrance (with Duckling).
  lists = {
    timer_label.wildcard = true;
    remembrance_text.wildcard = true;
  };

  # A timer as said ("Timer", "60 Minuten Timer", "Eine Stunde Timer",
  # "Nudel Timer"): remembrance reads its set duration or label from it, and
  # with neither takes the only timer.
  named = {
    text = "{{ label ~ ' ' if label is defined else '' }}Timer";
    inherit area;
  };

  # Speech for a timer action: `ok` (Jinja; `t` is the timer) on success,
  # the shared answers otherwise.
  speak = ok: ''
    ${r.jinja}
    {%- set r = action_response -%}
    {%- set t = r['items'][0] if r['items'] else none -%}
    {%- if r.status == 'ok' -%}${ok}
    {%- elif r.status == 'ambiguous' -%}{{ timer_choices(r.candidates) }}
    {%- elif r.status == 'no_match' -%}Diesen Timer gibt es nicht.
    {%- elif r.reason == 'no duration' -%}Ich habe nicht verstanden, um wie viel.
    {%- else -%}Das geht bei {{ 'dem ' ~ timer_name(t) if t else 'diesem Timer' }} gerade nicht.
    {%- endif -%}
  '';

  mkIntent = sentences: service: data: ok: {
    inherit sentences lists;
    script = {
      action = callService service data;
      speech.text = speak ok;
    };
  };

  # "[<name>] Timer um <duration> <verb>", "<Imperative> den [<name>] Timer
  # um <duration>"; any duration Duckling reads. The timer keeps its name:
  # "the 20 minute timer" stays that.
  adjust =
    verbs: imperatives: shorten: participle:
    mkIntent
      [
        "{timer_label:label} Timer um {remembrance_text:text} (${verbs})"
        "Timer um {remembrance_text:text} (${verbs})"
        "(${imperatives}) den {timer_label:label} Timer um {remembrance_text:text}"
        "(${imperatives}) den Timer um {remembrance_text:text}"
      ]
      "timer_adjust"
      (
        named
        // {
          delta_text = "{{ text }}";
          inherit shorten;
        }
      )
      "{{ timer_name(t) }} um {{ dauer(r.parsed.delta | abs) }} ${participle}, noch {{ dauer(t.remaining) }}.";

in
{
  hass.voice.intents = {
    # "10 Minuten Timer[, ab jetzt]", "10 Minuten, ab jetzt", "Stelle einen
    # Timer auf 10 Minuten", "[Nudel] Timer (auf|für) 10 Minuten [starten]":
    # any duration Duckling reads ("anderthalb Stunden", "3,5 Minuten").
    # One intent: remembrance gets the same sentence for every pattern, as
    # "[<label>] Timer auf <duration>". Said without a duration (chatter
    # caught by a pattern), nothing starts.
    # "Nudeltimer" (one word) works too: closest_intent splits the compound.
    TimerStellen = {
      sentences = [
        # "auf"/"für" required: "<name> Timer <text>" and "Timer <text>" took
        # any sentence containing "Timer" ("Verlängere den Timer um …"
        # started a timer).
        "{timer_label:label} Timer (auf|für) {remembrance_text:text} [starten]"
        "Stelle einen Timer auf {remembrance_text:text}"
        "Timer (auf|für) {remembrance_text:text} [starten]"
        "{remembrance_text:text} Timer ab jetzt"
        "{remembrance_text:text} Timer"
        "{remembrance_text:text} ab jetzt"
      ];
      inherit lists;
      script = {
        action = callService "create_from_text" {
          kind = "timer";
          text = "{{ label ~ ' ' if label is defined else '' }}Timer auf {{ text }}";
          inherit area;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- set t = res['items'][0] if res['items'] else none -%}
          {%- if res.status == 'ok' -%}
            {{ timer_name(t) }}{{ ' auf ' ~ dauer(t.duration) if t.label else "" }} - ab jetzt.
          {%- elif res.reason == 'no duration' -%}Ich habe nicht verstanden, wie lange der Timer laufen soll.
          ${r.notUnderstood}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

    TimerVerlaengern = adjust "verlängern" "Verlängere" false "verlängert";
    TimerVerkuerzen = adjust "verkürzen|reduzieren" "Verkürze|Reduziere" true "verkürzt";

    # Without a name, the only timer (several: lists them).
    TimerLoeschen = mkIntent [
      "{timer_label:label} Timer (löschen|abbrechen|beenden)"
      "Timer (löschen|abbrechen|beenden)"
    ] "timer_cancel" named "{{ timer_name(t) }} gelöscht.";

    TimerAlleLoeschen = {
      sentences = [ "Alle Timer (löschen|abbrechen|beenden)" ];
      script = {
        action = callService "timer_cancel" { all = true; };
        speech.text = ''
          {%- set n = action_response['items'] | length -%}
          {{ 'Es läuft kein Timer.' if n == 0 else ('Timer gelöscht.' if n == 1 else 'Alle ' ~ n ~ ' Timer gelöscht.') }}
        '';
      };
    };

    # Without a name, all timers.
    TimerRestzeit = {
      sentences = [
        "Wie lang[e] noch auf dem {timer_label:label} Timer"
        "Wann geht der {timer_label:label} Timer"
        "Wie lang[e] (ist|läuft) [noch] der {timer_label:label} Timer [noch]"
        "Wie lang[e] noch"
        "Wann geht [mein|der] Timer"
        # "Wie lang ist mein Timer?" went to TimerStellen ("{text} Timer").
        "Wie lang[e] (ist|läuft) [noch] (mein|der) Timer"
        "Wie lang[e] läuft (mein|der) Timer noch"
      ];
      inherit lists;
      script = {
        action = callService "query" ({ kind = "timer"; } // named);
        speech.text = ''
          ${r.jinja}
          {%- set items = action_response['items'] | rejectattr('state', 'eq', 'ringing') | list -%}
          {%- if not items -%}Es läuft kein Timer.
          {%- else -%}
            {%- for t in items -%}
              {{ timer_name(t) }}: {{ 'pausiert, ' if t.state == 'paused' else "" }}noch {{ dauer(t.remaining) }}.{{ ' ' if not loop.last }}
            {%- endfor -%}
          {%- endif -%}
        '';
      };
    };
  };
}
