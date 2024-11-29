{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "vm-init";
  runtimeInputs = with pkgs; [ openssh ];
  text = ''
     set +o nounset
     set +o errexit
     if [ -z "$1" ]; then
         echo "Please provide the hostname you want to rebuild."
         exit 1
     fi
     if [ -z "$2" ]; then
         address=$(eval "nix eval .#nixosConfigurations.$1.config.vm.networking.address | tr -d '\"'")
         host="paki@$address"
     else
         host="$2"
     fi
     if [[ -z "$EDITOR" ]]; then
        echo "The EDITOR environment variable is not set. Please set it before running this script."
        exit 1
     fi


     # shellcheck disable=SC2034
     ssh_key_path="/etc/ssh/ssh_host_ed25519_key"
     tempfile=$(mktemp)

    $EDITOR "$tempfile"
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        echo "Error editing tempfile."
        exit 1
    fi

    key_content=$(cat "$tempfile")
    rm -f "$tempfile"
    if [[ -z "$key_content" ]]; then
        echo "Error reading key."
        exit 1
    fi

    # shellcheck disable=SC2087
    ssh -o StrictHostKeyChecking=no -o 'UserKnownHostsFile=/dev/null' -o 'LogLevel ERROR' "$host" << EOF
    set -e
    echo "$key_content" | sudo tee $ssh_key_path > /dev/null
    nix develop github:charludo/nix#keyctl -c sudo enable-host $ssh_key_path
    sudo reboot
    EOF

    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        echo "Failed to execute remote commands."
        exit 1
    fi

    echo "Waiting for $host to reboot..."
    sleep 15

    echo "Reconnecting to $host..."
    ssh "$host"
  '';
}
