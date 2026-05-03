{ lib, e }:
let
  ha = lib.ha;

  mkSonosBtn =
    {
      name,
      icon,
      height ? 184,
      padding ? "108px 0px 16px 20px",
      bg ? "var(--contrast2)",
      iconColor ? "var(--contrast20)",
      nameColor ? "var(--contrast20)",
      centered ? false,
      tapAction,
      entity ? null,
      states ? [ ],
    }:
    let
      base = {
        type = "custom:button-card";
        inherit name icon;
        tap_action = tapAction;
        styles =
          (ha.mkStyles {
            icon = {
              width = "24px";
              color = iconColor;
            };
            img_cell = {
              "justify-content" = if centered then "center" else "flex-start";
              "margin-top" = "0px";
            };
            name = {
              "justify-self" = if centered then "center" else "start";
              "font-size" = "14px";
              "margin-top" = "0px";
              color = nameColor;
            };
            card = {
              height = "${toString height}px";
              "border-radius" = "24px";
              padding = padding;
              "background-color" = bg;
            };
          })
          // {
            grid = ha.mkStyleProp { "grid-template-areas" = ''"i" "n"''; };
          };
      }
      // lib.optionalAttrs (entity != null) { inherit entity; }
      // lib.optionalAttrs (states != [ ]) { state = states; };
    in
    base;

  mkSonosSpeakerToggle =
    {
      name,
      entity,
      service,
    }:
    mkSonosBtn {
      inherit name entity;
      icon = "mdi:volume-high";
      height = 89;
      padding = "13px 0px 16px 20px";
      iconColor = "var(--white)";
      nameColor = "var(--white)";
      tapAction = {
        action = "call-service";
        haptic = "medium";
        inherit service;
      };
      states = [
        (ha.mkStateStyleFull {
          value = "[[[ return entity.attributes.is_volume_muted === true; ]]]";
          inherit name;
          icon = "mdi:volume-mute";
          bg = "var(--red)";
          iconColor = "var(--black)";
          styles.name = {
            "text-decoration" = "line-through";
            color = "var(--black)";
          };
        })
      ];
    };

  mkVolumeSlider = entity: height: {
    type = "custom:my-slider-v2";
    inherit entity;
    attribute = "volume_level";
    vertical = true;
    styles = {
      container = ha.mkStyleProp {
        "border-radius" = "100px";
        overflow = "visible";
        background = "none";
      };
      card = ha.mkStyleProp {
        height = "${toString height}px";
        padding = "0 20px";
        background = "var(--saturation)";
      };
      track = ha.mkStyleProp {
        overflow = "visible";
        background = "none";
      };
      progress = ha.mkStyleProp { background = "none"; };
      thumb = ha.mkStyleProp {
        background = "var(--black)";
        top = "-36px";
        height = "36px";
        width = "36px";
        "border-radius" = "100px";
        left = "-18px";
      };
    };
  };

  mkVolumeSliderCard =
    {
      name,
      entity,
      height,
    }:
    {
      type = "custom:button-card";
      inherit name;
      custom_fields.slider.card = mkVolumeSlider entity height;
      styles =
        (ha.mkStyles {
          card = {
            padding = "16px";
            "--mdc-ripple-press-opacity" = 0;
          };
          name = {
            "justify-self" = "start";
            "font-size" = "14px";
            margin = "4px 0 12px 0";
            color = "var(--contrast20)";
          };
        })
        // {
          grid = ha.mkStyleProp {
            "grid-template-areas" = ''"n" "slider"'';
            "grid-template-columns" = "1fr";
            "grid-template-rows" = "1fr auto";
            "align-items" = "center";
            "justify-items" = "center";
          };
        };
    };
