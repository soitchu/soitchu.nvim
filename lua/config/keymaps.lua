-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set({ "n", "i", "v" }, "<D-z>", "<cmd>undo<cr>", { desc = "Undo" })
vim.keymap.set({ "n", "i", "v" }, "<D-S-z>", "<cmd>redo<cr>", { desc = "Redo" })
vim.keymap.set("n", "<A-q>", "<cmd>bd<cr>", { desc = "Close buffer" })
vim.keymap.set("v", "<C-f>", "y/<C-r>\"<cr>", { desc = "Search selection in file" })
vim.keymap.set({ "n", "t" }, "<C-`>", function() Snacks.terminal.toggle() end, { desc = "Toggle terminal" })
vim.keymap.set("n", "<C-b>", function() Snacks.picker.explorer({ focus = false }) end, { desc = "Toggle explorer" })
vim.keymap.set("n", "<leader>z", "<cmd>set wrap!<cr>", { desc = "Toggle word wrap" })
-- Select all
vim.keymap.set({ "n", "v" }, "<D-a>", "ggVG", { desc = "Select all" })
vim.keymap.set("i", "<D-a>", "<Esc>ggVG", { desc = "Select all" })

-- Copy
vim.keymap.set("n", "<D-c>", '"+yy', { desc = "Copy line" })
vim.keymap.set("v", "<D-c>", '"+y`]', { desc = "Copy" })
vim.keymap.set("i", "<D-c>", '<Esc>"+yya', { desc = "Copy line" })

-- Cut
vim.keymap.set("n", "<D-x>", '"+dd', { desc = "Cut line" })
vim.keymap.set("v", "<D-x>", '"+d', { desc = "Cut" })
vim.keymap.set("i", "<D-x>", '<Esc>"+dda', { desc = "Cut line" })

-- Paste
vim.keymap.set("n", "<D-v>", '"+p', { desc = "Paste" })
vim.keymap.set("v", "<D-v>", '"+p', { desc = "Paste" })
vim.keymap.set("i", "<D-v>", '<C-r>+', { desc = "Paste" })

-- Delete selection with backspace
vim.keymap.set("v", "<BS>", "d", { desc = "Delete selection" })

-- Indent/Outdent
vim.keymap.set("n", "<D-]>", ">>", { desc = "Indent" })
vim.keymap.set("n", "<D-[>", "<<", { desc = "Outdent" })
vim.keymap.set("v", "<D-]>", ">gv", { desc = "Indent" })
vim.keymap.set("v", "<D-[>", "<gv", { desc = "Outdent" })
vim.keymap.set("i", "<D-]>", "<C-t>", { desc = "Indent" })
vim.keymap.set("i", "<D-[>", "<C-d>", { desc = "Outdent" })

-- Save
vim.keymap.set({ "n", "i", "v" }, "<D-s>", "<cmd>w<cr>", { desc = "Save" })

-- Search
vim.keymap.set("n", "<D-f>", "/", { desc = "Search" })
vim.keymap.set("v", "<D-f>", "y/<C-r>\"", { desc = "Search selection" })
vim.keymap.set("i", "<D-f>", "<Esc>/", { desc = "Search" })

-- Alt+Click to find references
vim.keymap.set("n", "<A-LeftMouse>", "<LeftMouse><cmd>Telescope lsp_references<cr>", { desc = "Find references" })
