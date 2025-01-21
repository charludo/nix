{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "add-user";
  runtimeInputs = with pkgs; [
    age
    sops
    ssh-to-age
  ];
  text = ''
    set +o nounset
    if [ -z "$1" ]; then
        echo "Please provide a path to the nix config root."
        exit 1
    fi

    read -r -p "Enter new username: " username
    if [ -d "$1/users/$username" ]; then
      echo "User of the same name already exist."
      exit 1
    fi
    mkdir -p "$1/users/$username"
    cd "$1/users/$username"

    ssh-keygen -t ed25519 -C "$username" -N "" -f /tmp/userkey <<<y > /dev/null 2>&1
    cp "/tmp/userkey.pub" "ssh.pub"
    rm "/tmp/userkey.pub"

    private_ssh=$(</tmp/userkey)
    private_age=$(ssh-to-age -private-key -i /tmp/userkey)
    rm "/tmp/userkey"

    echo "$private_age" >> "$HOME/.config/sops/age/keys.txt"
    echo "$private_age" > "/tmp/userage"
    public_age=$(age-keygen -y "/tmp/userage")
    rm "/tmp/userage"

    echo "$username's public AGE key is:"
    echo ""
    echo "$public_age"
    echo ""
    echo "Insert it into your .sops.yaml configuration file at the appropriate place"
    echo "IN A NEW CONSOLE WINDOW."
    echo ""
    echo "Type \"continue\" once you are done:"
    while true; do
        read -r -p ": " user_input
        if [[ "$user_input" == "continue" ]]; then
            break
        fi
    done

    echo "Create new secrets file for $username? Enter filename ending in .sops.yaml or leave blank to skip."
    read -r -p ": " secrets_file
    if [ -n "$secrets_file" ]; then
        echo "example: secret" > "$secrets_file"
        encrypted=$(sops -e "$secrets_file" --noeditor)
        echo "$encrypted" > "$secrets_file"
    fi

    cd "../.."
    find . \( \( -name '*.sops.yaml' -or -name '*.sops.yml' -or -name '*.sops.json' -or -name '*.sops' \) -and -not \( -name '.sops.yaml' \) \) -exec sops updatekeys --yes --enable-local-keyservice {} \;

    echo "Secrets have been rekeyed. Do you wish to remove the private age key from this machine?"
    while true; do
        read -r -p "(y/n): " user_input
        if [[ "$user_input" == "n" ]]; then
            break
        fi
        if [[ "$user_input" == "y" ]]; then
            head -n -1 "$HOME/.config/sops/age/keys.txt" > "/tmp/allage" && mv "/tmp/allage" "$HOME/.config/sops/age/keys.txt"
            break
        fi
    done

    echo ""
    echo "The following is your private SSH key. STORE IT SECURELY!"
    echo "Once you close this window, it will be gone."
    echo ""
    echo "$private_ssh"
  '';
}
