{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "waybar-playerctl";
  runtimeInputs = [
    pkgs.playerctl
    pkgs.bc
    pkgs.jq
  ];
  text = ''
    set +o pipefail
    set +o errexit
    PLAYER="mpv"

    # Function to get player status, title, and progress
    get_player_info() {
        status=$(playerctl -p "$PLAYER" status 2>/dev/null)
        if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
            echo ""
            return
        fi

        title=$(playerctl -p "$PLAYER" metadata --format "{{title}} ( {{duration(position)}} / {{duration(mpris:length)}} )")
        position=$(playerctl -p "$PLAYER" metadata --format "{{position}}")
        length=$(playerctl -p "$PLAYER" metadata --format "{{mpris:length}}")
        if [ -z "$length" ] || [ "$length" -eq 0 ] || [ "$position" -eq 0 ]; then
            progress=0
        else
            progress=$(echo "100/$length*$position" | bc -l)
        fi
        progress=''${progress%.*}

        if [ "$status" = "Playing" ]; then
            status="󰏤 "
        else
            status="󰐊 "
        fi

        if [ -n "$length" ]; then
            # shellcheck disable=SC2016,2215
            jq -c -n -M --arg status "$status" --arg title "$title" --arg progress "$progress" '{text: ($status + " " + $title), class: ("progress-" + $progress)}'
        fi

    }

    # Toggle player play/pause
    toggle_player() {
        status=$(playerctl -p "$PLAYER" status 2>/dev/null)
        if [ -z "$status" ]; then
            return
        fi

        if [ "$status" = "Playing" ]; then
            playerctl -p "$PLAYER" pause
        else
            playerctl -p "$PLAYER" play
        fi
    }

    # Main script
    if [ $# -eq 0 ]; then
        get_player_info
    else
        action=$1
        if [ "$action" = "toggle" ]; then
            toggle_player
            echo "Player toggled"
        else
            playerctl -p "$PLAYER" "$action"
            echo "Player $action"
        fi
    fi

  '';
}
