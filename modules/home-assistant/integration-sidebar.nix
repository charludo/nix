{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;

  sidebarCfg = (pkgs.formats.yaml { }).generate "sidebar-config.yaml" {
    sidebar_editable = false;
    order = lib.imap0 (
      idx: entry:
      {
        inherit (entry) item hide divider;
        order = idx + 1;
      }
      // lib.optionalAttrs (entry.name != null) { inherit (entry) name; }
    ) cfg.sidebar;
  };
in
{
  options.hass.sidebar = lib.mkOption {
    default = [ ];
    description = "Sidebar item order and visibility, written to custom-sidebar.yaml";
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          item = lib.mkOption {
            type = lib.types.str;
            description = "Panel slug as it appears in the sidebar URL (lovelace, history, ...)";
          };
          name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Override the display name shown in the sidebar";
          };
          hide = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Hide this item from the sidebar entirely";
          };
          divider = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Add a divider below this item";
          };
        };
      }
    );
  };

  config = lib.mkIf (cfg.sidebar != [ ]) {
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/www/sidebar-config.yaml - - - - ${sidebarCfg}"
    ];
  };
}
