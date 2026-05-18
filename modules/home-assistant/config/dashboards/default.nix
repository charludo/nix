{ pkgs, ... }:
let
  roundedTheme = import ./theme.nix { };
  themesDir = pkgs.runCommand "ha-themes" { } ''
    mkdir -p $out
    cp ${(pkgs.formats.yaml { }).generate "Rounded.yaml" { Rounded = roundedTheme; }} $out/Rounded.yaml
  '';
in
{
  imports = [
    ./areas.nix
    ./home
    ./stromverbrauch.nix
    ./sensoren.nix
    ./wetter.nix
    ./garten.nix
  ];

  hass.sidebar = [
    { item = "Home"; }
    { item = "Garten"; }
    {
      item = "Wetter";
      divider = true;
    }
    { item = "Sensoren"; }
    { item = "Stromverbrauch"; }
    {
      item = "Räume";
      divider = true;
    }
    { item = "Music Assistant"; }
    { item = "Map"; }
    { item = "To-do lists"; }
    {
      item = "Logbook";
      hide = true;
    }
    {
      item = "History";
      hide = true;
    }
    {
      item = "Energy";
      hide = true;
    }
    {
      item = "Media";
      hide = true;
    }
  ];

  services.home-assistant = {
    customLovelaceModules =
      with pkgs.home-assistant-custom-lovelace-modules;
      with pkgs.ours.home-assistant.custom-lovelace-modules;
      [
        auto-entities
        button-card
        custom-sidebar
        card-mod
        mini-graph-card
        mushroom
        plotly-chart-card
        swipe-card
        lg-remote-control
        my-slider-v2
        xiaomi-vacuum-map-card
        layout-card
        weather-radar-card
        google-fonts-quicksand
      ];

    config.frontend.themes = "!include_dir_merge_named ${themesDir}";
  };
}
