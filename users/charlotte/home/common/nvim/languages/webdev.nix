{ pkgs, ... }:
{
  programs.nixvim.plugins.lsp.servers = {
    html.enable = true;
    htmx.enable = true;
    eslint.enable = true;
    phpactor.enable = true;
  };

  programs.nixvim.plugins.lint.lintersByFt = {
    javascript = [ "eslint_d" ];
    javascriptreact = [ "eslint_d" ];
    "javascript.jsx" = [ "eslint_d" ];
    typescript = [ "eslint_d" ];
    typescriptreact = [ "eslint_d" ];
    "typescript.txs" = [ "eslint_d" ];
    vue = [ "eslint_d" ];
    svelte = [ "eslint_d" ];
    astro = [ "eslint_d" ];
  };
  programs.nixvim.plugins.conform-nvim.formattersByFt = {
    css = [ "prettierd" ];
    sass = [ "prettierd" ];
    scss = [ "prettierd" ];
    less = [ "prettierd" ];

    jinja = [ "djlint" ];
    "jinja.html" = [ "djlint" ];
    twig = [ "djlint" ];
    htmldjango = [ "djlint" ];
    django = [ "djlint" ];
    html = [ "djlint" ];

    javascript = [ "prettierd" ];
    javascriptreact = [ "prettierd" ];
    "javascript.jsx" = [ "prettierd" ];
    typescript = [ "prettierd" ];
    typescriptreact = [ "prettierd" ];
    "typescript.txs" = [ "prettierd" ];
    vue = [ "prettierd" ];
    svelte = [ "prettierd" ];
    astro = [ "prettierd" ];

    php = [ "php-cs-fixer" ];
  };
  programs.nixvim.extraPackages = with pkgs; [ djlint prettierd eslint_d php83Packages.php-cs-fixer ];
}
