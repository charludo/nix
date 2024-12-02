{ lib }:
# Opinionated component library for Home Assistant Lovelace dashboards.
#
# Compose dashboards from these helpers rather than hand-rolling cards.
# When a real card needs styling not covered by a helper, prefer adding
# a new helper (or extending an existing one with a default-keeping
# parameter) over reaching for raw button-card YAML inside a view.
#
# Sections, top to bottom:
#   - Style primitives          mkStyles, mkStyleProp, mkStateStyle…
#   - Layout                    mkHStack, mkVStack, mkGridSection, mkButtonGrid
#   - Conditions                stateIs, stateNot, orConditions, mkConditional
#   - Headers                   mkTitleCard, mkMushTitle, mkBadgeTitleCard, mkHeaderBadge
#   - Buttons                   mkServiceButton, mkActionCard, mkToggleCard, mkRoomToggleCard,
#                               mkPillButton, mkAutoToggleWithSetting, mkInputTextPreset
#   - Status banners            mkStatusBanner
#   - Sliders                   mkBrightnessSlider, mkVolumeSlider, mkSliderCard, mkVolumeSliderCard
#   - Sensors / glance          mkSensorCard, mkGlanceCard, mkTempTile
#   - Graphs                    mkMiniGraph, mkTempHumGraph, mkPowerGraph, mkPowerStack,
#                               mkHistoryGraph, mkPlotlyGraph, mkTempHum/PowerPlotly*
#   - Gauges                    mkGauge, mkUvGauge
#   - Sonos                     mkSonosAlbumArt, mkSpeakerToggle
#   - Navigation                mkNavCard
#   - Maintenance               mkRemainingCard
#   - Picture-elements          mkElementConditional
let
  inherit (lib) optionalAttrs filterAttrs;
