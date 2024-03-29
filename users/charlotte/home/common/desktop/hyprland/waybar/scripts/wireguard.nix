{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "waybar-wireguard";
  runtimeInputs = [ pkgs.networkmanager pkgs.gawk pkgs.gnugrep ];
  text = ''
    set +o pipefail
    CONN="hoehle"
    ACTIVE=0;
    conn_exists=$(nmcli connection show | grep -icP "(''${CONN}).*wireguard")
    if [ "$conn_exists" -eq "1" ]; then
        conn_status=$(nmcli -t -f ACTIVE,NAME con show --active | grep ''${CONN} | awk '{print $1}')
        if [ "$conn_status" == "yes:''${CONN}" ]; then
            ACTIVE=1
        fi
    fi

    if [[ $# -eq 0 ]]; then
        if [ "$ACTIVE" -eq "0" ]; then
            echo "󱛏 "
        else
            echo "󰤪   ''${CONN}"
        fi
    elif [[ $1 == "--switch" ]]; then
        if [ "$ACTIVE" -eq "0" ]; then
            nmcli c up ''$CONN
        else
            nmcli c down ''$CONN
        fi
    else
        exit 1
    fi
  '';
} 
