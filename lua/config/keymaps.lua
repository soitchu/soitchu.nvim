-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

vim.keymap.set({ "n", "i", "v" }, "<D-z>", "<cmd>undo<cr>", { desc = "Undo" })
vim.keymap.set({ "n", "i", "v" }, "<D-S-z>", "<cmd>redo<cr>", { desc = "Redo" })
vim.keymap.set("n", "<A-q>", "<cmd>bd<cr>", { desc = "Close buffer" })
vim.keymap.set("v", "<C-f>", "y/<C-r>\"<cr>", { desc = "Search selection in file" })
vim.keymap.set({ "n", "t" }, "<C-`>", function()
  Snacks.terminal.toggle()
  vim.schedule(function()
    vim.cmd("resize +1")
  end)
end, { desc = "Toggle terminal" })
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
vim.keymap.set("v", "<D-v>", '"+p', { desc = "Paste" })
vim.keymap.set("i", "<D-v>", '<C-r>+', { desc = "Paste" })
vim.keymap.set("t", "<D-v>", '<C-\\><C-n>"+pa', { desc = "Paste" })

-- Shift+Arrow selection
vim.keymap.set("n", "<S-Left>", "vh", { desc = "Select left" })
vim.keymap.set("n", "<S-Right>", "vl", { desc = "Select right" })
vim.keymap.set("n", "<S-Up>", "Vk", { desc = "Select up" })
vim.keymap.set("n", "<S-Down>", "Vj", { desc = "Select down" })
vim.keymap.set("v", "<S-Left>", "h", { desc = "Select left" })
vim.keymap.set("v", "<S-Right>", "l", { desc = "Select right" })
vim.keymap.set("v", "<S-Up>", "k", { desc = "Select up" })
vim.keymap.set("v", "<S-Down>", "j", { desc = "Select down" })
vim.keymap.set("i", "<S-Left>", "<Esc>vh", { desc = "Select left" })
vim.keymap.set("i", "<S-Right>", "<Esc>vl", { desc = "Select right" })
vim.keymap.set("i", "<S-Up>", "<Esc>Vk", { desc = "Select up" })
vim.keymap.set("i", "<S-Down>", "<Esc>Vj", { desc = "Select down" })

-- Delete selection with backspace
vim.keymap.set("v", "<BS>", "d", { desc = "Delete selection" })

-- Indent/Outdent
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

  local client = vim.lsp.get_clients({ bufnr = 0 })[1]
  local params = vim.lsp.util.make_position_params(0, client and client.offset_encoding or "utf-16")
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

-- Quick quit
vim.keymap.set("n", "<D-w>", "<cmd>q<cr>", { desc = "Quit" })

-- Delete word backwards
vim.keymap.set("i", "<C-BS>", "<C-w>", { desc = "Delete word backwards" })

-- Toggle comment
vim.keymap.set("v", "<D-/>", "gcgv", { desc = "Toggle comment", remap = true })
vim.keymap.set("i", "<D-/>", "<Esc>gcca", { desc = "Toggle comment", remap = true })

-- Toggle diffview. This lives here rather than in the plugin's `keys` spec
-- because LazyVim maps <leader>gd to the Snacks git_diff picker on VeryLazy,
-- which runs *after* lazy.nvim installs `keys` handlers and would win.
-- config/keymaps.lua is loaded after LazyVim's own keymaps, so this sticks.
vim.keymap.set("n", "<leader>gd", function()
  local ok, lib = pcall(require, "diffview.lib")
  if ok and next(lib.views) then
    vim.cmd("DiffviewClose")
    return
  end

  -- Diffview resolves the repo from the cwd, which under Neovide is wherever
  -- the app was launched from (often ~ or /) rather than a worktree -- hence
  -- "Not a repo (or any parent), or no supported VCS adapter!". Resolve from
  -- the current buffer instead and hand diffview an explicit -C path.
  local name = vim.api.nvim_buf_get_name(0)
  local from = name ~= "" and vim.fs.dirname(name) or (vim.uv or vim.loop).cwd()
  local root = vim.fs.root(from, ".git")

  if not root then
    vim.notify("Not inside a git repository: " .. from, vim.log.levels.WARN)
    return
  end

  -- diffview's arg parser wants `-C=<path>`; `-C <path>` is silently ignored
  vim.cmd("DiffviewOpen -C=" .. vim.fn.fnameescape(root) .. " HEAD")
end, { desc = "Toggle diff view" })

