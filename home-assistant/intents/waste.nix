{ config, lib, ... }:
let
  collections = lib.attrValues config.hass.wasteCollection.collections;

  # Bags go out the evening before: a collection tomorrow means "muss heute raus",
  # and "Ist heute …?" is answered yes for today and tomorrow.
  jinjaCollection =
    c:
    "{'slug': '${c.slug}', 'sensor': '${c.sensor}', 'subj': '${c.subject}', "
    + "'muss': '${if c.plural then "müssen" else "muss"}', "
    + "'wird': '${if c.plural then "werden" else "wird"}'}";

  # Defines `e`: known collections sorted by date, each with `d` (date) and `n`
  # (days from today), plus the macros used to phrase them.
  prelude = ''
    {%- macro wann(d) -%}
      {%- set n = (d - now().date()).days -%}
      {%- set wd = ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][d.weekday()] -%}
      {%- if n == 0 -%}heute
      {%- elif n == 1 -%}morgen
      {%- elif n < 7 -%}am {{ wd }}
      {%- else -%}am {{ wd }}, den {{ d.day }}. {{ ['Januar','Februar','März','April','Mai','Juni','Juli','August','September','Oktober','November','Dezember'][d.month - 1] }}
      {%- endif -%}
    {%- endmacro -%}
    {#- "der Restmüll muss heute raus" / "Papier und Plastik werden am Montag abgeholt" -#}
    {%- macro status(x) -%}
      {%- if x.n == 1 -%}{{ x.subj }} {{ x.muss }} heute raus
      {%- else -%}{{ x.subj }} {{ x.wird }} {{ wann(x.d) }} abgeholt
      {%- endif -%}
    {%- endmacro -%}
    {#- Verb-second form after "Allerdings": "muss heute der Restmüll raus" -#}
    {%- macro statusInv(x) -%}
      {%- if x.n == 1 -%}{{ x.muss }} heute {{ x.subj }} raus
      {%- else -%}{{ x.wird }} heute {{ x.subj }} abgeholt
      {%- endif -%}
    {%- endmacro -%}
    {%- macro statuses(xs, inv=false) -%}
      {%- set ns = namespace(s=[]) -%}
      {%- for x in xs -%}
        {%- set ns.s = ns.s + [statusInv(x) if inv else status(x)] -%}
      {%- endfor -%}
      {{- ns.s | join(', ') -}}
    {%- endmacro -%}
    {%- macro cap(s) -%}{{ s[:1] | upper }}{{ s[1:] }}{%- endmacro -%}
    {%- set ns = namespace(e=[]) -%}
    {%- for c in [${lib.concatMapStringsSep ", " jinjaCollection collections}] -%}
      {%- set d = strptime(states(c.sensor), '%Y-%m-%d', none) -%}
      {%- if d is not none -%}
        {%- set ns.e = ns.e + [dict(c, d=d.date(), n=(d.date() - now().date()).days)] -%}
      {%- endif -%}
    {%- endfor -%}
    {%- set e = ns.e | sort(attribute='d') -%}
    {%- set soon = e | selectattr('n', 'le', 1) | list -%}
  '';

  outdated = "Ich kenne keine Abholtermine mehr, der Müllkalender muss aktualisiert werden.";

  aliases = c: "(${lib.concatStringsSep "|" c.aliases})";

  perCollection =
    c:
    let
      mine = "e | selectattr('slug', 'eq', '${c.slug}') | first";
      others = "soon | rejectattr('slug', 'eq', '${c.slug}') | list";
    in
    {
      "MuellWann_${c.slug}" = {
        sentences = [
          "Wann (muss|kommt) [der |die |das ]${aliases c}[ raus]"
          "Wann wird [der |die |das ]${aliases c} abgeholt"
          "Wann ist [der |die |das ]${aliases c}"
        ];
        script.speech.text = prelude + ''
          {% set x = ${mine} %}
          {% if x is defined %}{{ cap(status(x)) }}.{% else %}${outdated}{% endif %}
        '';
      };

      "MuellHeute_${c.slug}" = {
        sentences = [
          "Ist heute [der |die |das ]${aliases c}"
          "(Kommt|Muss) heute [der |die |das ]${aliases c}[ raus]"
          "Muss [der |die |das ]${aliases c} heute raus"
          "Wird heute [der |die |das ]${aliases c} abgeholt"
        ];
        script.speech.text = prelude + ''
          {% set x = ${mine} %}
          {% set others = ${others} %}
          {% if x is not defined %}
            ${outdated}
          {% elif x.n <= 1 %}
            Ja, {{ status(x) }}.
          {% else %}
            Nein, {{ x.subj }} {{ x.wird }} erst {{ wann(x.d) }} abgeholt.
            {% if others %}Allerdings {{ statuses(others, inv=true) }}.{% endif %}
          {% endif %}
        '';
      };
    };
in
{
  hass.voice.intents = lib.mkMerge (
    [
      {
        MuellWann = {
          sentences = [
            "Wann muss [der ]Müll raus"
            "Wann wird [der ]Müll abgeholt"
            "Wann (kommt|ist) [die ]Müllabfuhr"
            "Wann ist [der nächste ]Müll[tag]"
          ];
          script.speech.text = prelude + ''
            {% if e %}{{ cap(statuses(e)) }}.{% else %}${outdated}{% endif %}
          '';
        };

        MuellHeute = {
          sentences = [
            "Ist heute Müll[abfuhr|tag]"
            "(Kommt|Ist) heute [die ]Müllabfuhr"
            "Muss heute [der ]Müll raus"
            "Wird heute [der ]Müll abgeholt"
          ];
          script.speech.text = prelude + ''
            {% if soon %}
              Ja, {{ statuses(soon) }}.
            {% elif e %}
              Nein. {{ cap(e[0].subj) }} {{ e[0].wird }} das nächste Mal {{ wann(e[0].d) }} abgeholt{% if e[1:] %}, {{ statuses(e[1:]) }}{% endif %}.
            {% else %}
              ${outdated}
            {% endif %}
          '';
        };
      }
    ]
    ++ map perCollection collections
  );
}
