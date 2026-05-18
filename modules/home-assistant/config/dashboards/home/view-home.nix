{
  lib,
  e,
  areas,
}:
let
  ha = lib.ha;
  mkAutoToggle =
    {
      entity,
      name,
      onColor,
    }:
    ha.mkToggleCard {
      inherit entity name onColor;
      icon = ha.robotIcon;
    };
in
{
  type = "sections";
  max_columns = 1;
  icon = "mdi:home";
  header = {
    card = ha.mkTitleCard "Home";
  };
  sections = [
    {
      type = "grid";
      cards = [

        # Temperature swipe carousel
        {
          type = "custom:swipe-card";
          card_width = "calc(100% - 48px)";
          parameters = {
            centeredSlides = true;
            centeredSlidesBounds = true;
            slidesPerView = "auto";
            spaceBetween = 16;
            initialSlide = 1;
          };
          cards = [
            (ha.mkTempTile "Gewächshaus" e.sensor.thermometer_gewachshaus.temperature)
            (ha.mkTempTile "Terrasse" e.sensor.thermometer_terrasse.temperature)
            (ha.mkTempTile "Wohnzimmer" e.sensor.thermometer_wohnzimmer.temperature)
            (ha.mkTempTile "Schlafzimmer" e.sensor.thermometer_schlafzimmer.temperature)
            (ha.mkTempTile "Badezimmer" e.sensor.thermometer_badezimmer.temperature)
            (ha.mkTempTile "Büro" e.sensor.thermometer_buro.temperature)
            (ha.mkTempTile "Serverschrank" e.sensor.thermometer_serverschrank.temperature)
            (ha.mkTempTile "Filamentbox" e.sensor.thermometer_filamentbox.humidity)
          ];
        }

        # Conditional status banners (music, door, botty)
        {
          square = false;
          type = "grid";
          columns = 1;
          cards = [
            (ha.mkConditional [ (ha.stateIs e.media_player.alle "playing") ] (
              ha.mkActionCard {
                name = "Musik anhalten";
                icon = "mdi:pause";
                entity = e.media_player.alle;
                label = "[[[ return states['${e.media_player.alle}'].attributes.media_title ]]]";
                service = e.script.sonos_play_pause;
                haptic = "medium";
                cardBg = "var(--yellow)";
                iconColor = "var(--black)";
                nameColor = "var(--black)";
                extraCardProps."margin-top" = "24px";
              }
            ))
            (ha.mkConditional [ (ha.stateIs e.binary_sensor.tursensor.opening "on") ] (
              ha.mkActionCard {
                name = "Wohnungstür offen";
                icon = "mdi:door-open";
                entity = e.binary_sensor.tursensor.opening;
                label = ''[[[return "seit: " + states["${e.sensor.tursensor_last_changed}"].state ]]]'';
                service = e.script.botty_zurueckkehren;
                holdAction = {
                  action = "more-info";
                  haptic = "medium";
                };
                cardBg = "var(--red)";
                iconColor = "var(--contrast1)";
                nameColor = "var(--contrast1)";
                zIndex = 1;
                extraCardProps."margin-top" = "24px";
              }
            ))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.turalarm_persistent "on") ] (
              ha.mkActionCard {
                name = "Wohnungstür wurde geöffnet";
                icon = "mdi:door-open";
                entity = e.binary_sensor.tursensor.opening;
                label = ''[[[return "letzte Änderung: " + states["${e.sensor.tursensor_last_changed}"].state + ", jetzt: " + states["${e.binary_sensor.tursensor.opening}"].state ]]]'';
                service = "input_boolean.turn_off";
                serviceData.entity_id = e.input_boolean.turalarm_persistent;
                holdAction = {
                  action = "more-info";
                  haptic = "medium";
                };
                confirmation = "Sicher, dass du die Warnung deaktivieren möchtest?";
                cardBg = "var(--red)";
                iconColor = "var(--contrast1)";
                nameColor = "var(--contrast1)";
                zIndex = 1;
                extraCardProps."margin-top" = "24px";
              }
            ))
            (ha.mkConditional [ (ha.stateNot e.vacuum.botty "docked") ] (
              ha.mkActionCard {
                name = "Botty anhalten";
                icon = "mdi:robot-vacuum";
                label = ''[[[return states["${e.sensor.botty_current_clean_area}"].state + "m² gereinigt"]]]'';
                service = e.script.botty_pausieren;
                cardBg = "var(--blue)";
                iconColor = "var(--contrast1)";
                nameColor = "var(--contrast1)";
                zIndex = 1;
                extraCardProps."margin-top" = "24px";
              }
            ))
          ];
        }

        # Licht & Co grid
        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Licht & Co";
          cards = [
            (ha.mkToggleCard {
              entity = e.light.strahler.light;
              name = "Strahler";
              onColor = "var(--yellow)";
              withSlider = true;
            })
            (ha.mkToggleCard {
              entity = e.fan.xiaomi_smart_fan;
              name = "Ventilator";
              onColor = "var(--blue)";
              withSlider = true;
              sliderColorMode = "fan";
            })
          ];
        }

        # Garten grid
        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Garten";
          tap_action = {
            action = "navigate";
            navigation_path = "/dashboard-garten";
          };
          cards = [
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_anzucht "on") ] (
              ha.mkToggleCard {
                entity = e.switch.steckdose_pflanzenlicht.switch;
                name = "Pflanzenlicht";
                icon = "mdi:flower-pollen";
                onColor = "var(--green)";
              }
            ))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_anzucht "on") ] {
              type = "custom:button-card";
              entity = e.automation.pflanzenlicht;
              name = "Pflanzlicht-Automatik";
              icon = ha.robotIcon;
              tap_action = {
                action = "toggle";
                haptic = "medium";
              };
              hold_action = {
                action = "more-info";
                haptic = "medium";
              };
              custom_fields = {
                uren = "[[[ return states['${e.input_number.stunden_sonnenlicht_setzlinge}'].state + 'h' ]]]";
                slider.card = {
                  type = "custom:my-slider-v2";
                  entity = e.input_number.stunden_sonnenlicht_setzlinge;
                  min = 1;
                  max = 24;
                  step = 1;
                  styles = {
                    container = {
                      background = "none";
                      "border-radius" = "100px";
                      overflow = "visible";
                    };
                    card = {
                      height = "16px";
                      padding = "0 8px";
                      background = "[[[ return states['${e.automation.pflanzenlicht}']?.state === 'on' ? 'linear-gradient(90deg, rgba(255,255,255,0.3) 0%, rgba(255,255,255,1) 100%)' : 'var(--contrast4)'; ]]]";
                    };
                    track = {
                      overflow = "visible";
                      background = "none";
                    };
                    progress.background = "none";
                    thumb = {
                      background = "[[[ return states['${e.automation.pflanzenlicht}']?.state === 'on' ? 'var(--black)' : 'var(--contrast20)'; ]]]";
                      top = "2px";
                      right = "-6px";
                      height = "12px";
                      width = "12px";
                      "border-radius" = "100px";
                    };
                  };
                };
              };
              styles =
                (ha.mkStyles {
                  card = {
                    background = "var(--contrast2)";
                    padding = "16px";
                    "--mdc-ripple-press-opacity" = 0;
                  };
                  img_cell = {
                    "justify-self" = "start";
                    width = "24px";
                  };
                  icon = {
                    width = "24px";
                    height = "24px";
                    color = "var(--contrast8)";
                  };
                  name = {
                    "justify-self" = "start";
                    "font-size" = "14px";
                    margin = "4px 0 12px 0";
                    color = "var(--contrast8)";
                  };
                })
                // {
                  grid = ha.mkStyleProp {
                    "grid-template-areas" = ''"i i" "n uren" "slider slider"'';
                    "grid-template-columns" = "1fr min-content";
                    "grid-template-rows" = "1fr min-content min-content";
                  };
                  custom_fields = ha.mkStyles {
                    uren = {
                      "font-size" = "12px";
                      color = "var(--contrast9)";
                      "padding-left" = "2px";
                      "align-self" = "center";
                      "margin-bottom" = "12px";
                    };
                  };
                };
              state = [
                (ha.mkStateStyle "on" {
                  card.background = "var(--green)";
                  icon.color = "var(--black)";
                  name.color = "var(--black)";
                })
                (ha.mkStateStyle "off" {
                  icon.color = "var(--contrast20)";
                  name.color = "var(--contrast20)";
                })
              ];
            })
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_bewasserung "on") ] (
              ha.mkToggleCard {
                entity = e.switch.steckdose_wasserpumpe.switch;
                name = "Wasserpumpe";
                icon = "mdi:water-pump";
                onColor = "var(--blue)";
              }
            ))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_bewasserung "on") ] (mkAutoToggle {
              entity = e.automation.deaktiviere_pumpe_nach_regen;
              name = "Bewässerungs-Automatik";
              onColor = "var(--blue)";
            }))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_heizung "on") ] (
              ha.mkToggleCard {
                entity = e.switch.steckdose_gewachshaus_heizung.switch;
                name = "Gewächshaus Heizung";
                icon = "mdi:radiator";
                onColor = "var(--red)";
              }
            ))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_heizung "on") ] (mkAutoToggle {
              entity = e.automation.heat_greenhouse;
              name = "Heizungs-Automatik";
              onColor = "var(--red)";
            }))
          ];
        }

        # Alarme grid
        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Alarme";
          cards = [
            {
              type = "custom:button-card";
              entity = e.input_boolean.turalarm;
              name = ''[[[ return entity.state === "on" ? "Türalarm: Armed" : "Türalarm:  Disarmed"; ]]]'';
              icon = "[[[ return entity.attributes.icon ]]]";
              show_label = true;
              confirmation.text = "Sicher, dass du Alarm an/aus schalten willst?";
              styles = ha.mkStyles {
                card = {
                  background = "var(--contrast2)";
                  padding = "16px";
                  "--mdc-ripple-press-opacity" = 0;
                };
                img_cell = {
                  "justify-self" = "start";
                  width = "24px";
                };
                icon = {
                  width = "24px";
                  height = "24px";
                  color = "var(--contrast8)";
                };
                name = {
                  "justify-self" = "start";
                  "font-size" = "14px";
                  margin = "4px 0 12px 0";
                  color = "var(--contrast8)";
                };
              };
              state = [
                (ha.mkStateStyle "on" {
                  card = {
                    background = "var(--red)";
                  };
                  icon = {
                    color = "var(--black)";
                  };
                  name = {
                    color = "var(--black)";
                  };
                })
                (ha.mkStateStyle "off" {
                  icon = {
                    color = "var(--contrast20)";
                  };
                  name = {
                    color = "var(--contrast20)";
                  };
                })
              ];
            }
          ];
        }

        # Dashboards nav grid
        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Dashboards";
          cards = [
            (ha.mkNavCard "Wetter" "/dashboard-umwelt-details")
            (ha.mkNavCard "Sensoren" "/dashboard-umwelt")
            (ha.mkNavCard "Garten" "/dashboard-garten")
            (ha.mkNavCard "Stromverbrauch" "/dashboard-stromverbrauch")
          ];
        }

        # Rooms swipe-card
        {
          square = false;
          type = "grid";
          columns = 1;
          title = "Räume";
          cards = [
            {
              type = "custom:swipe-card";
              parameters = {
                centeredSlides = true;
                centeredSlidesBounds = true;
                slidesPerView = 2.5;
                initialSlide = 0;
                spaceBetween = 16;
                freeMode = true;
                centerInsufficientSlides = true;
                snapToSlideEdge = true;
              };
              cards = map (
                nv:
                let
                  slug = e.area.${ha.mkSlug nv.name};
                in
                {
                  type = "area";
                  area = slug;
                  show_camera = false;
                  display_type = "compact";
                  navigation_path = "/dashboard-areas/${slug}";
                }
              ) (lib.sort (a: b: a.value.order < b.value.order) (lib.mapAttrsToList lib.nameValuePair areas));
            }
          ];
        }

      ];
    }
  ];
}
