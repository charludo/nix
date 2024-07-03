{ config, ... }:
{
  programs.zsh = {
    enable = true;
    history.ignoreDups = true;
    enableCompletion = false;
    syntaxHighlighting = {
      enable = true;
      highlighters = [ "main" "brackets" ];
    };
    antidote = {
      enable = true;
      plugins = [
        "zsh-users/zsh-autosuggestions"
        "romkatv/powerlevel10k"
      ];
    };
    initExtra = ''
      source ~/.p10k.zsh
    '';
    initExtraFirst = ''
      if [[ -r "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh" ]];
      then
      source "''${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-''${(%):-%n}.zsh"
      fi

      ZSH_HIGHLIGHT_HIGHLIGHTERS=(main cursor)
      typeset -gA ZSH_HIGHLIGHT_STYLES
      typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet
      ZSH_HIGHLIGHT_STYLES[comment]='fg=#"${config.colorscheme.palette.base04}"'
      ZSH_HIGHLIGHT_STYLES[alias]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[suffix-alias]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[global-alias]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[function]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[command]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[precommand]='fg=#"${config.colorscheme.palette.base0B}",italic'
      ZSH_HIGHLIGHT_STYLES[autodirectory]='fg=#"${config.colorscheme.palette.base09}",italic'
      ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#"${config.colorscheme.palette.base09}"'
      ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#"${config.colorscheme.palette.base09}"'
      ZSH_HIGHLIGHT_STYLES[back-quoted-argument]='fg=#"${config.colorscheme.palette.base0E}"'
      ZSH_HIGHLIGHT_STYLES[builtin]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[hashed-command]='fg=#"${config.colorscheme.palette.base0B}"'
      ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-unquoted]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[command-substitution-quoted]='fg=#"${config.colorscheme.palette.base0A}"'
      ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter-quoted]='fg=#"${config.colorscheme.palette.base0A}"'
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#"${config.colorscheme.palette.base0A}"'
      ZSH_HIGHLIGHT_STYLES[single-quoted-argument-unclosed]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#"${config.colorscheme.palette.base0A}"'
      ZSH_HIGHLIGHT_STYLES[double-quoted-argument-unclosed]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[rc-quote]='fg=#"${config.colorscheme.palette.base0A}"'
      ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument-unclosed]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[assign]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[named-fd]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[numeric-fd]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[path]='fg=#"${config.colorscheme.palette.base05}",underline'
      ZSH_HIGHLIGHT_STYLES[path_pathseparator]='fg=#"${config.colorscheme.palette.base08}",underline'
      ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#"${config.colorscheme.palette.base05}",underline'
      ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]='fg=#"${config.colorscheme.palette.base08}",underline'
      ZSH_HIGHLIGHT_STYLES[globbing]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#"${config.colorscheme.palette.base0E}"'
      ZSH_HIGHLIGHT_STYLES[back-quoted-argument-unclosed]='fg=#"${config.colorscheme.palette.base08}"'
      ZSH_HIGHLIGHT_STYLES[redirection]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[arg0]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[default]='fg=#"${config.colorscheme.palette.base05}"'
      ZSH_HIGHLIGHT_STYLES[cursor]='fg=#"${config.colorscheme.palette.base05}"'
    '';
  };

  home.file.".p10k.zsh" = { source = ./zsh_p10k.zsh; };
}
