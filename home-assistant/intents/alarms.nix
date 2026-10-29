{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  expand = r.expand {
    "<zeit>" = r.timeShapes;
    "<tag>" = [ "{remembrance_tag:day}" ];
  };

  lists = {
    inherit (r.lists)
      remembrance_stunde
      remembrance_minute
      remembrance_uhrzeit
      remembrance_tag
      ;
  };

  hhmm = "'%02d:%02d' | format(${r.hourOf}, ${r.minuteOf})";

  # Speech for an action on existing alarms: `ok` (Jinja; `i` is the first
  # alarm, `items` all of them) on success, the shared answers otherwise.
  speak = ok: ''
    ${r.jinja}
    {%- set res = action_response -%}
    {%- set items = res['items'] -%}
    {%- set i = items[0] if items else none -%}
    {%- if res.status == 'ok' -%}${ok}
    {%- elif res.status == 'ambiguous' -%}Welchen meinst du? {{ wecker_choices(res.candidates) }}?
    {%- elif res.status == 'no_match' -%}Da ist kein Wecker.
    ${r.failed "Wecker"}
    {%- else -%}Das hat nicht geklappt.
    {%- endif -%}
  '';

  # Set from the sentence as said: remembrance reads the time ("um halb
  # sieben", "6 Uhr morgens"), a day or repeats ("werktags", "montags und
  # mittwochs"), "sanft" and the music ("mit Musik", "mit der Playlist …").
  # "Weck mich …" rings gently (you're asleep), "Stelle einen Wecker …" at
  # full volume. A playlist named on its own comes from Music Assistant's
  # list (`mass_playlist`), so a misheard name still finds it.
  setIntents = r.fromText {
    name = "WeckerStellen";
    kind = "alarm";
    sentences = [
      "Stelle einen Wecker {remembrance_text:text}"
      "Stelle einen Wecker {remembrance_text:text} mit der Playlist {mass_playlist}"
      "Wecker {remembrance_text:text}"
      "Weck mich {remembrance_text:text}"
      "Weck mich {remembrance_text:text} mit der Playlist {mass_playlist}"
    ];
    speech = ''
      ${r.jinja}
      {%- set res = action_response -%}
      {%- if res.status == 'ok' -%}
        {%- set i = res['items'][0] -%}
        {%- set p = res.parsed -%}
        {%- if p.days -%}
          {%- set names = {'täglich': 'jeden Tag', 'wochenende': 'am Wochenende', 'werktags': 'werktags'} -%}
          {%- set ns = namespace(n=[]) -%}
          {%- for d in p.days -%}{%- set ns.n = ns.n + [names.get(d, d ~ 's')] -%}{%- endfor -%}
          Wecker {{ ns.n | join(' und ') }} um {{ uhrzeit(as_local(as_datetime(i.start))) }} gestellt
        {%- else -%}Wecker {{ zeitpunkt(i.start) }} gestellt
        {%- endif -%}
        {{- (', mit der Playlist ' ~ p.playlist if p.playlist else ', mit Musik') if p.playlist is defined else "" -}}.
      ${r.notUnderstood}
      ${r.failed "Wecker"}
      {%- else -%}Das hat nicht geklappt.
      {%- endif -%}
    '';
  };

  # The alarm a sentence names by its time ("den Wecker um 7 Uhr"), if any.
  target = {
    time = "{{ ${hhmm} if ${r.timeSaid} else '' }}";
    inherit area;
  };
in
{
  hass.voice.intents = setIntents // {
    # One day off, for every alarm that rings that day.
    WeckerAuslassen = {
      sentences = expand [
        "Wecker <tag> aus"
        "Kein Wecker <tag>"
        "<tag> kein Wecker"
        "Wecker für <tag> (ausschalten|aus)"
        "Weck mich <tag> nicht"
      ];
      inherit lists;
      script = {
        action = callService "alarm_skip" {
          all = true;
          date = "${r.jinja}{{ zieltag(day) }}";
        };
        speech.text = ''
          ${r.jinja}
          {%- set res = action_response -%}
          {%- if res.status == 'ok' -%}Okay, {{ tag_name(day) }} kein Wecker.
          {%- elif res.status == 'no_match' -%}{{ tag_name(day)[:1] | upper ~ tag_name(day)[1:] }} ist sowieso kein Wecker gestellt.
          ${r.failed "Wecker"}
          {%- else -%}Das hat nicht geklappt.
          {%- endif -%}
        '';
      };
    };

    # Not "Wecker aus" or "Schalte den Wecker aus": said while it rings,
    # they mean stop (`Stopp`), not off for good.
    WeckerDeaktivieren = {
      sentences = expand [
        "Wecker deaktivieren"
        "Deaktiviere den Wecker"
        "Deaktiviere den Wecker um <zeit>"
      ];
      inherit lists;
      script = {
        action = callService "alarm_disable" target;
        speech.text = speak "Wecker um {{ uhrzeit(as_local(as_datetime(i.start))) }} deaktiviert.";
      };
    };

    WeckerAktivieren = {
      sentences = expand [
        "Wecker aktivieren"
        "Aktiviere den Wecker"
        "Aktiviere den Wecker um <zeit>"
      ];
      inherit lists;
      script = {
        action = callService "alarm_enable" target;
        speech.text = speak "Wecker wieder aktiviert, er klingelt {{ zeitpunkt(i.next_ring) }}.";
      };
    };

    WeckerWann = {
      sentences = [
        "Wann (klingelt|geht|ist) (der|mein) [nächste|nächster] Wecker"
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

    WeckerLoeschen = {
      sentences = expand [
        "Lösche den Wecker"
        "Lösche den Wecker um <zeit>"
        "Wecker um <zeit> löschen"
      ];
      inherit lists;
      script = {
        action = callService "alarm_delete" target;
        speech.text = speak "Wecker um {{ uhrzeit(as_local(as_datetime(i.start))) }} gelöscht.";
      };
    };
  };
}
