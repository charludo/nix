{ lib }:
let
  ha = lib.ha;

  p = "x1c";
  ams = "x1c_ams";
  spool = "x1c_external_spool";

  assetV = "2";
  img = name: "/local/bambu/${name}.png?v=${assetV}";

  ent = {
    # ── Printer ────────────────────────────────────────────────────
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

    # ── AMS ───────────────────────────────────────────────────────
    amsActive = "binary_sensor.${ams}_aktiv";
    amsId = "sensor.${ams}_aktiv"; # there's no sensor.<ams>_id in this install; use the activity sensor as label source
    amsHumidityIx = "sensor.${ams}_index_der_luftfeuchtigkeit";
    amsHumidity = "sensor.${ams}_luftfeuchtigkeit";
    amsTemp = "sensor.${ams}_temperatur";
    amsSlot = i: "sensor.${ams}_slot_${toString i}";

    # ── External spool ────────────────────────────────────────────
    spoolSensor = "sensor.${spool}_externe_spule";
    spoolActive = "binary_sensor.${spool}_aktiv";
  };

  # Translate the original YAML's HA-color names into our theme vars so
  # the badges/overlays match the rest of the dashboard. Used inline.
  # picture-elements has its own conditional element type, which uses
  # `elements: [...]` instead of the Lovelace `conditional` card's
  # singular `card:`. ha.mkConditional emits the latter, hence a
  # standalone helper here.
  mkElementConditional = conditions: elements: {
    type = "conditional";
    inherit conditions elements;
  };

  # config-template-card evaluates `${…}` (not `[[[ … ]]]`) inside its
  # child element's style block. Kept on a single line — config-template
  # has been spotty with multiline templates inside style values.
  wifiColor = e: "\${states['${e}'].state > -67 ? 'var(--blue)' : 'var(--red)'}";

  # Picture-elements *element* (state-icon, state-label, conditional...)
  # styles are CSS-prop maps in the YAML; pass them through unchanged.

  # ── x1_carbon_printer.yaml ────────────────────────────────────────
  printerCard = {
    type = "picture-elements";
    image = img "on";
    entity = ent.light;
    state_image = {
      "on" = img "on";
      "off" = img "off";
      "unavailable" = img "off";
    };
    card_mod.style = ''
      ha-card {
        background: none !important;
        border: none !important;
        box-shadow: none !important;
      }
    '';
    elements = [
      # WiFi signal — circular state-badge in the same visual style as
      # the nozzle/bed/chamber badges below, with the circle border
      # tinted blue/red by signal strength.
      {
        type = "custom:config-template-card";
        entities = [ ent.wifi ];
        element = {
          type = "state-badge";
          entity = ent.wifi;
          tap_action.action = "none";
        };
        style = {
          left = "88%";
          top = "14.75%";
          "font-size" = "0.8em";
          color = "rgba(0,0,0,0)";
          "--label-badge-red" = wifiColor ent.wifi;
        };
      }

      # Chamber light toggle (centred on the printer's light bay).
      {
        type = "state-icon";
        entity = ent.light;
        style = {
          top = "46%";
          left = "18%";
          "--mdc-icon-size" = "2.6em";
        };
        tap_action.action = "toggle";
      }

      # Status label across the top.
      {
        type = "state-label";
        entity = ent.status;
        style = {
          top = "8.6%";
          left = "32.8%";
          "font-size" = "1.2em";
          color = "var(--contrast20)";
        };
      }

      # Cover image overlay + progress badge while a job is active.
      (mkElementConditional
        [
          {
            entity = ent.status;
            state = [
              "running"
              "pause"
            ];
          }
        ]
        [
          (mkElementConditional
            [
              {
                entity = ent.coverImage;
                state_not = "unavailable";
              }
            ]
            [
              {
                type = "custom:hui-element";
                card_type = "picture-entity";
                show_name = false;
                show_state = false;
                entity = ent.coverImage;
                style = {
                  top = "50%";
                  left = "50%";
                  transform = "translate(-45%, -40%) scale(75%, 75%)";
                  "--ha-card-border-width" = "0px";
                  "--ha-card-background" = "none";
                };
              }
            ]
          )
          {
            type = "state-badge";
            entity = ent.progress;
            tap_action.action = "none";
            style = {
              top = "18.5%";
              left = "81%";
              "font-size" = "1em";
              color = "rgba(0,0,0,0)";
              "--label-badge-red" = "var(--blue)";
            };
          }
        ]
      )

      # Nozzle / bed / chamber temperature badges over their hardware.
      {
        type = "state-badge";
        entity = ent.nozzleTemp;
        style = {
          top = "31%";
          left = "51%";
          "font-size" = "0.8em";
          color = "rgba(0,0,0,0)";
        };
      }
      {
        type = "state-badge";
        entity = ent.bedTemp;
        style = {
          top = "84%";
          left = "51%";
          "font-size" = "0.8em";
          color = "rgba(0,0,0,0)";
        };
      }
      (mkElementConditional
        [
          {
            entity = ent.chamberTemp;
            state_not = "unavailable";
          }
        ]
        [
          {
            type = "state-badge";
            entity = ent.chamberTemp;
            style = {
              top = "32.25%";
              left = "19%";
              "font-size" = "0.8em";
              color = "rgba(0,0,0,0)";
            };
          }
        ]
      )
    ];
  };

  # ── ams_ams.yaml ─────────────────────────────────────────────────
  # One slot overlay = the filament icon (with tinted background) on top
  # of the AMS image and a state-label below showing the filament type.
  amsSlotOverlay =
    idx: iconLeftPct: labelLeftPct:
    let
      e = ent.amsSlot idx;
      colorVar = "--tray-${toString idx}-color";
      bgVar = "--tray-${toString idx}-bg";
    in
    [
      {
        type = "custom:config-template-card";
        entities = [ e ];
        element = {
          type = "state-icon";
          entity = e;
          icon = "\${states['${e}'].state.toLowerCase() != 'empty' ? 'local:filament-2' : 'mdi:tray' }";
        };
        style = {
          top = "28%";
          left = "${iconLeftPct}%";
          "--paper-item-icon-color" = "var(${colorVar})";
          "--icon-primary-color" = "var(${colorVar})";
          "--state-icon-color" = "var(${colorVar})";
          background-color = "rgba(0,0,0,0.5)";
          box-shadow = "0 0 5px 5px var(${bgVar})";
          border-radius = "50px";
          "--mdc-icon-size" = "2.4em";
        };
      }
      {
        type = "state-label";
        entity = e;
        attribute = "type";
        tap_action.action = "none";
        style = {
          top = "77%";
          left = "${labelLeftPct}%";
          text-align = "center";
          "font-size" = "1em";
          background-color = "rgba(0,0,0,0.4)";
          box-shadow = "0 0 5px 5px rgba(0, 0, 0, 0.4)";
          border-radius = "50px";
          pointer-events = "none";
          color = "var(--contrast20)";
        };
      }
    ];

  amsCard = {
    type = "picture-elements";
    image = img "ams";
    elements =
      (amsSlotOverlay 1 "21.4" "21")
      ++ (amsSlotOverlay 2 "39.7" "40")
      ++ (amsSlotOverlay 3 "59.7" "60")
      ++ (amsSlotOverlay 4 "79.6" "79.6")
      ++ [
        # AMS temperature badge — only when reading.
        (mkElementConditional
          [
            (ha.stateNot ent.status "offline")
            {
              entity = ent.amsTemp;
              state_not = "unavailable";
            }
            {
              entity = ent.amsTemp;
              state_not = "unknown";
            }
          ]
          [
            {
              type = "state-badge";
              entity = ent.amsTemp;
              style = {
                top = "50.75%";
                left = "8%";
                "font-size" = "0.75em";
                color = "rgba(0,0,0,0)";
              };
            }
          ]
        )
        # Humidity index icon top-right.
        (mkElementConditional
          [ (ha.stateNot ent.status "offline") ]
          [
            {
              type = "custom:config-template-card";
              entities = [ ent.amsHumidityIx ];
              element = {
                type = "state-icon";
                entity = ent.amsHumidityIx;
                icon = "\${'local:humidity-level-dark-' + states['${ent.amsHumidityIx}'].state + '#fullcolor'}";
              };
              style = {
                top = "42.5%";
                left = "92.5%";
                background-color = "#1c1c1c";
                border-radius = "50px";
                border = "0.12em solid var(--humidity-border-color)";
                "--mdc-icon-size" = "2.05em";
              };
            }
          ]
        )
      ];
    card_mod.style = ''
      ha-card {
        background: none !important;
        border: none !important;
        box-shadow: none !important;
        --humidity-border-color: {% if states('${ent.amsHumidityIx}') != 'unavailable' and states('${ent.amsHumidityIx}') | int > 3 %} var(--red); {% elif states('${ent.amsHumidityIx}') != 'unavailable' and states('${ent.amsHumidityIx}') | int > 2 %} var(--orange); {% elif states('${ent.amsHumidityIx}') != 'unavailable' and states('${ent.amsHumidityIx}') | int > 1 %} var(--yellow); {% else %} var(--green); {% endif %}
        --tray-1-color: {% if is_state_attr('${ent.amsSlot 1}', 'color', '#00000000') %} var(--contrast20); {% else %} {{ state_attr('${ent.amsSlot 1}', 'color') }}; {% endif %}
        --tray-2-color: {% if is_state_attr('${ent.amsSlot 2}', 'color', '#00000000') %} var(--contrast20); {% else %} {{ state_attr('${ent.amsSlot 2}', 'color') }}; {% endif %}
        --tray-3-color: {% if is_state_attr('${ent.amsSlot 3}', 'color', '#00000000') %} var(--contrast20); {% else %} {{ state_attr('${ent.amsSlot 3}', 'color') }}; {% endif %}
        --tray-4-color: {% if is_state_attr('${ent.amsSlot 4}', 'color', '#00000000') %} var(--contrast20); {% else %} {{ state_attr('${ent.amsSlot 4}', 'color') }}; {% endif %}
        --tray-1-bg: {% if is_state_attr('${ent.amsSlot 1}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %}
        --tray-2-bg: {% if is_state_attr('${ent.amsSlot 2}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %}
        --tray-3-bg: {% if is_state_attr('${ent.amsSlot 3}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %}
        --tray-4-bg: {% if is_state_attr('${ent.amsSlot 4}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %}
      }
    '';
  };

  # ── x1_carbon_external_spool.yaml ───────────────────────────────
  spoolCard = {
    type = "picture-elements";
    image = img "spool";
    elements = [
      {
        type = "custom:config-template-card";
        entities = [ ent.spoolSensor ];
        element = {
          type = "state-icon";
          entity = ent.spoolSensor;
          icon = "\${states['${ent.spoolSensor}'].state.toLowerCase() != 'empty' ? 'local:filament-2' : 'mdi:tray' }";
        };
        style = {
          top = "50%";
          left = "50%";
          transform = "translate(-50%, -50%) scale(200%)";
          "--paper-item-icon-color" = "var(--spool-color)";
          "--icon-primary-color" = "var(--spool-color)";
          "--state-icon-color" = "var(--spool-color)";
          background-color = "rgba(0,0,0,0.5)";
          box-shadow = "0 0 5px 5px var(--spool-bg)";
          border-radius = "50px";
          "--mdc-icon-size" = "1.8em";
        };
      }
      {
        type = "state-label";
        entity = ent.spoolSensor;
        attribute = "type";
        tap_action.action = "none";
        style = {
          top = "50%";
          left = "85%";
          text-align = "center";
          "font-size" = "1em";
          background-color = "rgba(0,0,0,0.4)";
          box-shadow = "0 0 5px 5px rgba(0, 0, 0, 0.4)";
          border-radius = "50px";
          pointer-events = "none";
          color = "var(--contrast20)";
        };
      }
    ];
    card_mod.style = ''
      ha-card {
        margin-left: auto;
        margin-right: auto;
        width: 60%;
        height: 60%;
        background: none !important;
        border: none !important;
        box-shadow: none !important;
        --spool-color: {{ state_attr('${ent.spoolSensor}', 'color') or 'var(--contrast20)' }};
        --spool-bg: {% if is_state_attr('${ent.spoolSensor}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %};
      }
    '';
  };

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
      card_mod.style = ''
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
    };
in
{
  type = "sections";
  max_columns = 3;
  icon = "mdi:printer-3d-nozzle";
  path = "x1c";
  header.card = ha.mkTitleCard "X1 Carbon";

  sections = [
    # ── Left column: live view, AMS, printer image, external spool ──
    (ha.mkGridSection [
      (ha.mkMushTitle "Live-View")
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

      (ha.mkMushTitle "Drucker")
      amsCard
      printerCard

      (ha.mkConditional
        [
          {
            condition = "state";
            entity = ent.spoolSensor;
            state_not = "unavailable";
          }
        ]
        {
          type = "vertical-stack";
          cards = [
            spoolCard
          ];
        }
      )
    ])

    # ── Middle column: reserved for later. ──────────────────────────
    (ha.mkGridSection [ ])

    # ── Right column: details, top-to-bottom. ───────────────────────
    (ha.mkGridSection [
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
        (tempGauge {
          name = "Kammer";
          entity = ent.chamberTemp;
          max = 60;
        })
      ])
      {
        type = "entities";
        entities = [
          {
            entity = ent.nozzleTarget;
            name = "Soll Düse";
          }
          {
            entity = ent.bedTarget;
            name = "Soll Bett";
          }
        ];
      }

      (ha.mkMushTitle "AMS")
      {
        type = "entities";
        entities = [
          {
            entity = ent.amsTemp;
            name = "Temperatur";
          }
          {
            entity = ent.amsHumidity;
            name = "Feuchte";
          }
          {
            entity = ent.amsHumidityIx;
            name = "Feuchte-Index";
          }
        ];
      }

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

      (ha.mkMushTitle "Druckdetails")
      {
        type = "entities";
        entities = [
          {
            entity = ent.task;
            name = "Task";
          }
          {
            entity = ent.progress;
            name = "Fortschritt";
          }
          {
            entity = ent.stage;
            name = "Phase";
          }
          {
            entity = ent.layer;
            name = "Layer";
          }
          {
            entity = ent.layerTotal;
            name = "Layer gesamt";
          }
          {
            entity = ent.startTime;
            name = "Start";
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
            entity = ent.speedProfile;
            name = "Geschwindigkeit";
          }
        ];
      }

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
          {
            entity = ent.printError;
            name = "Druckfehler";
          }
        ];
      }
    ])
  ];
}
