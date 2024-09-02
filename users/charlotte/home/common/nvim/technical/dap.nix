# shamelessly stolen from: https://github.com/redyf/Neve/blob/main/config/dap/dap.nix
{ config, lib, ... }:
let
  colors = import ../colors.nix { inherit config lib; };
in
{
  programs.nixvim.plugins.dap = {
    enable = true;
    signs = {
      dapBreakpoint = { text = "●"; texthl = "DapBreakpoint"; };
      dapBreakpointCondition = { text = "●"; texthl = "DapBreakpointCondition"; };
      dapLogPoint = { text = "◆"; texthl = "DapLogPoint"; };
    };
    extensions = {
      dap-python = {
        enable = true;
      };
      dap-ui = {
        enable = true;
        floating.mappings = {
          close = [ "<ESC>" "q" ];
        };
      };
      dap-virtual-text = {
        enable = true;
      };
    };
    configurations = { };
  };

  programs.nixvim.keymaps = [
    { mode = "n"; key = "<leader>dB"; action = "<cmd>lua require('dap').set_breakpoint(vim.fn.input('Breakpoint condition: '))<cr>"; options = { silent = true; desc = "Breakpoint Condition"; }; }
    { mode = "n"; key = "<leader>db"; action = "<cmd>DapToggleBreakpoint<cr>"; options = { silent = true; desc = "Toggle Breakpoint"; }; }
    { mode = "n"; key = "<leader>dr"; action = "<cmd>DapContinue<cr>"; options = { silent = true; desc = "Start or Continue"; }; }
    { mode = "n"; key = "<leader>du"; action = "<cmd>lua require('dapui').toggle()<cr>"; options = { silent = true; desc = "Dap UI"; }; }
  ];

  programs.nixvim.extraConfigLua = /* lua */ ''
    local dap = require "dap"
    local dapui = require "dapui"
    dapui.setup()
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end
  '';

  programs.nixvim.highlight = {
    DapBreakpoint = { fg = colors.red; };
    DapBreakpointCondition = { fg = colors.yellow; };
    DapLogPoint = { fg = colors.cyan; };
    DapStopped = { fg = colors.baby_pink; };

    DAPUIScope = { fg = colors.cyan; };
    DAPUIType = { fg = colors.dark_purple; };
    DAPUIValue = { fg = colors.cyan; };
    DAPUIVariable = { fg = colors.white; };
    DapUIModifiedValue = { fg = colors.orange; };
    DapUIDecoration = { fg = colors.cyan; };
    DapUIThread = { fg = colors.green; };
    DapUIStoppedThread = { fg = colors.cyan; };
    DapUISource = { fg = colors.purple; };
    DapUILineNumber = { fg = colors.cyan; };
    DapUIFloatBorder = { fg = colors.cyan; };

    DapUIWatchesEmpty = { fg = colors.baby_pink; };
    DapUIWatchesValue = { fg = colors.green; };
    DapUIWatchesError = { fg = colors.baby_pink; };

    DapUIBreakpointsPath = { fg = colors.cyan; };
    DapUIBreakpointsInfo = { fg = colors.green; };
    DapUIBreakPointsCurrentLine = { fg = colors.green; bold = true; };
    DapUIBreakpointsDisabledLine = { fg = colors.grey_fg2; };

    DapUIStepOver = { fg = colors.blue; };
    DapUIStepOverNC = { fg = colors.blue; };
    DapUIStepInto = { fg = colors.blue; };
    DapUIStepIntoNC = { fg = colors.blue; };
    DapUIStepBack = { fg = colors.blue; };
    DapUIStepBackNC = { fg = colors.blue; };
    DapUIStepOut = { fg = colors.blue; };
    DapUIStepOutNC = { fg = colors.blue; };
    DapUIStop = { fg = colors.red; };
    DapUIStopNC = { fg = colors.red; };
    DapUIPlayPause = { fg = colors.green; };
    DapUIPlayPauseNC = { fg = colors.green; };
    DapUIRestart = { fg = colors.green; };
    DapUIRestartNC = { fg = colors.green; };
    DapUIUnavailable = { fg = colors.grey_fg; };
    DapUIUnavailableNC = { fg = colors.grey_fg; };
  };
}
