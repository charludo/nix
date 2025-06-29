{ config, pkgs, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;
  rofi-theme = {
    "*" = {
      bg-col = mkLiteral "#${config.colorScheme.palette.base00}";
      bg-col-light = mkLiteral "#${config.colorScheme.palette.base00}";
      border-col = mkLiteral "#${config.colorScheme.palette.base00}";
      selected-col = mkLiteral "#${config.colorScheme.palette.base00}";
      blue = mkLiteral "#${config.colorScheme.palette.base0D}";
      fg-col = mkLiteral "#${config.colorScheme.palette.base05}";
      fg-col2 = mkLiteral "#${config.colorScheme.palette.base08}";
      grey = mkLiteral "#${config.colorScheme.palette.base03}";

      font = "${config.fontProfiles.regular.family} 13";
    };

    element-text = {
      background-color = mkLiteral "inherit";
      text-color = mkLiteral "inherit";
    };

    element-icon = {
      background-color = mkLiteral "inherit";
      text-color = mkLiteral "inherit";
    };

    mode-switcher = {
      background-color = mkLiteral "inherit";
      text-color = mkLiteral "inherit";
    };

    window = {
      background-color = mkLiteral "rgba(0, 0, 0, 25%)";
      border = 0;
      fullscreen = true;
      padding = mkLiteral "calc(50% - 200px) calc(50% - 360px)";
    };

    mainbox = {
      border = 3;
      border-color = mkLiteral "@border-col";
      background-color = mkLiteral "@bg-col";
      border-radius = 15;
    };

    inputbar = {
      children = mkLiteral "[ prompt,entry ]";
      background-color = mkLiteral "@bg-col";
      border-radius = 5;
      padding = 2;
    };

    prompt = {
      background-color = mkLiteral "@blue";
      padding = 6;
      text-color = mkLiteral "@bg-col";
      border-radius = 10;
      margin = mkLiteral "20px 0px 0px 20px";
    };

    textbox-prompt-colon = {
      expand = false;
    };

    entry = {
      padding = 6;
      margin = mkLiteral "20px 0px 0px 10px";
      text-color = mkLiteral "@fg-col";
      background-color = mkLiteral "@bg-col";
    };

    listview = {
      border = mkLiteral "0px 0px 0px";
      padding = mkLiteral "6px 0px 0px";
      margin = mkLiteral "10px 0px 0px 20px";
      columns = 2;
      lines = 6;
      background-color = mkLiteral "@bg-col";
    };

    element = {
      padding = 5;
      background-color = mkLiteral "@bg-col";
      text-color = mkLiteral "@fg-col";
    };

    element-icon = {
      size = mkLiteral "25px";
    };

    "element selected" = {
      background-color = mkLiteral "@selected-col";
      text-color = mkLiteral "@fg-col2";
    };

    mode-switcher = {
      spacing = 0;
    };

    button = {
      padding = 10;
      background-color = mkLiteral "@bg-col-light";
      text-color = mkLiteral "@grey";
      vertical-align = mkLiteral "0.5";
      horizontal-align = mkLiteral "0.5";
      border = mkLiteral "0px 0px 4px 0px";
    };

    "button selected" = {
      background-color = mkLiteral "@bg-col";
      text-color = mkLiteral "@blue";
      border-color = mkLiteral "@blue";
    };

    message = {
      background-color = mkLiteral "@bg-col-light";
      margin = 2;
      padding = 2;
      border-radius = 5;
    };

    textbox = {
      padding = 6;
      margin = mkLiteral "20px 0px 0px 20px";
      text-color = mkLiteral "@blue";
      background-color = mkLiteral "@bg-col-light";
    };
  };

  rofi-cliphist = pkgs.writeShellApplication {
    name = "rofi-cliphist";
    runtimeInputs = [
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.gawk
    ];
    text = # bash
      ''
        set +o pipefail
        set +o errexit
        set +o nounset

        tmp_dir="/tmp/cliphist"
        rm -rf "$tmp_dir"

        if [[ -n "$1" ]]; then
            cliphist decode <<<"$1" | wl-copy
            exit
        fi

        mkdir -p "$tmp_dir"

        read -r -d ''' prog <<EOF
        /^[0-9]+\s<meta http-equiv=/ { next }
        match(\$0, /^([0-9]+)\s(\[\[\s)?binary.*(jpg|jpeg|png|bmp)/, grp) {
          system("echo " grp[1] "\\\\\t | cliphist decode >$tmp_dir/"grp[1]"."grp[3])
          print \$0"\0icon\x1f$tmp_dir/"grp[1]"."grp[3]
          next
        }
        1
        EOF
        cliphist list | gawk "$prog"
      '';
  };

  rofi-screenshot = pkgs.writeShellApplication {
    name = "rofi-screenshot";
    runtimeInputs = [ pkgs.hyprshot ];
    text = # bash
      ''
        set +o nounset

        all=(monitorcopy monitorsave windowcopy windowsave regioncopy regionsave)

        declare -A texts
        texts[monitorcopy]="󱉧  Monitor (Copy)"
        texts[monitorsave]="  Monitor (Save)"
        texts[windowcopy]="󱉧  Window (Copy)"
        texts[windowsave]="  Window (Save)"
        texts[regioncopy]="󱉧  Region (Copy)"
        texts[regionsave]="  Region (Save)"

        declare -A actions
        actions[monitorcopy]="hyprshot -m output --clipboard-only"
        actions[monitorsave]="hyprshot -m output"
        actions[windowcopy]="hyprshot -m window --clipboard-only"
        actions[windowsave]="hyprshot -m window"
        actions[regioncopy]="hyprshot -m region --clipboard-only"
        actions[regionsave]="hyprshot -m region"

        function check_valid {
            shift 1
            for entry in "''${@}"
            do
                if [ -z "''${actions[$entry]+x}" ]
                then
                    echo "Invalid choice in $1: $entry" >&2
                    exit 1
                fi
            done
        }

        function write_message {
            echo -n "<span font_size=\"medium\">$1</span>"
        }

        function print_selection {
            echo -e "$1" | read -r -d ''' entry; echo "echo $entry"
        }

        declare -A messages
        for entry in "''${all[@]}"
        do
            messages[$entry]="''${texts[$entry]^}"
        done

        echo -e "\0no-custom\x1ftrue"
        echo -e "\0markup-rows\x1ftrue"

        if [ -z "$1" ]
        then
            for entry in "''${all[@]}"
            do
                echo -e "''${messages[$entry]}"
            done
        else
            for entry in "''${all[@]}"
            do
                if [ "$1" = "''${messages[$entry]}" ]
                then
                    # shellcheck disable=SC1065
                    coproc ( ''${actions[$entry]}  > /dev/null  2>&1 )
                    exit 0
                fi
            done
            echo "Invalid selection: $1" >&2
            exit 1
        fi
      '';
  };
  rofi-screencapture = pkgs.writeShellApplication {
    name = "rofi-screencapture";
    runtimeInputs = [
      pkgs.wf-recorder
      pkgs.slurp
    ];
    text = # bash
      ''
        set +o nounset

        dt=$(eval 'date "+%Y-%m-%d %H:%M:%S"')
        directory="''${ROFI_SCREENCAPTURE_DIR:-''${XDG_VIDEOS_DIR:-$HOME/Videos}/Screencaptures}"
        filename="''${directory}/''${dt}.mkv"
        mkdir -p "''${directory}"

        all=(monitor region save cancel)

        record_monitor() {
          wf-recorder -f "''${filename}" -a -g "$(slurp -o)"
        }
        record_region() {
          wf-recorder -f "''${filename}" -a -g "$(slurp)"
        }

        declare -A texts
        texts[monitor]="󰿎  Monitor"
        texts[region]="󰿎  Region"
        texts[save]="  Save Recording"
        texts[cancel]="󰜺  Cancel Recording"

        declare -A actions
        actions[monitor]="record_monitor"
        actions[region]="record_region"
        actions[save]="pkill -INT -x wf-recorder"
        actions[cancel]="killall wf-recorder"

        function check_valid {
            shift 1
            for entry in "''${@}"
            do
                if [ -z "''${actions[$entry]+x}" ]
                then
                    echo "Invalid choice in $1: $entry" >&2
                    exit 1
                fi
            done
        }

        function write_message {
            echo -n "<span font_size=\"medium\">$1</span>"
        }

        function print_selection {
            echo -e "$1" | read -r -d ''' entry; echo "echo $entry"
        }

        declare -A messages
        for entry in "''${all[@]}"
        do
            messages[$entry]="''${texts[$entry]^}"
        done

        echo -e "\0no-custom\x1ftrue"
        echo -e "\0markup-rows\x1ftrue"

        if [ -z "$1" ]
        then
            for entry in "''${all[@]}"
            do
                echo -e "''${messages[$entry]}"
            done
        else
            for entry in "''${all[@]}"
            do
                if [ "$1" = "''${messages[$entry]}" ]
                then
                    ''${actions[$entry]}
                    exit 0
                fi
            done
            echo "Invalid selection: $1" >&2
            exit 1
        fi
      '';
  };
  rofi-projects = pkgs.writeShellApplication {
    name = "rofi-projects";
    runtimeInputs = [ pkgs.hyprshot ];
    text = # bash
      ''
        set +o nounset

        all=(${builtins.concatStringsSep " " (map (entry: entry.name) config.projects)})

        echo -e "\0no-custom\x1ftrue"
        echo -e "\0markup-rows\x1ftrue"

        if [ -z "$1" ]
        then
            for entry in "''${all[@]}"
            do
                echo -e "''${entry}"
            done
        else
            for entry in "''${all[@]}"
            do
                if [ "$1" = "''${entry}" ]
                then
                    # shellcheck disable=SC1065
                    coproc ( ${config.home.sessionVariables.TERMINAL} --working-directory "${config.xdg.userDirs.extraConfig.XDG_PROJECTS_DIR}/''${entry}" -e direnv exec . nvim)
                    exit 0
                fi
            done
            echo "Invalid selection: $1" >&2
            exit 1
        fi
      '';
  };
in
{
  home.packages = [
    rofi-cliphist
    rofi-screenshot
    rofi-screencapture
    rofi-projects

    pkgs.cliphist
    pkgs.rofi-rbw
    pkgs.rofi-emoji-wayland
    pkgs.rofi-systemd
    pkgs.rofi-power-menu
  ];

  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    font = "${config.fontProfiles.regular.family} 13";
    location = "center";
    plugins = [
      pkgs.rofi-power-menu
      pkgs.rofi-emoji-wayland
    ];
    terminal = "${config.home.sessionVariables.TERMINAL}";
    theme = rofi-theme;
    extraConfig = {
      icon-theme = "${config.iconsProfile.name}       ";
      show-icons = true;
      drun-display-format = "{icon} {name}";
      disable-history = false;
      hide-scrollbar = true;
      display-drun = " 󰀻  Apps   ";
      display-run = "   Run ";
      display-network = " 󰤨  Network";
      display-ssh = "    SSH   ";
      display-emoji = "    Emoji   ";
      display-filebrowser = "    Files   ";
      display-clipboard = " 󱣹  Clipboard   ";
      display-power-menu = " 󰐥  Power   ";
      display-screenshot = " 󰹑   Screenshot   ";
      display-screencapture = "    Screencapture   ";
      display-projects = "    Projects   ";
      sidebar-mode = true;
      parse-known-hosts = false;
      kb-mode-next = "Alt+Right,Control+Tab";
      kb-mode-previous = "Alt+Left,Control+ISO_Left_Tab";
      kb-custom-1 = "Alt+Return";
    };
  };
}
