# Installation

- use the official installer image with Calamares to install NixOS as usual (feel free to add no desktop environment for a way faster build)
- make sure to name the user just like your main user on that system is going to be called (to not get UID conflicts with SOPS)
- reboot into the newly installed system
- add the following to `/etc/nixos/configuration.nix`:
  ```nix
  services.openssh.enable=true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = with pkgs; [ git ];
  ```
- `sudo nixos-rebuild switch`
- login via ssh
- copy `/etc/nixos/hardware-configuration.nix` to your hosts `hardware-configuration.nix` in your flake, add, commit, push
- replace `/etc/ssh/ssh_host_ed25519_key` with your hosts' intended SSH key
- add `~/.ssh/id_ed25519`, and run `chmod 600 ~/.ssh/id_ed25519`
- run `nix develop github:charludo/nix#keyctl` and use `enable-user` and `sudo enable-host` to set up the sops keys
- run `sudo GIT_SSH_COMMAND='ssh -i /home/<username>/.ssh/id_ed25519 -o IdentitiesOnly=yes' nixos-rebuild switch --flake github:charludo/nix#<your_host>` to install the system properly this time
