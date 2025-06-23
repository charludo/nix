{ config, ... }:
let
  colors = config.palette;
in
{
  plugins.cmp-nvim-lsp.enable = true;
  plugins.cmp-emoji.enable = true;
  plugins.cmp-latex-symbols.enable = true;

  plugins.cmp = {
    enable = true;
    settings = {
      completion.completeopt = "menu,menuone,noselect";
      completion.keyword_length = 2;

      formatting = {
        fields = [
          "abbr"
          "kind"
          "menu"
        ];
        format = # lua
          ''
            function(_, item)
              local icons = {
                Namespace = "󰌗",
                Text = "󰉿",
                Method = "󰆧",
                Function = "󰆧",
                Constructor = "",
                Field = "󰜢",
                Variable = "󰀫",
                Class = "󰠱",
                Interface = "",
                Module = "",
                Property = "󰜢",
                Unit = "󰑭",
                Value = "󰎠",
                Enum = "",
                Keyword = "󰌋",
                Snippet = "",
                Color = "󰏘",
                File = "󰈚",
                Reference = "󰈇",
                Folder = "󰉋",
                EnumMember = "",
                Constant = "󰏿",
                Struct = "󰙅",
                Event = "",
                Operator = "󰆕",
                TypeParameter = "󰊄",
                Table = "",
                Object = "󰅩",
                Tag = "",
                Array = "[]",
                Boolean = "",
                Number = "",
                Null = "󰟢",
                String = "󰉿",
                Calendar = "",
                Watch = "󰥔",
                Package = "",
                Copilot = "",
                Codeium = "",
                TabNine = "",
              }
              local icon = icons[item.kind] or ""
              icon = " " .. icon .. " "
              item.kind = string.format("%s %s", icon, item.kind or "")
              item.abbr = string.sub(item.abbr, 1, 40)
              item.menu = string.sub(item.menu or "", 1, 60)

              return item
            end
          '';
      };

      mapping = {
        "<C-Space>" = "cmp.mapping.complete()";
        "<C-e>" = "cmp.mapping.close()";
        "<CR>" = # lua
          ''
            cmp.mapping.confirm {
              behavior = cmp.ConfirmBehavior.Insert,
              select = true,
            }
          '';
        "<Tab>" = # lua
          ''
            cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_next_item()
              elseif require("luasnip").expand_or_jumpable() then
                vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-expand-or-jump", true, true, true), "")
              else
                fallback()
              end
            end, {
              "i",
              "s",
            })
          '';
        "<S-Tab>" = # lua
          ''
            cmp.mapping(function(fallback)
              if cmp.visible() then
                cmp.select_prev_item()
              elseif require("luasnip").jumpable(-1) then
                vim.fn.feedkeys(vim.api.nvim_replace_termcodes("<Plug>luasnip-jump-prev", true, true, true), "")
              else
                fallback()
              end
            end, {
              "i",
              "s",
            })
          '';
      };

      preselect = "cmp.PreselectMode.Item"; # let's see if this stops autoselection!
      sources = [
        {
          name = "nvim_lsp";
          priority = 6;
          entry_filter = # lua
            ''
              function(entry, _)
                return require("cmp.types").lsp.CompletionItemKind[entry:get_kind()] ~= "Text"
              end
            '';
        }
        {
          name = "luasnip";
          priority = 4;
        }
        {
          name = "emoji";
          priority = 5;
        }
        {
          name = "latex_symbols";
          priority = 5;
        }
        {
          name = "rust_analyzer";
          priority = 6;
        }
        {
          name = "buffer";
          priority = 3;
        }
        {
          name = "nvim_lua";
          priority = 4;
        }
        {
          name = "path";
          priority = 5;
        }
      ];

      snippet.expand = # lua
        ''
          function(args)
            require("luasnip").lsp_expand(args.body)
          end
        '';

      window = {
        completion = {
          side_padding = 1;
          winhighlight = "Normal:CmpPmenu,CursorLine:CmpSel,Search:None";
          scrollbar = false;
          border = {
            __raw = ''
              {
                { "╭", "CmpBorder" },
                { "─", "CmpBorder" },
                { "╮", "CmpBorder" },
                { "│", "CmpBorder" },
                { "╯", "CmpBorder" },
                { "─", "CmpBorder" },
                { "╰", "CmpBorder" },
                { "│", "CmpBorder" },
              }
            '';
          };
        };
        documentation = {
          border = {
            __raw = ''
              {
                { "╭", "CmpDocBorder" },
                { "─", "CmpDocBorder" },
                { "╮", "CmpDocBorder" },
                { "│", "CmpDocBorder" },
                { "╯", "CmpDocBorder" },
                { "─", "CmpDocBorder" },
                { "╰", "CmpDocBorder" },
                { "│", "CmpDocBorder" },
              }
            '';
          };
          winhighlight = "Normal:CmpDoc";
        };
      };
    };
  };

  opts.pumheight = 5;

  highlight = {
    CmpItemAbbr = {
      fg = colors.white;
    };
    CmpItemAbbrMatch = {
      fg = colors.blue;
      bold = true;
    };
    CmpDoc = {
      bg = colors.black2;
    };
    CmpDocBorder = {
      fg = colors.black2;
      bg = colors.black2;
    };
    CmpPmenu = {
      bg = colors.darker_black;
    };
    CmpSel = {
      link = "PmenuSel";
      bold = true;
    };
    CmpBorder = {
      fg = colors.darker_black;
      bg = colors.darker_black;
    };

    CmpItemKindConstant = {
      fg = colors.base09;
    };
    CmpItemKindFunction = {
      fg = colors.base0D;
    };
    CmpItemKindIdentifier = {
      fg = colors.base08;
    };
    CmpItemKindField = {
      fg = colors.base08;
    };
    CmpItemKindVariable = {
      fg = colors.base0E;
    };
    CmpItemKindSnippet = {
      fg = colors.red;
    };
    CmpItemKindText = {
      fg = colors.base0B;
    };
    CmpItemKindStructure = {
      fg = colors.base0E;
    };
    CmpItemKindType = {
      fg = colors.base0A;
    };
    CmpItemKindKeyword = {
      fg = colors.base07;
    };
    CmpItemKindMethod = {
      fg = colors.base0D;
    };
    CmpItemKindConstructor = {
      fg = colors.blue;
    };
    CmpItemKindFolder = {
      fg = colors.base07;
    };
    CmpItemKindModule = {
      fg = colors.base0A;
    };
    CmpItemKindProperty = {
      fg = colors.base08;
    };
    CmpItemKindEnum = {
      fg = colors.blue;
    };
    CmpItemKindUnit = {
      fg = colors.base0E;
    };
    CmpItemKindClass = {
      fg = colors.teal;
    };
    CmpItemKindFile = {
      fg = colors.base07;
    };
    CmpItemKindInterface = {
      fg = colors.green;
    };
    CmpItemKindColor = {
      fg = colors.white;
    };
    CmpItemKindReference = {
      fg = colors.base05;
    };
    CmpItemKindEnumMember = {
      fg = colors.purple;
    };
    CmpItemKindStruct = {
      fg = colors.base0E;
    };
    CmpItemKindValue = {
      fg = colors.cyan;
    };
    CmpItemKindEvent = {
      fg = colors.yellow;
    };
    CmpItemKindOperator = {
      fg = colors.base05;
    };
    CmpItemKindTypeParameter = {
      fg = colors.base08;
    };
    CmpItemKindCopilot = {
      fg = colors.green;
    };
    CmpItemKindCodeium = {
      fg = colors.vibrant_green;
    };
    CmpItemKindTabNine = {
      fg = colors.baby_pink;
    };
  };
}
