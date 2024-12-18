{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "enable-host";
  runtimeInputs = with pkgs; [ openssh ssh-to-age ];
  text = ''
    set +o nounset
    set +o errexit
    if [ -z "$1" ]; then
        echo "Please provide a path to the host's private SSH key file."
        exit 1
    fi

    if [[ $(id -u) != 0 ]]; then
        echo "Please run this script with sudo."
        exit 1
    fi

    ssh-keygen -f "$1" -y > "$1.pub"
    echo "- regenerated public key"

    echo "done!"
  '';
}
