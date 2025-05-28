{ config, private-settings, ... }:

{
  programs.thunderbird = {
    enable = true;
    profiles.charlotte = {
      isDefault = true;
      settings = {
        "calendar.week.start" = 1;
        "mailnews.default_sort_order" = 2;
        "mailnews.default_sort_type" = 18;
        "mailnews.default_news_sort_order" = 2;
        "mailnews.default_news_sort_type" = 18;
        "browser.display.background_color" = "#${config.colorScheme.palette.base00}";
        "browser.display.foreground_color" = "#${config.colorScheme.palette.base04}";
        "browser.display.document_color_use" = 2;
        "browser.anchor_color" = "#${config.colorScheme.palette.base0D}";
        "browser.visited_color" = "#${config.colorScheme.palette.base0E}";
        "font.name.serif.x-western" = "${config.fontProfiles.regular.family}";
        "font.name.sans-serif.x-western" = "${config.fontProfiles.regular.family}";
        "mailnews.start_page.enabled" = false;
        "mail.spam.markAsReadOnSpam" = true;
        "mail.openpgp.allow_external_gnupg" = true;
        "mail.openpgp.fetch_pubkeys_from_gnupg" = true;
        "mailnews.default_news_view_flags" = 0;
        "mailnews.default_view_flags" = 0;
        "toolkit.legacyUserProfileCustomizations.stylesheets" = false; # disables the userChorme below, since it's currently not in use
        "extensions.webextensions.uuids" =
          "{\"default-theme@mozilla.org\":\"2115b3dd-e066-41ea-844d-2c5019d120d9\",\"{a62ef8ec-5fdc-40c2-873c-223b8a6925cc}\":\"ac20100e-09a8-418a-8a8d-53387f57cc59\"}";
        "extensions.webextensions.ExtensionStorageIDB.migrated.{a62ef8ec-5fdc-40c2-873c-223b8a6925cc}" =
          true;
        "spellchecker.dictionary" = "en-US,de-DE";
      };
      userChrome = # css
        ''
          ul li ul li ul li div.container span.folder-count-badge.unread-count {
            display:none !important;
          }
        '';
    };
  };

  accounts.email.accounts = private-settings.accounts;

  home.file.".thunderbird/${config.home.username}/xulstore.json" = {
    force = true;
    text = ''
      {
        "chrome://messenger/content/messenger.xhtml":{
          "toolbar-menubar":{
            "autohide":"true"
          },
          "today-pane-splitter":{
            "hidden":"true"
          },
          "today-none-box":{
            "collapsed":"true"
          },
          "today-minimonth-box":{
            "collapsed":"true"
          },
          "todo-tab-panel":{
            "collapsed":"true"
          },
          "folderTree":{
            "mode":"all"
          },
          "quickFilterBar":{
            "collapsed":"true"
          },
          "messagepaneboxwrapper":{
            "collapsed":"false"
          },
          "threadPane":{
            "view":"table"
          },
          "agenda-panel":{
            "collapsed":"-moz-missing\n",
            "collapsedinmodes":"calendar"
          },
          "mini-day-box":{
            "collapsed":"-moz-missing\n"
          },
          "view-box":{
            "selectedIndex":"1"
          },
          "bottom-events-box":{
            "hidden":"true"
          },
          "calendar_show_unifinder_command":{
            "checked":"false"
          },
          "calendar-view-splitter":{
            "hidden":"true"
          },
          "folderPaneHeaderBar":{
            "hidden":"false"
          },
          "spacesToolbar":{
            "hidden":"false"
          },
          "threadPaneHeader":{
            "hidden":"true"
          }
        },
        "about:preferences":{
          "paneDeck":{
            "lastSelected":"paneGeneral"
          }
        }
      }
    '';
  };
}
