{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  modules = import ./modules.nix {
    inherit
      pkgs
      lib
      config
      private-settings
      ;
  };
in
{
  imports = [ ./scripts ];
  # Note: Only basic setup and styling is handled here.
  # Custom modules are created in ./modules.nix.
  # The actual bars are configured in the host-specific files.
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    package = pkgs.waybar.overrideAttrs (oa: {
      mesonFlag = (oa.mesonFlag or [ ]) ++ [ "-Dexperimental=true" ];
    });
    settings = {
      # Not nice, but simple.
      # Make all modules available to all bars in use.
      primary = modules;
      top = modules;
      bottom = modules;
    };
    style =
      let
        palette = config.colors.palette;
      in
      # css
      ''
        @define-color progress  alpha(${palette.base0E}, 0.15);
        window {
          background-color: transparent;
        }

        label {
          color: @text;
        }

        .modules-left {
          margin-left: 16px;
        }
        .modules-right {
          margin-right: 16px;
        }

        #workspaces,
        #clock,
        #custom-weather,
        #battery,
        #bluetooth,
        #cpu,
        #disk,
        #memory,
        #network,
        #pulseaudio-slider,
        #temperature,
        #custom-power,
        #tray,
        #custom-wireguard,
        #custom-playerctl,
        #custom-mail,
        #custom-calendar,
        #custom-lemmy,
        #custom-reddit,
        #custom-updates {
          margin: 0px 4px;
          padding: 0px 12px;
          border-radius: 64px;
          background-color: alpha(${palette.base0E}, 0.05);
        }

        #custom-playerctl {
          background-size: 100% 100%;
          background-repeat: no-repeat;
          background-position: center;
        }

        #pulseaudio-slider {
          min-width: 100px;
        }

        #workspaces button.persistent {
            color: alpha(${palette.base05}, 0.7);
        }
        #workspaces button.empty {
          opacity: 0.7;
        }
        #workspaces button.active {
          color: ${palette.base09};
        }

        /* Is this an ugly hack? Yes! Does it Work? Also yes! */
      ''
      + lib.concatMapStrings (
        i:
        let
          pct = toString i;
        in
        # css
        ''
          #custom-playerctl.progress-${pct} {
            background-image: linear-gradient(to right, @progress ${pct}%, transparent ${pct}%);
          }
        ''
      ) (lib.range 1 100);
  };
}
