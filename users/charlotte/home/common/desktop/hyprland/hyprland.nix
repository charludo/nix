{ config, pkgs, lib, ... }:
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;

    settings =
      let
        primary = "0xff${config.colorScheme.palette.base0E}";
        accent = "0xff${config.colorScheme.palette.base09}";
        inactive = "0xaa${config.colorScheme.palette.base02}";
        base = "0xaa${config.colorScheme.palette.base00}";

        mainMod = "SUPER";
        shiftMod = "SUPERSHIFT";
        ctrlMod = "SUPERCTRL";
      in
      {
        general = {
          layout = "master";
          allow_tearing = false;

          gaps_in = 5;
          gaps_out = 20;
          border_size = 2;

          "col.active_border" = "${primary} ${accent} 45deg";
          "col.inactive_border" = inactive;
        };

        decoration = {
          rounding = 10;
          active_opacity = 1.0;
          inactive_opacity = 0.85;
          fullscreen_opacity = 1.0;

          blur = {
            enabled = true;
            size = 5;
            passes = 1;
            new_optimizations = true;
            ignore_opacity = true;
          };

          drop_shadow = false;
          shadow_range = 4;
          shadow_render_power = 3;
          shadow_offset = "3 3";
          "col.shadow" = "${base}";
        };

        animations = {
          enabled = true;
          bezier = [
            "myBezier, 0.05, 0.9, 0.1, 1.05"
          ];
          animation = [
            "windows, 1, 7, myBezier"
            "windowsOut, 1, 7, default, popin 80%"
            "border, 1, 10, default"
            "borderangle, 1, 8, default"
            "fade, 1, 7, default"
            "workspaces, 1, 6, default"
          ];
        };

        dwindle = {
          pseudotile = true;
          preserve_split = true;
        };
        master = {
          new_is_master = false;
        };

        gestures = {
          workspace_swipe = true;
          workspace_swipe_fingers = 3;
        };

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          animate_manual_resizes = true;
          new_window_takes_over_fullscreen = 2;
        };

        layerrule = [
          "blur,waybar"
          "ignorezero,waybar"

          "blur,rofi"
          "ignorezero,rofi"
        ];

        binds = {
          movefocus_cycles_fullscreen = false;
        };

        input = {
          kb_layout = "us";
          kb_variant = "intl";

          follow_mouse = 1;
          sensitivity = 0;

          touchpad = {
            natural_scroll = false;
            disable_while_typing = false;
          };
        };

        monitor = map
          (m:
            let
              resolution = "${toString m.width}x${toString m.height}"; #@${toString m.refreshRate}";
              position = "${toString m.x}x${toString m.y}";
            in
            "${m.name},${if m.enabled then "${resolution},${position},1" else "disable"}"
          )
          (config.monitors) ++ [ ",preferred,auto,auto" ];
        workspace = map
          (m:
            "${m.name},${m.workspace}"
          )
          (lib.filter (m: m.enabled && m.workspace != null) config.monitors);

        exec = [
          "hyprctl setcursor ${config.cursorProfile.name} ${toString config.cursorProfile.size}"
          "waybar" # Start from here because using systemd misses users's environment...
          "wl-paste --watch cliphist store"

        ];

        bindm = [
          "${mainMod},mouse:272,movewindow"
          "${mainMod},mouse:273,resizewindow"
        ];

        bind =
          let
            workspaces = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" ];
            terminal = config.home.sessionVariables.TERMINAL;

            rofi = "${pkgs.rofi-wayland.override {plugins = [pkgs.rofi-emoji];}}/bin/rofi";
            rofi-rbw = "${pkgs.rofi-rbw}/bin/rofi-rbw";
            menu = "${rofi} -modi \"drun,ssh,filebrowser\" -show drun -sort -sorting-method \"fzf\" -matching \"fuzzy\"";
            projects = "${rofi} -modi \"projects:rofi-projects\" -show projects -sort -sorting-method \"fzf\" -matching \"fuzzy\"";
            clipboard = "${rofi} -modi \"emoji,clipboard:rofi-cliphist\" -show emoji -show-icons";
            rbw = "rbw-unlock && ${rofi-rbw} --target password --prompt \"   Bitwarden   \"";
            screenshots = "${rofi} -modi \"screenshot:rofi-screenshot,screencapture:rofi-screencapture\" -show screenshot";

            # Not in 23.11 yet!
            hyprlock = "${pkgs.hyprlock}/bin/hyprlock";

            pactl = "${pkgs.pulseaudio}/bin/pactl";
            playerctl = "${config.services.playerctld.package}/bin/playerctl";
            playerctld = "${config.services.playerctld.package}/bin/playerctld";
          in
          [
            # Program bindings
            "${mainMod},Return,exec,${terminal}"
            "${mainMod},q,killactive"
            "${mainMod},l,exec,${hyprlock}"

            # Rofi
            "${mainMod},d,exec,${menu}"
            "${shiftMod},d,exec,${projects}"
            "${mainMod},p,exec,${clipboard}"
            "${shiftMod},p,exec,${rbw}"
            ",PRINT,exec,${screenshots}"

            # Window behavior
            "${mainMod},v,toggleFloating"
            "${shiftMod},v,pseudo"
            "${mainMod},j,toggleSplit"
            "${mainMod},f,fullscreen"

            # Single-workspace window navigation & sizing
            "${mainMod},left,moveFocus,l"
            "${mainMod},right,moveFocus,r"
            "${mainMod},up,moveFocus,u"
            "${mainMod},down,moveFocus,d"
            "${ctrlMod},right,resizeactive,60 0"
            "${ctrlMod},left,resizeactive,-60 0"
            "${ctrlMod},up,resizeactive,0 -60"
            "${ctrlMod},down,resizeactive,0 60"

            # Brightness control (only works if the system has lightd)
            ",XF86MonBrightnessUp,exec,brightnessctl s +10%"
            ",XF86MonBrightnessDown,exec,brightnessctl s 10%-"

            # Volume
            ",XF86AudioRaiseVolume,exec,${pactl} set-sink-volume @DEFAULT_SINK@ +5%"
            ",XF86AudioLowerVolume,exec,${pactl} set-sink-volume @DEFAULT_SINK@ -5%"
            ",XF86AudioMute,exec,${pactl} set-sink-mute @DEFAULT_SINK@ toggle"
            "SHIFT,XF86AudioMute,exec,${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"
            ",XF86AudioMicMute,exec,${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"
          ] ++

          (lib.optionals config.services.playerctld.enable [
            # Media control
            ",XF86AudioNext,exec,${playerctl} next"
            ",XF86AudioPrev,exec,${playerctl} previous"
            ",XF86AudioPlay,exec,${playerctl} play-pause"
            ",XF86AudioStop,exec,${playerctl} stop"
            "ALT,XF86AudioNext,exec,${playerctld} shift"
            "ALT,XF86AudioPrev,exec,${playerctld} unshift"
            "ALT,XF86AudioPlay,exec,systemctl --user restart playerctld"
          ]) ++

          # Movement
          [
            "${mainMod},apostrophe,workspace,previous"
            "${mainMod},s,togglespecialworkspace,magic"
            "${shiftMod},s,movetoworkspacesilent,special:magic"

            "${shiftMod},left,movewindow,l"
            "${shiftMod},right,movewindow,r"
            "${shiftMod},up,movewindow,u"
            "${shiftMod},down,movewindow,d"
          ] ++
          (map
            (n: "${mainMod},${n},workspace,${n}")
            workspaces) ++
          (map
            (n: "${shiftMod},${n},movetoworkspacesilent,${n}")
            workspaces);
      };
    extraConfig = ''
    '';
  };
}
