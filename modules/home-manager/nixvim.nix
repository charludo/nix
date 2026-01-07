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
  options.nixvim.spellChecking = lib.mkOption {
    type = lib.types.bool;
    description = "Whether to enable spellchecking for en and de";
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
      palette = lib.colors.extendPalette config.colorScheme.palette;
      languages = cfg.languages;

      opts = lib.mkIf cfg.spellChecking {
        spell = true;
        spelllang = [
          "en"
          "de"
        ];
      };

      autoCmd = lib.mkIf cfg.spellChecking [
        {
          event = "TermOpen";
          pattern = "*";
          command = "setlocal nospell";
        }
      ];
    };

    xdg.configFile = lib.mkIf cfg.spellChecking {
      "nvim/spell/de.latin1.spl".source = builtins.fetchurl {
        url = "https://ftp.nluug.nl/pub/vim/runtime/spell/de.latin1.spl";
        sha256 = "sha256:0hn303snzwmzf6fabfk777cgnpqdvqs4p6py6jjm58hdqgwm9rw9";
      };
      "nvim/spell/de.latin1.sug".source = builtins.fetchurl {
        url = "https://ftp.nluug.nl/pub/vim/runtime/spell/de.latin1.sug";
        sha256 = "sha256:0mz07d0a68fhxl9vmy1548vnbayvwv1pc24zhva9klgi84gssgwm";
      };
      "nvim/spell/de.utf-8.spl".source = builtins.fetchurl {
        url = "https://ftp.nluug.nl/pub/vim/runtime/spell/de.utf-8.spl";
        sha256 = "sha256:1ld3hgv1kpdrl4fjc1wwxgk4v74k8lmbkpi1x7dnr19rldz11ivk";
      };
      "nvim/spell/de.utf-8.sug".source = builtins.fetchurl {
        url = "https://ftp.nluug.nl/pub/vim/runtime/spell/de.utf-8.sug";
        sha256 = "sha256:0j592ibsias7prm1r3dsz7la04ss5bmsba6l1kv9xn3353wyrl0k";
      };
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

    home.file.".hidden".text = ''
      go
    '';
  };
}
