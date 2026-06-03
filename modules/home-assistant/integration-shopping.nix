{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.hass.shopping;
in
{
  options.hass.shopping = {
    todoEntity = lib.mkOption {
      type = lib.types.str;
      default = "todo.einkaufsliste";
      description = "HA todo entity ID to read uncompleted items from";
    };

    supermarkets = lib.mkOption {
      default = { };
      description = "Map of supermarket display name to categories shown on the shopping dashboard";
      example = lib.literalExpression ''
        {
          ALDI.categories = [ "Obst" "Gemüse" "Milchprodukte" ];
          REWE = {
            color = "var(--red)";
            categories = [ "Obst" "Aufschnitt" ];
          };
        }
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            categories = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "Aisle-ordered list of category names";
            };
            color = lib.mkOption {
              type = lib.types.str;
              default = "var(--green)";
              description = "CSS color expression for the supermarket's button";
            };
            icon = lib.mkOption {
              type = lib.types.str;
              default = "mdi:cart-outline";
              description = "MDI icon shown on the supermarket's button";
            };
          };
        }
      );
    };
  };

  config = lib.mkIf (cfg.supermarkets != { }) {
    services.home-assistant.customComponents = [
      pkgs.ours.home-assistant.grocery-categorize
    ];

    services.home-assistant.extraPackages = py: [
      py.rapidfuzz
      py.numpy
      py.markdown
    ];

    services.home-assistant.config.grocery_categorize = {
      inherit (cfg) todoEntity;
      supermarkets = lib.mapAttrs (_: s: s.categories) cfg.supermarkets;
    };
  };
}
