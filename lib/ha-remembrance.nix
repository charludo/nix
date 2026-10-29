{ lib }:
# Building blocks for voice intents on top of hass-remembrance (timers,
# reminders, alarms): sentence shapes, slot lists, the service call, and Jinja
# macros for the spoken answers. German only.
rec {
  # Alarms with a "Musik: <playlist>" line in their description (just
  # "Musik": this one) wake up to that playlist instead of the chime.
  defaultWakePlaylist = "500 random tracks (from library)";

  # Jinja macros, prepended to a template that uses them:
  #   dauer(seconds)  "1 Minute und 30 Sekunden"; whole minutes from 10 min
  #   timer_name(t)   "Nudel-Timer", "5 Minuten Timer",
  #                   "Timer über 1 Stunde und 30 Minuten"
  #                   (no hyphen after a number: Pocket TTS's normaliser
  #                   doesn't spell out "5-Minuten" and garbles it)
  #   oder(names)     "A, B oder C", capitalised
  #   timer_choices(items)  "Den 5 Minuten Timer oder den Nudel-Timer"
  #   uhrzeit(dt)     "7 Uhr", "13:30 Uhr"
  #   zeitpunkt(iso)  "heute um 13 Uhr", "morgen um 7:30 Uhr",
  #                   "am Samstag um 9 Uhr", "am 3.11. um 9 Uhr"
  #   zieltag(day)    the date (ISO) a spoken day ("0" today, "1" tomorrow,
  #                   …, "MO" … "SU") means, never in the past
  #   tag_name(day)   "heute", "morgen", "am Samstag"
  #   wecker_choices(items)      "Den um 7 Uhr oder den um 8:30 Uhr"
  #   erinnerung_choices(items)  "Die an Zahnarzt oder die an Blumen gießen"
  #   wake_playlist(description) the playlist an alarm wakes up to, "" if none
  #   wake_gentle(description)   "1" if the alarm gets louder gently ("Sanft"
  #                              line), "" if it rings at full volume
  # `t` is an item as remembrance's services and events return it.
  jinja = ''
    {%- macro dauer(sec) -%}
      {%- set t = sec | float(0) | round(0) | int -%}
      {%- if t >= 600 -%}{%- set t = ((t / 60) | round(0) | int) * 60 -%}{%- endif -%}
      {%- set h = t // 3600 -%}{%- set m = (t % 3600) // 60 -%}{%- set s = t % 60 -%}
      {%- set ns = namespace(p=[]) -%}
      {%- if h -%}{%- set ns.p = ns.p + [h ~ (' Stunde' if h == 1 else ' Stunden')] -%}{%- endif -%}
      {%- if m -%}{%- set ns.p = ns.p + [m ~ (' Minute' if m == 1 else ' Minuten')] -%}{%- endif -%}
      {%- if s or not ns.p -%}{%- set ns.p = ns.p + [s ~ (' Sekunde' if s == 1 else ' Sekunden')] -%}{%- endif -%}
      {{- (ns.p[:-1] | join(', ') ~ ' und ' ~ ns.p[-1]) if ns.p | length > 1 else ns.p[0] -}}
    {%- endmacro -%}
    {%- macro timer_name(t) -%}
      {%- set d = t.duration | float(0) | round(0) | int -%}
      {%- if t.label -%}{{ t.label }}-Timer
      {%- elif d == 3600 -%}Ein-Stunden-Timer
      {%- elif d == 60 -%}Ein-Minuten-Timer
      {%- elif d % 3600 == 0 -%}{{ d // 3600 }} Stunden Timer
      {%- elif d < 3600 and d % 60 == 0 -%}{{ d // 60 }} Minuten Timer
      {%- elif d < 60 -%}{{ d }} Sekunden Timer
      {%- else -%}Timer über {{ dauer(d) }}
      {%- endif -%}
    {%- endmacro -%}
    {%- macro oder(names) -%}
      {%- set s = (names[:-1] | join(', ') ~ ' oder ' ~ names[-1]) if names | length > 1 else names[0] -%}
      {{- s[:1] | upper ~ s[1:] -}}
    {%- endmacro -%}
    {%- macro timer_choices(items) -%}
      {%- set ns = namespace(n=[]) -%}
      {%- for t in items -%}{%- set ns.n = ns.n + ['den ' ~ timer_name(t)] -%}{%- endfor -%}
      {{- oder(ns.n) -}}
    {%- endmacro -%}
    {%- macro uhrzeit(dt) -%}
      {{- dt.hour ~ (' Uhr' if dt.minute == 0 else ':' ~ '%02d' | format(dt.minute) ~ ' Uhr') -}}
    {%- endmacro -%}
    {%- macro zeitpunkt(iso) -%}
      {%- set dt = as_local(as_datetime(iso)) -%}
      {%- set days = (dt.date() - now().date()).days -%}
      {%- set wochentage = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'] -%}
      {%- if days == 0 -%}heute
      {%- elif days == 1 -%}morgen
      {%- elif days == 2 -%}übermorgen
      {%- elif 2 < days < 7 -%}am {{ wochentage[dt.weekday()] }}
      {%- else -%}am {{ dt.day }}.{{ dt.month }}.
      {%- endif %} um {{ uhrzeit(dt) -}}
    {%- endmacro -%}
    {%- macro zieltag(day) -%}
      {%- set codes = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'] -%}
      {%- set today = now().date() -%}
      {%- if day in codes -%}
        {{- (today + timedelta(days=(codes.index(day) - today.weekday()) % 7)).isoformat() -}}
      {%- else -%}
        {{- (today + timedelta(days=day | int(0))).isoformat() -}}
      {%- endif -%}
    {%- endmacro -%}
    {%- macro tag_name(day) -%}
      {%- set names = {'0': 'heute', '1': 'morgen', '2': 'übermorgen', 'MO': 'am Montag', 'TU': 'am Dienstag',
                       'WE': 'am Mittwoch', 'TH': 'am Donnerstag', 'FR': 'am Freitag', 'SA': 'am Samstag',
                       'SU': 'am Sonntag'} -%}
      {{- names.get(day | string, 'heute') -}}
    {%- endmacro -%}
    {%- macro wecker_choices(items) -%}
      {%- set ns = namespace(n=[]) -%}
      {%- for i in items -%}{%- set ns.n = ns.n + ['den um ' ~ uhrzeit(as_local(as_datetime(i.start)))] -%}{%- endfor -%}
      {{- oder(ns.n) -}}
    {%- endmacro -%}
    {%- macro erinnerung_choices(items) -%}
      {{- oder(items | map(attribute='label') | map('regex_replace', '^', 'die an ') | list) -}}
    {%- endmacro -%}
    {%- macro wake_playlist(description) -%}
      {%- set m = (description or "") | regex_findall('(?im)^\s*musik\s*:?\s*(.*?)\s*$') -%}
      {{- (m[0] or "${defaultWakePlaylist}") if m else "" -}}
    {%- endmacro -%}
    {%- macro wake_gentle(description) -%}
      {{- "1" if (description or "") | regex_search('(?im)^\s*sanft\s*$') else "" -}}
    {%- endmacro -%}
  '';

  # 0 to 100 as digits and German words. HA's own number lists hold digits
  # only: closest_intent scores a spoken "eine" or "zwanzig" against those
  # and drops the sentence.
  germanNumber =
    n:
    let
      ones = [
        ""
        "eins"
        "zwei"
        "drei"
        "vier"
        "fünf"
        "sechs"
        "sieben"
        "acht"
        "neun"
      ];
      teens = [
        "zehn"
        "elf"
        "zwölf"
        "dreizehn"
        "vierzehn"
        "fünfzehn"
        "sechzehn"
        "siebzehn"
        "achtzehn"
        "neunzehn"
      ];
      tens = [
        ""
        ""
        "zwanzig"
        "dreißig"
        "vierzig"
        "fünfzig"
        "sechzig"
        "siebzig"
        "achtzig"
        "neunzig"
      ];
      t = n / 10;
      o = lib.mod n 10;
    in
    if n == 0 then
      [ "null" ]
    else if n == 1 then
      [
        "eins"
        "ein"
        "eine"
        "einer"
      ]
    else if n < 10 then
      [ (builtins.elemAt ones n) ]
    else if n < 20 then
      [ (builtins.elemAt teens (n - 10)) ]
    else if n == 100 then
      [
        "hundert"
        "einhundert"
      ]
    else if o == 0 then
      [ (builtins.elemAt tens t) ]
    else
      [ "${if o == 1 then "ein" else builtins.elemAt ones o}und${builtins.elemAt tens t}" ];
  numberValues =
    from: to:
    lib.concatMap (
      n:
      map (w: {
        "in" = w;
        out = n;
      }) ([ (toString n) ] ++ germanNumber n)
    ) (lib.range from to);

  # Spoken days, as `zieltag` takes them.
  days = {
    "heute" = "0";
    "morgen" = "1";
    "übermorgen" = "2";
    "Montag" = "MO";
    "Dienstag" = "TU";
    "Mittwoch" = "WE";
    "Donnerstag" = "TH";
    "Freitag" = "FR";
    "Samstag" = "SA";
    "Sonntag" = "SU";
  };
  # A slot list from { spoken = value; }.
  valuesOf = lib.mapAttrsToList (
    k: v: {
      "in" = k;
      out = v;
    }
  );

  # Slot lists shared by the intents (lists are global per language, hence
  # the prefixes).
  lists = {
    timer_zahl.values = numberValues 1 100;
    remembrance_stunde.values = numberValues 0 23;
    remembrance_minute.values = numberValues 0 59;
    remembrance_uhrzeit.values = lib.concatMap (
      h:
      map (
        m:
        let
          mm = lib.fixedWidthNumber 2 m;
        in
        {
          "in" = "${toString h} ${mm}";
          out = "${lib.fixedWidthNumber 2 h}:${mm}";
        }
      ) (lib.range 0 59)
    ) (lib.range 0 23);
    # Days, as `zieltag` takes them; weekdays also with "am".
    remembrance_tag.values = valuesOf (
      days
      // lib.mapAttrs' (d: lib.nameValuePair "am ${d}") (
        removeAttrs days [
          "heute"
          "morgen"
          "übermorgen"
        ]
      )
    );
  };

  # Spoken durations, one sentence per shape: closest_intent expands each
  # pattern into at most 16 variants (`expansion_cap`), so alternations and
  # optionals inside one pattern get cut off. Fuzzy matching covers
  # "Minute"/"Minuten" and articles anyway. `p` prefixes the slot names, so
  # one sentence can hold two durations.
  # Single units first: changes (`lib.take 3`) use only those. Before "und",
  # singular and plural both: matched against only "Minuten", "eine Minute
  # und …" shifts closest_intent's alignment into the number and loses it.
  # Elsewhere the plural alone matches fine, and each optional doubles the
  # candidates to score.
  durationShapes = p: [
    "{timer_zahl:${p}minutes} Minuten"
    "{timer_zahl:${p}hours} Stunden"
    "{timer_zahl:${p}seconds} Sekunden"
    "{timer_zahl:${p}hours} Stunde[n] und {timer_zahl:${p}minutes} Minuten"
    "{timer_zahl:${p}minutes} Minute[n] und {timer_zahl:${p}seconds} Sekunden"
  ];
  # Jinja expression: the seconds a duration's slots add up to.
  secondsOf =
    p:
    "((${p}hours | default(0) | int) * 3600 + (${p}minutes | default(0) | int) * 60"
    + " + (${p}seconds | default(0) | int))";

  # Clock times: "13 Uhr", "13 Uhr 30", "13:30 Uhr" (closest_intent turns
  # the colon into a space), "13:30".
  # "13:30" arrives as "13 30" (closest_intent turns the colon into a
  # space), which two number slots side by side can't split: it's one slot
  # of its own (`clock`). Longer shapes first: "7 Uhr" and "7 Uhr 15" score
  # the same, and the tie goes to the first, which would drop the minutes;
  # a trailing slot left empty is harmless, as hassil then matches the
  # shorter sentence. Use `hourOf`/`minuteOf` to read them.
  timeShapes = [
    "{remembrance_uhrzeit:clock} Uhr"
    "{remembrance_stunde:hour} Uhr {remembrance_minute:minute}"
    "{remembrance_uhrzeit:clock}"
    "{remembrance_stunde:hour} Uhr"
  ];
  hourOf = "(clock.split(':')[0] | int if clock is defined else hour | default(9) | int)";
  minuteOf = "(clock.split(':')[1] | int if clock is defined else minute | default(0) | int)";
  # Jinja test: was a clock time said?
  timeSaid = "(clock is defined or hour is defined)";

  # Every sentence once per shape of each placeholder it contains.
  expand =
    placeholders: sentences:
    lib.foldlAttrs (
      acc: placeholder: shapes:
      lib.concatMap (
        s:
        if lib.hasInfix placeholder s then
          map (x: lib.replaceStrings [ placeholder ] [ x ] s) shapes
        else
          [ s ]
      ) acc
    ) sentences placeholders;

  area = "{{ preferred_area_id | default('') }}";

  # Answers to a failed calendar write, as Jinja `elif` branches on `res`;
  # `what` names the items ("Erinnerungen", "Wecker").
  failed = what: ''
    {%- elif res.reason == 'no calendar configured' -%}${what} sind noch nicht eingerichtet.
    {%- elif res.reason == 'in the past' -%}Dieser Zeitpunkt ist schon vorbei.
    {%- elif (res.reason or "").startswith('calendar') -%}Ich komme gerade nicht an den Kalender.
  '';

  # Answers to a sentence `create_from_text` didn't understand, as Jinja
  # `elif` branches on `res` (more per kind: `no duration`, `no summary`).
  notUnderstood = ''
    {%- elif res.reason == 'vague time' -%}Bitte sag mir eine genaue Uhrzeit.
    {%- elif res.reason == 'no time' -%}Ich habe keine Uhrzeit verstanden.
    {%- elif (res.reason or "").startswith('duckling') or res.reason == 'no duckling configured' -%}Ich kann gerade keine Zeitangaben lesen.
  '';

  # Intents that hand the whole sentence to remembrance's `create_from_text`
  # (its parser reads times, repeats, labels): one per pattern, as `name`,
  # `name2`, …, since the script puts the sentence back together from its
  # pattern ("Weck mich {remembrance_text:text}" -> "Weck mich {{ text }}").
  # Patterns are literal apart from their slots; `{remembrance_text:…}` is a
  # wildcard, other lists come with `lists`.
  fromText =
    {
      name,
      kind,
      sentences,
      speech,
      lists ? { },
    }:
    let
      # "{list:slot}" or "{slot}" -> "{{ slot }}"
      sentenceOf =
        pattern:
        lib.concatMapStrings (part: if builtins.isList part then "{{ ${lib.last part} }}" else part) (
          builtins.split "\\{(([a-z_]+):)?([a-z_]+)}" pattern
        );
    in
    lib.listToAttrs (
      lib.imap1 (
        i: pattern:
        lib.nameValuePair (name + lib.optionalString (i > 1) (toString i)) {
          sentences = [ pattern ];
          lists = {
            remembrance_text.wildcard = true;
          }
          // lists;
          script = {
            action = callService "create_from_text" {
              inherit kind area;
              text = sentenceOf pattern;
            };
            speech.text = speech;
          };
        }
      ) sentences
    );

  # Call `remembrance.<service>` and stop with its response, which the
  # speech reads as `action_response`.
  callService = service: data: [
    {
      action = "remembrance.${service}";
      inherit data;
      response_variable = "r";
    }
    {
      stop = "";
      response_variable = "r";
    }
  ];
}
