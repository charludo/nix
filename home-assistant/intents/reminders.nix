{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  # `text`: as said, read by remembrance with Duckling.
  lists.remembrance_text.wildcard = true;

  # "Erinnerung an …" (or "für …") says what about first, "Erinnere mich
  # morgen um 10 an …" when first; remembrance finds both, from "Erinnere
  # mich <text>" (what about follows "an", "für" or "dass").
  remindText = "Erinnere mich {{ text }}";
in
{
  hass.voice.intents = {
    # "Erinnere mich morgen um 10 Uhr vormittags an xyz", "Erinnerung an
    # xyz am 17. April um 5 Uhr nachmittags", "Erinnerung für xyz in 10
    # Minuten". The preposition stays in `text` (remembrance needs it).
    ErinnerungStellen = {
      sentences = [
        "Erinnere mich {remembrance_text:text}"
        "Erinnerung {remembrance_text:text}"
      ];
      inherit lists;
      script = {
        action = callService "create_from_text" {
          kind = "reminder";
          text = remindText;
          inherit area;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}
            {%- set i = res['items'][0] -%}
            Okay, Erinnerung {{ zeitpunkt(i.start) }}: {{ i.label }}.
          {%- elif res.reason == 'no summary' -%}Ich habe nicht verstanden, woran ich dich erinnern soll.
          ${r.notUnderstood}
          ${r.failed "Erinnerungen"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

    # "Was steht an" (today), "Was steht <wann> an": "morgen", "Dienstag",
    # "nächsten Samstag", "am 17. April", "nächste Woche".
    ErinnerungenHeute = {
      sentences = [
        "Was steht an"
        "Was steht {remembrance_text:text} an"
      ];
      inherit lists;
      script = {
        action = callService "query" {
          kind = "reminder";
          when_text = "{{ text if text is defined else 'heute' }}";
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- set items = res['items'] -%}
          {%- if res.status == 'ok' -%}
            {%- set one_day = (as_datetime(res.parsed.to) - as_datetime(res.parsed['from'])).total_seconds() <= 86400 -%}
            {%- set tag = datum(res.parsed['from']) -%}
            {%- set tag = tag[:1] | upper ~ tag[1:] -%}
            {%- if not items -%}{{ tag if one_day else 'Da' }} steht nichts an.
            {%- elif one_day -%}
              {{ tag }}:
              {%- for i in items %} um {{ uhrzeit(as_local(as_datetime(i.start))) }} {{ i.label }}{{ ',' if not loop.last else '.' }}
              {%- endfor -%}
            {%- else -%}
              {{ items | length }} {{ 'Erinnerung' if items | length == 1 else 'Erinnerungen' }}:
              {%- for i in items %} {{ zeitpunkt(i.start) }} {{ i.label }}{{ ',' if not loop.last else '.' }}
              {%- endfor -%}
            {%- endif -%}
          ${r.notUnderstood}
          ${r.failed "Erinnerungen"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

    # "Erinnerung an <was/wann> löschen", "Lösche [die|meine] Erinnerung an
    # <was/wann>": what about ("den Zahnarzt"), when ("morgen um 9"), or both.
    ErinnerungLoeschen = {
      sentences = [
        "Erinnerung an {remembrance_text:text} löschen"
        "Lösche [die|meine] Erinnerung an {remembrance_text:text}"
      ];
      inherit lists;
      script = {
        action = callService "reminder_delete_from_text" {
          text = "{{ text }}";
          inherit area;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}
            {%- set i = res['items'][0] -%}
            Erinnerung {{ zeitpunkt(i.start) }} an {{ i.label }} gelöscht.
          {%- elif res.status == 'ambiguous' -%}{{ erinnerung_choices(res.candidates) }}
          {%- elif res.status == 'no_match' -%}Diese Erinnerung gibt es nicht.
          ${r.notUnderstood}
          ${r.failed "Erinnerungen"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };
  };
}
