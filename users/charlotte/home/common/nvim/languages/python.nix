{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers.pylsp = {
    enable = true;
    filetypes = [ "python" ];
    settings.plugins = {
      black.enabled = true;
      black.line_length = 88;

      isort.enabled = true;
      pylint.enabled = true;

      pycodestyle.enabled = true;
      pycodestyle.maxLineLength = 88;
      pycodestyle.ignore = [ "E501" "W503" "R0903" ];

      # pylsp_mypy.enabled = true;
      # pylsp_mypy.dmypy = true;

      ruff.enabled = true;
      ruff.lineLength = 88;
    };
  };
  programs.nixvim.plugins.lint.lintersByFt.python = [ "pylint" ];
  programs.nixvim.extraPackages = [ pkgs.pylint pkgs.ruff ];
  home.shellAliases.ruff = "${pkgs.ruff}/bin/ruff";

  programs.nixvim.plugins.dap.configurations.python = [{
    name = "Launch Django DAP";
    type = "python";
    request = "launch";
    program = { __raw = /* lua */ '' vim.loop.cwd() .. "/.venv/bin/django-admin" ''; };
    args = [ "runserver" "--noreload" ];
    justMyCode = true;
    django = true;
    console = "integratedTerminal";
    env = {
      "DJANGO_SETTINGS_MODULE" = "true";
      "INTEGREAT_CMS_DEBUG" = "true";
      "INTEGREAT_CMS_SECRET_KEY" = "dummy";
    };
  }];
}
