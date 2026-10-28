{ lib, ... }:
let
  r = lib.ha.remembrance;
  inherit (r) area callService;

  expand = r.expand {
    "<zeit>" = r.timeShapes;
    "<tag>" = [ "{remembrance_tag:day}" ];
    "<wiederholung>" = [ "{remembrance_wiederholung:days}" ];
  };

  lists = {
    inherit (r.lists)
      remembrance_stunde
      remembrance_minute
      remembrance_uhrzeit
      remembrance_tag
      ;
    # Repeats, as remembrance's `days` takes them.
    remembrance_wiederholung.values =
      lib.mapAttrsToList
        (k: v: {
          "in" = k;
          out = v;
        })
        {
          "werktags" = "werktags";
          "jeden Tag" = "täglich";
          "täglich" = "täglich";
          "am Wochenende" = "wochenende";
          "montags" = "montag";
          "dienstags" = "dienstag";
          "mittwochs" = "mittwoch";
          "donnerstags" = "donnerstag";
          "freitags" = "freitag";
          "samstags" = "samstag";
          "sonntags" = "sonntag";
        };
  };

  clock = "{{ '%02d:%02d' | format(${r.hourOf}, ${r.minuteOf}) }}";
  # The day a spoken day and time mean (the `ziel` macro rolls over to the
  # next one when it's already past).
  onDay = "${r.jinja}{{ ziel(day, ${r.hourOf}, ${r.minuteOf})[:10] if day is defined else '' }}";
  # An alarm's description, as the ring script reads it: a "Sanft" line for
  # gently getting louder (said as "Weck mich …": you're asleep; "Stelle
  # einen Wecker …" rings at full volume), a "Musik: <playlist>" line for
  # waking up to music ("Musik" alone: the default playlist).
  descriptionOf =
    gentle: music:
    lib.concatStringsSep "\n" (
      lib.optional gentle "Sanft"
      ++ lib.optional music "Musik{{ ': ' ~ mass_playlist if mass_playlist is defined else \"\" }}"
    );
  musicSaid = "{{ 'mit der Playlist ' ~ mass_playlist if mass_playlist is defined else 'mit Musik' }}";
  repeatName = "{{ {'täglich': 'jeden Tag', 'wochenende': 'am Wochenende'}.get(days, days) }}";

  failed = ''
    {%- elif res.reason == 'no calendar configured' -%}Wecker sind noch nicht eingerichtet.
    {%- elif res.reason == 'in the past' -%}Dieser Zeitpunkt ist schon vorbei.
    {%- elif (res.reason or "").startswith('calendar') -%}Ich komme gerade nicht an den Kalender.
  '';

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
    ${failed}
    {%- else -%}Das hat nicht geklappt.
    {%- endif -%}
  '';

  # Alarms set by voice, once (on a spoken day, else the next time it comes)
  # or repeating (`days`).
  mkAlarm =
    {
      sentences,
      gentle,
      music,
      repeat,
    }:
    {
      sentences = expand sentences;
      inherit lists;
      script = {
        action = callService "alarm_create" (
          {
            time = clock;
            inherit area;
          }
          // (if repeat then { days = "{{ days }}"; } else { date = onDay; })
          // lib.optionalAttrs (gentle || music) { description = descriptionOf gentle music; }
        );
        speech.text = speak (
          (
            if repeat then
              "Wecker ${repeatName} um {{ uhrzeit(as_local(as_datetime(i.start))) }} gestellt"
            else
              "Wecker {{ zeitpunkt(i.start) }} gestellt"
          )
          + lib.optionalString music ", ${musicSaid}"
          + "."
        );
      };
    };

  # The alarm a sentence names by its time ("den Wecker um 7 Uhr"), if any.
  target = {
    time = "{{ '%02d:%02d' | format(${r.hourOf}, ${r.minuteOf}) if ${r.timeSaid} else '' }}";
    inherit area;
  };
in
{
  hass.voice.intents = {
    WeckerStellen = mkAlarm {
      gentle = false;
      music = false;
      repeat = false;
      sentences = [
        "Stelle einen Wecker (auf|für) <zeit>"
        "Stelle einen Wecker <tag> um <zeit>"
        "Wecker (auf|für) <zeit>"
      ];
    };
    WeckMich = mkAlarm {
      gentle = true;
      music = false;
      repeat = false;
      sentences = [
        "Weck mich um <zeit>"
        "Weck mich <tag> um <zeit>"
      ];
    };
    WeckerMitMusik = mkAlarm {
      gentle = false;
      music = true;
      repeat = false;
      sentences = [
        "Stelle einen Wecker (auf|für) <zeit> mit Musik"
        "Stelle einen Wecker <tag> um <zeit> mit Musik"
      ];
    };
    WeckMichMitMusik = mkAlarm {
      gentle = true;
      music = true;
      repeat = false;
      sentences = [
        "Weck mich um <zeit> mit Musik"
        "Weck mich <tag> um <zeit> mit Musik"
        "Weck mich um <zeit> mit der Playlist {mass_playlist}"
        "Weck mich <tag> um <zeit> mit der Playlist {mass_playlist}"
      ];
    };

    WeckerWiederholt = mkAlarm {
      gentle = false;
      music = false;
      repeat = true;
      sentences = [
        "Stelle einen Wecker <wiederholung> um <zeit>"
        "Wecker <wiederholung> um <zeit>"
      ];
    };
    WeckMichWiederholt = mkAlarm {
      gentle = true;
      music = false;
      repeat = true;
      sentences = [ "Weck mich <wiederholung> um <zeit>" ];
    };
    WeckMichWiederholtMitMusik = mkAlarm {
      gentle = true;
      music = true;
      repeat = true;
      sentences = [
        "Weck mich <wiederholung> um <zeit> mit Musik"
        "Weck mich <wiederholung> um <zeit> mit der Playlist {mass_playlist}"
      ];
    };

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
          ${failed}
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
