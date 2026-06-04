{
  lib,
  e,
  areas,
  wateringTimes ? [ ],
}:
let
  ha = lib.ha;

  broadcastPresets = [
    {
      name = "Gleich da";
      icon = "mdi:home-clock";
      text = "Ich bin in 5 Minuten zuhause.";
    }
    {
      name = "Ruf zurück";
      icon = "mdi:phone-alert";
      text = "Bitte ruf mich dringend zurück.";
    }
    {
      name = "Hallo?!";
      icon = "mdi:heart-pulse";
      text = "Gib ein Lebenszeichen.";
    }
  ];

  # Watering-slot toggle (input_boolean named after the time string),
  # rendered as a compact pill row.
  mkWateringSlot =
    t:
    let
      slug = lib.replaceStrings [ ":" ] [ "_" ] t;
    in
    ha.mkPillButton {
      entity = "input_boolean.bewasserung_zeit_${slug}";
      name = t;
    };

  timerBanner =
    timer:
    ha.mkActiveBanner {
      conditions = [ (ha.stateIs timer "active") ];
      name = "Timer";
      icon = "mdi:timer-sand";
      label = "[[[ const f = new Date(states['${timer}'].attributes.finishes_at); return 'Endet um ' + f.toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' }); ]]]";
      service = "timer.cancel";
      serviceData.entity_id = timer;
      confirmation = "Timer wirklich abbrechen?";
    };
