{ lib, config, ... }:
let
  e = config.hass.entities;
  areas = config.hass.areas;
in
{
  services.home-assistant = {
    config = {
      lovelace = {
        dashboards.lovelace = {
          mode = "yaml";
          filename = "ui-lovelace.yaml";
          title = "Home";
          icon = "mdi:home";
          show_in_sidebar = true;
          require_admin = false;
        };
      };
    };
  };

  services.home-assistant.lovelaceConfig = {
    default = true;
    views = [
      (import ./view-home.nix {
        inherit lib e areas;
        wateringTimes = map (t: if builtins.isString t then t else t.time) config.hass.bewasserung.times;
      })
      (import ./view-botty.nix { inherit lib e; })
      (import ./view-sonos.nix { inherit lib e; })
      (import ./view-tv.nix { inherit lib e; })
      (import ./view-x1c.nix { inherit lib; })
      (import ./view-einkaufsliste.nix {
        inherit lib;
        supermarkets = config.hass.shopping.supermarkets or { };
        todoEntity = config.hass.shopping.todoEntity;
      })
      (import ./view-einstellungen.nix { inherit lib e; })
    ];
  };
}
