{ pkgs, ... }:

{
  programs.firefox = {
    enable = true;
    profiles.charlotte = {
      extensions = with pkgs.inputs.firefox-addons; [
        # bitwarden
        facebook-container
        sponsorblock
        ublock-origin
      ];
      search = {
        force = true;
        default = "Kagi";
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
          "Nix Packages" = {
            urls = [{
              template = "https://search.nixos.org/packages";
              params = [
                { name = "type"; value = "packages"; }
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
            definedAliases = [ "@np" ];
          };
          "HM Options" = {
            urls = [{
              template = "https://mipmip.github.io/home-manager-option-search/";
              params = [
                { name = "query"; value = "{searchTerms}"; }
              ];
            }];
            icon = "${pkgs.fetchurl {
                url = "https://mipmip.github.io/home-manager-option-search/images/favicon.png";
                sha256 = "sha256-oFp+eoTLXd0GAK/VrYRUeoXntJDfTu6VnzisEt+bW74=";
              }}";
            definedAliases = [ "@nh" ];
          };
          "Bing".metaData.hidden = true;
          "DuckDuckGo".metaData.hidden = true;
          "eBay".metaData.hidden = true;
          "Google".metaData.alias = "@g";
        };
      };
      bookmarks = { };
      settings = {
        "intl.accept_languages" = "en-us,en,de-de";
        "browser.startup.page" = 3;
        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.download.useDownloadDir" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts.havePinned" = false;
        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.uiCustomization.state" = ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["sponsorblocker_ajay_app-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_contain-facebook-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","_testpilot-containers-browser-action","reset-pbm-toolbar-button","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":[]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","sponsorblocker_ajay_app-browser-action","_contain-facebook-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list","unified-extensions-area"],"currentVersion":20,"newElementCount":8}'';
        "dom.security.https_only_mode" = true;
        "identity.fxaccounts.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "text/html" = [ "firefox.desktop" ];
    "text/xml" = [ "firefox.desktop" ];
    "x-scheme-handler/http" = [ "firefox.desktop" ];
    "x-scheme-handler/https" = [ "firefox.desktop" ];
  };
}
