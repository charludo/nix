{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "waybar-wireguard";
  runtimeInputs = [
    pkgs.systemd
  ];
  text = ''
    set +o errexit
    set +o pipefail
    CONN="hoehle"
    SERVICE="wireguard-''${CONN}.service"

    if systemctl is-active --quiet "$SERVICE"; then
        ACTIVE=1
    else
        ACTIVE=0
    fi

    if [[ $# -eq 0 ]]; then
        if [ "$ACTIVE" -eq "0" ]; then
            echo "󱛏 "
        else
            echo "󰤪   ''${CONN}"
        fi
    elif [[ $1 == "--switch" ]]; then
        if [ "$ACTIVE" -eq "0" ]; then
            systemctl start "$SERVICE"
        else
            systemctl stop "$SERVICE"
        fi
    else
        exit 1
    fi
  '';
}
