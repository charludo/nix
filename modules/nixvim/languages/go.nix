{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.languages.go;
in
{
  options.languages.go.enable = lib.mkEnableOption "Language config for go";

  config = lib.mkIf cfg.enable {
    plugins.lsp.servers.gopls = {
      enable = true;
      settings.gopls = {
        completeUnimported = true;
        usePlaceholders = true;
        analyses = {
          unusedparams = true;
        };
      };
    };

    plugins.conform-nvim.settings.formatters_by_ft.go = [
      "gofumpt"
      "goimports"
    ];
    plugins.lint.lintersByFt.go = [ "golangcilint" ];
    plugins.lint.linters.golangcilint.cmd = lib.getExe pkgs.golangci-lint;

    plugins.neotest.adapters.go = {
      enable = true;
      settings.args = [ "-coverprofile=coverage.out" ];
    };
    plugins.dap-go.enable = true;

    extraPackages = with pkgs; [
      delve
      gofumpt
    ];
  };
}
