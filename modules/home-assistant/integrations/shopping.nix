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
    todo_entity = lib.mkOption {
      type = lib.types.str;
      default = "todo.einkaufsliste";
      description = "HA todo entity ID to read uncompleted items from";
    };

    supermarkets = lib.mkOption {
      default = { };
      description = "Map of supermarket display name → categories shown on the shopping dashboard";
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
              description = "Ordered list of category names; order = store aisle sequence";
            };
            color = lib.mkOption {
              type = lib.types.str;
              default = "var(--green)";
              description = "CSS colour expression for the supermarket's button";
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
      pkgs.ours.home-assistant.custom-components.grocery_categorize
    ];

    # rapidfuzz + numpy only — the component pulls them in via
    # manifest.json, but HA on NixOS doesn't auto-resolve.
    services.home-assistant.extraPackages = py: [
      py.rapidfuzz
      py.numpy
      py.markdown
    ];

    services.home-assistant.config.grocery_categorize = {
      inherit (cfg) todo_entity;
      # Component only cares about category order, not the colour.
      supermarkets = lib.mapAttrs (_: s: s.categories) cfg.supermarkets;
    };
  };
}
