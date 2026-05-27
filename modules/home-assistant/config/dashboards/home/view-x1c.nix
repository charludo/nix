{ lib }:
let
  ha = lib.ha;

  # Entity ids the Bambu Lab integration produces with this HA setup
  # (friendly names translated to German → slugified). Keeping the
  # mapping in one place so the view itself stays readable; if you ever
  # switch HA back to English friendly names or rename the devices,
  # only this block needs updating.
  p = "x1c";
  ams = "x1c_ams";
  spool = "x1c_external_spool";

  # Cloudflare keys by full URL and honours HA's 31-day Cache-Control,
  # so a stale 404 can hang around for a month. Bump this every time
  # the asset files change and CF will treat it as a new URL.
  assetV = "1";
  img = name: "/local/bambu/${name}.png?v=${assetV}";

  ent = {
    # ── Printer ─────────────────────────────────────────────────────
    status = "sensor.${p}_druckstatus";
    progress = "sensor.${p}_druckfortschritt";
    remaining = "sensor.${p}_verbleibende_zeit";
    stage = "sensor.${p}_aktueller_arbeitsschritt";
    task = "sensor.${p}_name_der_aufgabe";
    startTime = "sensor.${p}_startzeit";
    endTime = "sensor.${p}_endzeit";
    layer = "sensor.${p}_aktuelle_schicht";
    layerTotal = "sensor.${p}_gesamtzahl_der_schichten";
    activeTray = "sensor.${p}_aktiver_slot";
    speedProfile = "sensor.${p}_geschwindigkeitsprofil";

    nozzleTemp = "sensor.${p}_temperatur_der_duse";
    bedTemp = "sensor.${p}_druckbetttemperatur";
    chamberTemp = "sensor.${p}_temperatur_im_druckraum";
    nozzleTarget = "sensor.${p}_zieltemperatur_der_duse";
    bedTarget = "sensor.${p}_zieltemperatur_vom_druckbett";

    coolingFan = "sensor.${p}_bauteillufterdrehzahl";
    chamberFan = "sensor.${p}_druckraumlufterdrehzahl";
    auxFan = "sensor.${p}_hotendlufterdrehzahl";

    wifi = "sensor.${p}_wi_fi_signalqualitat";
    light = "light.${p}_druckraumbeleuchtung";
    cameraSwitch = "switch.${p}_kamera_aktivieren";
    camera = "camera.${p}_kamera";
    coverImage = "image.${p}_titelbild";

    hms = "binary_sensor.${p}_hms_fehler";
    firmware = "binary_sensor.${p}_firmware_status";
    door = "binary_sensor.${p}_gehausetur";
    online = "binary_sensor.${p}_online";
    printError = "binary_sensor.${p}_druckfehler";

    # ── AMS ────────────────────────────────────────────────────────
    amsActive = "binary_sensor.${ams}_aktiv";
    amsHumidityIx = "sensor.${ams}_index_der_luftfeuchtigkeit";
    amsHumidity = "sensor.${ams}_luftfeuchtigkeit";
    amsTemp = "sensor.${ams}_temperatur";
    amsSlot = i: "sensor.${ams}_slot_${toString i}";

    # ── External spool ─────────────────────────────────────────────
    spoolSensor = "sensor.${spool}_externe_spule";
    spoolActive = "binary_sensor.${spool}_aktiv";
  };

  isActive = ha.orConditions [
    (ha.stateIs ent.status "running")
    (ha.stateIs ent.status "pause")
  ];

  tempGauge =
    {
      name,
      entity,
      max,
    }:
    {
      type = "gauge";
      inherit entity name max;
      min = 0;
      needle = true;
      segments = [
        {
          from = 0;
          color = "var(--blue)";
        }
        {
          from = max * 0.4;
          color = "var(--green)";
        }
        {
          from = max * 0.7;
          color = "var(--yellow)";
        }
        {
          from = max * 0.9;
          color = "var(--red)";
        }
      ];
      card_mod.style = {
        "." = ''
          ha-card {
            padding-top: 32px !important;
            position: relative;
          }
          .title {
            position: absolute !important;
            top: 12px;
            left: 16px;
            font-size: var(--ha-font-size-l) !important;
            color: var(--secondary-text-color) !important;
            margin: 0 !important;
            text-align: left !important;
          }
        '';
        "ha-gauge"."$" = ''
          .value-text {
            font-size: var(--ha-font-size-xs) !important;
          }
        '';
      };
    };

  # AMS slot tile. Background tints with the configured filament colour
  # (attribute keys come from pybambu, so they stay English: `color`,
  # `type`, `active`).
  amsSlotCard =
    idx:
    let
      e = ent.amsSlot idx;
    in
    {
      type = "custom:mushroom-template-card";
      entity = e;
      primary = "Slot ${toString idx}";
      secondary = "{{ state_attr('${e}', 'type') or states('${e}') }}";
      icon = "{% if states('${e}') | lower != 'empty' %}mdi:spool{% else %}mdi:tray{% endif %}";
      icon_color = "{{ state_attr('${e}', 'color') or 'disabled' }}";
      fill_container = true;
      layout = "vertical";
      badge_icon = "{% if is_state_attr('${e}', 'active', true) %}mdi:check-circle{% endif %}";
      badge_color = "var(--yellow)";
    };

  humidityCard = {
    type = "custom:mushroom-template-card";
    entity = ent.amsHumidityIx;
    primary = "AMS Feuchte";
    secondary = "Index {{ states('${ent.amsHumidityIx}') }} / 5";
    icon = "mdi:water-percent";
    icon_color = ''
      {% set v = states('${ent.amsHumidityIx}') | int(0) %}
      {% if v >= 4 %}red
      {% elif v >= 3 %}orange
      {% elif v >= 2 %}yellow
      {% else %}green
      {% endif %}
    '';
    fill_container = true;
  };
