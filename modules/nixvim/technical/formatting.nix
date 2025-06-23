{
  plugins.conform-nvim = {
    enable = true;
    settings = {
      format_on_save = # lua
        ''
          {
            lsp_fallback = true,
            timout_md = 500,
          }
        '';
      formatters_by_ft = {
        "_" = [ "trim_whitespace" ];
      };
    };
  };

  keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>af";
      action = ''<cmd>lua vim.o.eventignore = vim.o.eventignore == "" and "BufWritePre" or ""<cr>'';
      options = {
        desc = "toggle auto-formatting";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>fm";
      action = ''<cmd>lua require("conform").format()<cr>'';
      options = {
        desc = "format buffer";
      };
    }
  ];
}
