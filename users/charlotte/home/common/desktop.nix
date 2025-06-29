{ pkgs, secrets, ... }:
{
  imports = [ ../../../../modules/hyprland ];

  desktop = {
    alacritty.enable = true;
    element.enable = true;
    firefox.enable = true;
    firefox.profileName = "charlotte";
    jellyfin.enable = true;
    nemo.enable = true;
    pulse.enable = true;
    sioyek.enable = true;
    thunderbird.enable = true;
    thunderbird.profileName = "charlotte";
    yubikey-notify.enable = true;
  };

  home.packages = with pkgs; [
    shotwell
    telegram-desktop
  ];

  age.secrets.lemmy-username.rekeyFile = secrets.charlotte-lemmy-username;
  age.secrets.lemmy-password.rekeyFile = secrets.charlotte-lemmy-password;
  age.secrets.reddit-username.rekeyFile = secrets.charlotte-reddit-username;
  age.secrets.reddit-token.rekeyFile = secrets.charlotte-reddit-token;
  age.secrets.waybar-mail.rekeyFile = secrets.charlotte-waybar-mail;
  age.secrets.waybar-calendar-personal.rekeyFile = secrets.charlotte-waybar-calendar-personal;
}
