{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "vm-rebuild";
  runtimeInputs = with pkgs; [ openssh ssh-to-age ];
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

    nixos-rebuild switch --flake ".#$1" --target-host "$host" --use-remote-sudo
  '';
}
