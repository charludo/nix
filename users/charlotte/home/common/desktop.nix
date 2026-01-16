{
  lib,
  pkgs,
  private-settings,
  secrets,
  ...
}:
{
  imports = [ ../../../../modules/hyprland ];

  desktop = {
    alacritty.enable = true;
    element.enable = true;
    firefox.enable = true;
    firefox.profileName = "charlotte";
    firefox.replaceXDGEntry = true;
    firefox.extraConfig = {
      "browser.toolbars.bookmarks.visibility" = "never";
      "browser.uiCustomization.state" =
        ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["sponsorblocker_ajay_app-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_contain-facebook-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","_testpilot-containers-browser-action","reset-pbm-toolbar-button","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":[]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","sponsorblocker_ajay_app-browser-action","_contain-facebook-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list","unified-extensions-area"],"currentVersion":20,"newElementCount":8}'';
    };
    gtkProfile.enable = true;
    jellyfin.enable = true;
    nemo.enable = true;
    pulse.enable = true;
    qtProfile.enable = true;
    sioyek.enable = true;
    thunderbird.enable = true;
    thunderbird.profileName = "charlotte";
    yubikey-notify.enable = true;
  };

  home.packages = with pkgs; [
    shotwell
    telegram-desktop
  ];

  accounts.email.accounts = lib.mkDefault private-settings.charlotte.accounts;

  age.secrets.lemmy-username.rekeyFile = secrets.charlotte-lemmy-username;
  age.secrets.lemmy-password.rekeyFile = secrets.charlotte-lemmy-password;
  age.secrets.reddit-username.rekeyFile = secrets.charlotte-reddit-username;
  age.secrets.reddit-token.rekeyFile = secrets.charlotte-reddit-token;
  age.secrets.waybar-mail.rekeyFile = secrets.charlotte-waybar-mail;
  age.secrets.waybar-calendar-personal.rekeyFile = secrets.charlotte-waybar-calendar-personal;
}
