{ config, ... }:
let
  colors = config.palette;
in
{
  plugins.lspconfig.enable = true;

  # Register defaults for all servers.
  lsp.servers."*".config.capabilities.__raw = ''
    require('cmp_nvim_lsp').default_capabilities()
  '';

  lsp.keymaps = [
    {
      key = "K";
      lspBufAction = "hover";
    }
    {
      key = "gd";
      action.__raw = "require('telescope.builtin').lsp_definitions";
    }
    {
      key = "gD";
      action.__raw = "require('telescope.builtin').lsp_references";
    }
    {
      key = "gi";
      action.__raw = "require('telescope.builtin').lsp_implementations";
    }
    {
      key = "gt";
      action.__raw = "require('telescope.builtin').lsp_type_definitions";
    }
    {
      key = "gE";
      action.__raw = "require('telescope.builtin').diagnostics";
    }
    {
      key = "M";
      action.__raw = "vim.diagnostic.open_float";
    }
  ];

  highlight = {
    LspReferenceText = {
      fg = colors.darker_black;
      bg = colors.white;
    };
    LspReferenceRead = {
      fg = colors.darker_black;
      bg = colors.white;
    };
    LspReferenceWrite = {
      fg = colors.darker_black;
      bg = colors.white;
    };
    DiagnosticHint = {
      fg = colors.purple;
    };
    DiagnosticError = {
      fg = colors.red;
    };
    DiagnosticWarn = {
      fg = colors.yellow;
    };
    DiagnosticInformation = {
      fg = colors.green;
    };
    LspSignatureActiveParameter = {
      fg = colors.black;
      bg = colors.green;
    };
    RenamerTitle = {
      fg = colors.black;
      bg = colors.red;
    };
    RenamerBorder = {
      fg = colors.red;
    };
    SagaBorder = {
      bg = colors.darker_black;
    };
    SagaNormal = {
      bg = colors.darker_black;
    };

    "@lsp.type.class" = {
      link = "Structure";
    };
    "@lsp.type.decorator" = {
      link = "Function";
    };
    "@lsp.type.enum" = {
      link = "Type";
    };
    "@lsp.type.enumMember" = {
      link = "Constant";
    };
    "@lsp.type.function" = {
      link = "@function";
    };
    "@lsp.type.interface" = {
      link = "Structure";
    };
    "@lsp.type.macro" = {
      link = "@macro";
    };
    "@lsp.type.method" = {
      link = "@function.method";
    };
    "@lsp.type.namespace" = {
      link = "@module";
    };
    "@lsp.type.parameter" = {
      link = "@variable.parameter";
    };
    "@lsp.type.property" = {
      link = "@property";
    };
    "@lsp.type.struct" = {
      link = "Structure";
    };
    "@lsp.type.type" = {
      link = "@type";
    };
    "@lsp.type.typeParamater" = {
      link = "TypeDef";
    };
    "@lsp.type.variable" = {
      link = "@variable";
    };
    "@event" = {
      fg = colors.base08;
    };
    "@modifier" = {
      fg = colors.base08;
    };
    "@regexp" = {
      fg = colors.base0F;
    };
  };

  keymaps = [
    {
      key = "<M-CR>";
      action = "<cmd>lua vim.lsp.buf.code_action()<CR>";
      options = {
        desc = "Code Actions";
      };
      mode = [ "n" ];
    }
  ];

  extraConfigLua = # lua
    ''
      vim.diagnostic.config {
        virtual_text = {
          prefix = "",
        },
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = "󰅙",
            [vim.diagnostic.severity.WARN] = "",
            [vim.diagnostic.severity.INFO] = "󰋼",
            [vim.diagnostic.severity.HINT] = "󰌵",
          },
        },
        underline = true,

        float = {
          border = "single",
        },
      }

      vim.o.winborder = "rounded"
    '';
}
