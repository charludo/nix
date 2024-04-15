{
  programs.nixvim.plugins.nvim-autopairs = {
    enable = true;
    settings.disabled_filetype = [ "TelescopePrompt" "vim" ];
  };

  programs.nixvim.extraConfigLua = /* lua */ ''
    local cmp_autopairs = require "nvim-autopairs.completion.cmp"
    require("cmp").event:on("confirm_done", cmp_autopairs.on_confirm_done())
  '';
}
