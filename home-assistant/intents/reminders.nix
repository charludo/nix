{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  expand = r.expand {
    "<tag>" = [ "{remembrance_tag:day}" ];
  };

  lists = {
    inherit (r.lists) remembrance_tag;
    erinnerung_text.wildcard = true;
  };

  # Set from the sentence as said: remembrance reads when ("in 10 Minuten",
  # "morgen um 7 Uhr 15", "am Samstag": at 9) and what about (after "an" or
  # "dass", wherever the time is).
  createIntents = r.fromText {
    name = "ErinnerungStellen";
    kind = "reminder";
    sentences = [ "Erinnere mich {remembrance_text:text}" ];
    speech = ''
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
in
{
  hass.voice.intents = createIntents // {
    ErinnerungenHeute = {
      sentences = expand [
        "Was steht <tag> an"
        "Was steht an"
        "Welche Erinnerungen habe ich <tag>"
        "Welche Erinnerungen habe ich"
      ];
      inherit lists;
      script = {
        action = callService "query" {
          kind = "reminder";
          from = "${r.jinja}{{ zieltag(day | default('0')) }}T00:00:00";
          to = "${r.jinja}{{ zieltag(day | default('0')) }}T23:59:59";
        };
        speech.text = ''
          ${r.jinja}
          {%- set items = action_response['items'] -%}
          {%- set tag = tag_name(day | default('0')) -%}
          {%- if not items -%}{{ tag[:1] | upper ~ tag[1:] }} steht nichts an.
          {%- else -%}
            {{ tag[:1] | upper ~ tag[1:] }}:
            {%- for i in items %} um {{ uhrzeit(as_local(as_datetime(i.start))) }} {{ i.label }}{{ ',' if not loop.last else '.' }}
            {%- endfor -%}
          {%- endif -%}
        '';
      };
    };

    ErinnerungLoeschen = {
      sentences = [
        "Lösche die Erinnerung an {erinnerung_text:text}"
        "Erinnerung an {erinnerung_text:text} löschen"
      ];
      inherit lists;
      script = {
        action = callService "reminder_delete" {
          label = "{{ text }}";
          inherit area;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}Erinnerung an {{ res['items'][0].label }} gelöscht.
          {%- elif res.status == 'ambiguous' -%}Welche meinst du? {{ erinnerung_choices(res.candidates) }}?
          {%- elif res.status == 'no_match' -%}Diese Erinnerung gibt es nicht.
          ${r.failed "Erinnerungen"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };
  };
}
