-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Show hidden files in netrw
vim.g.netrw_hide = 0
vim.g.netrw_list_hide = ""

-- Neovide font
vim.o.guifont = "JetBrainsMono Nerd Font:h14"

-- On macOS, Option composes special characters by default (h/j/k/l become
-- ˙∆˚¬), so <A-...> mappings never reach Neovim. Send Meta instead.
-- Values: "only_left", "only_right", "both", "none".
vim.g.neovide_input_macos_option_key_is_meta = "both"

-- Neovide padding (makes tabs and UI taller)
vim.g.neovide_padding_top = 12
vim.g.neovide_padding_bottom = 4

-- Don't move cursor when scrolling
vim.o.scrolloff = 0

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
