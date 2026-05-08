{ lib, supermarkets, todoEntity }:
let
  ha = lib.ha;

  mkBigBtn =
    {
      name,
      icon,
      color ? "var(--contrast2)",
      fg ? "var(--contrast20)",
      tapAction,
    }:
    {
      type = "custom:button-card";
      inherit name icon;
      tap_action = tapAction;
      styles =
        (ha.mkStyles {
          icon = {
            width = "24px";
            color = fg;
          };
          img_cell = {
            "justify-content" = "center";
            "margin-top" = "0px";
          };
          name = {
            "justify-self" = "center";
            "font-size" = "14px";
            "margin-top" = "0px";
            color = fg;
          };
          card = {
            height = "88px";
            "border-radius" = "24px";
            padding = "16px";
            "background-color" = color;
          };
        })
        // {
          grid = ha.mkStyleProp { "grid-template-areas" = ''"i" "n"''; };
        };
    };

  # Supermarket buttons use the user-chosen bright colour with black
  # foreground so the contrast pops.
  mkSupermarketButton =
    name: spec:
    mkBigBtn {
      inherit name;
      icon = spec.icon;
      color = spec.color;
      fg = "var(--black)";
      tapAction = {
        action = "perform-action";
        perform_action = "grocery_categorize.refresh";
        data.supermarket = name;
        haptic = "medium";
      };
    };

  # Print button keeps the muted dark default — light text on dark
  # contrast2 background, matching the rest of the TV remote-style
  # buttons in the system.
  printButton = mkBigBtn {
    name = "Print";
    icon = "mdi:printer";
    tapAction = {
      action = "url";
      url_path = "/api/grocery_categorize/print";
      haptic = "medium";
    };
  };
  # Wrap a flat button list into rows of <perRow>. ``ha.mkHStack``
  # itself doesn't accept a `columns` field — when too many buttons
  # share one HStack the cells get squished — so we chunk into
  # multiple HStacks of fixed width.
  chunk = perRow: list:
    if list == [ ] then
      [ ]
    else
      [ (lib.take perRow list) ] ++ chunk perRow (lib.drop perRow list);

  allButtons = lib.mapAttrsToList mkSupermarketButton supermarkets ++ [ printButton ];
  buttonRows = map ha.mkHStack (chunk 3 allButtons);
in
{
  type = "sections";
  max_columns = 1;
  path = "einkaufsliste";
  icon = "mdi:cart";
  header = {
    card = ha.mkBadgeTitleCard {
      name = "Einkaufsliste";
      badgeCard = {
        type = "custom:button-card";
        name = ''[[[ return states["${todoEntity}"].state + " Einträge"; ]]]'';
        show_icon = false;
        entity = todoEntity;
        tap_action = {
          action = "navigate";
          navigation_path = "/todo?entity_id=${todoEntity}";
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
          })
          // {
            grid = ha.mkStyleProp {
              "grid-template-areas" = ''"n"'';
              "grid-template-rows" = "min-content";
            };
          };
      };
    };
  };
  sections = [
    {
      type = "grid";
      cards = buttonRows ++ [
        {
          type = "markdown";
          content = "{{ state_attr('sensor.einkaufsliste', 'markdown') or '_Tippe einen Markt an, um die Liste zu generieren._' }}";
        }
      ];
    }
  ];
}
