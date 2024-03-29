{ config, lib, ... }:
let
  colors = import ../colors.nix { inherit config lib; };
in
{
  programs.nixvim.plugins.treesitter.enable = true;

  programs.nixvim.keymaps = [
    { key = "<leader>ts"; action = "<cmd>TSBufToggle highlight<CR>"; options = { desc = "toggle tree sitter syntax highlighting"; }; mode = [ "n" ]; }
  ];

  programs.nixvim.highlight = {
    Boolean = { fg = colors.base09; };
    Character = { fg = colors.base08; };
    Conditional = { fg = colors.base0E; };
    Constant = { fg = colors.base08; };
    Define = { fg = colors.base0E; sp = "none"; };
    Delimiter = { fg = colors.base0F; };
    Float = { fg = colors.base09; };
    Variable = { fg = colors.base05; };
    Function = { fg = colors.base0D; };
    Identifier = { fg = colors.base08; sp = "none"; };
    Include = { fg = colors.base0D; };
    Keyword = { fg = colors.base0E; };
    Label = { fg = colors.base0A; };
    Number = { fg = colors.base09; };
    Operator = { fg = colors.base05; sp = "none"; };
    PreProc = { fg = colors.base0A; };
    Repeat = { fg = colors.base0A; };
    Special = { fg = colors.base0C; };
    SpecialChar = { fg = colors.base0F; };
    Statement = { fg = colors.base08; };
    StorageClass = { fg = colors.base0A; };
    String = { fg = colors.base0B; };
    Structure = { fg = colors.base0E; };
    Tag = { fg = colors.base0A; };
    Todo = { fg = colors.base0A; bg = colors.base01; };
    Type = { fg = colors.base0A; sp = "none"; };
    Typedef = { fg = colors.base0A; };

    TodoBgFix = { fg = colors.black2; bg = colors.red; bold = true; };
    TodoBgHack = { fg = colors.black2; bg = colors.orange; bold = true; };
    TodoBgNote = { fg = colors.black2; bg = colors.white; bold = true; };
    TodoBgPerf = { fg = colors.black2; bg = colors.purple; bold = true; };
    TodoBgTest = { fg = colors.black2; bg = colors.purple; bold = true; };
    TodoBgTodo = { fg = colors.black2; bg = colors.yellow; bold = true; };
    TodoBgWarn = { fg = colors.orange; bold = true; };
    TodoFgFix = { fg = colors.red; };
    TodoFgHack = { fg = colors.orange; };
    TodoFgNote = { fg = colors.white; };
    TodoFgPerf = { fg = colors.purple; };
    TodoFgTest = { fg = colors.purple; };
    TodoFgTodo = { fg = colors.yellow; };
    TodoFgWarn = { fg = colors.orange; };
    TodoSignFix = { link = "TodoFgFix"; };
    TodoSignHack = { link = "TodoFgHack"; };
    TodoSignNote = { link = "TodoFgNote"; };
    TodoSignPerf = { link = "TodoFgPerf"; };
    TodoSignTest = { link = "TodoFgTest"; };
    TodoSignTodo = { link = "TodoFgTodo"; };
    TodoSignWarn = { link = "TodoFgWarn"; };


    "@variable" = { fg = colors.base05; };
    "@variable.builtin" = { fg = colors.base09; };
    "@variable.parameter" = { fg = colors.base08; };
    "@variable.member" = { fg = colors.base08; };
    "@variable.member.key" = { fg = colors.base08; };

    "@module" = { fg = colors.base08; };

    "@constant" = { fg = colors.base08; };
    "@constant.builtin" = { fg = colors.base09; };
    "@constant.macro" = { fg = colors.base08; };

    "@string" = { fg = colors.base0B; };
    "@string.regex" = { fg = colors.base0C; };
    "@string.escape" = { fg = colors.base0C; };
    "@character" = { fg = colors.base08; };

    "@number" = { fg = colors.base09; };
    "@number.float" = { fg = colors.base09; };

    "@annotation" = { fg = colors.base0F; };
    "@attribute" = { fg = colors.base0A; };
    "@error" = { fg = colors.base08; };

    "@keyword.exception" = { fg = colors.base08; };
    "@keyword" = { fg = colors.base0E; };
    "@keyword.function" = { fg = colors.base0E; };
    "@keyword.return" = { fg = colors.base0E; };
    "@keyword.operator" = { fg = colors.base0E; };
    "@keyword.import" = { link = "Include"; };
    "@keyword.conditional" = { fg = colors.base0E; };
    "@keyword.conditional.ternary" = { fg = colors.base0E; };
    "@keyword.repeat" = { fg = colors.base0A; };
    "@keyword.storage" = { fg = colors.base0A; };
    "@keyword.directive.define" = { fg = colors.base0E; };
    "@keyword.directive" = { fg = colors.base0A; };

    "@function" = { fg = colors.base0D; };
    "@function.builtin" = { fg = colors.base0D; };
    "@function.macro" = { fg = colors.base08; };
    "@function.call" = { fg = colors.base0D; };
    "@function.method" = { fg = colors.base0D; };
    "@function.method.call" = { fg = colors.base0D; };
    "@constructor" = { fg = colors.base0C; };

    "@operator" = { fg = colors.base05; };
    "@reference" = { fg = colors.base05; };
    "@punctuation.bracket" = { fg = colors.base0F; };
    "@punctuation.delimiter" = { fg = colors.base0F; };
    "@symbol" = { fg = colors.base0B; };
    "@tag" = { fg = colors.base0A; };
    "@tag.attribute" = { fg = colors.base08; };
    "@tag.delimiter" = { fg = colors.base0F; };
    "@text" = { fg = colors.base05; };
    "@text.emphasis" = { fg = colors.base09; };
    "@text.strike" = { fg = colors.base0F; strikethrough = true; };
    "@type.builtin" = { fg = colors.base0A; };
    "@definition" = { sp = colors.base04; underline = true; };
    "@scope" = { bold = true; };
    "@property" = { fg = colors.base08; };

    "@markup.heading" = { fg = colors.base0D; };
    "@markup.raw" = { fg = colors.base09; };
    "@markup.link" = { fg = colors.base08; };
    "@markup.link.url" = { fg = colors.base09; underline = true; };
    "@markup.link.label" = { fg = colors.base0C; };
    "@markup.list" = { fg = colors.base08; };
    "@markup.strong" = { bold = true; };
    "@markup.italic" = { italic = true; };
    "@markup.strikethrough" = { strikethrough = true; };
    "@markup.quote" = { bg = colors.black2; };

    "@comment" = { fg = colors.grey_fg; };
    "@comment.todo" = { fg = colors.grey; bg = colors.white; };
    "@comment.warning" = { fg = colors.black2; bg = colors.base09; };
    "@comment.note" = { fg = colors.black2; bg = colors.white; };
    "@comment.danger" = { fg = colors.black2; bg = colors.red; };

    "@diff.plus" = { fg = colors.green; };
    "@diff.minus" = { fg = colors.red; };
    "@diff.delta" = { fg = colors.light_grey; };
  };
}
