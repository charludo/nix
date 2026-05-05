{ lib, pkgs, config, ... }:
let
  cfg = config.hass.shopping;
  customComponents = pkgs.callPackage ../../../pkgs/by-name/home-assistant/custom-components/package.nix { };
in
{
  options.hass.shopping = {
    todo_entity = lib.mkOption {
      type = lib.types.str;
      default = "todo.einkaufsliste";
      description = ''
        HA todo entity ID to read uncompleted items from. Items with
        ``status = "needs_action"`` are categorised; completed ones are
        ignored.
      '';
    };

    supermarkets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          categories = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = ''
              Ordered list of category names (matching
              ``custom_components/grocery_categorize/categories.py``).
              Order = store aisle sequence. Categories not listed are
              silently dropped from this supermarket's view; ``Sonstiges``
              is always rendered last when non-empty.
            '';
          };
          color = lib.mkOption {
            type = lib.types.str;
            default = "var(--green)";
            description = ''
              Background colour for the supermarket's button on the
              shopping-list dashboard view. Any CSS colour expression
              works (``"var(--blue)"``, ``"#ff8800"`` etc.).
            '';
          };
        };
      });
      default = { };
      example = lib.literalExpression ''
        {
          ALDI = {
            color = "var(--blue)";
            categories = [ "Obst" "Gemüse" "Backwaren" "Milchprodukte" ];
          };
          REWE = {
            color = "var(--red)";
            categories = [ "Obst" "Gemüse" "Charcuterie" ];
          };
        }
      '';
      description = ''
        Map from supermarket display name → ``{ color, categories }``.
        ``grocery_categorize.refresh`` writes into the single
        ``sensor.einkaufsliste`` whose ``markdown`` attribute the
        dashboard markdown card reads.
      '';
    };
  };

  config = lib.mkIf (cfg.supermarkets != { }) {
    services.home-assistant.customComponents = [ customComponents.grocery_categorize ];

    # rapidfuzz + numpy only — the component pulls them in via
    # manifest.json, but HA on NixOS doesn't auto-resolve, so wire
    # them in explicitly.
    services.home-assistant.extraPackages = py: [
      py.rapidfuzz
      py.numpy
      py.markdown
    ];

    services.home-assistant.config.grocery_categorize = {
      todo_entity = cfg.todo_entity;
      # Component only cares about the category order, not the colour.
      supermarkets = lib.mapAttrs (_: spec: spec.categories) cfg.supermarkets;
    };
  };
}
