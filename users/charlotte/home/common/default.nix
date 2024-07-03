{ inputs, lib, pkgs, config, outputs, ... }:
{
  imports = [
    inputs.nix-colors.homeManagerModules.colorscheme
    inputs.sops-nix.homeManagerModules.sops
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  nixpkgs = {
    overlays = builtins.attrValues outputs.overlays;
    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  nix = {
    package = lib.mkDefault pkgs.nix;
    settings = {
      experimental-features = [ "nix-command" "flakes" "repl-flake" ];
      warn-dirty = false;
    };
  };

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
    defaultSopsFile = ../../user_secrets.sops.yaml;
    defaultSopsFormat = "yaml";

    # Required because sops-nix doesn't know our UUID
    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";
  };

  # Required to restart sops-nix after changing the home-manager configuration
  home.activation.setupEtc = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    /run/current-system/sw/bin/systemctl start --user sops-nix
  '';
  sops.secrets.placeholder = { };

  programs = {
    home-manager.enable = true;
  };

  home = {
    username = lib.mkDefault "charlotte";
    homeDirectory = lib.mkDefault "/home/${config.home.username}";
    stateVersion = lib.mkDefault "23.11";
    sessionPath = [ "$HOME/.local/bin" ];
    sessionVariables = {
      FLAKE = "$HOME/nix";
      EDITOR = "nvim";
      TERMINAL = "${pkgs.alacritty}/bin/alacritty";
    };
    language.base = "en_US.UTF-8";
  };

  home.file = {
    ".colorscheme".text = config.colorscheme.slug;
    ".colorscheme.json".text = builtins.toJSON config.colorscheme;
  };
}
