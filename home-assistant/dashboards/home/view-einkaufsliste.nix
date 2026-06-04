{
  lib,
  supermarkets,
  todoEntity,
}:
let
  ha = lib.ha;

  mkSupermarketButton =
    name: spec:
    ha.mkServiceButton {
      inherit name;
      icon = spec.icon;
      service = "grocery_categorize.refresh";
      serviceData.supermarket = name;
      haptic = "medium";
      bg = spec.color;
      fg = "var(--black)";
    };

  printButton = ha.mkServiceButton {
    name = "Print";
    icon = "mdi:printer";
    haptic = "medium";
    tapAction = {
      action = "url";
      url_path = "/api/grocery_categorize/print";
      haptic = "medium";
    };
  };

  buttons = lib.mapAttrsToList mkSupermarketButton supermarkets ++ [ printButton ];
in
{
  type = "sections";
  max_columns = 1;
  path = "einkaufsliste";
  icon = "mdi:cart";
  header.card = ha.mkBadgeTitleCard {
    name = "Einkaufsliste";
    badgeCard = ha.mkHeaderBadge {
      entity = todoEntity;
      name = ''[[[ return states["${todoEntity}"].state + " Einträge"; ]]]'';
      tapAction = {
        action = "navigate";
        navigation_path = "/todo?entity_id=${todoEntity}";
        haptic = "medium";
      };
    };
  };
  sections = [
    {
      type = "grid";
      cards = ha.mkButtonGrid 3 buttons ++ [
        {
          type = "markdown";
          content = "{{ state_attr('sensor.einkaufsliste', 'markdown') or '_Tippe einen Markt an, um die Liste zu generieren._' }}";
        }
      ];
    }
  ];
}
