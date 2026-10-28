{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService secondsOf;

  # When, as spoken. The slots decide the service's fields: `in` for a
  # duration, `at` (via the `ziel` macro) for a day and/or time.
  expand = r.expand {
    "<wann>" =
      map (d: "in ${d}") (r.durationShapes "")
      ++ map (t: "um ${t}") r.timeShapes
      ++ map (t: "{remembrance_tag:day} um ${t}") r.timeShapes
      ++ [
        "{remembrance_tag_tageszeit:daytime}"
        "{remembrance_tag:day}"
      ];
    "<tag>" = [ "{remembrance_tag:day}" ];
  };

  lists = {
    inherit (r.lists)
      timer_zahl
      remembrance_stunde
      remembrance_minute
      remembrance_uhrzeit
      remembrance_tag
      remembrance_tag_tageszeit
      ;
    erinnerung_text.wildcard = true;
  };

  # A day without a time means 9 o'clock, a time without a day the next
  # time it comes.
  at = ''
    ${r.jinja}
    {%- if daytime is defined -%}
      {%- set dt = daytime.split(' ') -%}
      {{ ziel(dt[0], dt[1], 0) }}
    {%- elif day is defined or ${r.timeSaid} -%}
      {{ ziel(day | default(""), ${r.hourOf}, ${r.minuteOf}) }}
    {%- endif -%}
  '';
in
{
  hass.voice.intents = {
    ErinnerungStellen = {
      sentences = expand [ "Erinnere mich <wann> an {erinnerung_text:text}" ];
      inherit lists;
      script = {
        action = callService "reminder_create" {
          summary = "{{ text }}";
          inherit at area;
          "in" = "{{ ${secondsOf ""} }}";
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}
            {%- set i = res['items'][0] -%}
            Okay, ich erinnere dich {{ zeitpunkt(i.start) }} an {{ i.label }}.
          ${r.failed "Erinnerungen"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

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
