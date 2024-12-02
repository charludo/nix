{ lib, e }:
let
  ha = lib.ha;

  bottyDocked = ha.stateIs e.vacuum.botty "docked";
  bottyNotDocked = ha.stateNot e.vacuum.botty "docked";
  bottyRunning = ha.orConditions [
    (ha.stateIs e.vacuum.botty "returning")
    (ha.stateIs e.vacuum.botty "cleaning")
  ];
  bottyPaused = ha.stateIs e.vacuum.botty "paused";

  cleaningDuration = ''[[[return Math.round(states["${e.sensor.botty_aktuelle_reinigungsdauer}"].state / 60) + " Minuten"]]]'';
in
{
  type = "sections";
  max_columns = 1;
  path = "botty";
  icon = "mdi:robot-vacuum";
  header.card = ha.mkBadgeTitleCard {
    name = "Botty";
    badgeCard = ha.mkHeaderBadge {
      entity = e.vacuum.botty;
      name = ''[[[return states["${e.vacuum.botty}"].attributes.status]]]'';
      label = ''[[[return states["${e.vacuum.botty}"].attributes.battery_level + "%"]]]'';
    };
  };
  sections = [
    {
      type = "grid";
      cards = [
        # Xiaomi vacuum map. The map's internal palette is reskinned via
        # the `vacuum-map` card_mod class defined in theme.nix; only the
        # github-issue-481 hover-menu fix stays inline because it
        # targets a deeply nested shadow root.
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
          card_mod = {
            class = "vacuum-map";
            style."ha-button-menu"."$"."mwc-menu"."$"."mwc-menu-surface"."$" = ''
              /* Temporary fix for github issue 481 */ div {
                left: 0 !important;
                top: 0 !important;
                position: absolute !important;
              }
            '';
          };
        }

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

        # Row 2: Sofa selector + state-driven control buttons. Each
        # control is conditional on the vacuum's state so only the
        # currently-relevant actions are visible.
        (ha.mkHStack [
          (ha.mkRoomToggleCard {
            entity = e.input_boolean.botty_sofa_reinigen;
            name = "Sofa";
            icon = "mdi:sofa-single";
          })
          (ha.mkConditional [ bottyDocked ] (
            ha.mkActionCardWhite {
              name = "Anzahl";
              icon = "mdi:numeric-1-box";
              label = "Wiederholungen";
              entity = e.input_number.botty_wiederholungen;
              service = e.script.botty_wiederholungen;
              haptic = "medium";
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
              zIndex = 1;
            }
          ))
          (ha.mkConditional [ bottyDocked ] (
            ha.mkActionCardGreen {
              name = "Reinigung";
              icon = "mdi:robot-vacuum";
              label = "starten";
              service = e.script.botty_reinigung;
              zIndex = 1;
            }
          ))
          (ha.mkConditional [ bottyRunning ] (
            ha.mkActionCardWhite {
              name = "Pausieren";
              icon = "mdi:pause";
              label = cleaningDuration;
              service = e.script.botty_pausieren;
              zIndex = 1;
            }
          ))
          (ha.mkConditional [ bottyPaused ] (
            ha.mkActionCardWhite {
              name = "Fortsetzen";
              icon = "mdi:play";
              label = cleaningDuration;
              service = e.script.botty_fortsetzen;
              zIndex = 1;
            }
          ))
          (ha.mkConditional [ bottyNotDocked ] (
            ha.mkActionCardRed {
              name = "Beenden";
              icon = "mdi:home";
              label = ''[[[return states["${e.sensor.botty_aktueller_reinigungsbereich}"].state + "m² gereinigt"]]]'';
              service = e.script.botty_zurueckkehren;
              zIndex = 1;
            }
          ))
        ])

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
