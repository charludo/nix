{ lib }:
rec {
  # Single source of truth for the "battery is low" threshold, used by
  # both the alert automation and the dashboard warning card so the
  # number doesn't drift between them.
  lowBatteryThreshold = 10;

  # ---------------------------------------------------------------------------
  # Slug helper (shared with areas and devices)
  # ---------------------------------------------------------------------------

  # Mirrors Home Assistant's `homeassistant.util.slugify`:
  #   1. transliterate German umlauts → ASCII
  #   2. lowercase
  #   3. replace any run of non-[a-z0-9] with a single "_"
  #   4. strip leading/trailing "_"
  # Keep this in sync with the `slugify()` in zha-reconciler/zha_reconciler.py
  # so dashboard entity_ids and the entity_ids the reconciler renames to match.
  mkSlug =
    name:
    let
      transliterated =
        lib.replaceStrings
          [ "ä" "ö" "ü" "Ä" "Ö" "Ü" "ß" ]
          [ "a" "o" "u" "a" "o" "u" "ss" ]
          name;
      lowered = lib.toLower transliterated;
      pieces = builtins.filter (p: builtins.isString p && p != "") (
        builtins.split "[^a-z0-9]+" lowered
      );
    in
    lib.concatStringsSep "_" pieces;

  # ---------------------------------------------------------------------------
  # Style helpers
  # ---------------------------------------------------------------------------

  # { "font-size" = "12px"; color = "red"; }
  # → [{ "font-size" = "12px"; }, { color = "red"; }]
  mkStyleProp = lib.mapAttrsToList (k: v: { ${k} = v; });

  # { card = { height = "84px"; }; icon = { color = "var(--black)"; }; }
  # → { card = [{ height = "84px"; }]; icon = [{ color = "var(--black)"; }]; }
  mkStyles = lib.mapAttrs (_: mkStyleProp);

  # ---------------------------------------------------------------------------
  # Condition builders (for conditional cards)
  # ---------------------------------------------------------------------------

  stateIs = entity: state: {
    condition = "state";
    inherit entity state;
  };
  stateNot = entity: state_not: {
    condition = "state";
    inherit entity state_not;
  };
  orConditions = conditions: {
    condition = "or";
    inherit conditions;
  };

  mkConditional = conditions: card: {
    type = "conditional";
    inherit conditions card;
  };

  # ---------------------------------------------------------------------------
  # State-based style helpers (for button-card `state` list)
  # ---------------------------------------------------------------------------

  # Auto-adds operator: "template" when value is a JS template string
  _stateOperator =
    value: if lib.hasPrefix "[[[ " value || lib.hasPrefix "[[[" value then "template" else null;

  mkStateStyle =
    value: styles:
    lib.filterAttrs (_: v: v != null) {
      inherit value;
      operator = _stateOperator value;
      styles = mkStyles styles;
    };

  # Like mkStateStyle but also overrides name/icon fields.
  # bg/iconColor/nameColor are convenience shorthands for the common style pattern;
  # styles (optional) merges on top for anything else.
  mkStateStyleFull =
    {
      value,
      styles ? { },
      name ? null,
      icon ? null,
      bg ? null,
      iconColor ? null,
      nameColor ? null,
    }:
    let
      convenienceStyles =
        lib.optionalAttrs (bg != null) { card."background-color" = bg; }
        // lib.optionalAttrs (iconColor != null) { icon.color = iconColor; }
        // lib.optionalAttrs (nameColor != null) { name.color = nameColor; };
    in
    lib.filterAttrs (_: v: v != null) {
      inherit value name icon;
      operator = _stateOperator value;
      styles = mkStyles (convenienceStyles // styles);
    };

  # ---------------------------------------------------------------------------
  # Mushroom card helpers
  # ---------------------------------------------------------------------------

  mkMushTitle = title: {
    type = "custom:mushroom-title-card";
    inherit title;
  };

  # mushroom-light-card used to toggle a plain switch
  mkMushToggle = entity: {
    type = "custom:mushroom-light-card";
    inherit entity;
    icon = "mdi:toggle-switch-outline";
    use_light_color = false;
    show_brightness_control = false;
  };

  # ---------------------------------------------------------------------------
  # History / graph helpers
  # ---------------------------------------------------------------------------

  mkHistoryGraph = entities: {
    type = "history-graph";
    inherit entities;
    hours_to_show = 24;
  };

  # temp + humidity mini-graph-card (secondary axis = humidity)
  mkTempHumGraph =
    {
      name,
      tempEntity,
      humEntity,
      lowerBound ? "~16",
      upperBound ? "~28",
    }:
    mkMiniGraph {
      inherit name;
      entities = [
        {
          entity = tempEntity;
          show_state = true;
          state_adaptive_color = true;
        }
        {
          entity = humEntity;
          show_state = true;
          y_axis = "secondary";
          state_adaptive_color = true;
        }
      ];
      lower_bound = lowerBound;
      upper_bound = upperBound;
      lower_bound_secondary = 0;
      upper_bound_secondary = 100;
    };

  # power + current mini-graph-card (secondary axis = current)
  mkPowerGraph =
    {
      name ? "Verbrauch",
      powerEntity,
      currentEntity,
      upperCurrent ? 1,
    }:
    mkMiniGraph {
      inherit name;
      entities = [
        {
          entity = powerEntity;
          show_state = true;
          state_adaptive_color = true;
        }
        {
          entity = currentEntity;
          show_state = true;
          y_axis = "secondary";
          state_adaptive_color = true;
        }
      ];
      lower_bound = "~0";
      upper_bound = "~120";
      lower_bound_secondary = 0;
      upper_bound_secondary = upperCurrent;
    };

  # Full vertical-stack for a smart plug: title + toggle + history + power graph
  mkPowerStack =
    {
      title,
      switchEntity,
      historyEntity ? switchEntity,
      historyExtra ? { },
      powerEntity,
      currentEntity,
      upperCurrent ? 1,
      extraCards ? [ ],
    }:
    {
      type = "vertical-stack";
      cards = [
        (mkMushTitle title)
        (mkMushToggle switchEntity)
        (
          {
            type = "history-graph";
            entities = [
              {
                entity = historyEntity;
                name = " ";
              }
            ];
            hours_to_show = 24;
          }
          // historyExtra
        )
        (mkPowerGraph { inherit powerEntity currentEntity upperCurrent; })
      ]
      ++ extraCards;
    };

  # ---------------------------------------------------------------------------
  # Plotly graph helpers
  # ---------------------------------------------------------------------------

  mkPlotlyGraph =
    {
      title,
      entities,
      yRange ? null,
      y2Range ? null,
    }:
    {
      type = "custom:plotly-graph";
      inherit title entities;
      hours_to_show = 24;
      refresh_interval = 10;
      config.scrollZoom = false;
      layout =
        lib.optionalAttrs (yRange != null) { yaxis.range = yRange; }
        // lib.optionalAttrs (y2Range != null) { yaxis2.range = y2Range; };
    };

  # Convenience wrapper: plotly card for a single area's temp+humidity
  mkTempHumPlot =
    {
      name,
      tempEntity,
      humEntity,
    }:
    mkPlotlyGraph {
      title = name;
      entities = mkTempHumPlotlyEntities humEntity tempEntity;
      yRange = [
        0
        100
      ];
      y2Range = [
        16
        28
      ];
    };

  # Standard 3-trace plotly pattern: humidity line, temperature (today + yesterday)
  mkTempHumPlotlyEntities = humEntity: tempEntity: [
    {
      entity = humEntity;
      name = "Luftfeuchtigkeit";
      line.width = 2;
    }
    {
      entity = tempEntity;
      name = "Temperatur";
      line = {
        color = "orange";
        width = 3;
      };
    }
    {
      entity = tempEntity;
      name = "Gestern";
      time_offset = "1d";
      line = {
        color = "orange";
        width = 1;
        dash = "dot";
      };
    }
  ];

  # 3-trace plotly pattern for a power plug: current (A) + power today + yesterday
  mkPowerPlotlyEntities = powerEntity: currentEntity: [
    {
      entity = currentEntity;
      name = "Stromstärke";
      yaxis = "y2";
      line.width = 2;
    }
    {
      entity = powerEntity;
      name = "Leistung";
      line = {
        color = "orange";
        width = 3;
      };
    }
    {
      entity = powerEntity;
      name = "Gestern";
      time_offset = "1d";
      line = {
        color = "orange";
        width = 1;
        dash = "dot";
      };
    }
  ];

  # Convenience wrapper: plotly card for a single device's power+current
  mkPowerPlot =
    {
      name,
      powerEntity,
      currentEntity,
    }:
    mkPlotlyGraph {
      title = name;
      entities = mkPowerPlotlyEntities powerEntity currentEntity;
    };

  # ---------------------------------------------------------------------------
  # Stacks and sections
  # ---------------------------------------------------------------------------

  mkHStack = cards: {
    type = "horizontal-stack";
    inherit cards;
  };
  mkVStack = cards: {
    type = "vertical-stack";
    inherit cards;
  };
  mkGridSection = cards: {
    type = "grid";
    inherit cards;
  };
  mkViewHeader = name: {
    card = mkTitleCard name;
    layout = "center";
  };

  # ---------------------------------------------------------------------------
  # Simple card builders
  # ---------------------------------------------------------------------------

  mkTitleCard = name: {
    type = "custom:button-card";
    inherit name;
    styles = mkStyles {
      card = {
        background = "none";
        padding = "16px 0";
        "--mdc-ripple-press-opacity" = 0;
      };
      name = {
        "font-size" = "32px";
        color = "var(--contrast20)";
      };
    };
  };

  # Sensor tile for the temperature swipe carousel
  mkTempTile = name: entity: {
    type = "sensor";
    inherit entity name;
    hours_to_show = 24;
    detail = 1;
    graph = "line";
    icon = "none";
    card_mod.class = "graph";
  };

  # custom:mini-graph-card
  mkMiniGraph =
    {
      name,
      entities,
      height ? 180,
      group_by ? "hour",
      lower_bound ? "~0",
      upper_bound ? "~30",
      lower_bound_secondary ? 0,
      upper_bound_secondary ? 100,
      extraConfig ? { },
    }:
    {
      type = "custom:mini-graph-card";
      inherit
        name
        entities
        height
        group_by
        lower_bound
        upper_bound
        lower_bound_secondary
        upper_bound_secondary
        ;
      font_size = 80;
      hour24 = true;
      show.legend = false;
    }
    // extraConfig;

  # Dashboard navigation link (uses mushroom-entity-card as a nav button)
  mkNavCard = name: path: {
    type = "custom:mushroom-entity-card";
    # mushroom-entity-card requires *some* entity; we don't render its
    # state, so just pin to sun.sun which the suns module always defines.
    entity = "sun.sun";
    inherit name;
    fill_container = true;
    secondary_info = "none";
    icon = "mdi:arrow-right";
    icon_type = "icon";
    icon_color = "disabled";
    tap_action = {
      action = "navigate";
      navigation_path = path;
    };
  };

  # ---------------------------------------------------------------------------
  # Action card (84px, rounded, left-aligned) — used for conditional status
  # banners and botty control buttons
  # ---------------------------------------------------------------------------

  mkActionCardStyles =
    {
      cardBg ? "var(--contrast2)",
      iconColor ? "var(--contrast8)",
      nameColor ? "var(--contrast8)",
      labelColor ? "var(--contrast5)",
      zIndex ? null,
      extraCardProps ? { },
    }:
    mkStyles {
      icon = {
        width = "24px";
        color = iconColor;
      };
      img_cell = {
        "justify-content" = "flex-start";
        "margin-top" = "-4px";
      };
      name = {
        "justify-self" = "start";
        color = nameColor;
        "font-size" = "12px";
        "margin-bottom" = "0px";
      };
      card = {
        height = "84px";
        "background-color" = cardBg;
        "box-shadow" = "none";
        "border-radius" = "24px";
        padding = "12px 0 12px 14px";
      }
      // lib.optionalAttrs (zIndex != null) { "z-index" = zIndex; }
      // extraCardProps;
      label = {
        "justify-self" = "start";
        color = labelColor;
        "font-size" = "12px";
      };
    };

  # button-card calling a service via perform-action, styled with
  # mkActionCardStyles. Optional fields are dropped from the result.
  mkActionCard =
    {
      name,
      icon,
      service,
      label ? null,
      entity ? null,
      state ? null,
      serviceData ? null,
      holdAction ? null,
      confirmation ? null,
      haptic ? "success",
      cardBg ? "var(--contrast2)",
      iconColor ? "var(--contrast8)",
      nameColor ? "var(--contrast8)",
      labelColor ? "var(--contrast5)",
      zIndex ? null,
      extraCardProps ? { },
    }:
    lib.filterAttrs (_: v: v != null) {
      type = "custom:button-card";
      inherit
        name
        icon
        label
        entity
        state
        ;
      show_label = if label != null then true else null;
      tap_action = {
        inherit haptic;
        action = "perform-action";
        perform_action = service;
      }
      // lib.optionalAttrs (serviceData != null) { data = serviceData; };
      hold_action = holdAction;
      confirmation = if confirmation == null then null else { text = confirmation; };
      styles = mkActionCardStyles {
        inherit
          cardBg
          iconColor
          nameColor
          labelColor
          zIndex
          extraCardProps
          ;
      };
    };

  # ---------------------------------------------------------------------------
  # Toggle card (light / fan / switch)
  # off state: contrast2 background, muted colours
  # on state: coloured background, black text
  # ---------------------------------------------------------------------------

  # The brightness slider embedded in light/fan toggle cards
  mkBrightnessSlider = entity: colorMode: {
    type = "custom:my-slider-v2";
    inherit entity colorMode;
    styles = {
      container = {
        background = "none";
        "border-radius" = "100px";
        overflow = "visible";
      };
      card = {
        height = "16px";
        padding = "0 8px";
        background = "[[[ return entity?.state === 'on' ? 'linear-gradient(90deg, rgba(255,255,255,0.3) 0%, rgba(255,255,255,1) 100%)' : 'var(--contrast4)'; ]]]";
      };
      track = {
        overflow = "visible";
        background = "none";
      };
      progress = {
        background = "none";
      };
      thumb = {
        background = "[[[ if (!entity || entity.state === 'off') return 'var(--contrast20)'; if (entity.state === 'on') return 'var(--black)'; return 'var(--contrast8)'; ]]]";
        top = "2px";
        right = "-6px";
        height = "12px";
        width = "12px";
        "border-radius" = "100px";
      };
    };
  };

  mkToggleCard =
    {
      entity,
      name,
      icon ? "[[[ return entity?.attributes?.icon ]]]",
      onColor ? "var(--yellow)",
      onIconColor ? "var(--black)",
      onNameColor ? "var(--black)",
      withSlider ? false,
      sliderEntity ? entity,
      sliderColorMode ? "brightness",
      tapAction ? {
        action = "toggle";
        haptic = "medium";
      },
      holdAction ? {
        action = "more-info";
        haptic = "medium";
      },
    }:
    let
      baseStyles = mkStyles {
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
      gridStyle = mkStyleProp {
        "grid-template-areas" = ''"i" "n" "slider"'';
        "grid-template-columns" = "1fr";
        "grid-template-rows" = "1fr min-content min-content";
      };
      styles = if withSlider then baseStyles // { grid = gridStyle; } else baseStyles;
      sliderField = lib.optionalAttrs withSlider {
        custom_fields.slider.card = mkBrightnessSlider sliderEntity sliderColorMode;
      };
    in
    {
      type = "custom:button-card";
      inherit entity name icon;
      tap_action = tapAction;
      hold_action = holdAction;
      inherit styles;
      state = [
        (mkStateStyle "on" {
          card = {
            background = onColor;
          };
          icon = {
            color = onIconColor;
          };
          name = {
            color = onNameColor;
          };
        })
        (mkStateStyle "off" {
          icon = {
            color = "var(--contrast20)";
          };
          name = {
            color = "var(--contrast20)";
          };
        })
      ];
    }
    // sliderField;

  # ---------------------------------------------------------------------------
  # Room toggle card (Botty room selection)
  # Same on/off pattern but different base style (no slider, different padding)
  # ---------------------------------------------------------------------------

  mkRoomToggleCard =
    {
      entity,
      name,
      icon,
      onColor ? "var(--yellow)",
    }:
    {
      type = "custom:button-card";
      inherit entity name icon;
      show_label = true;
      tap_action = {
        action = "toggle";
        haptic = "medium";
      };
      state = [
        (mkStateStyle "on" {
          card = {
            "background-color" = onColor;
            "box-shadow" = "none";
          };
          icon = {
            color = "var(--black)";
          };
          name = {
            color = "var(--black)";
          };
          label = {
            color = "var(--black)";
            opacity = "0.5";
          };
        })
        (mkStateStyle "off" {
          card = {
            background = "var(--contrast2)";
            "box-shadow" = "none";
          };
          icon = {
            width = "24px";
            color = "var(--contrast20)";
          };
          name = {
            color = "var(--contrast20)";
          };
          label = {
            color = "var(--contrast9)";
          };
        })
      ];
      styles = mkStyles {
        icon = {
          width = "24px";
        };
        img_cell = {
          "justify-content" = "flex-start";
          "margin-top" = "-4px";
        };
        name = {
          "justify-self" = "start";
          "font-size" = "12px";
          "margin-bottom" = "0px";
        };
        card = {
          height = "84px";
          "border-radius" = "24px";
          padding = "12px 0 12px 14px";
          "box-sizing" = "border-box";
          "--mdc-ripple-press-opacity" = 0;
        };
        label = {
          "justify-self" = "start";
          "font-size" = "12px";
        };
      };
    };

  # ---------------------------------------------------------------------------
  # Title card with status badge (used for Botty and Sonos section headings)
  # ---------------------------------------------------------------------------

  mkBadgeTitleCard =
    {
      name,
      badgeCard,
      badgeMargin ? "16px auto 0 auto",
    }:
    {
      type = "custom:button-card";
      inherit name;
      custom_fields.badge.card = badgeCard;
      styles =
        (mkStyles {
          card = {
            background = "none";
            padding = "16px 0";
            "--mdc-ripple-press-opacity" = 0;
          };
          name = {
            "font-size" = "32px";
            color = "var(--contrast20)";
          };
        })
        // {
          grid = mkStyleProp { "grid-template-areas" = ''"n" "badge"''; };
          custom_fields = mkStyles {
            badge = {
              margin = badgeMargin;
              "--mdc-ripple-press-opacity" = 0.5;
            };
          };
        };
    };

  # ---------------------------------------------------------------------------
  # Brush/maintenance remaining counter card (Botty)
  # ---------------------------------------------------------------------------

  mkRemainingCard =
    {
      sensorTemplate,
      label,
      resetScript,
      resetConfirmation,
    }:
    {
      type = "custom:button-card";
      name = "[[[return Math.round(states[\"${sensorTemplate}\"].state / 60 / 60)]]]";
      inherit label;
      show_label = true;
      custom_fields.eenheid = "&nbsp;h";
      tap_action = {
        action = "call-service";
        haptic = "medium";
        service = resetScript;
      };
      confirmation.text = resetConfirmation;
      styles =
        (mkStyles {
          name = {
            "font-size" = "32px";
            color = "var(--contrast20)";
          };
          card = {
            height = "80px";
            "border-radius" = "24px";
            padding = "30px 0 6px 16px";
            "box-sizing" = "border-box";
            background = "var(--contrast2)";
            "box-shadow" = "none";
          };
          label = {
            "justify-self" = "start";
            "font-size" = "12px";
            color = "var(--contrast20)";
            "margin-top" = "-2px";
          };
        })
        // {
          grid = mkStyleProp {
            "grid-template-areas" = ''"n eenheid" "l l"'';
            "grid-template-columns" = "min-content min-content";
          };
          custom_fields = mkStyles {
            eenheid = {
              "font-size" = "12px";
              color = "var(--contrast9)";
              "margin-bottom" = "6px";
              "padding-left" = "2px";
            };
          };
        };
    };

  robotIcon = "[[[ return entity?.state === 'on' ? 'mdi:robot-happy' : 'mdi:robot-dead'; ]]]";
}