in
rec {
  # ---------------------------------------------------------------------------
  # Constants & shared templates
  # ---------------------------------------------------------------------------

  # Battery low threshold (used by both the alerting automation and the
  # status-banner condition on the home view).
  lowBatteryThreshold = 10;

  # Button-card icon template that swaps based on the entity's on/off
  # state. Use for any automation toggle so "running" looks alive and
  # "off" looks dead.
  robotIcon = "[[[ return entity?.state === 'on' ? 'mdi:robot-happy' : 'mdi:robot-dead'; ]]]";

  # ---------------------------------------------------------------------------
  # Style helpers
  # ---------------------------------------------------------------------------

  # { "font-size" = "12px"; color = "red"; }
  # → [{ "font-size" = "12px"; }, { color = "red"; }]
  mkStyleProp = lib.mapAttrsToList (k: v: { ${k} = v; });

  # { card = { height = "84px"; }; icon = { color = "var(--black)"; }; }
  # → { card = [{ height = "84px"; }]; icon = [{ color = "var(--black)"; }]; }
  mkStyles = lib.mapAttrs (_: mkStyleProp);

  # Auto-adds operator: "template" when the match value is a JS template
  # ([[[ ... ]]]) rather than a literal state string.
  _stateOperator =
    value: if lib.hasPrefix "[[[ " value || lib.hasPrefix "[[[" value then "template" else null;

  mkStateStyle =
    value: styles:
    filterAttrs (_: v: v != null) {
      inherit value;
      operator = _stateOperator value;
      styles = mkStyles styles;
    };

  # Like mkStateStyle but also overrides name/icon and accepts shorthand
  # bg/iconColor/nameColor for the common state-recolor pattern.
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
        optionalAttrs (bg != null) { card."background-color" = bg; }
        // optionalAttrs (iconColor != null) { icon.color = iconColor; }
        // optionalAttrs (nameColor != null) { name.color = nameColor; };
    in
    filterAttrs (_: v: v != null) {
      inherit value name icon;
      operator = _stateOperator value;
      styles = mkStyles (convenienceStyles // styles);
    };

  # Shorthand: the two-state "on highlights / off mutes" colouring used by
  # mkToggleCard and inline toggle-style button-cards. Returns the
  # button-card `state` list.
  mkOnOffStates =
    {
      onColor ? "var(--yellow)",
      onIconColor ? "var(--black)",
      onNameColor ? "var(--black)",
      offIconColor ? "var(--contrast20)",
      offNameColor ? "var(--contrast20)",
    }:
    [
      (mkStateStyle "on" {
        card.background = onColor;
        icon.color = onIconColor;
        name.color = onNameColor;
      })
      (mkStateStyle "off" {
        icon.color = offIconColor;
        name.color = offNameColor;
      })
    ];

  # ---------------------------------------------------------------------------
  # Layout
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

  # Wrap a flat list of buttons into rows of <perRow>: returns a list of
  # mkHStacks (caller wraps in grid/vstack). mkHStack itself doesn't have
  # a column count, so this is how we get uniform N-per-row layouts.
  mkButtonGrid =
    perRow: buttons:
    let
      chunk = n: list: if list == [ ] then [ ] else [ (lib.take n list) ] ++ chunk n (lib.drop n list);
    in
    map mkHStack (chunk perRow buttons);

  mkViewHeader = name: {
    card = mkTitleCard name;
    layout = "center";
  };

  # ---------------------------------------------------------------------------
  # Conditions
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
  # Headers
  # ---------------------------------------------------------------------------

  # Large transparent header card, just a name in 32px.
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

  mkMushTitle = title: {
    type = "custom:mushroom-title-card";
    inherit title;
  };

  # Title card with a smaller "badge" card pinned beneath the name. Used
  # for Sonos/Botty/Einkaufsliste/X1C dashboards where we want a live
  # state pill next to the page title.
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

  # Status pill used inside mkBadgeTitleCard's badgeCard: white pill,
  # small monospaced-ish 12px text, optional separated label after the
  # name (e.g. battery %). Tapping opens more-info by default.
  mkHeaderBadge =
    {
      entity,
      name,
      label ? null,
      tapAction ? {
        action = "more-info";
        haptic = "medium";
      },
    }:
    {
      type = "custom:button-card";
      inherit entity name;
      show_icon = false;
      show_label = label != null;
      tap_action = tapAction;
    }
    // optionalAttrs (label != null) { inherit label; }
    // {
      styles =
        (mkStyles (
          {
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
          }
          // optionalAttrs (label != null) {
            label = {
              color = "var(--contrast12)";
            };
          }
        ))
        // {
          grid = mkStyleProp (
            if label != null then
              {
                "grid-template-areas" = ''"n gutter l"'';
                "grid-template-rows" = "min-content";
              }
            else
              {
                "grid-template-areas" = ''"n"'';
                "grid-template-rows" = "min-content";
              }
          );
        };
    };

  # ---------------------------------------------------------------------------
  # Buttons
  # ---------------------------------------------------------------------------

  # Generic "tap → perform-action" button. The workhorse for any
  # service-call surface: TV remote keys, Sonos transport controls,
  # supermarket buttons, X1C speed/control pills.
  #
  # Defaults: 88px tall, 24px corner radius, centred icon + name,
  # contrast2 background, contrast20 foreground. Override `align`,
  # `height`, `padding`, and `radius` for compact (control-pill) or
  # tall (Sonos-large) variants.
  mkServiceButton =
    {
      name,
      icon,
      service ? null,
      serviceData ? null,
      serviceTarget ? null,
      haptic ? "light",

      bg ? "var(--contrast2)",
      fg ? "var(--contrast20)",
      iconColor ? null,
      nameColor ? null,

      height ? 88,
      padding ? null,
      radius ? "24px",
      align ? "center",
      fontSize ? "14px",

      entity ? null,
      state ? null,
      tapAction ? null,
      holdAction ? null,
      confirmation ? null,
    }:
    let
      defaultPadding = if align == "center" then "16px" else "13px 0px 16px 20px";
      effectivePadding = if padding == null then defaultPadding else padding;
      iconC = if iconColor == null then fg else iconColor;
      nameC = if nameColor == null then fg else nameColor;

      effectiveTap =
        if tapAction != null then
          tapAction
        else
          {
            inherit haptic;
            action = "perform-action";
            perform_action = service;
          }
          // optionalAttrs (serviceData != null) { data = serviceData; }
          // optionalAttrs (serviceTarget != null) { target.entity_id = serviceTarget; };
    in
    filterAttrs (_: v: v != null) {
      type = "custom:button-card";
      inherit
        name
        icon
        entity
        state
        ;
      tap_action = effectiveTap;
      hold_action = holdAction;
      confirmation = if confirmation == null then null else { text = confirmation; };
      styles =
        (mkStyles {
          icon = {
            width = "24px";
            color = iconC;
          };
          img_cell = {
            "justify-content" = if align == "center" then "center" else "flex-start";
            "margin-top" = "0px";
          };
          name = {
            "justify-self" = if align == "center" then "center" else "start";
            "font-size" = fontSize;
            "margin-top" = "0px";
            color = nameC;
          };
          card = {
            height = "${toString height}px";
            "border-radius" = radius;
            padding = effectivePadding;
            "background-color" = bg;
          };
        })
        // {
          grid = mkStyleProp { "grid-template-areas" = ''"i" "n"''; };
        };
    };

  # Status-banner-style action card: 84px, rounded, left-aligned, icon
  # over name with an optional label line. Designed for both the
  # full-width conditional banners on the home view (use mkStatusBanner
  # to wrap with the canonical conditional + top-margin) and the
  # Botty row-buttons (tap services nested inside a row).
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
    filterAttrs (_: v: v != null) {
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
      // optionalAttrs (serviceData != null) { data = serviceData; };
      hold_action = holdAction;
      confirmation = if confirmation == null then null else { text = confirmation; };
      styles = mkStyles {
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
        // optionalAttrs (zIndex != null) { "z-index" = zIndex; }
        // extraCardProps;
        label = {
          "justify-self" = "start";
          color = labelColor;
          "font-size" = "12px";
        };
      };
    };

  # Wrap any card in a conditional that fires when the listed conditions
  # hold; default styling adds a 24px top margin and z-index 1 so the
  # banner floats above the grid when it appears mid-page.
  mkStatusBanner =
    args@{
      conditions,
      ...
    }:
    let
      actionArgs = builtins.removeAttrs args [
        "conditions"
        "tapNavigatePath"
      ];
      base = mkActionCard (
        actionArgs
        // {
          zIndex = args.zIndex or 1;
          extraCardProps = (args.extraCardProps or { }) // {
            "margin-top" = args.marginTop or "24px";
          };
        }
      );
      # If a navigation path is given, override tap_action to navigate
      # instead of perform-action.
      withNav =
        if args ? tapNavigatePath then
          base
          // {
            tap_action = {
              action = "navigate";
              navigation_path = args.tapNavigatePath;
              haptic = "medium";
            };
          }
        else
          base;
    in
    mkConditional conditions withNav;

  # Brightness slider embedded in light/fan toggle cards. The fill
  # gradient and thumb colour are state-driven: muted when the parent
  # entity is off, lit when on.
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

  # On/off entity toggle. Tap toggles, hold opens more-info. With
  # withSlider = true, embeds a mkBrightnessSlider beneath the name —
  # use for lights and fans where the slider's entity_id matches the
  # toggle's.
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
      # Optional small text rendered to the right of the name (like the
      # hours indicator on mkAutoToggleWithSetting). Pass a button-card JS
      # template; return '' to hide it for a given state.
      indicator ? null,
      tapAction ? {
        action = "toggle";
        haptic = "medium";
      },
      holdAction ? {
        action = "more-info";
        haptic = "medium";
      },
      confirmation ? null,
      state ? null,
    }:
    let
      hasIndicator = indicator != null;
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
      # The grid only needs overriding when a slider row or a corner
      # indicator is present; otherwise button-card's default stack is fine.
      gridAreas =
        if withSlider && hasIndicator then
          ''"i i" "n ind" "slider slider"''
        else if withSlider then
          ''"i" "n" "slider"''
        else if hasIndicator then
          ''"i i" "n ind"''
        else
          null;
      gridStyle = mkStyleProp {
        "grid-template-areas" = gridAreas;
        "grid-template-columns" = if hasIndicator then "1fr min-content" else "1fr";
        "grid-template-rows" =
          if withSlider then "1fr min-content min-content" else "1fr min-content";
      };
      indicatorStyle = optionalAttrs hasIndicator {
        custom_fields = mkStyles {
          ind = {
            "font-size" = "12px";
            color = "var(--contrast9)";
            "padding-left" = "2px";
            "align-self" = "center";
            "margin-bottom" = "12px";
          };
        };
      };
      styles =
        baseStyles
        // optionalAttrs (gridAreas != null) { grid = gridStyle; }
        // indicatorStyle;
      customFields =
        optionalAttrs withSlider { slider.card = mkBrightnessSlider sliderEntity sliderColorMode; }
        // optionalAttrs hasIndicator { ind = indicator; };
      defaultStates = mkOnOffStates { inherit onColor onIconColor onNameColor; };
    in
    filterAttrs (_: v: v != null) {
      type = "custom:button-card";
      inherit
        entity
        name
        icon
        styles
        ;
      tap_action = tapAction;
      hold_action = holdAction;
      confirmation = if confirmation == null then null else { text = confirmation; };
      state = if state == null then defaultStates else state;
    }
    // optionalAttrs (customFields != { }) { custom_fields = customFields; };

  # Compact toggle pill: tight padding, 20px icon, 12px name. Designed
  # for rows of small period/slot buttons (e.g. watering time slots).
  mkPillButton =
    {
      entity,
      name,
      icon ? "mdi:clock-outline",
      onColor ? "var(--blue)",
      tapAction ? {
        action = "toggle";
        haptic = "selection";
      },
    }:
    {
      type = "custom:button-card";
      inherit entity name icon;
      tap_action = tapAction;
      styles = mkStyles {
        card = {
          background = "var(--contrast2)";
          padding = "8px 4px";
          "--mdc-ripple-press-opacity" = 0;
        };
        img_cell = {
          "justify-self" = "center";
          width = "20px";
        };
        icon = {
          width = "20px";
          height = "20px";
          color = "var(--contrast8)";
        };
        name = {
          "justify-self" = "center";
          "font-size" = "12px";
          margin = "4px 0 0 0";
          color = "var(--contrast8)";
        };
      };
      state = [
        (mkStateStyle "on" {
          card.background = onColor;
          icon.color = "var(--black)";
          name.color = "var(--black)";
        })
        (mkStateStyle "off" {
          icon.color = "var(--contrast20)";
          name.color = "var(--contrast20)";
        })
      ];
    };

  # Room toggle pill for the Botty room-selector row: same on/off
  # palette as mkToggleCard, but 84px tall, left-aligned icon, no
  # slider. Off-state uses contrast2 background with muted label.
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
          icon.color = "var(--black)";
          name.color = "var(--black)";
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
          name.color = "var(--contrast20)";
          label.color = "var(--contrast9)";
        })
      ];
      styles = mkStyles {
        icon.width = "24px";
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

  # Automation toggle that also exposes a numeric setting (input_number)
  # as a slider underneath. The slider's enabled colour tracks the
  # automation's state, not the input_number's, so the slider visually
  # "dims" while the automation is off — the user can still drag it,
  # they just won't see the bright fill.
  mkAutoToggleWithSetting =
    {
      entity,
      name,
      icon ? robotIcon,
      onColor ? "var(--green)",
      settingEntity,
      settingMin ? 1,
      settingMax ? 24,
      settingStep ? 1,
      settingSuffix ? "h",
    }:
    {
      type = "custom:button-card";
      inherit entity name icon;
      tap_action = {
        action = "toggle";
        haptic = "medium";
      };
      hold_action = {
        action = "more-info";
        haptic = "medium";
      };
      custom_fields = {
        uren = "[[[ return states['${settingEntity}'].state + '${settingSuffix}' ]]]";
        slider.card = {
          type = "custom:my-slider-v2";
          entity = settingEntity;
          min = settingMin;
          max = settingMax;
          step = settingStep;
          styles = {
            container = {
              background = "none";
              "border-radius" = "100px";
              overflow = "visible";
            };
            card = {
              height = "16px";
              padding = "0 8px";
              background = "[[[ return states['${entity}']?.state === 'on' ? 'linear-gradient(90deg, rgba(255,255,255,0.3) 0%, rgba(255,255,255,1) 100%)' : 'var(--contrast4)'; ]]]";
            };
            track = {
              overflow = "visible";
              background = "none";
            };
            progress.background = "none";
            thumb = {
              background = "[[[ return states['${entity}']?.state === 'on' ? 'var(--black)' : 'var(--contrast20)'; ]]]";
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
        (mkStyles {
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
          grid = mkStyleProp {
            "grid-template-areas" = ''"i i" "n uren" "slider slider"'';
            "grid-template-columns" = "1fr min-content";
            "grid-template-rows" = "1fr min-content min-content";
          };
          custom_fields = mkStyles {
            uren = {
              "font-size" = "12px";
              color = "var(--contrast9)";
              "padding-left" = "2px";
              "align-self" = "center";
              "margin-bottom" = "12px";
            };
          };
        };
      state = mkOnOffStates { inherit onColor; };
    };

  # ---------------------------------------------------------------------------
  # Colour variants
  # ---------------------------------------------------------------------------
  #
  # Each base component below has a small family of colour-named
  # wrappers that pre-bake the (bg, fg) pair appropriate for the brand
  # palette. Use these — not raw bg/fg overrides — so colour choices
  # stay consistent across views and one rename in lib reskins
  # everywhere at once.
  #
  # Brand palette / readable foreground pairs:
  #   green   → black     (success / play / "on")
  #   yellow  → black     (active / lights / highlight)
  #   blue    → black     (info / water / cool)
  #   orange  → black     (warning / pause)
  #   red     → contrast1 (alarm / stop / muted)
  #   white   → contrast1 (high-contrast neutral)

  # --- Service buttons ------------------------------------------------------

  mkButtonGreen =
    args:
    mkServiceButton (
      {
        bg = "var(--green)";
        fg = "var(--black)";
        haptic = "medium";
      }
      // args
    );
  mkButtonYellow =
    args:
    mkServiceButton (
      {
        bg = "var(--yellow)";
        fg = "var(--black)";
        haptic = "medium";
      }
      // args
    );
  mkButtonBlue =
    args:
    mkServiceButton (
      {
        bg = "var(--blue)";
        fg = "var(--black)";
        haptic = "medium";
      }
      // args
    );
  mkButtonOrange =
    args:
    mkServiceButton (
      {
        bg = "var(--orange)";
        fg = "var(--black)";
        haptic = "medium";
      }
      // args
    );
  mkButtonRed =
    args:
    mkServiceButton (
      {
        bg = "var(--red)";
        fg = "var(--contrast1)";
        haptic = "medium";
      }
      // args
    );
  mkButtonWhite =
    args:
    mkServiceButton (
      {
        bg = "var(--contrast20)";
        fg = "var(--contrast1)";
        haptic = "medium";
      }
      // args
    );

  # --- Action cards ---------------------------------------------------------
  #
  # Same brand palette as the buttons; used for the conditional row
  # buttons (Botty controls) where margin/z-index aren't desired. For
  # the floating-banner case (home view alerts) use the matching
  # mkStatusBanner colour variants further down.

  mkActionCardGreen =
    args:
    mkActionCard (
      {
        cardBg = "var(--green)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--black)";
      }
      // args
    );
  mkActionCardYellow =
    args:
    mkActionCard (
      {
        cardBg = "var(--yellow)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--black)";
      }
      // args
    );
  mkActionCardBlue =
    args:
    mkActionCard (
      {
        cardBg = "var(--blue)";
        iconColor = "var(--contrast1)";
        nameColor = "var(--contrast1)";
        labelColor = "var(--contrast1)";
      }
      // args
    );
  mkActionCardRed =
    args:
    mkActionCard (
      {
        cardBg = "var(--red)";
        iconColor = "var(--contrast1)";
        nameColor = "var(--contrast1)";
        labelColor = "var(--contrast1)";
      }
      // args
    );
  mkActionCardWhite =
    args:
    mkActionCard (
      {
        cardBg = "var(--contrast20)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--contrast7)";
      }
      // args
    );

  # --- Status banners -------------------------------------------------------

  mkInfoBanner =
    args:
    mkStatusBanner (
      {
        cardBg = "var(--blue)";
        iconColor = "var(--contrast1)";
        nameColor = "var(--contrast1)";
        labelColor = "var(--contrast1)";
      }
      // args
    );
  mkSuccessBanner =
    args:
    mkStatusBanner (
      {
        cardBg = "var(--green)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--black)";
      }
      // args
    );
  mkActiveBanner =
    args:
    mkStatusBanner (
      {
        cardBg = "var(--yellow)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--black)";
      }
      // args
    );
  mkWarningBanner =
    args:
    mkStatusBanner (
      {
        cardBg = "var(--orange)";
        iconColor = "var(--black)";
        nameColor = "var(--black)";
        labelColor = "var(--black)";
      }
      // args
    );
  mkAlertBanner =
    args:
    mkStatusBanner (
      {
        cardBg = "var(--red)";
        iconColor = "var(--contrast1)";
        nameColor = "var(--contrast1)";
        labelColor = "var(--contrast1)";
      }
      // args
    );

  # --- Toggle cards ---------------------------------------------------------

  # `mkToggleCard` already defaults onColor to yellow, so mkToggleYellow
  # is just the base. The other variants pre-bake a different onColor.
  mkToggleYellow = mkToggleCard;
  mkToggleGreen = args: mkToggleCard ({ onColor = "var(--green)"; } // args);
  mkToggleBlue = args: mkToggleCard ({ onColor = "var(--blue)"; } // args);
  mkToggleRed = args: mkToggleCard ({ onColor = "var(--red)"; } // args);

  # Automation-toggle variants: bake robotIcon (mdi:robot-happy/dead
  # state swap) into the icon slot so callers just give entity + name.
  mkAutoToggleYellow =
    args:
    mkToggleCard (
      {
        icon = robotIcon;
        onColor = "var(--yellow)";
      }
      // args
    );
  mkAutoToggleGreen =
    args:
    mkToggleCard (
      {
        icon = robotIcon;
        onColor = "var(--green)";
      }
      // args
    );
  mkAutoToggleBlue =
    args:
    mkToggleCard (
      {
        icon = robotIcon;
        onColor = "var(--blue)";
      }
      // args
    );

  # mkAutoToggleWithSetting variants — automation toggle with embedded
  # number slider, parametrised by colour.
  mkAutoToggleWithSettingGreen =
    args: mkAutoToggleWithSetting ({ onColor = "var(--green)"; } // args);
  mkAutoToggleWithSettingYellow =
    args: mkAutoToggleWithSetting ({ onColor = "var(--yellow)"; } // args);
  mkAutoToggleWithSettingBlue = args: mkAutoToggleWithSetting ({ onColor = "var(--blue)"; } // args);

  # --- Pill buttons ---------------------------------------------------------

  # `mkPillButton` defaults onColor to blue; alias kept for symmetry.
  mkPillBlue = mkPillButton;
  mkPillGreen = args: mkPillButton ({ onColor = "var(--green)"; } // args);
  mkPillYellow = args: mkPillButton ({ onColor = "var(--yellow)"; } // args);

  # ---------------------------------------------------------------------------

  # Tappable preset that fills an input_text helper (used by the
  # broadcast form's quick-pick buttons).
  mkInputTextPreset =
    {
      name,
      icon,
      target,
      value,
    }:
    mkServiceButton {
      inherit name icon;
      service = "input_text.set_value";
      serviceData = {
        entity_id = target;
        inherit value;
      };
      haptic = "selection";
      bg = "var(--contrast2)";
      fg = "var(--contrast20)";
      align = "start";
      padding = "16px";
    };

  # ---------------------------------------------------------------------------
  # Sliders & slider cards
  # ---------------------------------------------------------------------------

  # Vertical Sonos volume slider with the brand saturation gradient.
  mkVolumeSlider =
    {
      entity,
      height ? 200,
    }:
    {
      type = "custom:my-slider-v2";
      inherit entity;
      attribute = "volume_level";
      vertical = true;
      styles = {
        container = mkStyleProp {
          "border-radius" = "100px";
          overflow = "visible";
          background = "none";
        };
        card = mkStyleProp {
          height = "${toString height}px";
          padding = "0 20px";
          background = "var(--saturation)";
        };
        track = mkStyleProp {
          overflow = "visible";
          background = "none";
        };
        progress = mkStyleProp { background = "none"; };
        thumb = mkStyleProp {
          background = "var(--black)";
          top = "-36px";
          height = "36px";
          width = "36px";
          "border-radius" = "100px";
          left = "-18px";
        };
      };
    };

  # Slider wrapped in a named button-card frame (name above, slider
  # beneath).
  mkSliderCard =
    {
      name,
      slider,
    }:
    {
      type = "custom:button-card";
      inherit name;
      custom_fields.slider.card = slider;
      styles =
        (mkStyles {
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
          grid = mkStyleProp {
            "grid-template-areas" = ''"n" "slider"'';
            "grid-template-columns" = "1fr";
            "grid-template-rows" = "1fr auto";
            "align-items" = "center";
            "justify-items" = "center";
          };
        };
    };

  # Convenience wrapper for the common case: named card containing a
  # volume slider.
  mkVolumeSliderCard =
    {
      name,
      entity,
      height ? 200,
    }:
    mkSliderCard {
      inherit name;
      slider = mkVolumeSlider { inherit entity height; };
    };

  # ---------------------------------------------------------------------------
  # Sensors & glance
  # ---------------------------------------------------------------------------

  # Opinionated sensor card (HA built-in `type = sensor`). Defaults:
  # line graph, detail 2. Filters out nulls so callers can pass `null`
  # for unused fields.
  mkSensorCard =
    {
      entity,
      name,
      icon ? null,
      unit ? null,
      graph ? "line",
      detail ? 2,
      hours_to_show ? null,
      gridOptions ? null,
      cardModStyle ? null,
    }:
    filterAttrs (_: v: v != null) {
      type = "sensor";
      inherit
        entity
        name
        icon
        unit
        graph
        detail
        hours_to_show
        ;
      grid_options = gridOptions;
      card_mod = if cardModStyle == null then null else { style = cardModStyle; };
    };

  # Glance card with sensible defaults; entities can be passed as either
  # strings (entity ids) or attrsets ({ entity, name? }).
  mkGlanceCard =
    {
      entities,
      title ? null,
      columns ? null,
      showName ? null,
      showIcon ? null,
      showState ? null,
    }:
    filterAttrs (_: v: v != null) {
      type = "glance";
      inherit title columns;
      show_name = showName;
      show_icon = showIcon;
      show_state = showState;
      entities = map (e: if builtins.isString e then { entity = e; } else e) entities;
    };

  # Temperature swipe-tile (the carousel on the home view).
  mkTempTile = name: entity: {
    type = "sensor";
    inherit entity name;
    hours_to_show = 24;
    detail = 1;
    graph = "line";
    icon = "none";
    card_mod.class = "graph";
  };

  # ---------------------------------------------------------------------------
  # Graphs
  # ---------------------------------------------------------------------------

  mkHistoryGraph = entities: {
    type = "history-graph";
    inherit entities;
    hours_to_show = 24;
  };

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

  # Smart-plug stack: title + plain-switch toggle + 24h history graph +
  # power/current mini-graph. The history entity defaults to the switch
  # but can be overridden (e.g. for the server rack where we graph the
  # power_on_state select instead).
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
        (mkPlainSwitchToggle switchEntity)
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

  # Mushroom-light-card configured as a plain switch toggle (no light-
  # colour ramp, no brightness control). Used inside mkPowerStack for
  # the smart-plug on/off.
  mkPlainSwitchToggle = entity: {
    type = "custom:mushroom-light-card";
    inherit entity;
    icon = "mdi:toggle-switch-outline";
    use_light_color = false;
    show_brightness_control = false;
  };

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
        optionalAttrs (yRange != null) { yaxis.range = yRange; }
        // optionalAttrs (y2Range != null) { yaxis2.range = y2Range; };
    };

  # Standard 3-trace plotly pattern: humidity line, temperature today,
  # temperature yesterday (dotted).
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

  # 3-trace plotly pattern for a power plug: current (A) + power today
  # + power yesterday.
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

  mkTempHumPlot =
    {
      name,
      tempEntity,
      humEntity,
      yRange ? [
        0
        100
      ],
      y2Range ? [
        16
        28
      ],
    }:
    mkPlotlyGraph {
      title = name;
      entities = mkTempHumPlotlyEntities humEntity tempEntity;
      inherit yRange y2Range;
    };

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
  # Gauges
  # ---------------------------------------------------------------------------

  # Gauge with consistent layout (title pinned top-left via the `gauge`
  # card_mod class defined in theme.nix).
  mkGauge =
    {
      name,
      entity,
      min ? 0,
      max,
      needle ? true,
      segments,
      extraCardModStyle ? null,
    }:
    {
      type = "gauge";
      inherit
        entity
        name
        min
        max
        needle
        segments
        ;
      card_mod = {
        class = "gauge";
      }
      // optionalAttrs (extraCardModStyle != null) { style = extraCardModStyle; };
    };

  # Pre-configured UV-index gauge using the standard WHO colour bands.
  mkUvGauge =
    entity:
    mkGauge {
      inherit entity;
      name = "UV-Index";
      min = 0;
      max = 13;
      segments = [
        {
          from = 0;
          color = "#4eb84e";
          label = "niedrig";
        }
        {
          from = 2.5;
          color = "#f6c700";
          label = "mittel";
        }
        {
          from = 5.5;
          color = "#f08000";
          label = "hoch";
        }
        {
          from = 7.5;
          color = "#d6001c";
          label = "sehr hoch";
        }
        {
          from = 10.5;
          color = "#7a2bb5";
          label = "extrem";
        }
      ];
      extraCardModStyle."ha-gauge"."$" = ''
        .value-text {
          font-size: var(--ha-font-size-xs) !important;
        }
      '';
    };

  # Linear-band thermometer gauge: blue/green/yellow/red segments at
  # 0%/40%/70%/90% of `max`. Used by the X1C view for nozzle/bed/chamber
  # temperatures.
  mkThermometerGauge =
    {
      name,
      entity,
      max,
    }:
    mkGauge {
      inherit name entity max;
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
    };

  # ---------------------------------------------------------------------------
  # Sonos
  # ---------------------------------------------------------------------------

  # Album-art card with a blurred copy of the cover as the background
  # and a small foreground tile with title + artist. Tap navigates to
  # Music Assistant. The blur and the foreground share the same
  # entity_picture so they always stay in sync.
  mkSonosAlbumArt = entity: {
    type = "custom:button-card";
    inherit entity;
    show_entity_picture = true;
    entity_picture = "[[[ return states['${entity}'].attributes.entity_picture ]]]";
    show_name = false;
    tap_action = {
      action = "navigate";
      navigation_path = "/music_assistant";
    };
    custom_fields.info.card = {
      type = "custom:button-card";
      inherit entity;
      show_entity_picture = true;
      entity_picture = "[[[ return states['${entity}'].attributes.entity_picture ]]]";
      tap_action = {
        action = "navigate";
        navigation_path = "/music_assistant";
      };
      name = ''
        [[[
          if (states['${entity}'].attributes.media_title)
            return states['${entity}'].attributes.media_title;
          else
            return "-";
        ]]]
      '';
      label = ''
        [[[
          if (states['${entity}'].attributes.media_artist)
            return states['${entity}'].attributes.media_artist;
          else
            return "";
        ]]]
      '';
      show_label = true;
      show_icon = true;
      styles =
        (mkStyles {
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
          grid = mkStyleProp {
            "grid-template-areas" = ''"i gutter n" "i gutter l"'';
            "grid-template-columns" = "min-content 24px 1fr";
            "grid-template-rows" = "min-content";
          };
          custom_fields = mkStyles {
            image = {
              "--mdc-ripple-press-opacity" = 0.5;
            };
          };
        };
    };
    styles =
      (mkStyles {
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
        grid = mkStyleProp {
          "grid-template-areas" = ''"info"'';
          "grid-template-columns" = "1fr";
          "grid-template-rows" = "min-content";
        };
      };
  };

  # Speaker toggle (mute/unmute) — service-button with a state-driven
  # red+struck-through "muted" variant.
  mkSpeakerToggle =
    {
      name,
      entity,
      service,
    }:
    mkServiceButton {
      inherit name entity service;
      icon = "mdi:volume-high";
      height = 89;
      align = "start";
      padding = "13px 0px 16px 20px";
      haptic = "medium";
      fg = "var(--white)";
      state = [
        (mkStateStyleFull {
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

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  # Dashboard navigation link (mushroom-entity-card pinned to sun.sun
  # since it always exists; we don't render its state).
  mkNavCard = name: path: {
    type = "custom:mushroom-entity-card";
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
  # Maintenance
  # ---------------------------------------------------------------------------

  # Brush/filter remaining counter card (Botty maintenance). Shows
  # remaining hours next to a "h" suffix; tap with confirmation calls
  # the reset script.
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

  # ---------------------------------------------------------------------------
  # Picture-elements
  # ---------------------------------------------------------------------------

  # picture-elements has its own conditional element type, which takes
  # `elements: [...]` instead of the Lovelace `conditional` card's
  # singular `card:`. mkConditional emits the latter, so this helper
  # exists for the picture-elements path.
  mkElementConditional = conditions: elements: {
    type = "conditional";
    inherit conditions elements;
  };
}