in
{
  type = "sections";
  max_columns = 1;
  icon = "mdi:music-note";
  path = "";
  header = {
    card = ha.mkBadgeTitleCard {
      name = "Sonos";
      badgeCard = {
        type = "custom:button-card";
        name = ''[[[ return states["${e.media_player.alle}"].state.charAt(0).toUpperCase() + states["${e.media_player.alle}"].state.slice(1); ]]]'';
        show_icon = false;
        entity = e.media_player.alle;
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

        # Album art with blurred background
        {
          type = "custom:button-card";
          entity = e.media_player.alle;
          show_entity_picture = true;
          entity_picture = "[[[ return states['${e.media_player.alle}'].attributes.entity_picture ]]]";
          show_name = false;
          tap_action = {
            action = "navigate";
            navigation_path = "/music-assistant";
          };
          custom_fields.info.card = {
            type = "custom:button-card";
            entity = e.media_player.alle;
            show_entity_picture = true;
            entity_picture = "[[[ return states['${e.media_player.alle}'].attributes.entity_picture ]]]";
            tap_action = {
              action = "navigate";
              navigation_path = "/music-assistant";
            };
            name = ''
              [[[
                if (states['${e.media_player.alle}'].attributes.media_title)
                  return states['${e.media_player.alle}'].attributes.media_title;
                else
                  return "-";
              ]]]
            '';
            label = ''
              [[[
                if (states['${e.media_player.alle}'].attributes.media_artist)
                  return states['${e.media_player.alle}'].attributes.media_artist;
                else
                  return "";
              ]]]
            '';
            show_label = true;
            show_icon = true;
            styles =
              (ha.mkStyles {
                card = {
                  "font-family" = "hk nova medium";
                  background = "none";
                  "border-radius" = 0;
                  padding = "24px";
                  "--mdc-ripple-press-opacity" = 0;
                };
                img_cell = {
                  height = "100px";
                  width = "100px";
                  "border-radius" = "16px";
                };
                icon = {
                  height = "100%";
                  width = "100%";
                };
                name = {
                  "font-size" = "18px";
                  color = "var(--contrast20)";
                  width = "100%";
                  "text-align" = "left";
                  "align-self" = "end";
                };
                label = {
                  "font-size" = "16px";
                  color = "var(--contrast20)";
                  opacity = 0.5;
                  width = "100%";
                  "text-align" = "left";
                  "align-self" = "start";
                };
              })
              // {
                grid = ha.mkStyleProp {
                  "grid-template-areas" = ''"i gutter n" "i gutter l"'';
                  "grid-template-columns" = "min-content 24px 1fr";
                  "grid-template-rows" = "min-content";
                };
                custom_fields = ha.mkCustomFieldStyles {
                  image = {
                    "--mdc-ripple-press-opacity" = 0.5;
                  };
                };
              };
          };
          styles =
            (ha.mkStyles {
              card = {
                background = "none";
                padding = 0;
                position = "relative";
                "--mdc-ripple-press-opacity" = 0;
              };
              img_cell = {
                position = "absolute";
              };
              icon = {
                width = "125%";
                opacity = "var(--color-tint)";
                "-webkit-filter" = "blur(15px)";
                filter = "blur(15px)";
              };
            })
            // {
              grid = ha.mkStyleProp {
                "grid-template-areas" = ''"info"'';
                "grid-template-columns" = "1fr";
                "grid-template-rows" = "min-content";
              };
            };
        }

        # Play/pause + speaker toggles row
        (ha.mkHStack [
          (mkSonosBtn {
            name = "Abspielen";
            icon = "mdi:play";
            entity = e.media_player.office;
            bg = "var(--green)";
            iconColor = "var(--black)";
            nameColor = "var(--black)";
            tapAction = {
              action = "call-service";
              haptic = "medium";
              service = e.script.sonos_play_pause;
            };
            states = [
              (ha.mkStateStyleFull {
                value = "[[[ return entity?.state === 'playing'; ]]]";
                name = "Pausieren";
                icon = "mdi:pause";
                bg = "var(--yellow)";
              })
            ];
          })
          (ha.mkVStack [
            (mkSonosSpeakerToggle {
              name = "Wohnzimmer";
              entity = e.media_player.living_room;
              service = e.script.sonos_wohnzimmer_toggle;
            })
            (mkSonosSpeakerToggle {
              name = "Büro";
              entity = e.media_player.office;
              service = e.script.sonos_buro_toggle;
            })
          ])
        ])

        # Previous / Next / Shuffle+Loop row
        (ha.mkHStack [
          (mkSonosBtn {
            name = "Voriger";
            icon = "mdi:skip-previous";
            tapAction = {
              action = "call-service";
              haptic = "medium";
              service = "media_player.media_previous_track";
              service_data.entity_id = e.media_player.alle;
            };
          })
          (mkSonosBtn {
            name = "Nächster";
            icon = "mdi:skip-next";
            tapAction = {
              action = "call-service";
              haptic = "medium";
              service = "media_player.media_previous_track";
              service_data.entity_id = e.media_player.alle;
            };
          })
          (ha.mkVStack [
            (mkSonosBtn {
              name = "Shuffle aus";
              icon = "mdi:shuffle-disabled";
              entity = e.media_player.alle;
              height = 88;
              padding = "13px 0px 16px 20px";
              iconColor = "var(--white)";
              nameColor = "var(--white)";
              tapAction = {
                action = "call-service";
                haptic = "medium";
                service = "media_player.shuffle_set";
                service_data = {
                  entity_id = e.media_player.alle;
                  shuffle = "[[[\n  return !entity.attributes.shuffle;\n]]]\n";
                };
              };
              states = [
                (ha.mkStateStyleFull {
                  value = "[[[\n  return entity.attributes.shuffle === true;\n]]]\n";
                  name = "Shuffle an";
                  icon = "mdi:shuffle";
                  bg = "var(--yellow)";
                  nameColor = "var(--black)";
                  iconColor = "var(--black)";
                })
              ];
            })
            (mkSonosBtn {
              name = "Loop aus";
              icon = "mdi:repeat-off";
              entity = e.media_player.alle;
              height = 88;
              padding = "13px 0px 16px 20px";
              iconColor = "var(--white)";
              nameColor = "var(--white)";
              tapAction = {
                action = "call-service";
                haptic = "medium";
                service = "media_player.repeat_set";
                service_data = {
                  entity_id = e.media_player.alle;
                  repeat = "[[[\n  const modes = ['off', 'all'];\n  const current = entity.attributes.repeat ?? 'off';\n  return modes[(modes.indexOf(current) + 1) % modes.length];\n]]]\n";
                };
              };
              states = [
                (ha.mkStateStyleFull {
                  value = "[[[\n  return entity.attributes.repeat === \"all\";\n]]]\n";
                  name = "Loop an";
                  icon = "mdi:repeat";
                  bg = "var(--yellow)";
                  nameColor = "var(--black)";
                  iconColor = "var(--black)";
                })
              ];
            })
          ])
        ])

        # Volume sliders + seek + per-room volume
        (ha.mkHStack [
          (mkVolumeSliderCard {
            name = "";
            entity = e.media_player.alle;
            height = 400;
          })
          (ha.mkVStack [
            (mkSonosBtn {
              name = "Zurück";
              icon = "mdi:rewind-10";
              height = 84;
              padding = "8px 0px 16px 20px";
              tapAction = {
                action = "call-service";
                haptic = "medium";
                service = e.script.media_seek;
                data = {
                  seek_amount = -10;
                  media_player = e.media_player.alle;
                };
              };
            })
            (mkVolumeSliderCard {
              name = "Wohnzimmer";
              entity = e.media_player.living_room;
              height = 276;
            })
          ])
          (ha.mkVStack [
            (mkSonosBtn {
              name = "Vorwärts";
              icon = "mdi:fast-forward-10";
              height = 84;
              padding = "8px 0px 16px 20px";
              tapAction = {
                action = "call-service";
                haptic = "medium";
                service = e.script.media_seek;
                data = {
                  seek_amount = 10;
                  media_player = e.media_player.alle;
                };
              };
            })
            (mkVolumeSliderCard {
              name = "Büro";
              entity = e.media_player.office;
              height = 276;
            })
          ])
        ])

        # Player reset button
        (mkSonosBtn {
          name = "Player neu starten";
          icon = "mdi:restart";
          entity = e.media_player.alle;
          height = 88;
          padding = "13px 0px 16px 20px";
          iconColor = "var(--white)";
          nameColor = "var(--white)";
          centered = true;
          tapAction = {
            action = "call-service";
            service = e.script.sonos_reset;
          };
          states = [
            (ha.mkStateStyleFull {
              value = "[[[\n  return entity.state === \"off\";\n]]]\n";
              name = "Player ist aus";
              icon = "mdi:restart-alert";
              bg = "var(--red)";
              nameColor = "var(--black)";
              iconColor = "var(--black)";
            })
          ];
        })

      ];
    }
  ];
}
