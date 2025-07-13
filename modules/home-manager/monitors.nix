{ lib, config, ... }:

let
  inherit (lib) mkOption types;
in
{
  options.monitors = mkOption {
    type = types.listOf (
      types.submodule {
        options = {
          name = mkOption {
            type = types.str;
            example = "DP-1";
            description = "name of the monitor";
          };
          primary = mkOption {
            type = types.bool;
            default = false;
            description = "whether this is the primary monitor. Must only be set once.";
          };
          width = mkOption {
            type = types.int;
            example = 1920;
            description = "width of the monitor in px";
          };
          height = mkOption {
            type = types.int;
            example = 1080;
            description = "height of the monitor in px";
          };
          refreshRate = mkOption {
            type = types.int;
            default = 60;
            description = "refresh rate of the monitor";
          };
          scaling = mkOption {
            type = types.number;
            default = 1;
            description = "scaling applied to this monitor";
          };
          x = mkOption {
            type = types.int;
            default = 0;
            description = "x-axis setoff for monitor positioning";
          };
          y = mkOption {
            type = types.int;
            default = 0;
            description = "y-axis setoff for monitor positioning";
          };
          enabled = mkOption {
            type = types.bool;
            default = true;
            description = "whether this monitor is enabled";
          };
          workspaces = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "what workspaces to always show on this monitor";
          };
          wallpaper = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "path to the wallpaper to use for this monitor";
          };
        };
      }
    );
    default = [ ];
    description = "configuration of all monitors";
  };
  config = {
    assertions = [
      {
        assertion =
          ((lib.length config.monitors) != 0)
          -> ((lib.length (lib.filter (m: m.primary) config.monitors)) == 1);
        message = "Exactly one monitor must be set to primary.";
      }
    ];
  };
}
