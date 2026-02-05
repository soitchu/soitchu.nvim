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

-- Ctrl+Click: go to definition, or show references if already at definition
vim.keymap.set("n", "<C-LeftMouse>", function()
  -- Move cursor to mouse position
  local mouse = vim.fn.getmousepos()
  if mouse.winid ~= 0 then
    vim.api.nvim_set_current_win(mouse.winid)
    vim.api.nvim_win_set_cursor(mouse.winid, { mouse.line, mouse.column - 1 })
  end

  local params = vim.lsp.util.make_position_params()
  local current_pos = vim.api.nvim_win_get_cursor(0)
  local current_file = vim.api.nvim_buf_get_name(0)

  vim.lsp.buf_request(0, "textDocument/definition", params, function(err, result)
    if err or not result or vim.tbl_isempty(result) then
      vim.cmd("Telescope lsp_references")
      return
    end

    local def = result[1] or result
    local def_uri = def.uri or def.targetUri
    local def_range = def.range or def.targetSelectionRange

    if def_uri and def_range then
      local def_file = vim.uri_to_fname(def_uri)
      local def_line = def_range.start.line + 1

      if def_file == current_file and def_line == current_pos[1] then
        vim.cmd("Telescope lsp_references")
      else
        vim.lsp.buf.definition()
      end
    else
      vim.lsp.buf.definition()
    end
  end)
end, { desc = "Go to definition or references" })

-- Ctrl+P to open file finder
vim.keymap.set("n", "<C-p>", "<leader><leader>", { desc = "Find files", remap = true })
