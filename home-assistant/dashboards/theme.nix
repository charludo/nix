# Rounded theme — dark mode only
{ }:
let
  colors = {
    contrast1 = "#000000";
    contrast2 = "#111318";
    contrast3 = "#171A21";
    contrast4 = "#1C1F27";
    contrast5 = "#262A35";
    contrast6 = "#353946";
    contrast7 = "#434856";
    contrast8 = "#535865";
    contrast9 = "#636774";
    contrast10 = "#777A83";
    contrast11 = "#898C94";
    contrast12 = "#969AA6";
    contrast13 = "#A4A9B6";
    contrast14 = "#B3B8C6";
    contrast15 = "#C3C8D5";
    contrast16 = "#D4D8E2";
    contrast17 = "#E1E5EF";
    contrast18 = "#EAEDF6";
    contrast19 = "#F4F6FB";
    contrast20 = "#FFFFFF";

    black = "#000000";
    white = "#FFFFFF";

    # Brand colors
    blue = "rgb(144, 191, 255)";
    green = "rgb(206, 245, 149)";
    yellow = "rgb(255, 218, 120)";
    orange = "rgb(255, 181, 129)";
    red = "rgb(255, 145, 138)";
    purple = "rgb(239, 177, 255)";

    # Comma-separated RGB triplets — same hues as the brand colours
    # above. Mushroom cards (and a few HA internals) read these via
    # `var(--rgb-<name>)` and assemble `rgb(<triplet>)` themselves, so
    # writing `icon_color = "yellow"` on a mushroom card resolves to
    # our brand yellow instead of mushroom's default.
    rgb-blue = "144, 191, 255";
    rgb-green = "206, 245, 149";
    rgb-yellow = "255, 218, 120";
    rgb-orange = "255, 181, 129";
    rgb-red = "255, 145, 138";
    rgb-purple = "239, 177, 255";
    rgb-white = "255, 255, 255";
    rgb-black = "0, 0, 0";
    rgb-grey = "119, 122, 131"; # = contrast10
    rgb-disabled = "28, 31, 39"; # = contrast4

    # Tints (alpha 0.15)
    blue-tint = "rgba(144, 191, 255, 0.15)";
    green-tint = "rgba(206, 245, 149, 0.15)";
    yellow-tint = "rgba(255, 218, 120, 0.15)";
    orange-tint = "rgba(255, 181, 129, 0.15)";
    red-tint = "rgba(255, 145, 138, 0.15)";
    purple-tint = "rgba(239, 177, 255, 0.15)";

    # Gradients
    brightness = "linear-gradient(90deg, rgba(232,176,29,0.4) 0%, rgba(255,211,94,1) 100%)";
    brightness-tint = "linear-gradient(90deg, rgba(232,176,29,0.06) 0%, rgba(255,211,94,0.15) 100%)";
    temperature = "linear-gradient(90deg, rgba(177,197,255,1) 0%, rgba(255,175,131,1) 100%)";
    temperature-tint = "linear-gradient(90deg, rgba(177,197,255,0.15) 0%, rgba(255,175,131,0.15) 100%)";
    saturation = "linear-gradient(0deg, rgba(25,32,42,1) 0%, rgba(144,191,255,1) 100%)";
  };
