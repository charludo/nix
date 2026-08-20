{
  config,
  pkgs,
  lib,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = true;
    xwayland.enable = true;
    configType = "lua";

    settings =
      let
        primary = "0xff${config.colors.paletteStripped.base0E}";
        accent = "0xff${config.colors.paletteStripped.base09}";
        inactive = "0xaa${config.colors.paletteStripped.base02}";
        base = "0xaa${config.colors.paletteStripped.base00}";

        mainMod = "SUPER";
        shiftMod = "SUPER + SHIFT";
        ctrlMod = "SUPER + CTRL";
      in
      {
        config = {
          general = {
            layout = "master";
            allow_tearing = false;

            gaps_in = 5;
            gaps_out = 20;
            border_size = 2;

            col = {
              active_border = {
                colors = [
                  primary
                  accent
                ];
                angle = 45;
              };
              inactive_border = inactive;
            };
          };

          decoration = {
            rounding = 10;
            active_opacity = 1.0;
            inactive_opacity = 0.85;
            fullscreen_opacity = 1.0;

            blur = {
              enabled = true;
              size = 2;
              passes = 3;
              new_optimizations = true;
              ignore_opacity = true;
            };

            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
              offset = [
                3
                3
              ];
              color = base;
            };
          };

          animations = {
            enabled = true;
          };

          dwindle = {
            preserve_split = true;
          };

          misc = {
            disable_hyprland_logo = true;
            disable_splash_rendering = true;
            animate_manual_resizes = true;
            on_focus_under_fullscreen = 2;
            enable_anr_dialog = false;
            disable_watchdog_warning = true;
          };

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

          xwayland = {
            force_zero_scaling = true;
          };

          ecosystem = {
            no_update_news = true;
            no_donation_nag = true;
          };
        };

        curve = [
          {
            _args = [
              "myBezier"
              {
                type = "bezier";
                points = [
                  [
                    0.05
                    0.9
                  ]
                  [
                    0.1
                    1.05
                  ]
                ];
              }
            ];
          }
        ];

        animation = [
          {
            leaf = "windows";
            enabled = true;
            speed = 7;
            bezier = "myBezier";
          }
          {
            leaf = "windowsOut";
            enabled = true;
            speed = 7;
            bezier = "default";
            style = "popin 80%";
          }
          {
            leaf = "border";
            enabled = true;
            speed = 10;
            bezier = "default";
          }
          {
            leaf = "borderangle";
            enabled = true;
            speed = 8;
            bezier = "default";
          }
          {
            leaf = "fade";
            enabled = true;
            speed = 3;
            bezier = "default";
          }
          {
            leaf = "workspaces";
            enabled = true;
            speed = 6;
            bezier = "default";
          }
        ];

        window_rule = [
          {
            match.class = "org.jellyfin.JellyfinDesktop";
            fullscreen_state = "0";
          }
        ];

        layer_rule = [
          {
            match.namespace = "waybar";
            blur = true;
            ignore_alpha = 0;
          }
          {
            match.namespace = "rofi";
            blur = true;
            animation = "fade";
          }
        ];

        gesture = [
          {
            fingers = 3;
            direction = "horizontal";
            action = "workspace";
          }
        ];

        monitor =
          map (
            m:
            if m.enabled then
              {
                output = m.name;
                mode = "${toString m.width}x${toString m.height}"; # @${toString m.refreshRate}";
                position = "${toString m.x}x${toString m.y}";
                scale = m.scaling;
              }
            else
              {
                output = m.name;
                disabled = true;
              }
          ) config.monitors
          ++ [
            {
              output = "";
              mode = "preferred";
              position = "auto";
              scale = "auto";
            }
          ];
        workspace_rule = lib.lists.flatten (
          map (
            m:
            map (w: {
              workspace = w;
              monitor = m.name;
            }) m.workspaces
          ) (lib.filter (m: m.enabled && m.workspaces != null) config.monitors)
        );

        exec_cmd = [
          "systemctl --user import-environment"
          "hyprctl setcursor ${config.cursorProfile.name} ${toString config.cursorProfile.size}"
          "wl-paste --watch cliphist store"
        ];

        bind =
          let
            inherit (lib.generators) mkLuaInline;
            luaStr = lib.generators.toLua { };

            # `hl.bind(keys, dispatcher [, opts])`
            mkBind = keys: dispatcher: {
              _args = [
                keys
                dispatcher
              ];
            };

            exec = cmd: mkLuaInline "hl.dsp.exec_cmd(${luaStr cmd})";
            focus = args: mkLuaInline "hl.dsp.focus(${luaStr args})";
            window = fn: args: mkLuaInline "hl.dsp.window.${fn}(${luaStr args})";
            windowBare = fn: mkLuaInline "hl.dsp.window.${fn}()";

            workspaces = [
              "0"
              "1"
              "2"
              "3"
              "4"
              "5"
              "6"
              "7"
              "8"
              "9"
            ];
            terminal = config.home.sessionVariables.TERMINAL;

            rofi = "${lib.getExe (pkgs.rofi.override { plugins = [ pkgs.rofi-emoji ]; })}";
            rofi-rbw = "${lib.getExe pkgs.rofi-rbw}";
            menu = "${rofi} -modi \"drun,ssh,filebrowser\" -show drun -sort -sorting-method \"fzf\" -matching \"fuzzy\"";
            projects = "${rofi} -modi \"projects:rofi-projects\" -show projects -sort -sorting-method \"fzf\" -matching \"fuzzy\"";
            clipboard = "${rofi} -modi \"emoji,clipboard:rofi-cliphist\" -show emoji -show-icons";
            rbw = "${rofi-rbw} --target password --prompt \"   Vaultwarden   \"";
            screenshots = "${rofi} -modi \"screenshot:rofi-screenshot,screencapture:rofi-screencapture\" -show screenshot";
            hyprlock = "${lib.getExe pkgs.hyprlock}";

            pactl = "${lib.getExe' pkgs.pulseaudio "pactl"}";
            playerctl = "${lib.getExe' config.services.playerctld.package "playerctl"}";
            playerctld = "${lib.getExe' config.services.playerctld.package "playerctld"}";
          in
          [
            # Program bindings
            (mkBind "${mainMod} + Return" (exec terminal))
            (mkBind "${mainMod} + q" (windowBare "close"))
            (mkBind "${shiftMod} + q" (exec "${lib.getExe' pkgs.hyprland "hyprctl"} kill"))
            (mkBind "${mainMod} + l" (exec hyprlock))
            (mkBind "${shiftMod} + l" (exec "${lib.getExe' pkgs.systemd "systemctl"} suspend"))

            (mkBind "${mainMod} + Tab" (windowBare "cycle_next"))
            (mkBind "${mainMod} + Tab" (windowBare "bring_to_top"))

            # Rofi
            (mkBind "${mainMod} + d" (exec menu))
            (mkBind "${shiftMod} + d" (exec projects))
            (mkBind "${mainMod} + p" (exec clipboard))
            (mkBind "${shiftMod} + p" (exec rbw))
            (mkBind "PRINT" (exec screenshots))

            # Window behavior
            (mkBind "${mainMod} + v" (window "float" { action = "toggle"; }))
            (mkBind "${shiftMod} + v" (windowBare "pseudo"))
            (mkBind "${mainMod} + f" (windowBare "fullscreen"))

            # Single-workspace window navigation & sizing
            (mkBind "${mainMod} + left" (focus {
              direction = "left";
            }))
            (mkBind "${mainMod} + right" (focus {
              direction = "right";
            }))
            (mkBind "${mainMod} + up" (focus {
              direction = "up";
            }))
            (mkBind "${mainMod} + down" (focus {
              direction = "down";
            }))
            (mkBind "${ctrlMod} + right" (
              window "resize" {
                x = 60;
                y = 0;
                relative = true;
              }
            ))
            (mkBind "${ctrlMod} + left" (
              window "resize" {
                x = -60;
                y = 0;
                relative = true;
              }
            ))
            (mkBind "${ctrlMod} + up" (
              window "resize" {
                x = 0;
                y = -60;
                relative = true;
              }
            ))
            (mkBind "${ctrlMod} + down" (
              window "resize" {
                x = 0;
                y = 60;
                relative = true;
              }
            ))

            # Brightness control (only works if the system has lightd)
            (mkBind "XF86MonBrightnessUp" (exec "brightnessctl s +10%"))
            (mkBind "XF86MonBrightnessDown" (exec "brightnessctl s 10%-"))

            # Volume
            (mkBind "XF86AudioRaiseVolume" (exec "${pactl} set-sink-volume @DEFAULT_SINK@ +5%"))
            (mkBind "XF86AudioLowerVolume" (exec "${pactl} set-sink-volume @DEFAULT_SINK@ -5%"))
            (mkBind "XF86AudioMute" (exec "${pactl} set-sink-mute @DEFAULT_SINK@ toggle"))
            (mkBind "SHIFT + XF86AudioMute" (exec "${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"))
            (mkBind "XF86AudioMicMute" (exec "${pactl} set-source-mute @DEFAULT_SOURCE@ toggle"))
          ]
          ++

            (lib.optionals config.services.playerctld.enable [
              # Media control
              (mkBind "XF86AudioNext" (exec "${playerctl} next"))
              (mkBind "XF86AudioPrev" (exec "${playerctl} previous"))
              (mkBind "XF86AudioPlay" (exec "${playerctl} play-pause"))
              (mkBind "XF86AudioStop" (exec "${playerctl} stop"))
              (mkBind "ALT + XF86AudioNext" (exec "${playerctld} shift"))
              (mkBind "ALT + XF86AudioPrev" (exec "${playerctld} unshift"))
              (mkBind "ALT + XF86AudioPlay" (exec "systemctl --user restart playerctld"))
            ])
          ++

            # Movement
            [
              (mkBind "${mainMod} + apostrophe" (focus {
                workspace = "previous";
              }))
              (mkBind "${mainMod} + s" (mkLuaInline "hl.dsp.workspace.toggle_special(\"magic\")"))
              (mkBind "${shiftMod} + s" (
                window "move" {
                  workspace = "special:magic";
                  follow = false;
                }
              ))

              (mkBind "${shiftMod} + left" (window "move" { direction = "left"; }))
              (mkBind "${shiftMod} + right" (window "move" { direction = "right"; }))
              (mkBind "${shiftMod} + up" (window "move" { direction = "up"; }))
              (mkBind "${shiftMod} + down" (window "move" { direction = "down"; }))

              (mkBind "${mainMod} + mouse:272" (windowBare "drag"))
              (mkBind "${mainMod} + mouse:273" (windowBare "resize"))
            ]
          ++ (map (
            n:
            mkBind "${mainMod} + ${n}" (focus {
              workspace = n;
            })
          ) workspaces)
          ++ (map (
            n:
            mkBind "${shiftMod} + ${n}" (
              window "move" {
                workspace = n;
                follow = false;
              }
            )
          ) workspaces);
      };
    extraConfig = "";
  };
}
