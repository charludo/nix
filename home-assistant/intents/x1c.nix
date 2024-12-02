let
  status = "sensor.x1c_druckstatus";
  remaining = "sensor.x1c_verbleibende_zeit";
  layer = "sensor.x1c_aktuelle_schicht";
  layerTotal = "sensor.x1c_gesamtzahl_der_schichten";
in
{
  hass.voice.intents = {
    X1CDruckdauer = {
      sentences = [
        "Wie lange (dauert|braucht) der [3D-]Druck[er] [noch]"
        "Wann ist der [3D-]Druck[er] fertig"
        "Druckzeit"
      ];
      script.speech.text = ''
        {% set st = states('${status}') %}
        {% if st == 'running' or st == 'pause' %}
          {% set rem = states('${remaining}') | int(0) %}
          {% set tot = states('${layerTotal}') | int(0) %}
          {% set lay = tot - (states('${layer}') | int(0)) %}
          {% if rem >= 60 %}
            {% set h = rem // 60 %}
            {% set m = rem % 60 %}
            {% set t = h | string + (' Stunde' if h == 1 else " Stunden") + (' und ' + m | string + (' Minute' if m == 1 else " Minuten") if m > 0 else "") %}
          {% else %}
            {% set t = rem | string + (' Minute' if rem == 1 else " Minuten") %}
          {% endif %}
          {% if st == 'pause' %}
            Der Drucker ist pausiert, mit noch {{ t }} und {{ lay }} von {{ tot }} Ebenen verbleibend.
          {% else %}
            Der Drucker druckt noch {{ t }}, mit noch {{ lay }} von {{ tot }} Ebenen verbleibend.
          {% endif %}
        {% elif st == 'finish' %}
          Der Druck ist fertig.
        {% elif st == 'failed' %}
          Der Druck ist fehlgeschlagen.
        {% elif st == 'prepare' %}
          Der Druck wird vorbereitet.
        {% elif st == 'offline' or st == 'unknown' or st == 'unavailable' %}
          Der Drucker ist offline.
        {% else %}
          Keine laufenden Druckaufträge.
        {% endif %}
      '';
    };
  };
}
