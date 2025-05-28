{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.nixvim.languages.go;
in
{
  options.nixvim.languages.go.enable = lib.mkEnableOption "Language config for go";

  config = lib.mkIf cfg.enable {
    programs.nixvim.plugins.lsp.servers.gopls = {
      enable = true;
      settings.gopls = {
        completeUnimported = true;
        usePlaceholders = true;
        analyses = {
          unusedparams = true;
        };
      };
    };

    programs.nixvim.plugins.conform-nvim.settings.formatters_by_ft.go = [
      "gofumpt"
      "goimports"
    ];
    programs.nixvim.plugins.lint.lintersByFt.go = [ "golangcilint" ];
    programs.nixvim.plugins.lint.linters.golangcilint.cmd = lib.getExe pkgs.golangci-lint;

    programs.nixvim.plugins.neotest.adapters.go.enable = true;
    programs.nixvim.plugins.dap-go.enable = true;

    programs.nixvim.extraPackages = with pkgs; [
      delve
      gofumpt
    ];
  };
}
