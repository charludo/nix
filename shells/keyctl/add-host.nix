{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "add-host";
  runtimeInputs = with pkgs; [
    age
    sops
    ssh-to-age
  ];
  text = ''
    set +o nounset
    set +o errexit
    if [ -z "$1" ]; then
        echo "Please provide a path to the nix config root."
        exit 1
    fi

    read -r -p "Enter new hostname: " hostname
    if [ -d "$1/hosts/$hostname" ]; then
      echo "Host of the same name already exist."
      exit 1
    fi
    mkdir -p "$1/hosts/$hostname"
    cd "$1/hosts/$hostname"

    ssh-keygen -t ed25519 -C "$hostname" -N "" -f /tmp/hostkey <<<y > /dev/null 2>&1
    cp "/tmp/hostkey.pub" "ssh_host_ed25519_key.pub"
    rm "/tmp/hostkey.pub"

    private_ssh=$(</tmp/hostkey)
    private_age=$(ssh-to-age -private-key -i /tmp/hostkey)
    rm "/tmp/hostkey"

    echo "$private_age" >> "$HOME/.config/sops/age/keys.txt"
    echo "$private_age" > "/tmp/hostage"
    public_age=$(age-keygen -y "/tmp/hostage")
    rm "/tmp/hostage"

    echo "$hostname's public AGE key is:"
    echo ""
    echo "$public_age"
    echo ""
    echo "Insert it into your .sops.yaml configuration file at the appropriate place"
    echo "IN A NEW CONSOLE WINDOW."
    echo ""
    echo "Type \"continue\" once you are done:"
    while true; do
        read -r -p ": " host_input
        if [[ "$host_input" == "continue" ]]; then
            break
        fi
    done

    cd "../.."
    find . \( \( -name '*.sops.yaml' -or -name '*.sops.yml' -or -name '*.sops.json' -or -name '*.sops' \) -and -not \( -name '.sops.yaml' \) \) -exec sops updatekeys --yes --enable-local-keyservice {} \;

    echo "Secrets have been rekeyed. Do you wish to remove the private age key from this machine?"
    while true; do
        read -r -p "(y/n): " host_input
        if [[ "$host_input" == "n" ]]; then
            break
        fi
        if [[ "$host_input" == "y" ]]; then
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
