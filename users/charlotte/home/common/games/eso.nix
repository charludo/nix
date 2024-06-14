{ inputs, pkgs, config, ... }:
let
  reShade = inputs.eso-reshade.files;
  esoHome = "${config.home.homeDirectory}/.steam/steam/steamapps/common/Zenimax Online/The Elder Scrolls Online/game/client/";
  ttcHome = "${config.home.homeDirectory}/.steam/steam/steamapps/compatdata/306130/pfx/drive_c/users/steamuser/Documents/Elder Scrolls Online/live/AddOns/TamrielTradeCentre";
  ttc-update = pkgs.writeShellApplication {
    name = "ttc-update";
    runtimeInputs = with pkgs; [ curl unzip ];
    text = ''
      curl -o "${ttcHome}/PriceTable.zip" 'https://eu.tamrieltradecentre.com/pc/download/PriceTable'
      unzip -o "${ttcHome}/PriceTable.zip" -d "${ttcHome}/"
      rm "${ttcHome}/PriceTable.zip"
    '';
  };
in
{
  home.packages = [ ttc-update ];

  xdg.desktopEntries.ttc-update = {
    name = "TTC Update";
    type = "Application";
    comment = "Application for managing and playing games on Steam";
    terminal = true;
    exec = "ttc-update";
    icon = "internet";
  };

  home.file."${esoHome}/reshade-shaders/".source = "${reShade}/reshade-shaders/";
  home.file."${esoHome}/d3d11.dll".source = "${reShade}/d3d11.dll";
  home.file."${esoHome}/d3dcompiler_47.dll".source = "${reShade}/d3dcompiler_47.dll";
  home.file."${esoHome}/ReShade.ini".source = "${reShade}/ReShade.ini";
  home.file."${esoHome}/ReShadePreset.ini".source = "${reShade}/ReShadePreset.ini";
  home.file."${esoHome}/ReShade64.json".source = "${reShade}/ReShade64.json";
  home.file."${esoHome}/ReShade64_XR.json".source = "${reShade}/ReShade64_XR.json";
}
