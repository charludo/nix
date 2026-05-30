{ lib, config, ... }:
{
  options.hass.scripts = lib.mkOption {
    default = { };
    description = "Home Assistant scripts keyed by slug";
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          alias = lib.mkOption {
            type = lib.types.str;
            description = "Human-readable name shown in the UI";
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Longer description of what the script does";
          };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "MDI icon shown for the script";
          };
          sequence = lib.mkOption {
            type = lib.types.listOf lib.types.anything;
            default = [ ];
            description = "Sequence of actions the script executes";
          };
          mode = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Execution mode (single, restart, queued, parallel)";
          };
          fields = lib.mkOption {
            type = lib.types.attrsOf lib.types.anything;
            default = { };
            description = ''
              Declared input fields with `selector`s. When the script
              is run from the UI (more-info → Run, or the Run service
              from Dev Tools), HA renders a form with these fields
              and passes the entered values as script variables.
            '';
          };
        };
      }
    );
  };

  config.services.home-assistant.config.script = config.hass.scripts;
}
