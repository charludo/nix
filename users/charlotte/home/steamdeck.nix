{
  imports = [
    ./common
  ];
  home.hostname = "steamdeck";

  gpg.enable = false;
  ssh.enable = false;
  xdgProfile.enable = false;

  cli = {
    bat.enable = true;
    fish.enable = true;
    fzf.enable = true;
    nix-your-shell.enable = true;
  };
  games.eso.enable = true;
}
