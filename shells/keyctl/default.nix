{ pkgs, ... }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    age
    sops
    ssh-to-age
    (import ./add-user.nix { inherit pkgs; })
    (import ./add-host.nix { inherit pkgs; })
    (import ./enable-user.nix { inherit pkgs; })
    (import ./enable-host.nix { inherit pkgs; })
  ];

  shellHook = ''
    echo " ___   _  _______  __   __  _______  _______  ___     ";
    echo "|   | | ||       ||  | |  ||       ||       ||   |    ";
    echo "|   |_| ||    ___||  |_|  ||       ||_     _||   |    ";
    echo "|      _||   |___ |       ||       |  |   |  |   |    ";
    echo "|     |_ |    ___||_     _||      _|  |   |  |   |___ ";
    echo "|    _  ||   |___   |   |  |     |_   |   |  |       |";
    echo "|___| |_||_______|  |___|  |_______|  |___|  |_______|";
    echo ""
    echo ""

    echo "The following scripts are available:"
    echo "===================================="
    echo "- add-user      <path>    | create new user keys"
    echo "- add-host      <path>    | create new host keys"
    echo "- enable-user   <path>    |   activate user keys"
    echo "- enable-host   <path>    |   activate host keys"
  '';
}
