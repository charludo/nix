{ pkgs, ... }:
{
  services.remmina.enable = true;

  programs.plasma = {
    enable = true;

    workspace = {
      clickItemTo = "select";
      lookAndFeel = "org.kde.breezedark.desktop";
      cursor.theme = "Bibata-Modern-Ice";
      iconTheme = "Papirus-Dark";
      wallpaper = "${pkgs.libsForQt5.plasma-workspace-wallpapers}/share/wallpapers/summer_1am/contents/images/1080x1920.jpg";
    };

    panels = [
      {
        location = "bottom";
        widgets = [
          {
            name = "org.kde.plasma.kickoff";
            config = {
              General.icon = "nix-snowflake-white";
            };
          }
          "org.kde.plasma.pager"
          {
            name = "org.kde.plasma.icontasks";
            config = {
              General.launchers = [
                "applications:firefox.desktop"
                "applications:org.kde.dolphin.desktop"
                "applications:org.kde.konsole.desktop"
                "applications:org.remmina.Remmina.desktop"
              ];
            };
          }
          "org.kde.plasma.marginsseperator"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              calendar.firstDayOfWeek = "monday";
              time.format = "24h";
            };
          }
          "org.kde.plasma.showdesktop"
        ];
      }
    ];
  };

  programs.firefox = {
    enable = true;
    profiles.marie = {
      extensions = with pkgs.inputs.firefox-addons; [
        facebook-container
        sponsorblock
        ublock-origin
      ];
      search = {
        force = true;
        default = "Google";
        engines = {
          "Kagi" = {
            urls = [
              {
                template = "https://kagi.com/search";
                params = [
                  { name = "q"; value = "{searchTerms}"; }
                ];
              }
              {
                template = "https://kagi.com/api/autosuggest";
                type = "application/x-suggestions+json";
                params = [
                  { name = "q"; value = "{searchTerms}"; }
                ];
              }
            ];
            icon = "${pkgs.fetchurl {
                url = "https://kagi.com/favicon.ico";
                sha256 = "sha256-6I9Kn+JtovACV3fgJgHy0MAeqNT+qlHHAQb2meWWiXA=";
              }}";
            definedAliases = [ "@k" ];
          };
          "Bing".metaData.hidden = true;
          "DuckDuckGo".metaData.hidden = true;
          "Google".metaData.alias = "@g";
        };
      };
      bookmarks = { };
      settings = {
        "intl.accept_languages" = "en-us,en,de-de";
        "browser.search.widget.inNavBar" = true;
        "browser.startup.page" = 3;
        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.download.useDownloadDir" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["sponsorblocker_ajay_app-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_contain-facebook-browser-action","_12cf650b-1822-40aa-bff0-996df6948878_-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","search-container","downloads-button","_testpilot-containers-browser-action","reset-pbm-toolbar-button","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":[]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","sponsorblocker_ajay_app-browser-action","_contain-facebook-browser-action","_12cf650b-1822-40aa-bff0-996df6948878_-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list","unified-extensions-area"],"currentVersion":20,"newElementCount":9}'';
        "dom.security.https_only_mode" = true;
        "identity.fxaccounts.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
      };
    };
  };
}
