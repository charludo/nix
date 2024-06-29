{ pkgs, ... }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    openssh
    (import ./vm-new.nix { inherit pkgs; })
    (import ./vm-rebuild.nix { inherit pkgs; })
  ];

  shellHook = ''
    echo " __   __  __   __  _______  _______  ___     "
    echo "|  | |  ||  |_|  ||       ||       ||   |    "
    echo "|  |_|  ||       ||       ||_     _||   |    "
    echo "|       ||       ||       |  |   |  |   |    "
    echo "|       ||       ||      _|  |   |  |   |___ "
    echo " |     | | ||_|| ||     |_   |   |  |       |"
    echo "  |___|  |_|   |_||_______|  |___|  |_______|"
    echo ""
    echo ""

    echo "The following scripts are available:"
    echo "===================================="
    echo "- vm-new     <hostname>            | create a new VM and import it in proxmox"
    echo "- vm-rebuild <hostname> <ssh host> | rebuild in existing VM"
  '';
}
