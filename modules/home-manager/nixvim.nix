{ config, lib, ... }:
let
  cfg = config.nixvim;
in
{

  options.nixvim.enable = lib.mkEnableOption "Enable nixvim";
  options.nixvim.addDesktopEntry = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to add an xdg desktop entry for opening nixvim";
    default = true;
  };
  options.nixvim.languages = lib.mkOption {
    type = lib.types.anything;
    description = "Language configs to enable";
    default = { };
  };

  config = lib.mkIf cfg.enable {
    programs.nixvim = {
      imports = [ ../nixvim ];
      enable = true;
      colors = lib.mkDefault config.colorScheme.palette;
      languages = cfg.languages;
    };

    xdg.desktopEntries.code = lib.mkIf cfg.addDesktopEntry {
      name = "Code";
      type = "Application";
      comment = "Open NeoVim inside terminal";
      terminal = false;
      exec = "alacritty -e nvim";
      categories = [
        "Development"
        "Utility"
      ];
      icon = "nvim";
      mimeType = [ "text/*" ];
    };
  };
}
