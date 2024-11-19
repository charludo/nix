{ pkgs, ... }:
pkgs.mkShell {
  nativeBuildInputs = with pkgs; [
    age
    sops
    ssh-to-age
    (import ./keyctl/add-host.nix { inherit pkgs; })
    (import ./keyctl/add-user.nix { inherit pkgs; })
    (import ./keyctl/enable-host.nix { inherit pkgs; })
    (import ./keyctl/enable-user.nix { inherit pkgs; })

    openssh
    (import ./vmctl/vm-new.nix { inherit pkgs; })
    (import ./vmctl/vm-rebuild.nix { inherit pkgs; })
  ];
}
