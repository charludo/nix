{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "enable-user";
  runtimeInputs = with pkgs; [ openssh ssh-to-age ];
  text = ''
    set +o nounset
    set +o errexit
    if [ -z "$1" ]; then
        echo "Please provide a path to the host's private SSH key file."
        exit 1
    fi

    ssh-keygen -f "$1" -y > "$1.pub"
    echo "- regenerated public key"

    private_age=$(ssh-to-age -private-key -i "$1")
    mkdir -p "$HOME/.config/sops/age"
    echo "$private_age" >> "$HOME/.config/sops/age/keys.txt"
    chmod 600 "$HOME/.config/sops/age/keys.txt"
    echo "- converted private key to age and added to key list"

    echo "done!"
  '';
}
