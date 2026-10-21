-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Show hidden files in netrw
vim.g.netrw_hide = 0
vim.g.netrw_list_hide = ""

-- Neovide font
vim.o.guifont = "3270 Nerd Font Mono:h16"

-- On macOS, Option composes special characters by default (h/j/k/l become
-- ˙∆˚¬), so <A-...> mappings never reach Neovim. Send Meta instead.
-- Values: "only_left", "only_right", "both", "none".
vim.g.neovide_input_macos_option_key_is_meta = "both"

-- Neovide padding (makes tabs and UI taller)
vim.g.neovide_padding_top = 12
vim.g.neovide_padding_bottom = 4

-- Don't move cursor when scrolling
vim.o.scrolloff = 0

-- One line per wheel tick so trackpad scrolling looks smooth (snacks.scroll
-- deliberately doesn't animate mouse scrolls)
vim.o.mousescroll = "ver:1,hor:2"

-- Neovim doesn't detect .mdx at all, and nvim-treesitter ships no mdx parser.
-- Treat it as markdown (the compound filetype still lets `mdx` ftplugins and
-- LSP configs target it) and point treesitter at the markdown parser.
vim.filetype.add({ extension = { mdx = "markdown.mdx" } })
vim.treesitter.language.register("markdown", "mdx")

-- LazyVim's typescript extra now picks the TS server from this variable and
-- force-sets `enabled` on tsserver/ts_ls/vtsls/tsgo to match, overriding
-- anything set in lua/plugins/lsp.lua. Without this it defaults to vtsls and
-- tsgo is never configured or enabled.
vim.g.lazyvim_ts_lsp = "tsgo"

-- Clipboard over SSH. Neovim runs on a Linux box with the UI attached over SSH,
-- and the box has no clipboard of its own, so yanks never reached the Mac.
-- Send copies to the local terminal as OSC 52 instead; WezTerm puts them on
-- the system clipboard. WezTerm doesn't answer OSC 52 *paste* requests (Neovim
-- would hang waiting), so `p` pastes the last thing yanked here, and text
-- copied on the Mac goes in with Cmd+V, which the terminal types in.
local has_clipboard_tool = vim.fn.has("mac") == 1
  or vim.fn.executable("wl-copy") == 1
  or vim.fn.executable("xclip") == 1
  or vim.fn.executable("xsel") == 1
if not has_clipboard_tool then
  local osc52 = require("vim.ui.clipboard.osc52")
  local last = { {}, "v" } -- shared by + and *, like a real clipboard

  local function copy(reg)
    local send = osc52.copy(reg)
    return function(lines, regtype)
      last = { lines, regtype }
      send(lines)
    end
  end

  local function paste()
    return last
  end

  vim.g.clipboard = {
    name = "osc52-copy",
    copy = { ["+"] = copy("+"), ["*"] = copy("*") },
    paste = { ["+"] = paste, ["*"] = paste },
  }
end
