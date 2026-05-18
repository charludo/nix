{ lib, e }:
let
  ha = lib.ha;
in
{
  type = "sections";
  max_columns = 1;
  path = "botty";
  icon = "mdi:robot-vacuum";
  header = {
    card = ha.mkBadgeTitleCard {
      name = "Botty";
      badgeCard = {
        type = "custom:button-card";
        name = ''[[[return states["${e.vacuum.botty}"].attributes.status]]]'';
        label = ''[[[return states["${e.vacuum.botty}"].attributes.battery_level + "%"]]]'';
        show_label = true;
        show_icon = false;
        entity = e.vacuum.botty;
        tap_action = {
          action = "more-info";
          haptic = "medium";
        };
        styles =
          (ha.mkStyles {
            card = {
              padding = "6px 10px";
              "font-size" = "12px";
              "line-height" = "18px";
              "font-weight" = 500;
              background = "var(--contrast20)";
            };
            name = {
              color = "var(--contrast1)";
            };
            label = {
              color = "var(--contrast12)";
            };
          })
          // {
            grid = ha.mkStyleProp {
              "grid-template-areas" = ''"n gutter l"'';
              "grid-template-columns" = "min-content 5px min-content";
              "grid-template-rows" = "min-content";
            };
          };
      };
    };
  };
  sections = [
    {
      type = "grid";
      cards = [

        # Xiaomi vacuum map
        {
          type = "custom:xiaomi-vacuum-map-card";
          language = "de";
          icons = [ ];
          tiles = [ ];
          map_source = {
            camera = e.image.botty_live_map;
            crop = {
              top = 170;
              right = 210;
              left = 190;
              bottom = 210;
            };
          };
          calibration_source.camera = true;
          entity = e.vacuum.botty;
          vacuum_platform = "send_command";
          map_locked = true;
          two_finger_pan = false;
          map_modes = [
            { template = "vacuum_clean_zone"; }
            { template = "vacuum_goto"; }
          ];
          card_mod.style = {
            "ha-button-menu"."$"."mwc-menu"."$"."mwc-menu-surface"."$" = ''
              /* Temporary fix for github issue 481 */ div {
                left: 0 !important;
                top: 0 !important;
                position: absolute !important;
              }
            '';
            "." = ''
              ha-card {
                background: none !important;
                box-shadow: none !important;
                border-radius: 0px !important;
                overflow: visible !important;
                --map-card-internal-primary-color: var(--blue) !important;
                --map-card-internal-secondary-color: var(--contrast2) !important;
                --map-card-internal-primary-text-color: var(--black) !important;
                --map-card-internal-secondary-text-color: var(--contrast20) !important;
                --map-card-internal-manual-rectangle-fill-color: rgba(var(--blue-rgb),0.4) !important;
                --map-card-internal-manual-rectangle-fill-color-selected: rgba(var(--blue-rgb),0.3) !important;
              }
              .map-wrapper { border-radius: 24px !important; overflow: hidden; }
              .controls-wrapper { margin-right: 0 !important; margin-left: 0 !important; margin-bottom: 0 !important; }
              .controls-wrapper .map-controls-wrapper { margin: 0 !important; }
              mwc-list-item { background: var(--contrast2) !important; }
            '';
          };
        }

        # Room toggles row 1: Wohnzimmer, Büro, Küche
        (ha.mkHStack [
          (ha.mkRoomToggleCard {
            entity = e.input_boolean.botty_wohnzimmer_reinigen;
            name = "Wohnzimmer";
            icon = "mdi:television-classic";
          })
          (ha.mkRoomToggleCard {
            entity = e.input_boolean.botty_buro_reinigen;
            name = "Büro";
            icon = "mdi:chair-rolling";
          })
          (ha.mkRoomToggleCard {
            entity = e.input_boolean.botty_kueche_reinigen;
            name = "Küche";
            icon = "mdi:stove";
          })
        ])

        # Room toggles row 2: Sofa + repeat count + control buttons
        (ha.mkHStack [
          (ha.mkRoomToggleCard {
            entity = e.input_boolean.botty_sofa_reinigen;
            name = "Sofa";
            icon = "mdi:sofa-single";
          })
          (ha.mkConditional [ (ha.stateIs e.vacuum.botty "docked") ] {
            type = "custom:button-card";
            icon = "mdi:numeric-1-box";
            entity = e.input_number.botty_wiederholungen;
            name = "Anzahl";
            label = "Wiederholungen";
            show_label = true;
            state = [
              {
                value = "1.0";
                icon = "mdi:numeric-1-box";
              }
              {
                value = "2.0";
                icon = "mdi:numeric-2-box";
              }
              {
                value = "3.0";
                icon = "mdi:numeric-3-box";
              }
            ];
            tap_action = {
              action = "perform-action";
              perform_action = e.script.botty_wiederholungen;
              haptic = "medium";
            };
            styles = ha.mkActionCardStyles {
              cardBg = "var(--contrast20)";
              iconColor = "var(--contrast1)";
              nameColor = "var(--contrast1)";
              labelColor = "var(--contrast1)";
              zIndex = 1;
            };
          })
          (ha.mkConditional [ (ha.stateIs e.vacuum.botty "docked") ] {
            type = "custom:button-card";
            icon = "mdi:robot-vacuum";
            name = "Reinigung";
            label = "starten";
            show_label = true;
            tap_action = {
              action = "perform-action";
              perform_action = e.script.botty_reinigung;
              haptic = "success";
            };
            styles = ha.mkActionCardStyles {
              cardBg = "var(--green)";
              iconColor = "var(--black)";
              nameColor = "var(--black)";
              labelColor = "var(--black)";
              zIndex = 1;
            };
          })
          (ha.mkConditional
            [
              (ha.orConditions [
                (ha.stateIs e.vacuum.botty "returning")
                (ha.stateIs e.vacuum.botty "cleaning")
              ])
            ]
            {
              type = "custom:button-card";
              icon = "mdi:pause";
              name = "Pausieren";
              label = ''[[[return Math.round(states["${e.sensor.botty_aktuelle_reinigungsdauer}"].state / 60) + " Minuten"]]]'';
              show_label = true;
              tap_action = {
                action = "perform-action";
                perform_action = e.script.botty_pausieren;
                haptic = "success";
              };
              styles = ha.mkActionCardStyles {
                cardBg = "var(--white)";
                iconColor = "var(--black)";
                nameColor = "var(--black)";
                labelColor = "var(--contrast7)";
                zIndex = 1;
              };
            }
          )
          (ha.mkConditional [ (ha.stateIs e.vacuum.botty "paused") ] {
            type = "custom:button-card";
            icon = "mdi:play";
            name = "Fortsetzen";
            label = ''[[[return Math.round(states["${e.sensor.botty_aktuelle_reinigungsdauer}"].state / 60) + " Minuten"]]]'';
            show_label = true;
            tap_action = {
              action = "perform-action";
              perform_action = e.script.botty_fortsetzen;
              haptic = "success";
            };
            styles = ha.mkActionCardStyles {
              cardBg = "var(--white)";
              iconColor = "var(--black)";
              nameColor = "var(--black)";
              labelColor = "var(--contrast7)";
              zIndex = 1;
            };
          })
          (ha.mkConditional [ (ha.stateNot e.vacuum.botty "docked") ] {
            type = "custom:button-card";
            icon = "mdi:home";
            name = "Beenden";
            label = ''[[[return states["${e.sensor.botty_aktueller_reinigungsbereich}"].state + "m² gereinigt"]]]'';
            show_label = true;
            tap_action = {
              action = "perform-action";
              perform_action = e.script.botty_zurueckkehren;
              haptic = "success";
            };
            styles = ha.mkActionCardStyles {
              cardBg = "var(--red)";
              iconColor = "var(--contrast1)";
              nameColor = "var(--contrast1)";
              zIndex = 1;
            };
          })
        ])

        # Brush remaining counters row 1
        (ha.mkHStack [
          (ha.mkRemainingCard {
            sensorTemplate = e.sensor.botty_restkapazitat_der_hauptburste;
            label = "Hauptbürste";
            resetScript = e.script.botty_main_brush_reset;
            resetConfirmation = "Sicher, dass du die Hauptbürste zurücksetzen möchtest?";
          })
          (ha.mkRemainingCard {
            sensorTemplate = e.sensor.botty_restkapazitat_der_seitenburste;
            label = "Seintenbürste";
            resetScript = e.script.botty_side_brush_reset;
            resetConfirmation = "Sicher, dass du die Seitenbürste zurücksetzen möchtest?";
          })
        ])

        # Brush remaining counters row 2
        (ha.mkHStack [
          (ha.mkRemainingCard {
            sensorTemplate = e.sensor.botty_filter_restkapazitat;
            label = "Filter";
            resetScript = e.script.botty_filter_reset;
            resetConfirmation = "Sicher, dass du den Filter zurücksetzen möchtest?";
          })
          (ha.mkRemainingCard {
            sensorTemplate = e.sensor.botty_bis_sensorreinigung_verbleibend;
            label = "Sensorreinigung";
            resetScript = e.script.botty_sensor_cleaning_reset;
            resetConfirmation = "Sicher, dass du die Sensorreinigung zurücksetzen möchtest?";
          })
        ])

      ];
    }
  ];
}
