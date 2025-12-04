{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cli.fish;
in
{
  options.cli.fish.enable = lib.mkEnableOption "fish shell";

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;

      plugins = [
        {
          name = "tide";
          src = pkgs.fishPlugins.tide.src;
        }
        {
          name = "plugin-sudope";
          src = pkgs.fishPlugins.plugin-sudope.src;
        }
        {
          name = "autopair";
          src = pkgs.fishPlugins.autopair.src;
        }
      ];

      shellInit = # fish
        ''
          set fish_greeting
          _tide_find_and_remove kubectl tide_right_prompt_items
        '';
    };

    home.activation.configure-tide =
      lib.hm.dag.entryAfter [ "writeBoundary" ] # fish
        ''
          ${lib.getExe pkgs.fish} -c "tide configure --auto --style=Rainbow --prompt_colors='True color' --show_time=No --rainbow_prompt_separators=Angled --powerline_prompt_heads=Sharp --powerline_prompt_tails=Flat --powerline_prompt_style='One line' --prompt_spacing=Compact --icons='Many icons' --transient=No"
        '';
  };
}