in
{
  type = "sections";
  max_columns = 2;
  icon = "mdi:printer-3d-nozzle";
  path = "x1c";
  header.card = ha.mkTitleCard "X1 Carbon";

  sections = [
    # ── Status & quick actions ──────────────────────────────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "Status")

      (ha.mkConditional [ (ha.stateIs ent.status "offline") ] (
        ha.mkActionCard {
          name = "Drucker offline";
          icon = "mdi:printer-off";
          service = "homeassistant.update_entity";
          serviceData.entity_id = ent.status;
          cardBg = "var(--contrast4)";
          iconColor = "var(--contrast20)";
          nameColor = "var(--contrast20)";
          extraCardProps."margin-top" = "24px";
        }
      ))

      (ha.mkConditional [ isActive ] (
        ha.mkActionCard {
          name = "Druckt";
          icon = "mdi:printer-3d-nozzle";
          entity = ent.progress;
          label = "[[[ const pct = states['${ent.progress}']?.state ?? '?'; const rem = states['${ent.remaining}']?.state ?? '?'; const stage = states['${ent.stage}']?.state ?? ''; return pct + '% · noch ' + rem + ' min · ' + stage; ]]]";
          service = "homeassistant.update_entity";
          serviceData.entity_id = ent.progress;
          cardBg = "var(--blue)";
          iconColor = "var(--contrast1)";
          nameColor = "var(--contrast1)";
          labelColor = "var(--contrast1)";
          extraCardProps."margin-top" = "24px";
        }
      ))

      (ha.mkConditional [ (ha.stateIs ent.hms "on") ] (
        ha.mkActionCard {
          name = "HMS-Meldung";
          icon = "mdi:alert";
          entity = ent.hms;
          service = "homeassistant.update_entity";
          serviceData.entity_id = ent.hms;
          cardBg = "var(--red)";
          iconColor = "var(--contrast1)";
          nameColor = "var(--contrast1)";
          extraCardProps."margin-top" = "24px";
        }
      ))

      # The integration in this install only exposes the printing speed
      # as a read-only sensor (no select.* registered). Show it as a
      # mushroom tile; enable the writable select in HA's entity dialog
      # and we can swap this back to the four-pill selector.
      {
        type = "custom:mushroom-entity-card";
        entity = ent.speedProfile;
        name = "Geschwindigkeit";
        icon = "mdi:speedometer";
        fill_container = true;
      }
    ])

    # ── Live view (printer hero + camera + cover image) ─────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "Live")
      {
        type = "picture-entity";
        entity = ent.light;
        show_name = false;
        show_state = false;
        tap_action.action = "toggle";
        image = (img "on");
        state_image = {
          "on" = (img "on");
          "off" = (img "off");
          "unavailable" = (img "off");
        };
      }
      {
        type = "picture-glance";
        camera_view = "live";
        camera_image = ent.camera;
        title = null;
        entities = [
          {
            entity = ent.light;
            tap_action.action = "toggle";
          }
          { entity = ent.door; }
          { entity = ent.chamberTemp; }
        ];
      }
      (ha.mkConditional [ isActive ] {
        type = "picture-entity";
        entity = ent.coverImage;
        show_name = false;
        show_state = false;
      })
    ])

    # ── Druckdetails ────────────────────────────────────────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "Druckdetails")
      {
        type = "custom:mushroom-entity-card";
        entity = ent.task;
        name = "Task";
        icon = "mdi:clipboard-text";
        fill_container = true;
      }
      (ha.mkHStack [
        {
          type = "custom:mushroom-entity-card";
          entity = ent.progress;
          name = "Fortschritt";
          icon = "mdi:progress-helper";
        }
        {
          type = "custom:mushroom-template-card";
          entity = ent.layer;
          primary = "Layer";
          icon = "mdi:layers";
          icon_color = "var(--blue)";
          secondary = "{{ states('${ent.layer}') }} / {{ states('${ent.layerTotal}') }}";
        }
      ])
      {
        type = "entities";
        entities = [
          {
            entity = ent.stage;
            name = "Phase";
          }
          {
            entity = ent.startTime;
            name = "Start";
            secondary_info = "last-changed";
          }
          {
            entity = ent.endTime;
            name = "Ende";
          }
          {
            entity = ent.remaining;
            name = "Restzeit";
          }
          {
            entity = ent.firmware;
            name = "Firmware";
          }
          {
            entity = ent.activeTray;
            name = "Filament";
          }
          {
            entity = ent.printError;
            name = "Druckfehler";
          }
        ];
      }
    ])

    # ── Temperaturen ────────────────────────────────────────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "Temperaturen")
      (ha.mkHStack [
        (tempGauge {
          name = "Düse";
          entity = ent.nozzleTemp;
          max = 300;
        })
        (tempGauge {
          name = "Bett";
          entity = ent.bedTemp;
          max = 110;
        })
      ])
      (tempGauge {
        name = "Kammer";
        entity = ent.chamberTemp;
        max = 60;
      })
      {
        type = "entities";
        title = "Soll";
        entities = [
          {
            entity = ent.nozzleTarget;
            name = "Düse";
          }
          {
            entity = ent.bedTarget;
            name = "Bett";
          }
        ];
      }
    ])

    # ── Lüfter ──────────────────────────────────────────────────────
    # No writable fan.* entities are exposed here (only sensors of the
    # current rpm/duty), so this is read-only too.
    (ha.mkGridSection [
      (ha.mkMushTitle "Lüfter")
      {
        type = "entities";
        entities = [
          {
            entity = ent.coolingFan;
            name = "Bauteilkühlung";
            icon = "mdi:fan";
          }
          {
            entity = ent.chamberFan;
            name = "Kammer";
            icon = "mdi:fan";
          }
          {
            entity = ent.auxFan;
            name = "Hotend";
            icon = "mdi:fan";
          }
        ];
      }
    ])

    # ── AMS ─────────────────────────────────────────────────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "AMS")
      {
        type = "picture-entity";
        entity = ent.amsActive;
        show_name = false;
        show_state = false;
        image = (img "ams");
      }
      (ha.mkHStack [
        (amsSlotCard 1)
        (amsSlotCard 2)
        (amsSlotCard 3)
        (amsSlotCard 4)
      ])
      (ha.mkHStack [
        humidityCard
        {
          type = "custom:mushroom-entity-card";
          entity = ent.amsTemp;
          name = "AMS Temp";
          icon = "mdi:thermometer";
          icon_color = "blue";
          fill_container = true;
        }
      ])

      (ha.mkConditional
        [
          {
            condition = "state";
            entity = ent.spoolSensor;
            state_not = "unavailable";
          }
        ]
        (
          ha.mkHStack [
            {
              type = "picture-entity";
              entity = ent.spoolSensor;
              show_name = false;
              show_state = false;
              image = (img "spool");
            }
            {
              type = "custom:mushroom-template-card";
              entity = ent.spoolSensor;
              primary = "Externe Spool";
              secondary = "{{ state_attr('${ent.spoolSensor}', 'type') or states('${ent.spoolSensor}') }}";
              icon = "mdi:spool";
              icon_color = "{{ state_attr('${ent.spoolSensor}', 'color') or 'disabled' }}";
              badge_icon = "{% if is_state_attr('${ent.spoolSensor}', 'active', true) %}mdi:check-circle{% endif %}";
              badge_color = "var(--yellow)";
              fill_container = true;
            }
          ]
        )
      )
    ])

    # ── Diagnose ────────────────────────────────────────────────────
    (ha.mkGridSection [
      (ha.mkMushTitle "Diagnose")
      {
        type = "entities";
        entities = [
          {
            entity = ent.wifi;
            name = "WLAN";
          }
          {
            entity = ent.online;
            name = "Online";
          }
          {
            entity = ent.firmware;
            name = "Firmware-Update";
          }
          {
            entity = ent.light;
            name = "Kammerlicht";
          }
          {
            entity = ent.cameraSwitch;
            name = "Kamera";
          }
        ];
      }
    ])
  ];
}
