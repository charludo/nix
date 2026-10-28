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

  hhmm = "'%02d:%02d' | format(${r.hourOf}, ${r.minuteOf})";
  clock = "{{ ${hhmm} }}";
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

  # Alarms set by voice, once (on a spoken day, else the next time it comes)
  # or repeating (`days`), gently ("Weck mich": you're asleep) or not, with
  # music or not: one intent each.
  openers = [
    {
      say = "Stelle einen Wecker";
      gentle = false;
      once = [
        "(auf|für) <zeit>"
        "<tag> um <zeit>"
      ];
      music = true;
    }
    {
      say = "Wecker";
      gentle = false;
      once = [ "(auf|für) <zeit>" ];
      music = false;
    }
    {
      say = "Weck mich";
      gentle = true;
      once = [
        "um <zeit>"
        "<tag> um <zeit>"
      ];
      music = true;
    }
  ];
  sentencesOf =
    {
      gentle,
      music,
      repeat,
    }:
    lib.concatMap (
      o:
      let
        plain = map (w: "${o.say} ${w}") (if repeat then [ "<wiederholung> um <zeit>" ] else o.once);
      in
      lib.optionals (o.gentle == gentle && (o.music || !music)) (
        if music then
          lib.concatMap (s: [
            "${s} mit Musik"
            "${s} mit der Playlist {mass_playlist}"
          ]) plain
        else
          plain
      )
    ) openers;

  mkAlarm =
    {
      gentle,
      music,
      repeat,
    }@kind:
    lib.nameValuePair
      (
        "Wecker"
        + lib.optionalString gentle "Sanft"
        + lib.optionalString repeat "Wiederholt"
        + lib.optionalString music "MitMusik"
      )
      {
        sentences = expand (sentencesOf kind);
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
  alarmIntents = lib.listToAttrs (
    map mkAlarm (
      lib.cartesianProduct {
        gentle = [
          true
          false
        ];
        music = [
          true
          false
        ];
        repeat = [
          true
          false
        ];
      }
    )
  );

  # The alarm a sentence names by its time ("den Wecker um 7 Uhr"), if any.
  target = {
    time = "{{ ${hhmm} if ${r.timeSaid} else '' }}";
    inherit area;
  };
in
{
  hass.voice.intents = alarmIntents // {
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
