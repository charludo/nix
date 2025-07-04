{ config, ... }:
let
  colors = config.palette;
in
{
  extraConfigLua = # lua
    ''
      -- The following is largely copied from:
      -- https://github.com/NvChad/ui/blob/af9ab0cd9e193c68c443939fa7e4b8213db5693b/lua/nvchad/term/init.lua
      -- because frankly, it's the best in-neovim-terminal solution and should really be a standalone plugin
      local api = vim.api
      local g = vim.g
      local set_buf = api.nvim_set_current_buf

      g.nvchad_terms = {}

      local pos_data = {
        sp = { resize = "height", area = "lines" },
        vsp = { resize = "width", area = "columns" },
      }

      local config = {
        hl = "Normal:term,WinSeparator:WinSeparator",
        sizes = { sp = 0.3, vsp = 0.2 },
        float = {
          relative = "editor",
          row = 0.3,
          col = 0.25,
          width = 0.5,
          height = 0.4,
          border = "single",
        }
      }

      -- used for initially resizing terms
      vim.g.nvhterm = false
      vim.g.nvvterm = false

      -------------------------- util funcs -----------------------------
      local function chadterm_save_term_info(index, val)
        local terms_list = g.nvchad_terms
        terms_list[tostring(index)] = val
        g.nvchad_terms = terms_list
      end

      local function chadterm_opts_to_id(id)
        for _, opts in pairs(g.nvchad_terms) do
          if opts.id == id then
            return opts
          end
        end
      end

      local function chadterm_calc_float_opts(float_opts)
        local opts = vim.tbl_deep_extend("force", config.float, float_opts or {})
        local min_width = 120
        local min_padding = 1
        local min_feasible_width = math.min(min_width, vim.o.columns - 2 * min_padding)

        opts.width = math.max(min_feasible_width, math.ceil(opts.width * vim.o.columns))
        opts.height = math.ceil(opts.height * vim.o.lines)
        opts.row = math.ceil(opts.row * vim.o.lines)
        opts.col = 0.5 * (vim.o.columns - opts.width)

        return opts
      end

      local function chadterm_create_float(buffer, float_opts)
        local opts = chadterm_calc_float_opts(float_opts)
        vim.api.nvim_open_win(buffer, true, opts)
      end

      local function chadterm_format_cmd(cmd)
        return type(cmd) == "string" and cmd or cmd()
      end

      local function chadterm_display(opts)
        if opts.pos == "float" then
          chadterm_create_float(opts.buf, opts.float_opts)
        else
          vim.cmd(opts.pos)
        end

        local win = api.nvim_get_current_win()
        opts.win = win

        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].foldcolumn = "0"
        vim.wo[win].signcolumn = "no"
        vim.bo[opts.buf].buflisted = false
        vim.wo[win].winhl = opts.hl or config.hl
        vim.cmd "startinsert"

        -- resize non floating wins initially + or only when they're toggleable
        if (opts.pos == "sp" and not vim.g.nvhterm) or (opts.pos == "vsp" and not vim.g.nvvterm) or (opts.pos ~= "float") then
          local pos_type = pos_data[opts.pos]
          local size = opts.size and opts.size or config.sizes[opts.pos]
          local new_size = vim.o[pos_type.area] * size
          api["nvim_win_set_" .. pos_type.resize](0, math.floor(new_size))
        end

        api.nvim_win_set_buf(win, opts.buf)
      end

      local function chadterm_create(opts)
        local buf_exists = opts.buf
        opts.buf = opts.buf or vim.api.nvim_create_buf(false, true)

        -- handle cmd opt
        local shell = vim.o.shell
        local cmd = shell

        if opts.cmd and opts.buf then
          cmd = { shell, "-c", chadterm_format_cmd(opts.cmd) .. "; " .. shell }
        end

        chadterm_display(opts)

        chadterm_save_term_info(opts.buf, opts)

        if not buf_exists then
          vim.fn.termopen(cmd)
        end

        vim.g.nvhterm = opts.pos == "sp"
        vim.g.nvvterm = opts.pos == "vsp"
      end

      --------------------------- user api -------------------------------
      chadterm_new = function(opts)
        chadterm_create(opts)
      end

      chadterm_toggle = function(opts)
        local x = chadterm_opts_to_id(opts.id)
        opts.buf = x and x.buf or nil

        if (x == nil or not api.nvim_buf_is_valid(x.buf)) or vim.fn.bufwinid(x.buf) == -1 then
          chadterm_create(opts)
        else
          api.nvim_win_close(x.win, true)
        end
      end

      -- spawns term with *cmd & runs the *cmd if the keybind is run again
      chadterm_runner = function(opts)
        local x = chadterm_opts_to_id(opts.id)
        local clear_cmd = opts.clear_cmd or "clear; "
        opts.buf = x and x.buf or nil

        -- if buf doesn't exist
        if x == nil then
          chadterm_create(opts)
        else
          -- window isn't visible 
          if vim.fn.bufwinid(x.buf) == -1 then
            chadterm_display(opts)
          end

          local cmd = chadterm_format_cmd(opts.cmd)

          if x.buf == api.nvim_get_current_buf() then
            set_buf(g.buf_history[#g.buf_history -1])
            cmd = chadterm_format_cmd(opts.cmd)
            set_buf(x.buf)
          end

          local job_id = vim.b[x.buf].terminal_job_id
          vim.api.nvim_chan_send(job_id, clear_cmd .. cmd .. " \n")
        end
      end

      --------------------------- autocmds -------------------------------
      api.nvim_create_autocmd("TermClose", {
        callback = function(args)
          vim.api.nvim_input("<CR>")
          chadterm_save_term_info(args.buf, nil)
        end,
      })

      api.nvim_create_autocmd("VimResized", {
        callback = function()
          for _, term in pairs(g.nvchad_terms) do
            if term and term.pos == "float" and term.win and api.nvim_win_is_valid(term.win) then
              local float_opts = vim.tbl_deep_extend("force", config.float, term.float_opts or {})
              local opts = chadterm_calc_float_opts(float_opts)
              pcall(api.nvim_win_set_config, term.win, opts)
            end
          end
        end,
      })
    '';

  keymaps = [
    {
      mode = [ "n" ];
      key = "<leader>h";
      action = "<cmd>lua chadterm_new { pos = 'sp', size = 0.4 }<cr>";
      options = {
        desc = "Terminal New horizontal term";
      };
    }
    {
      mode = [ "n" ];
      key = "<leader>v";
      action = "<cmd>lua chadterm_new { pos = 'vsp', size = 0.4 }<cr>";
      options = {
        desc = "Terminal New vertical window";
      };
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "<A-v>";
      action = "<cmd>lua chadterm_toggle { pos = 'vsp', id = 'vtoggleTerm', size = 0.4 }<cr>";
      options = {
        desc = "Terminal Toggleable vertical term";
      };
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "<A-h>";
      action = "<cmd>lua chadterm_toggle { pos = 'sp', id = 'htoggleTerm', size = 0.4 }<cr>";
      options = {
        desc = "Terminal New horizontal term";
      };
    }
    {
      mode = [
        "n"
        "t"
      ];
      key = "<A-i>";
      action = "<cmd>lua chadterm_toggle { pos = 'float', id = 'floatTerm' }<cr>";
      options = {
        desc = "Terminal Toggle Floating term";
      };
    }
  ];

  globals = {
    terminal_color_0 = colors.base01;
    terminal_color_1 = colors.base08;
    terminal_color_2 = colors.base0B;
    terminal_color_3 = colors.base0A;
    terminal_color_4 = colors.base0D;
    terminal_color_5 = colors.base0E;
    terminal_color_6 = colors.base0C;
    terminal_color_7 = colors.base05;
    terminal_color_8 = colors.base03;
    terminal_color_9 = colors.base08;
    terminal_color_10 = colors.base0B;
    terminal_color_11 = colors.base0A;
    terminal_color_12 = colors.base0D;
    terminal_color_13 = colors.base0E;
    terminal_color_14 = colors.base0C;
    terminal_color_15 = colors.base07;
  };
}
