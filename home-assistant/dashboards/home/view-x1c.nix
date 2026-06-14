{ lib }:
let
  inherit (lib) ha;

  p = "x1c";
  ams = "x1c_ams";
  spool = "x1c_external_spool";

  assetV = "2";
  img = name: "/local/bambu/${name}.png?v=${assetV}";

  # Entity-id table for the Bambu integration; entities are referenced
  # by name elsewhere in this file rather than by `config.hass.entities`
  # because they were ported from an upstream YAML dashboard and the
  # underscore-slug convention here mirrors the source 1:1.
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

    coolingFanRpm = "sensor.${p}_bauteillufterdrehzahl";
    chamberFanRpm = "sensor.${p}_druckraumlufterdrehzahl";
    auxFanRpm = "sensor.${p}_hotendlufterdrehzahl";
    coolingFan = "fan.${p}_bauteillufter";
    chamberFan = "fan.${p}_druckraumlufter";
    auxFan = "fan.${p}_druckkopflufter";

    nozzleTargetNum = "number.${p}_zieltemperatur_der_duse";
    bedTargetNum = "number.${p}_zieltemperatur_des_druckbett";
    speedSelect = "select.${p}_druckgeschwindigkeit";

    btnPause = "button.${p}_druckvorgang_anhalten";
    btnResume = "button.${p}_druckvorgang_fortsetzen";
    btnStop = "button.${p}_druckvorgang_beenden";
    btnRefresh = "button.${p}_aktualisierung_der_daten_erzwingen";

    gcodeFile = "sensor.${p}_gcode_dateiname";
    nozzleType = "sensor.${p}_dusentyp";
    nozzleSize = "sensor.${p}_dusengrosse";
    bedType = "sensor.${p}_druckbett_typ";
    printType = "sensor.${p}_drucktyp";
    printWeight = "sensor.${p}_gewicht_des_drucks";
    printLength = "sensor.${p}_drucklange";
    objectsPrintable = "sensor.${p}_druckbare_objekte";
    objectsSkipped = "sensor.${p}_ubersprungene_objekte";
    sdStatus = "sensor.${p}_sd_kartenstatus";
    totalUsage = "sensor.${p}_gesamtnutzung";
    ipAddress = "sensor.${p}_ip_adresse";
    serial = "sensor.${p}_seriennummer";
    printerName = "sensor.${p}_name_des_druckers";
    mqttMode = "sensor.${p}_mqtt_verbindungsmodus";

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
    timelapse = "binary_sensor.${p}_aufnahme_von_zeitraffern";
    extruderFilament = "binary_sensor.${p}_extruder_filament_status";
    devLan = "binary_sensor.${p}_entwickler_lan_modus";

    # ── AMS ───────────────────────────────────────────────────────
    amsActive = "binary_sensor.${ams}_aktiv";
    amsId = "sensor.${ams}_aktiv";
    amsHumidityIx = "sensor.${ams}_index_der_luftfeuchtigkeit";
    amsHumidity = "sensor.${ams}_luftfeuchtigkeit";
    amsTemp = "sensor.${ams}_temperatur";
    amsSlot = i: "sensor.${ams}_slot_${toString i}";

    # ── External spool ────────────────────────────────────────────
    spoolSensor = "sensor.${spool}_externe_spule";
    spoolActive = "binary_sensor.${spool}_aktiv";
  };

  # Inline-evaluated template for config-template-card style props
  # (which only honor `${…}`, not `[[[ … ]]]`).
  wifiColor = e: "\${states['${e}'].state > -67 ? 'var(--blue)' : 'var(--red)'}";

  # Picture-elements helper for hiding chrome via the `picture-bare`
  # card_mod class from theme.nix.
  pictureBare = elements: {
    type = "picture-elements";
    card_mod.class = "picture-bare";
    inherit elements;
  };

  # ── Picture-elements: printer image with badges over hardware ────
  printerCard =
    (pictureBare [
      # WiFi signal — circular state-badge tinted by signal strength.
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
      (ha.mkElementConditional
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
          (ha.mkElementConditional
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
      (ha.mkElementConditional
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
    ])
    // {
      image = img "on";
      entity = ent.light;
      state_image = {
        "on" = img "on";
        "off" = img "off";
        "unavailable" = img "off";
      };
    };

  # ── AMS image with one filament overlay per slot ────────────────
  amsSlotOverlay =
    idx: iconLeftPct: labelLeftPct:
    let
      slot = ent.amsSlot idx;
      colorVar = "--tray-${toString idx}-color";
      bgVar = "--tray-${toString idx}-bg";
    in
    [
      {
        type = "custom:config-template-card";
        entities = [ slot ];
        element = {
          type = "state-icon";
          entity = slot;
          icon = "\${states['${slot}'].state.toLowerCase() != 'empty' ? 'local:filament-2' : 'mdi:tray' }";
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
        entity = slot;
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

  amsCard =
    (pictureBare (
      (amsSlotOverlay 1 "21.4" "21")
      ++ (amsSlotOverlay 2 "39.7" "40")
      ++ (amsSlotOverlay 3 "59.7" "60")
      ++ (amsSlotOverlay 4 "79.6" "79.6")
      ++ [
        (ha.mkElementConditional
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
        (ha.mkElementConditional
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
      ]
    ))
    // {
      image = img "ams";
      # Per-slot CSS variables driven by Jinja — moved here from the
      # global picture-bare class because the values are templated.
      card_mod = {
        class = "picture-bare";
        style = ''
          ha-card {
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
    };

  spoolCard =
    (pictureBare [
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
    ])
    // {
      image = img "spool";
      # Spool styles include Jinja-templated CSS vars (--spool-color etc),
      # plus extra sizing that the global picture-bare class doesn't cover.
      card_mod = {
        class = "picture-bare";
        style = ''
          ha-card {
            margin-left: auto;
            margin-right: auto;
            width: 60%;
            height: 60%;
            --spool-color: {{ state_attr('${ent.spoolSensor}', 'color') or 'var(--contrast20)' }};
            --spool-bg: {% if is_state_attr('${ent.spoolSensor}', 'active', true) %} rgba(255, 255, 126, 0.5); {% else %} rgba(0,0,0,0.5); {% endif %};
          }
        '';
      };
    };

  # Speed-mode pill: tinted yellow when the active speed matches the
  # option. 72px tall / 16px radius like the print-control row below.
  speedPill =
    option: name: icon:
    ha.mkServiceButton {
      inherit name icon;
      entity = ent.speedSelect;
      service = "select.select_option";
      serviceData.option = option;
      serviceTarget = ent.speedSelect;
      haptic = "medium";
      height = 72;
      padding = "12px";
      radius = "16px";
      fontSize = "12px";
      state = [
        (ha.mkStateStyle option {
          card.background = "var(--yellow)";
          icon.color = "var(--black)";
          name.color = "var(--black)";
        })
      ];
    };

  # Compact control button used by the print-control row (pause /
  # resume / cancel). 72px shape matches the speed pills above.
  controlButtonOpts = {
    service = "button.press";
    haptic = "medium";
    height = 72;
    padding = "12px";
    radius = "16px";
    fontSize = "13px";
  };
in
{
  type = "sections";
  max_columns = 3;
  icon = "mdi:printer-3d-nozzle";
  path = "x1c";
  header.card = ha.mkBadgeTitleCard {
    name = "X1 Carbon";
    badgeCard = ha.mkHeaderBadge {
      entity = ent.status;
      name = ''
        [[[
          const st = states["${ent.status}"]?.state ?? "unknown";
          const rem = states["${ent.remaining}"]?.state;
          const lay = states["${ent.layer}"]?.state;
          const tot = states["${ent.layerTotal}"]?.state;
          if (st === "running") {
            const layers = (lay && tot && lay !== "unknown" && tot !== "unknown")
              ? " · Layer " + lay + "/" + tot : "";
            return "Druckt · noch " + rem + " min" + layers;
          }
          if (st === "pause") return "Pausiert · noch " + rem + " min";
          if (st === "idle" || st === "finish") return "Idle";
          if (st === "prepare") return "Vorbereitung";
          if (st === "offline") return "Offline";
          if (st === "failed") return "Fehler";
          return st.charAt(0).toUpperCase() + st.slice(1);
        ]]]
      '';
    };
  };

  sections =
    let
      # The three columns only render while the printer is actually
      # reachable. They hide when it's powered off (status "offline", via
      # the wall switch) and when the integration can't reach it at all
      # ("unavailable"/"unknown"). The header badge stays visible above
      # and surfaces the state on its own.
      onlineOnly = [
        {
          condition = "state";
          entity = ent.status;
          state_not = [
            "offline"
            "unavailable"
            "unknown"
          ];
        }
      ];
      # Only the "can't reach the printer" case gets an explicit notice;
      # "offline" is a normal powered-down state the badge already covers.
      unreachable = [
        {
          condition = "state";
          entity = ent.status;
          state = [
            "unavailable"
            "unknown"
          ];
        }
      ];
    in
    [
      # ── Unreachable notice: shown only when the integration can't talk
      #    to the printer; the three columns below stay hidden then. ──
      (ha.mkGridSection [
        (ha.mkInfoBanner {
          conditions = unreachable;
          name = "Drucker nicht erreichbar";
          icon = "mdi:printer-3d-nozzle-alert";
          entity = ent.status;
          label = "X1 Carbon ist aktuell nicht verbunden.";
          service = "homeassistant.update_entity";
          serviceData.entity_id = ent.status;
        })
      ])

      # ── Left column: live view, AMS, printer image, external spool ──
      (
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
              {
                entity = ent.cameraSwitch;
                tap_action.action = "toggle";
              }
              { entity = ent.door; }
              { entity = ent.chamberTemp; }
            ];
          }

          (ha.mkMushTitle "Drucker")
          amsCard
          printerCard

          (ha.mkConditional [
            {
              condition = "state";
              entity = ent.spoolSensor;
              state_not = "unavailable";
            }
          ] (ha.mkVStack [ spoolCard ]))
        ])
        // {
          visibility = onlineOnly;
        }
      )

      # ── Middle column: live controls ───────────────────────────────
      (
        (ha.mkGridSection [
          (ha.mkMushTitle "Geschwindigkeit")
          (ha.mkHStack [
            (speedPill "silent" "Silent" "mdi:speedometer-slow")
            (speedPill "standard" "Standard" "mdi:speedometer-medium")
            (speedPill "sport" "Sport" "mdi:speedometer")
            (speedPill "ludicrous" "Ludicrous" "mdi:rocket-launch")
          ])

          (ha.mkMushTitle "Druck")
          # Pause and Resume merged into one state-driven button — name,
          # icon and target swap based on the print state.
          (ha.mkHStack [
            (ha.mkButtonOrange (
              controlButtonOpts
              // {
                name = "[[[ return entity.state === 'running' ? 'Pause' : 'Fortsetzen'; ]]]";
                icon = "[[[ return entity.state === 'running' ? 'mdi:pause' : 'mdi:play'; ]]]";
                entity = ent.status;
                serviceTarget = "[[[ return entity.state === 'running' ? '${ent.btnPause}' : '${ent.btnResume}'; ]]]";
              }
            ))
            (
              (ha.mkButtonRed (
                controlButtonOpts
                // {
                  name = "Abbruch";
                  icon = "mdi:stop-circle";
                  serviceTarget = ent.btnStop;
                }
              ))
              // {
                confirmation.text = "Druck wirklich abbrechen?";
              }
            )
          ])

          (ha.mkMushTitle "Soll-Temperaturen")
          {
            type = "custom:mushroom-number-card";
            entity = ent.nozzleTargetNum;
            name = "Düse";
            icon_color = "yellow";
            layout = "horizontal";
            display_mode = "slider";
          }
          {
            type = "custom:mushroom-number-card";
            entity = ent.bedTargetNum;
            name = "Bett";
            icon_color = "yellow";
            layout = "horizontal";
            display_mode = "slider";
          }

          (ha.mkMushTitle "Lüfter")
          {
            type = "custom:mushroom-fan-card";
            entity = ent.coolingFan;
            name = "Bauteilkühlung";
            icon_color = "var(--blue)";
            icon_animation = true;
            show_percentage_control = true;
            fill_container = false;
            layout = "horizontal";
          }
          {
            type = "custom:mushroom-fan-card";
            entity = ent.chamberFan;
            name = "Kammer";
            icon_color = "var(--blue)";
            icon_animation = true;
            show_percentage_control = true;
            fill_container = false;
            layout = "horizontal";
          }
          # Hotend (printhead) fan: the bambu_lab integration exposes it as
          # percentage-only — `fan.toggle` maps to set_percentage(100)
          # instead of true on/off — so we route the icon tap to more-info
          # and let the user drag the slider for control.
          {
            type = "custom:mushroom-fan-card";
            entity = ent.auxFan;
            name = "Hotend";
            icon_color = "var(--blue)";
            icon_animation = true;
            show_percentage_control = true;
            fill_container = false;
            layout = "horizontal";
            tap_action = {
              action = "more-info";
              haptic = "medium";
            };
          }

          (ha.mkMushTitle "Druckauftrag")
          {
            type = "entities";
            entities = [
              {
                entity = ent.gcodeFile;
                name = "Datei";
              }
              {
                entity = ent.printType;
                name = "Typ";
              }
              {
                entity = ent.printWeight;
                name = "Gewicht";
              }
              {
                entity = ent.printLength;
                name = "Filamentlänge";
              }
              {
                entity = ent.objectsPrintable;
                name = "Objekte";
              }
              {
                entity = ent.objectsSkipped;
                name = "Übersprungen";
              }
              {
                entity = ent.timelapse;
                name = "Aufnahme aktiv";
              }
            ];
          }
        ])
        // {
          visibility = onlineOnly;
        }
      )

      # ── Right column: details, top-to-bottom ───────────────────────
      (
        (ha.mkGridSection [
          (ha.mkAlertBanner {
            conditions = [ (ha.stateIs ent.hms "on") ];
            name = "HMS-Meldung";
            icon = "mdi:alert";
            entity = ent.hms;
            service = "homeassistant.update_entity";
            serviceData.entity_id = ent.hms;
          })

          (ha.mkMushTitle "Temperaturen")
          (ha.mkHStack [
            (ha.mkThermometerGauge {
              name = "Düse";
              entity = ent.nozzleTemp;
              max = 300;
            })
            (ha.mkThermometerGauge {
              name = "Bett";
              entity = ent.bedTemp;
              max = 110;
            })
            (ha.mkThermometerGauge {
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

          (ha.mkMushTitle "Lüfterdrehzahlen")
          {
            type = "entities";
            entities = [
              {
                entity = ent.coolingFanRpm;
                name = "Bauteilkühlung";
                icon = "mdi:fan";
              }
              {
                entity = ent.chamberFanRpm;
                name = "Kammer";
                icon = "mdi:fan";
              }
              {
                entity = ent.auxFanRpm;
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

          (ha.mkMushTitle "Hardware")
          {
            type = "entities";
            entities = [
              {
                entity = ent.nozzleType;
                name = "Düsentyp";
              }
              {
                entity = ent.nozzleSize;
                name = "Düsengröße";
              }
              {
                entity = ent.bedType;
                name = "Druckbett";
              }
              {
                entity = ent.sdStatus;
                name = "SD-Karte";
              }
              {
                entity = ent.totalUsage;
                name = "Gesamtnutzung";
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
                entity = ent.ipAddress;
                name = "IP";
              }
              {
                entity = ent.serial;
                name = "Seriennummer";
              }
              {
                entity = ent.printerName;
                name = "Druckername";
              }
              {
                entity = ent.mqttMode;
                name = "MQTT";
              }
              {
                entity = ent.devLan;
                name = "Entwickler-LAN";
              }
              {
                entity = ent.extruderFilament;
                name = "Extruder-Filament";
              }
              {
                entity = ent.printError;
                name = "Druckfehler";
              }
              {
                entity = ent.btnRefresh;
                name = "Daten neu laden";
              }
            ];
          }
        ])
        // {
          visibility = onlineOnly;
        }
      )
    ];
}
