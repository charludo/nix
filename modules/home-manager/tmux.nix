{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cli.tmux;
in
{
  options.cli.tmux.enable = lib.mkEnableOption "tmux, the terminal multiplexer";

  config = lib.mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      aggressiveResize = true;
      clock24 = true;
      escapeTime = 0;
      focusEvents = true;
      historyLimit = 50000;
      mouse = true;
      prefix = "C-a";
      shell = "${lib.getExe pkgs.fish}";
      terminal = "xterm-256color";

      plugins = with pkgs.tmuxPlugins; [
        dotbar
      ];

      extraConfig = ''
        set -g display-time 4000
        set -g status-interval 5

        bind -n M-Left previous-window
        bind -n M-Right next-window

        set-option -sa terminal-overrides ",xterm*:Tc"
        set-option -g renumber-windows on

        set -g base-index 1
        setw -g pane-base-index 1

        set -g @tmux-dotbar-position top
        set -g @tmux-dotbar-bg "${config.colors.palette.base00}"
      '';
    };
  };
}
