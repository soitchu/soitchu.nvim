-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)

-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Force Neovide to re-render after window changes (fixes text erasure with terminal splits)
if vim.g.neovide then
  vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed", "TermLeave" }, {
    callback = function()
      vim.schedule(function()
        vim.cmd("redraw!")
      end)
    end,
  })
end

-- gitsigns' diffthis() registers a BufHidden autocmd that calls
-- nvim_win_get_tabpage() on whichever window was current when the diff opened
-- (gitsigns/actions/diffthis.lua:167). If that window is gone by the time the
-- diff buffer is hidden -- e.g. clicking a barbar tab while focused in the
-- gitsigns:// base buffer -- it throws "Invalid window id". Still unguarded
-- upstream as of 2026-08-11, so swap in an equivalent that tolerates it.
vim.api.nvim_create_autocmd("BufWinEnter", {
  group = vim.api.nvim_create_augroup("gitsigns_diffthis_guard", { clear = true }),
  callback = function(args)
    if not vim.api.nvim_buf_get_name(args.buf):match("^gitsigns://") then
      return
    end

    -- Deferred: gitsigns registers its BufHidden autocmd just *after* the
    -- diffsplit that triggers this BufWinEnter, so run once it exists.
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(args.buf) then
        return
      end

      for _, ac in ipairs(vim.api.nvim_get_autocmds({ event = "BufHidden", buffer = args.buf })) do
        if ac.group_name ~= "gitsigns_diffthis_guard" then
          pcall(vim.api.nvim_del_autocmd, ac.id)
        end
      end

      vim.api.nvim_create_autocmd("BufHidden", {
        buffer = args.buf,
        group = "gitsigns_diffthis_guard",
        callback = function()
          -- Once no gitsigns:// buffer is on screen in this tabpage, the diff
          -- is over: clear 'diff' on the windows that are left. Never touch a
          -- diffview tab, which manages its own diff windows.
          local tab = vim.api.nvim_get_current_tabpage()
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
            if name:match("^gitsigns://") or name:match("^diffview://") then
              return
            end
          end
          for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
            if vim.api.nvim_win_is_valid(win) and vim.wo[win].diff then
              vim.wo[win].diff = false
            end
          end
        end,
      })
    end)
  end,
})

-- VS Code-style selection highlight: while a charwise selection sits on one
-- line, mark the other occurrences of that exact text in the visible part of
-- the window. Only the visible lines are scanned, so it stays cheap on big
-- files; scrolling re-runs it.
local selection_ns = vim.api.nvim_create_namespace("selection_matches")

-- VS Code's selectionHighlightBackground (#ADD6FF26) over the editor background.
local function set_selection_match_hl()
  vim.api.nvim_set_hl(0, "SelectionMatch", { bg = "#3a3f45", default = true })
end
set_selection_match_hl()

local function highlight_selection_matches()
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_clear_namespace(buf, selection_ns, 0, -1)
  if vim.fn.mode() ~= "v" then
    return
  end
  local v, c = vim.fn.getpos("v"), vim.fn.getpos(".")
  if v[2] ~= c[2] then
    return
  end
  local text = vim.fn.getregion(v, c, { type = "v" })[1]
  if not text or #text < 2 or not text:find("%S") then
    return
  end

  local sel_row, sel_col = v[2] - 1, math.min(v[3], c[3]) - 1
  local first, last = vim.fn.line("w0"), vim.fn.line("w$")
  for i, line in ipairs(vim.api.nvim_buf_get_lines(buf, first - 1, last, false)) do
    local row, from = first + i - 2, 1
    while true do
      local s, e = line:find(text, from, true)
      if not s then
        break
      end
      if row ~= sel_row or s - 1 ~= sel_col then
        vim.api.nvim_buf_set_extmark(buf, selection_ns, row, s - 1, {
          end_col = e,
          hl_group = "SelectionMatch",
          priority = 150,
        })
      end
      from = e + 1
    end
  end
end

local selection_group = vim.api.nvim_create_augroup("selection_matches", { clear = true })
vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "WinScrolled" }, {
  group = selection_group,
  callback = highlight_selection_matches,
})
vim.api.nvim_create_autocmd("ColorScheme", {
  group = selection_group,
  callback = set_selection_match_hl,
})
