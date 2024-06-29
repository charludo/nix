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
         echo "Please provide the ssh host you want to target."
         exit 1
     fi

    nixos-rebuild switch --flake ".#$1" --target-host "$2" --use-remote-sudo
  '';
}
