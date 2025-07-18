{
  config,
  lib,
  pkgs,
  private-settings,
  ...
}:
let
  cfg = config.desktop.firefox;
in
{
  options.desktop.firefox.enable = lib.mkEnableOption "Firefox Librewolf";
  options.desktop.firefox.profileName = lib.mkOption {
    type = lib.types.str;
    description = "name of the profile to use";
  };

  config = lib.mkIf cfg.enable {
    programs.librewolf = {
      enable = true;
      pkcs11Modules = [ pkgs.eid-mw ];
      profiles.${cfg.profileName} = {
        extensions.packages = with pkgs.inputs.firefox-addons; [
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
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                  ];
                }
                {
                  template = "https://kagi.com/api/autosuggest";
                  type = "application/x-suggestions+json";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
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
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "channel";
                      value = "unstable";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@np" ];
            };
            "Nix Options" = {
              urls = [
                {
                  template = "https://search.nixos.org/options";
                  params = [
                    {
                      name = "type";
                      value = "options";
                    }
                    {
                      name = "channel";
                      value = "unstable";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@no" ];
            };
            "HM Options" = {
              urls = [
                {
                  template = "https://home-manager-options.extranix.com/";
                  params = [
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                    {
                      name = "release";
                      value = "master";
                    }
                  ];
                }
              ];
              icon = "${pkgs.fetchurl {
                url = "https://home-manager-options.extranix.com/images/favicon.png";
                sha256 = "sha256-oFp+eoTLXd0GAK/VrYRUeoXntJDfTu6VnzisEt+bW74=";
              }}";
              definedAliases = [ "@nh" ];
            };
            "Nixpkgs Status" = {
              urls = [
                {
                  template = "https://nixpk.gs/pr-tracker.html";
                  params = [
                    {
                      name = "pr";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@ns" ];
            };
            "Nixpkgs Issues" = {
              urls = [
                {
                  template = "https://github.com/NixOS/nixpkgs/issues";
                  params = [
                    {
                      name = "q";
                      value = "is:issue {searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.fetchurl {
                url = "https://github.com/favicon.ico";
                sha256 = "sha256-LuQyN9GWEAIQ8Xhue3O1fNFA9gE8Byxw29/9npvGlfg=";
              }}";
              definedAliases = [ "@ni" ];
            };
            "Noogle" = {
              urls = [
                {
                  template = "https://noogle.dev/q";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                    {
                      name = "term";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.fetchurl {
                url = "https://noogle.dev/favicon.ico";
                sha256 = "sha256-K4rS0zRVqPc2/DqOv48L3qiEitTA20iigzvQ+c13WTI=";
              }}";
              definedAliases = [ "@noo" ];
            };
            "GitHub" = {
              urls = [
                {
                  template = "https://github.com/search";
                  params = [
                    {
                      name = "q";
                      value = "{searchTerms}";
                    }
                    {
                      name = "type";
                      value = "code";
                    }
                  ];
                }
              ];
              icon = "${pkgs.fetchurl {
                url = "https://github.com/favicon.ico";
                sha256 = "sha256-LuQyN9GWEAIQ8Xhue3O1fNFA9gE8Byxw29/9npvGlfg=";
              }}";
              definedAliases = [ "@gh" ];
            };
            "bing".metaData.hidden = true;
            "ddg".metaData.hidden = true;
            "DuckDuckGo Lite".metaData.hidden = true;
            "ebay".metaData.hidden = true;
            "MetaGer".metaData.hidden = true;
            "Mojeek".metaData.hidden = true;
            "SearXNG - searx.be".metaData.hidden = true;
            "StartPage".metaData.hidden = true;
            "wikipedia".metaData.hidden = true;
            "google".metaData.alias = "@g";
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
          "browser.newtabpage.enabled" = false;
          "browser.search.separatePrivateDefault" = false;
          "browser.shell.checkDefaultBrowser" = false;
          "browser.shell.defaultBrowserCheckCount" = 1;
          "browser.toolbars.bookmarks.visibility" = "never";
          "browser.uiCustomization.state" =
            ''{"placements":{"widget-overflow-fixed-list":[],"unified-extensions-area":["sponsorblocker_ajay_app-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_contain-facebook-browser-action"],"nav-bar":["back-button","forward-button","stop-reload-button","urlbar-container","downloads-button","_testpilot-containers-browser-action","reset-pbm-toolbar-button","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","ublock0_raymondhill_net-browser-action","unified-extensions-button"],"toolbar-menubar":["menubar-items"],"TabsToolbar":["tabbrowser-tabs","new-tab-button","alltabs-button"],"PersonalToolbar":[]},"seen":["save-to-pocket-button","developer-button","ublock0_raymondhill_net-browser-action","_testpilot-containers-browser-action","passbolt_passbolt_com-browser-action","amptra_keepa_com-browser-action","unchecker_ad5001_eu-browser-action","firefoxextension_reviewmeta_com-browser-action","_732216ec-0dab-43bb-ac85-4b5e1977599d_-browser-action","firefoxcolor_mozilla_com-browser-action","_446900e4-71c2-419f-a6a7-df9c091e268b_-browser-action","sponsorblocker_ajay_app-browser-action","_contain-facebook-browser-action"],"dirtyAreaCache":["nav-bar","PersonalToolbar","toolbar-menubar","TabsToolbar","widget-overflow-fixed-list","unified-extensions-area"],"currentVersion":20,"newElementCount":8}'';
          "dom.security.https_only_mode" = true;
          "privacy.trackingprotection.enabled" = true;
          "toolkit.legacyUserProfileCustomizations.stylesheets" = true;

          # Custom FFSync
          "identity.fxaccounts.enabled" = true;
          "identity.sync.tokenserver.uri" = "https://ffsync.${private-settings.domains.home}/1.0/sync/1.5";
          "services.sync.engine.addons" = true;
          "services.sync.engine.bookmarks" = true;
          "services.sync.engine.history" = true;
          "services.sync.engine.passwords" = false;
          "services.sync.engine.prefs" = false;
          "services.sync.engine.tabs" = false;
          "services.sync.engine.creditcards" = false;
          "services.sync.engine.addresses" = false;

          # LibreWolf-specific
          "general.autoScroll" = true;
          "middlemouse.paste" = false;
          "privacy.clearOnShutdown.history" = false;
          "privacy.clearOnShutdown.downloads" = false;
          "privacy.clearOnShutdown.cookies" = false;
          "network.cookie.lifetimePolicy" = 0;
          "privacy.fingerprintingProtection" = false;
          "privacy.resistFingerprinting" = false;
          "privacy.sanitize.sanitizeOnShutdown" = false;
          "webgl.disabled" = false;
        };
        userChrome = # css
          ''
            #alltabs-button { display: none !important; }
          '';
      };
    };

    xdg.mimeApps.defaultApplications = {
      "text/html" = [ "firefox.desktop" ];
      "text/xml" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
    };

    xdg.desktopEntries.firefox = {
      name = "Firefox (Librewolf)";
      genericName = "Web Browser";
      exec = "librewolf --name librewolf %U";
      icon = "firefox";
      type = "Application";
      terminal = false;
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      startupNotify = true;

      actions = {
        new-private-window = {
          name = "New Private Window";
          exec = "librewolf --private-window %U";
        };
        new-window = {
          name = "New Window";
          exec = "librewolf --new-window %U";
        };
        profile-manager-window = {
          name = "Profile Manager";
          exec = "librewolf --ProfileManager";
        };
      };
    };
  };
}
