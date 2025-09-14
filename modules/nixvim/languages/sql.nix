{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.sql;
in
{
  options.languages.sql.enable = lib.mkEnableOption "Language config for SQL";

  config = lib.mkIf cfg.enable {
    plugins.conform-nvim.settings.formatters_by_ft.sql = [
      "sqruff"
    ];
    plugins.lint.lintersByFt.sql = [ "sqruff" ];

    extraPackages = with pkgs; [
      sqruff
    ];
  };
}
