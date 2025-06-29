{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cli.gh;
in
{
  options.cli.gh.enable = lib.mkEnableOption "enable GitHub cli";

  config = lib.mkIf cfg.enable {
    programs.gh = {
      enable = true;
      extensions = with pkgs; [ gh-markdown-preview ];
      settings = {
        version = "1";
        git_protocol = "ssh";
        prompt = "enabled";
      };
    };
  };
}
