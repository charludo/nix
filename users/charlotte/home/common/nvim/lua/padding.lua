function IncreasePadding()
  Sad("40", 0, 15, "~/.config/alacritty/alacritty.toml")
  Sad("41", 0, 15, "~/.config/alacritty/alacritty.toml")
end

function DecreasePadding()
  Sad("40", 15, 0, "~/.config/alacritty/alacritty.toml")
  Sad("41", 15, 0, "~/.config/alacritty/alacritty.toml")
end

function Sad(line_nr, from, to, fname)
  vim.cmd(string.format("silent !sed -i '%ss/%s/%s/' %s", line_nr, from, to, fname))
end

vim.api.nvim_exec(
  [[
  augroup ChangeAlacrittyPadding
   au!
   au VimLeavePre * lua IncreasePadding()
   au VimEnter * lua DecreasePadding()
  augroup END
]],
  false
)
