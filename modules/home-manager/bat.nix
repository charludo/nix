{ config, lib, ... }:
let
  cfg = config.cli.bat;
in
{
  options.cli.bat.enable = lib.mkEnableOption "bat instead of cat";

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;
      config.theme = "base16";
    };
    home.shellAliases.cat = "bat -p";
    home.shellAliases.fzf = "fzf --preview 'bat --color=always --style=numbers --line-range=:500 {} 2>/dev/null'";
    home.sessionVariables.MANPAGER = "sh -c 'col -bx | bat -l man -p'";
    home.sessionVariables.MANROFFOPT = "-c";
  };
}
