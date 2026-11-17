{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  # `text`: when, as said ("um 7", "morgen um 6:30", "werktags um halb
  # sieben", "für Samstag"), read by remembrance with Duckling. Prepositions
  # stay in it: "7" alone isn't a time.
  lists = {
    remembrance_text.wildcard = true;
    wecker_sanft.values = [
      "sanft"
      "sanften"
    ];
    wecker_musik.values = [ "mit Musik" ];
  };

  # "sanft", "mit Musik" (the default wake-up playlist) or a playlist from
  # Music Assistant's list (`mass_playlist`, so a misheard name still finds
  # it). Passed on as the alarm's description, which the ring script reads
  # ("Sanft", "Musik", "Musik: <playlist>"). Slots, as the script only sees
  # what a slot caught.
  description = ''
    {%- set music = 'Musik: ' ~ mass_playlist if mass_playlist is defined else ('Musik' if wecker_musik is defined else "") -%}
    {{- ['Sanft' if wecker_sanft is defined else "", music] | select | join('\n') -}}
  '';

  # Days as remembrance returns them (`parsed.days`), spoken.
  dayNames = ''
    {%- set names = {'täglich': 'jeden Tag', 'wochenende': 'am Wochenende', 'werktags': 'werktags'} -%}
    {%- set ns = namespace(n=[]) -%}
    {%- for d in p.days -%}{%- set ns.n = ns.n + [names.get(d, d ~ 's')] -%}{%- endfor -%}
  '';
  # Delete alarms as said (see `WeckerLoeschen`); `all` for "alle Wecker …".
  deleteAlarms = all: sentences: {
    inherit sentences lists;
    script = {
      action = callService "alarm_delete_from_text" {
        text = "{{ text }}";
        inherit all area;
      };
      speech.text = ''
        ${r.jinja}
        {%- set res = action_response -%}
        {%- set p = res.parsed or {} -%}
        {%- set um = ' um ' ~ uhrzeit(as_datetime('2000-01-01T' ~ p.time)) if p.time else "" -%}
        {%- if res.status == 'ok' and p.days -%}
          ${dayNames}
          Alle Wecker {{ ns.n | join(' und ') }}{{ um }} gelöscht.
        {%- elif res.status == 'ok' and p.time -%}Wecker für {{ datum(p.date ~ 'T00:00:00') }}{{ um }} gelöscht.
        {%- elif res.status == 'ok' -%}Alle Wecker für {{ datum(p.date ~ 'T00:00:00') }} gelöscht.
        {%- elif res.status == 'ambiguous' -%}{{ wecker_choices(res.candidates) }}
        {%- elif res.status == 'no_match' -%}Da ist kein Wecker.
        {%- elif res.reason == 'no time' and (p.date or p.days) -%}Welche Uhrzeit? Oder sag „alle Wecker“.
        ${r.notUnderstood}
        ${r.failed "Wecker"}
        {%- else -%}Das hat nicht geklappt.
        {%- endif -%}
      '';
    };
  };
in
{
  hass.voice.intents = {
    # "[Stelle einen] [sanften] Wecker [auf|für] <wann>", "Weck mich
    # [um|am] <wann> [sanft] [mit Musik|mit der Playlist <playlist>]": one intent, the
    # time read from "Wecker <wann>". Gentle only when said.
    WeckerStellen = {
      sentences = [
        "[Stelle einen] {wecker_sanft} Wecker {remembrance_text:text}"
        "[Stelle einen] Wecker {remembrance_text:text}"
        "Weck mich {remembrance_text:text} {wecker_sanft} mit der Playlist {mass_playlist}"
        "Weck mich {remembrance_text:text} mit der Playlist {mass_playlist}"
        "Weck mich {remembrance_text:text} {wecker_sanft} {wecker_musik}"
        "Weck mich {remembrance_text:text} {wecker_musik}"
        "Weck mich {remembrance_text:text} {wecker_sanft}"
        "Weck mich {remembrance_text:text}"
      ];
      inherit lists;
      script = {
        action = callService "create_from_text" {
          kind = "alarm";
          text = "Wecker {{ text }}";
          inherit area description;
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}
            {%- set i = res['items'][0] -%}
            {%- set p = res.parsed -%}
            {%- if p.days -%}
              ${dayNames}
              {{- 'Sanfter ' if wecker_sanft is defined else "" }}Wecker {{ ns.n | join(' und ') }} um {{ uhrzeit(as_local(as_datetime(i.start))) }} gestellt
            {%- else -%}{{ 'Sanfter ' if wecker_sanft is defined else "" }}Wecker {{ zeitpunkt(i.start) }} gestellt
            {%- endif -%}
            {{- ', mit der Playlist ' ~ mass_playlist if mass_playlist is defined else (', mit Musik' if wecker_musik is defined else "") -}}.
          ${r.notUnderstood}
          ${r.failed "Wecker"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

    # "Wecker [für|um] <wann> löschen", "<wann> Wecker löschen". A repeat
    # said ("werktags um 6") deletes every alarm on those days at that
    # time; one occurrence ("morgen um 7", "um 7") leaves out just that one
    # (a one-off alarm is gone). Without a time it fails: a whole day or
    # repeat needs "alle" (`WeckerAlleLoeschen`).
    WeckerLoeschen = deleteAlarms false [
      "Wecker {remembrance_text:text} löschen"
      "{remembrance_text:text} Wecker löschen"
    ];
    # "Alle Wecker für morgen löschen", "Alle Wecker werktags löschen".
    WeckerAlleLoeschen = deleteAlarms true [ "Alle Wecker {remembrance_text:text} löschen" ];

    WeckerWann = {
      sentences = [
        # Split: closest_intent expands a pattern into at most 16 forms.
        "Wann klingelt (der|mein) [nächste|nächster] Wecker"
        "Wann geht (der|mein) [nächste|nächster] Wecker"
        "Wann ist (der|mein) [nächste|nächster] Wecker"
        "Ist ein Wecker gestellt"
      ];
      script = {
        action = callService "query" { kind = "alarm"; };
        speech.text = ''
          ${r.jinja}
          {%- set next = action_response['items'] | selectattr('next_ring') | sort(attribute='next_ring') | list -%}
          {%- if next -%}Der Wecker klingelt {{ zeitpunkt(next[0].next_ring) }}.
          {%- else -%}Es ist kein Wecker gestellt.
          {%- endif -%}
        '';
      };
    };
  };
}