in
{
  type = "sections";
  max_columns = 1;
  icon = "mdi:home";
  header.card = ha.mkTitleCard "Home";
  sections = [
    {
      type = "grid";
      cards = [

        # Temperature swipe carousel.
        {
          type = "custom:swipe-card";
          card_width = "calc(100% - 48px)";
          parameters = {
            centeredSlides = true;
            centeredSlidesBounds = true;
            slidesPerView = "auto";
            spaceBetween = 16;
            initialSlide = 2;
            touchAngle = 65;
            # Recalculate slide widths when the carousel's DOM
            # (re)attaches on view switch — without these, Swiper
            # measures the container before HA finishes sizing it and
            # snaps to the last reachable position.
            observer = true;
            observeParents = true;
            observeSlideChildren = true;
          };
          cards = [
            (ha.mkTempTile "Terrasse" e.sensor.thermometer_nordseite.temperature)
            (ha.mkTempTile "Gewächshaus" e.sensor.thermometer_gewachshaus.temperature)
            (ha.mkTempTile "Wetterstation" e.sensor.wetterstation.temperature)
            (ha.mkTempTile "Wohnzimmer" e.sensor.thermometer_wohnzimmer.temperature)
            (ha.mkTempTile "Schlafzimmer" e.sensor.thermometer_schlafzimmer.temperature)
            (ha.mkTempTile "Badezimmer" e.sensor.thermometer_badezimmer.temperature)
            (ha.mkTempTile "Büro" e.sensor.thermometer_buro.temperature)
            (ha.mkTempTile "Serverschrank" e.sensor.thermometer_serverschrank.temperature)
            (ha.mkTempTile "Filamentbox" e.sensor.thermometer_filamentbox.humidity)
          ];
        }

        # Conditional status banners (printer, music, door, battery,
        # botty, timers). Each adds itself to the column only while its
        # condition holds; otherwise it disappears entirely.
        {
          square = false;
          type = "grid";
          columns = 1;
          cards = [
            (ha.mkSuccessBanner {
              conditions = [ (ha.stateIs "sensor.x1c_druckstatus" "running") ];
              name = "X1C druckt";
              icon = "mdi:printer-3d-nozzle";
              entity = "sensor.x1c_druckstatus";
              label = "[[[ const rem = states['sensor.x1c_verbleibende_zeit']?.state ?? '?'; const lay = states['sensor.x1c_aktuelle_schicht']?.state ?? '?'; const tot = states['sensor.x1c_gesamtzahl_der_schichten']?.state ?? '?'; return 'noch ' + rem + ' min · Layer ' + lay + '/' + tot; ]]]";
              # mkStatusBanner requires a `service`; tapNavigatePath
              # overrides tap_action to navigate instead. The service
              # is harmless because it never fires.
              service = "homeassistant.update_entity";
              serviceData.entity_id = "sensor.x1c_druckstatus";
              tapNavigatePath = "/lovelace/x1c";
            })
            (ha.mkActiveBanner {
              conditions = [ (ha.stateIs e.media_player.office "playing") ];
              name = "Musik anhalten";
              icon = "mdi:pause";
              entity = e.media_player.alle;
              label = "[[[ return states['${e.media_player.alle}'].attributes.media_title ]]]";
              service = e.script.sonos_play_pause;
              haptic = "medium";
            })
            (ha.mkAlertBanner {
              conditions = [ (ha.stateIs e.binary_sensor.tursensor.opening "on") ];
              name = "Wohnungstür offen";
              icon = "mdi:door-open";
              entity = e.binary_sensor.tursensor.opening;
              label = ''[[[return "seit: " + states["${e.sensor.tursensor_last_changed}"].state ]]]'';
              service = e.script.botty_zurueckkehren;
              holdAction = {
                action = "more-info";
                haptic = "medium";
              };
            })
            (ha.mkAlertBanner {
              conditions = [ (ha.stateIs e.input_boolean.turalarm_persistent "on") ];
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
            })
            # Driven by sensor.zigbee_min_battery (a min-aggregation
            # group sensor over all zigbee battery entities; see
            # config/helpers.nix). Threshold lives in lib.ha so this
            # condition can't drift from the alerting automation.
            (ha.mkAlertBanner {
              conditions = [
                {
                  condition = "numeric_state";
                  entity = e.sensor.zigbee_min_battery;
                  below = ha.lowBatteryThreshold;
                }
              ];
              name = "Zigbee Akku schwach";
              icon = "mdi:battery-alert";
              entity = e.sensor.zigbee_min_battery;
              label = ''
                [[[
                  const names = [];
                  for (const id of Object.keys(states)) {
                    if (!id.endsWith('_battery')) continue;
                    const s = states[id];
                    const v = parseFloat(s.state);
                    if (!isNaN(v) && v < ${toString ha.lowBatteryThreshold}) {
                      names.push((s.attributes.friendly_name || id) + ' (' + s.state + '%)');
                    }
                  }
                  return names.join(', ');
                ]]]
              '';
              service = "homeassistant.update_entity";
              serviceData.entity_id = e.sensor.zigbee_min_battery;
              holdAction = {
                action = "more-info";
                haptic = "medium";
              };
            })
            (ha.mkInfoBanner {
              conditions = [ (ha.stateNot e.vacuum.botty "docked") ];
              name = "Botty anhalten";
              icon = "mdi:robot-vacuum";
              label = ''[[[return states["${e.sensor.botty_current_clean_area}"].state + "m² gereinigt"]]]'';
              service = e.script.botty_pausieren;
            })
          ]
          ++ map timerBanner (builtins.attrValues e.timer);
        }

        # Licht & Co
        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Licht & Co";
          cards = [
            (ha.mkToggleYellow {
              entity = e.light.strahler.light;
              name = "Strahler";
              withSlider = true;
            })
            (ha.mkToggleBlue {
              entity = e.fan.xiaomi_smart_fan;
              name = "Ventilator";
              withSlider = true;
              sliderColorMode = "fan";
            })
          ];
        }

        # Garten — each row is itself a conditional, so disabled
        # features simply disappear instead of leaving half-empty rows.
        # Visibility of each conditional is gated by an input_boolean
        # toggled from view-einstellungen.
        {
          square = false;
          type = "grid";
          columns = 1;
          title = "Garten";
          tap_action = {
            action = "navigate";
            navigation_path = "/dashboard-garten";
          };
          cards = [
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_anzucht "on") ] (
              ha.mkHStack [
                (ha.mkToggleGreen {
                  entity = e.switch.steckdose_pflanzenlicht.switch;
                  name = "Pflanzenlicht";
                  icon = "mdi:flower-pollen";
                })
                (ha.mkAutoToggleWithSettingGreen {
                  entity = e.automation.pflanzenlicht_automatik;
                  name = "Pflanzlicht-Automatik";
                  settingEntity = e.input_number.stunden_sonnenlicht_setzlinge;
                  settingMin = 1;
                  settingMax = 24;
                })
              ]
            ))
            # Bewässerung sits in its own vstack so the per-slot pill
            # row always lives directly under the Automatik toggle.
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_bewasserung "on") ] (
              ha.mkVStack [
                (ha.mkHStack [
                  (ha.mkToggleBlue {
                    entity = e.switch.steckdose_wasserpumpe.switch;
                    name = "Wasserpumpe";
                    icon = "mdi:water-pump";
                  })
                  # Tap toggles BOTH halves of the watering cycle at
                  # once so they stay in sync.
                  (ha.mkAutoToggleBlue {
                    entity = e.automation.wasserpumpe_an;
                    name = "Bewässerungs-Automatik";
                    tapAction = {
                      action = "perform-action";
                      perform_action = "automation.toggle";
                      haptic = "medium";
                      data.entity_id = [
                        e.automation.wasserpumpe_an
                        e.automation.wasserpumpe_aus
                      ];
                    };
                  })
                ])
                (ha.mkConditional [ (ha.stateIs e.automation.wasserpumpe_an "on") ] (
                  ha.mkHStack (map mkWateringSlot wateringTimes)
                ))
              ]
            ))
            (ha.mkConditional [ (ha.stateIs e.input_boolean.settings_garten_heizung "on") ] (
              ha.mkHStack [
                (ha.mkToggleYellow {
                  entity = e.switch.steckdose_gewachshaus_heizung.switch;
                  name = "Gewächshaus Heizung";
                  icon = "mdi:radiator";
                })
                (ha.mkAutoToggleYellow {
                  entity = e.automation.heat_greenhouse;
                  name = "Heizungs-Automatik";
                })
              ]
            ))
          ];
        }

        {
          square = false;
          type = "grid";
          columns = 2;
          title = "Alarme";
          cards = [
            (ha.mkToggleRed {
              entity = e.input_boolean.turalarm;
              name = ''[[[ return entity.state === "on" ? "Türalarm: Armed" : "Türalarm: Disarmed"; ]]]'';
              icon = "[[[ return entity.attributes.icon ]]]";
              confirmation = "Sicher, dass du Alarm an/aus schalten willst?";
            })
            # Toggles input_boolean.broadcast_open, which gates the
            # broadcast form revealed beneath this grid.
            (ha.mkToggleYellow {
              entity = "input_boolean.broadcast_open";
              name = "Broadcast";
              icon = "mdi:bullhorn";
            })
          ];
        }

        # Broadcast form. The preset buttons fill input_text without
        # sending, so the user can tweak before tapping Send. The Send
        # button reads the focused DOM input directly because HA's
        # input_text card only commits to state on blur/Enter — tapping
        # Send isn't a blur, so the entity state is almost always stale.
        (ha.mkConditional [ (ha.stateIs "input_boolean.broadcast_open" "on") ] (
          ha.mkVStack [
            {
              square = false;
              type = "grid";
              columns = 3;
              cards = map (
                preset:
                ha.mkInputTextPreset {
                  inherit (preset) name icon;
                  target = "input_text.broadcast_message";
                  value = preset.text;
                }
              ) broadcastPresets;
            }
            {
              type = "entities";
              entities = [
                {
                  entity = "input_text.broadcast_message";
                  name = "Nachricht";
                }
              ];
              show_header_toggle = false;
            }
            (ha.mkServiceButton {
              name = "Senden";
              icon = "mdi:send";
              haptic = "medium";
              align = "start";
              padding = "16px";
              tapAction = {
                action = "call-service";
                service = "script.broadcast_announce";
                data = {
                  sender = "[[[ return hass.user.name; ]]]";
                  message = ''
                    [[[
                      function deepActive(root) {
                        let a = root.activeElement;
                        while (a && a.shadowRoot && a.shadowRoot.activeElement) {
                          a = a.shadowRoot.activeElement;
                        }
                        return a;
                      }
                      const el = deepActive(document);
                      if (el && typeof el.value === 'string' && el.value.length > 0) {
                        return el.value;
                      }
                      return states['input_text.broadcast_message'].state;
                    ]]]
                  '';
                };
                confirmation.text = ''
                  [[[
                    function deepActive(root) {
                      let a = root.activeElement;
                      while (a && a.shadowRoot && a.shadowRoot.activeElement) {
                        a = a.shadowRoot.activeElement;
                      }
                      return a;
                    }
                    const el = deepActive(document);
                    const msg = (el && typeof el.value === 'string' && el.value.length > 0)
                      ? el.value
                      : (states['input_text.broadcast_message'].state || ''');
                    return 'Senden: "' + msg + '" ?';
                  ]]]
                '';
                haptic = "medium";
              };
            })
          ]
        ))

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
                touchAngle = 30;
                threshold = 8;
              };
              cards = map (
                nv:
                let
                  slug = e.area.${ha.mkSlug nv.name}.slug;
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
