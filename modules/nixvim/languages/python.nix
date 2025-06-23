{
  config,
  lib,
  ...
}:
let
  cfg = config.languages.python;
in
{
  options.languages.python.enable = lib.mkEnableOption "Language config for python";

  config = lib.mkIf cfg.enable {
    plugins.lsp.servers.ruff = {
      enable = true;
      filetypes = [ "python" ];
    };

    plugins.conform-nvim.settings.formatters_by_ft = {
      python = [ "ruff" ];
    };

    plugins.neotest.adapters.python.enable = true;

    plugins.dap-python.enable = true;
    plugins.dap.configurations.python = [
      {
        name = "Launch Django DAP";
        type = "python";
        request = "launch";
        program = {
          __raw = # lua
            ''vim.loop.cwd() .. "/.venv/bin/django-admin" '';
        };
        args = [
          "runserver"
          "--noreload"
        ];
        justMyCode = true;
        django = true;
        console = "integratedTerminal";
        env = {
          "DJANGO_SETTINGS_MODULE" = "true";
          "INTEGREAT_CMS_DEBUG" = "true";
          "INTEGREAT_CMS_SECRET_KEY" = "dummy";
        };
      }
    ];
  };
}