-- Alt + hjkl moves between windows, zellij style. Normal mode only, so
-- LazyVim's <A-j>/<A-k> "move line up/down" still work in insert and visual.
--
-- Horizontally it cascades: move a window if there is one, else step through
-- the barbar buffer tabs, and once you're on the last/first barbar buffer,
-- move to the next/previous tabpage (landing on its nearest window).
local function barbar_index()
  local ok, state = pcall(require, "barbar.state")
  if not ok then
    return nil, 0
  end
  local current = vim.api.nvim_get_current_buf()
  for i, bufnr in ipairs(state.buffers) do
    if bufnr == current then
      return i, #state.buffers
    end
  end
  return nil, #state.buffers
end

---@param direction "h"|"l"
local function nav_horizontal(direction)
  return function()
    local from = vim.api.nvim_get_current_win()
    vim.cmd("wincmd " .. direction)
    if vim.api.nvim_get_current_win() ~= from then
      return -- moved to another window; done
    end

    -- At the edge of the window layout: try the barbar buffers next.
    local index, count = barbar_index()
    local forward = direction == "l"
    if index and (forward and index < count or not forward and index > 1) then
      pcall(vim.cmd, forward and "BufferNext" or "BufferPrevious")
      return
    end

    -- On the last/first barbar buffer: move to the adjacent tabpage and land
    -- on the window nearest the edge we came from.
    if #vim.api.nvim_list_tabpages() < 2 then
      return
    end
    vim.cmd(forward and "tabnext" or "tabprevious")
    vim.cmd("wincmd " .. (forward and "t" or "b"))
  end
end

vim.keymap.set("n", "<A-h>", nav_horizontal("h"), { desc = "Window/buffer/tab left" })
vim.keymap.set("n", "<A-l>", nav_horizontal("l"), { desc = "Window/buffer/tab right" })
vim.keymap.set("n", "<A-j>", "<C-w>j", { desc = "Go to lower window" })
vim.keymap.set("n", "<A-k>", "<C-w>k", { desc = "Go to upper window" })

-- Alt + arrows: macOS-style word jumps horizontally, page scroll vertically.
vim.keymap.set("n", "<A-Left>", "b", { desc = "Previous word" })
vim.keymap.set("n", "<A-Right>", "w", { desc = "Next word" })
vim.keymap.set("n", "<A-Up>", "<C-b>", { desc = "Page up" })
vim.keymap.set("n", "<A-Down>", "<C-f>", { desc = "Page down" })

-- Close barbar tabs that aren't backed by a file on disk: [No Name] scratch
-- buffers and buffers named after a file that was never written. `force`
-- skips the save prompt, so whatever was typed in them is discarded.
-- Real files are left alone, saved or not.
vim.keymap.set("n", "<leader>bA", function()
  Snacks.bufdelete.delete({
    force = true,
    filter = function(buf)
      if not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= "" then
        return false -- unlisted, or a terminal/special buffer
      end
      local name = vim.api.nvim_buf_get_name(buf)
      return name == "" or not (vim.uv or vim.loop).fs_stat(name)
    end,
  })
end, { desc = "Delete Buffers Without a File" })

-- Jump to the active worktree. ~/app/current is a symlink that moves between
-- branches/*, so resolve it each time rather than caching the target.
vim.keymap.set("n", "<leader>gw", function()
  local target = vim.uv.fs_realpath(vim.fn.expand("~/app/current"))
  if not target then
    vim.notify("~/app/current does not resolve", vim.log.levels.WARN)
    return
  end
  vim.cmd.cd(vim.fn.fnameescape(target))
  vim.notify("cwd: " .. vim.fn.fnamemodify(target, ":~"))
end, { desc = "cd to current worktree" })

-- <leader>j/k page down/up, mirroring <A-Down>/<A-Up>.
vim.keymap.set({ "n", "x" }, "<leader>j", "<C-f>", { desc = "Page down" })
vim.keymap.set({ "n", "x" }, "<leader>k", "<C-b>", { desc = "Page up" })
