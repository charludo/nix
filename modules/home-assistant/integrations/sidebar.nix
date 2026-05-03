{
  lib,
  config,
  pkgs,
  ...
}:
let
  cfg = config.hass;

  itemSubmodule = lib.types.submodule {
    options = {
      item = lib.mkOption {
        type = lib.types.str;
        description = "Panel slug as it appears in the sidebar URL (e.g. lovelace, dashboard-areas, history)";
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
  };

  mkEntry =
    idx: entry:
    {
      inherit (entry) item hide divider;
      order = idx + 1;
    }
    // lib.optionalAttrs (entry.name != null) { name = entry.name; };

  sidebarFile = pkgs.formats.yaml { };
  sidebarCfg = sidebarFile.generate "sidebar-config.yaml" {
    sidebar_editable = false;
    order = lib.imap0 mkEntry cfg.sidebar;
  };
in
{
  options.hass.sidebar = lib.mkOption {
    type = lib.types.listOf itemSubmodule;
    default = [ ];
    description = "Sidebar item order and visibility, written to custom-sidebar.yaml";
  };

  config = lib.mkIf (cfg.sidebar != [ ]) {
    systemd.tmpfiles.rules = [
      "L+ ${config.services.home-assistant.configDir}/www/sidebar-config.yaml - - - - ${sidebarCfg}"
    ];
  };
}
