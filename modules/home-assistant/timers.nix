{ lib, config, ... }:
{
  options.hass.timers = lib.mkOption {
    default = { };
    description = "Home Assistant timer helpers keyed by slug";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Friendly name shown in the UI";
          };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "MDI icon";
          };
          duration = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Default duration as HH:MM:SS, overridden on timer.start";
          };
        };
      }
    );
  };

  config = lib.mkIf (config.hass.timers != { }) {
    services.home-assistant.config.timer = lib.mapAttrs (
      _: v: lib.filterAttrs (_: x: x != null) { inherit (v) name icon duration; }
    ) config.hass.timers;
  };
}