in
{
  # Typography
  primary-font-family = "Quicksand";
  secondary-font-family = "Quicksand";
  paper-font-common-base_-_font-family = "Quicksand";
  paper-font-common-code_-_font-family = "Quicksand";
  paper-font-body1_-_font-family = "Quicksand";
  paper-font-subhead_-_font-family = "Quicksand";
  paper-font-headline_-_font-family = "Quicksand";
  paper-font-caption_-_font-family = "Quicksand";
  paper-font-title_-_font-family = "Quicksand";
  ha-card-header-font-family = "Quicksand";

  # Spacing and shape
  horizontal-stack-card-margin = "0px 8px";
  vertical-stack-card-margin = "8px 0px";
  grid-card-gap = "16px";
  ha-card-border-width = "0px";
  ha-card-border-radius = "24px";
  masonry-view-card-margin = "40px 20px";

  # HA semantic color mappings
  primary-color = colors.blue;
  accent-color = colors.blue;
  primary-background-color = colors.contrast1;
  secondary-background-color = colors.contrast2;
  divider-color = colors.contrast3;

  primary-text-color = colors.contrast20;
  secondary-text-color = colors.contrast9;
  text-primary-color = colors.contrast20;
  disabled-text-color = colors.contrast6;
  text-accent-color = colors.contrast1;

  app-header-background-color = colors.contrast1;
  app-header-text-color = colors.contrast20;
  app-header-selection-bar-color = "transparent";
  app-header-edit-background-color = colors.contrast2;
  app-header-edit-text-color = colors.contrast20;

  card-background-color = colors.contrast2;
  ha-card-background = colors.contrast2;
  ha-card-border-color = colors.contrast6;
  paper-listbox-background-color = colors.contrast3;

  state-unavailable-color = colors.contrast6;
  state-light-off-color = colors.contrast10;
  state-light-on-color = colors.yellow;

  sidebar-icon-color = colors.contrast6;
  sidebar-text-color = colors.contrast20;
  sidebar-background-color = colors.contrast2;
  sidebar-selected-icon-color = colors.blue;
  sidebar-selected-text-color = colors.blue;

  paper-item-icon-color = colors.contrast9;
  mdc-button-outline-color = colors.contrast6;
  state-icon-color = colors.contrast9;

  paper-slider-knob-color = colors.contrast20;
  paper-slider-knob-start-color = colors.contrast15;
  paper-slider-pin-color = colors.contrast5;
  paper-slider-pin-start-color = colors.contrast4;
  paper-slider-active-color = colors.contrast15;
  paper-slider-secondary-color = colors.contrast7;
  paper-slider-container-color = colors.contrast5;

  switch-checked-button-color = colors.green;
  switch-checked-track-color = colors.green;
  switch-unchecked-button-color = colors.contrast9;
  switch-unchecked-track-color = colors.contrast6;

  paper-toggle-button-checked-button-color = colors.green;
  paper-toggle-button-checked-bar-color = colors.green;
  paper-toggle-button-unchecked-button-color = colors.contrast9;
  paper-toggle-button-unchecked-bar-color = colors.contrast6;

  table-row-background-color = colors.contrast2;
  table-row-alternative-background-color = colors.contrast3;
  data-table-background-color = colors.contrast1;
  mdc-text-field-fill-color = colors.contrast3;
  mdc-text-field-disabled-fill-color = colors.contrast3;

  input-fill-color = colors.contrast3;
  input-dropdown-icon-color = colors.contrast9;
  material-background-color = colors.contrast2;
  input-ink-color = colors.contrast20;
  input-label-ink-color = colors.contrast9;
  input-idle-line-color = colors.contrast7;
  input-hover-line-color = colors.contrast20;

  mdc-select-fill-color = colors.contrast3;
  mdc-select-ink-color = colors.contrast20;
  mdc-select-label-ink-color = colors.contrast9;
  mdc-select-idle-line-color = colors.contrast7;
  mdc-select-dropdown-icon-color = colors.contrast9;
  mdc-select-hover-line-color = colors.contrast20;

  mdc-theme-surface = colors.contrast2;
  mdc-checkbox-unchecked-color = colors.contrast15;

  # HA state color aliases
  blue-color = colors.blue;
  green-color = colors.green;
  yellow-color = colors.yellow;
  orange-color = colors.orange;
  red-color = colors.red;
  purple-color = colors.purple;
  grey-color = colors.contrast10;

  # CSS custom properties consumed at runtime by dashboard cards and card-mod CSS
  black = colors.black;
  white = colors.white;

  blue = colors.blue;
  green = colors.green;
  yellow = colors.yellow;
  orange = colors.orange;
  red = colors.red;
  purple = colors.purple;

  # Mushroom cards build their colours from these triplets; without
  # overriding, mushroom uses its own defaults instead of our brand
  # hues even though `icon_color = "yellow"` is written.
  rgb-blue = colors.rgb-blue;
  rgb-green = colors.rgb-green;
  rgb-yellow = colors.rgb-yellow;
  rgb-orange = colors.rgb-orange;
  rgb-red = colors.rgb-red;
  rgb-purple = colors.rgb-purple;
  rgb-white = colors.rgb-white;
  rgb-black = colors.rgb-black;
  rgb-grey = colors.rgb-grey;
  rgb-disabled = colors.rgb-disabled;

  # Entity-state-driven mushroom colours — these are what
  # state-coloured cards (light, switch, fan, climate, …) actually
  # render with. Mapping each to one of our brand triplets keeps the
  # palette consistent even without explicit icon_color overrides.
  rgb-state-light = colors.rgb-yellow;
  rgb-state-switch = colors.rgb-green;
  rgb-state-fan = colors.rgb-blue;
  rgb-state-climate-cooling = colors.rgb-blue;
  rgb-state-climate-heating = colors.rgb-red;
  rgb-state-media-player = colors.rgb-blue;
  rgb-state-number = colors.rgb-blue;
  rgb-state-vacuum = colors.rgb-blue;
  rgb-state-cover = colors.rgb-blue;
  rgb-state-default = colors.rgb-blue;

  blue-tint = colors.blue-tint;
  green-tint = colors.green-tint;
  yellow-tint = colors.yellow-tint;
  orange-tint = colors.orange-tint;
  red-tint = colors.red-tint;
  purple-tint = colors.purple-tint;

  brightness = colors.brightness;
  brightness-tint = colors.brightness-tint;
  temperature = colors.temperature;
  temperature-tint = colors.temperature-tint;
  saturation = colors.saturation;

  # Contrast scale (referenced via var(--contrastN) in button-card styles)
  contrast1 = colors.contrast1;
  contrast2 = colors.contrast2;
  contrast3 = colors.contrast3;
  contrast4 = colors.contrast4;
  contrast5 = colors.contrast5;
  contrast6 = colors.contrast6;
  contrast7 = colors.contrast7;
  contrast8 = colors.contrast8;
  contrast9 = colors.contrast9;
  contrast10 = colors.contrast10;
  contrast11 = colors.contrast11;
  contrast12 = colors.contrast12;
  contrast13 = colors.contrast13;
  contrast14 = colors.contrast14;
  contrast15 = colors.contrast15;
  contrast16 = colors.contrast16;
  contrast17 = colors.contrast17;
  contrast18 = colors.contrast18;
  contrast19 = colors.contrast19;
  contrast20 = colors.contrast20;

  # Without modes.dark, HA applies its light-mode MDC CSS overrides (selects,
  # text fields, etc.) regardless of our base values. This empty-ish modes.dark
  # activates HA's dark MDC path when the OS is in dark mode.
  modes.dark = {
    contrast1 = colors.contrast1;
    contrast2 = colors.contrast2;
    contrast3 = colors.contrast3;
    contrast4 = colors.contrast4;
    contrast5 = colors.contrast5;
    contrast6 = colors.contrast6;
    contrast7 = colors.contrast7;
    contrast8 = colors.contrast8;
    contrast9 = colors.contrast9;
    contrast10 = colors.contrast10;
    contrast11 = colors.contrast11;
    contrast12 = colors.contrast12;
    contrast13 = colors.contrast13;
    contrast14 = colors.contrast14;
    contrast15 = colors.contrast15;
    contrast16 = colors.contrast16;
    contrast17 = colors.contrast17;
    contrast18 = colors.contrast18;
    contrast19 = colors.contrast19;
    contrast20 = colors.contrast20;
  };

  # card-mod global overrides
  card-mod-theme = "Rounded";

  card-mod-view-yaml = ''

    hui-masonry-view:
      $: |

        /* Swipe-card full width on mobile */

        @media screen and (max-width: 599px) {
          #columns .column swipe-card {
            margin-left: -4px;
            margin-right: -4px;
          }
        }

  '';

  card-mod-card-yaml = ''

    .: |

      ha-card {
        transition: none !important;
        font-family: 'Quicksand', 'Roboto', sans-serif !important;
      }

      /* Graph card style */

      .graph {
        background: var(--blue-tint);
        display: flex;
        overflow: hidden;
      }

      .graph .name {
        font-size: 12px;
        line-height: 18px;
        background: var(--black);
        color: var(--white);
        padding: 6px 10px;
        border-radius: 100px;
        z-index: 1;
      }

      .graph .icon {
        display: none;
      }

      .graph .info {
        margin-top: 0;
        padding: 24px 24px 0 24px;
        order: 1;
      }

      ha-card.graph.type-entity div.footer {
        order: 3;
      }

      .graph .header {
        padding: 0 24px;
        order: 2;
        margin: 4px 0 -16px 0;
        z-index: 1;
      }

      /* Gauge: title pinned top-left so the needle has room to breathe. */

      .gauge ha-card {
        padding-top: 32px !important;
        position: relative;
      }

      .gauge .title {
        position: absolute !important;
        top: 12px;
        left: 16px;
        font-size: var(--ha-font-size-l) !important;
        color: var(--secondary-text-color) !important;
        margin: 0 !important;
        text-align: left !important;
      }

      /* Picture-elements wrapper used by the X1C view: no chrome,
         no background, no shadow — the printer/AMS/spool image IS the
         card. */

      .picture-bare ha-card {
        background: none !important;
        border: none !important;
        box-shadow: none !important;
      }

      /* Botty vacuum map: project our brand palette onto the
         xiaomi-vacuum-map-card's internal CSS vars and round the
         map's clip rect to match the rest of the dashboard. */

      .vacuum-map ha-card {
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

      .vacuum-map .map-wrapper {
        border-radius: 24px !important;
        overflow: hidden;
      }

      .vacuum-map .controls-wrapper {
        margin-right: 0 !important;
        margin-left: 0 !important;
        margin-bottom: 0 !important;
      }

      .vacuum-map .controls-wrapper .map-controls-wrapper {
        margin: 0 !important;
      }

      .vacuum-map mwc-list-item {
        background: var(--contrast2) !important;
      }

  '';
}
