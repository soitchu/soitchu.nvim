-- VS Code-style find/replace widget for the current buffer: two single-line
-- floating inputs pinned to the top-right of the window, live match
-- highlighting with an "N of M" counter, and replace-one / replace-all.
-- Opened from config/keymaps.lua.
--
-- It drives Vim's own search, so after closing, `n`/`N` keep stepping through
-- the same matches and the highlight behaves exactly like after `/`.
local M = {}

local ns = vim.api.nvim_create_namespace("find_replace")
local group = vim.api.nvim_create_augroup("find_replace", { clear = true })

-- Toggles and the last inputs survive between openings, like VS Code's.
local opts = { case = false, word = false, regex = false }
local last_find, last_replace = "", ""

---@type { target_win: integer, target_buf: integer, origin: integer[], find: { buf: integer, win: integer }, replace: { buf: integer, win: integer } }?
local state

local function text(buf)
  local ok, lines = pcall(vim.api.nvim_buf_get_lines, buf, 0, 1, false)
  return ok and lines[1] or ""
end

-- Backslash-escape every char in `chars`, leaving existing `\x` pairs alone so
-- an already-escaped `\/` in a regex isn't escaped twice.
local function escape(s, chars)
  local out, i = {}, 1
  while i <= #s do
    local c = s:sub(i, i)
    if c == "\\" then
      out[#out + 1] = s:sub(i, i + 1)
      i = i + 2
    else
      out[#out + 1] = chars:find(c, 1, true) and "\\" .. c or c
      i = i + 1
    end
  end
  return table.concat(out)
end

-- The Vim search pattern for the find input, or nil when it's empty. Regex
-- mode uses very-magic (`\v`), the closest Vim gets to JS regex syntax.
local function pattern()
  local find = text(state.find.buf)
  if find == "" then
    return nil
  end
  local body
  if opts.regex then
    body = "\\v" .. (opts.word and "<(" .. find .. ")>" or find)
  else
    local literal = (find:gsub("\\", "\\\\"))
    body = "\\V" .. (opts.word and "\\<" .. literal .. "\\>" or literal)
  end
  return (opts.case and "\\C" or "\\c") .. body
end

-- The replace input as a `:s` replacement. Literal mode escapes everything
-- `:s` treats specially; regex mode keeps `\1`/`&` and also accepts VS Code's
-- `$1`.
local function replacement()
  local rep = text(state.replace.buf)
  if opts.regex then
    return escape((rep:gsub("%$(%d)", "\\%1")), "/~")
  end
  return escape((rep:gsub("\\", "\\\\")), "/&~")
end

local function in_target(fn)
  return vim.api.nvim_win_call(state.target_win, fn)
end

local function is_ours(win)
  return state ~= nil and (win == state.find.win or win == state.replace.win)
end

-- Put the target cursor on the match covering `origin`, else the next one.
local function jump_from_origin(pat)
  vim.api.nvim_win_set_cursor(0, state.origin)
  local start = vim.fn.searchpos(pat, "bcW")
  if start[1] ~= 0 then
    local finish = vim.fn.searchpos(pat, "cneW")
    local o = { state.origin[1], state.origin[2] + 1 }
    if finish[1] > o[1] or (finish[1] == o[1] and finish[2] >= o[2]) then
      return
    end
  end
  vim.api.nvim_win_set_cursor(0, state.origin)
  vim.fn.search(pat, "cw")
end

-- Refresh the search highlight, the current-match highlight and the counter.
-- `jump` re-runs the incremental search from where the widget was opened.
local function update(jump)
  if not state then
    return
  end
  vim.api.nvim_buf_clear_namespace(state.target_buf, ns, 0, -1)

  local pat = pattern()
  local status, status_hl = "No results", "Comment"
  if not pat then
    vim.v.hlsearch = 0
  else
    local ok, count = pcall(in_target, function()
      if jump then
        jump_from_origin(pat)
      end
      local count = vim.fn.searchcount({ pattern = pat, maxcount = 0 })

      -- Searching only highlights the current match in the focused window,
      -- so mark the one under the target cursor ourselves.
      local cur = vim.api.nvim_win_get_cursor(0)
      local s = vim.fn.searchpos(pat, "cnW")
      if s[1] == cur[1] and s[2] == cur[2] + 1 then
        local e = vim.fn.searchpos(pat, "cneW")
        local line = vim.fn.getline(e[1])
        pcall(vim.api.nvim_buf_set_extmark, state.target_buf, ns, s[1] - 1, s[2] - 1, {
          end_row = e[1] - 1,
          end_col = math.min(#line, e[2] + vim.str_utf_end(line, e[2])),
          hl_group = "IncSearch",
          priority = 2000,
        })
      end
      return count
    end)

    if not ok or not count.total then
      status, status_hl = "Invalid pattern", "DiagnosticError"
      vim.v.hlsearch = 0
    else
      vim.fn.setreg("/", pat)
      vim.v.hlsearch = 1
      if count.total > 0 then
        status, status_hl = ("%d of %d"):format(count.current, count.total), "FloatFooter"
      end
    end
  end

  local function toggle(label, on)
    return { " " .. label .. " ", on and "Special" or "NonText" }
  end
  vim.api.nvim_win_set_config(state.find.win, {
    footer = {
      { " " .. status .. " ", status_hl },
      toggle("Aa", opts.case),
      toggle("ab", opts.word),
      toggle(".*", opts.regex),
    },
    footer_pos = "right",
  })
end

local function step(flags)
  local pat = pattern()
  if not pat then
    return
  end
  pcall(in_target, function()
    vim.fn.search(pat, flags)
    state.origin = vim.api.nvim_win_get_cursor(0)
  end)
  update(false)
end

local function writable()
  if vim.bo[state.target_buf].modifiable and not vim.bo[state.target_buf].readonly then
    return true
  end
  vim.notify("Buffer is not modifiable", vim.log.levels.WARN)
  return false
end

-- Replace the match under the cursor and move to the next one. If the cursor
-- isn't on a match, just move to the next one first, as VS Code does.
local function replace_one()
  local pat = pattern()
  if not pat or not writable() then
    return
  end
  local spat, srep = escape(pat, "/"), replacement()
  pcall(in_target, function()
    local cur = vim.api.nvim_win_get_cursor(0)
    local s = vim.fn.searchpos(pat, "cnW")
    if s[1] ~= cur[1] or s[2] ~= cur[2] + 1 then
      vim.fn.search(pat, "w")
      return
    end

    local e = vim.fn.searchpos(pat, "cneW")
    local before = #vim.api.nvim_get_current_line()
    vim.cmd(("keeppatterns s/\\%%#%s/%s/e"):format(spat, srep))

    -- Continue *after* the inserted text, so replacing `a` with `aa` doesn't
    -- keep matching its own output.
    if e[1] == s[1] then
      local line = vim.api.nvim_get_current_line()
      local matched = e[2] + vim.str_utf_end(vim.fn.getline(e[1]), e[2]) - s[2] + 1
      local inserted = matched + #line - before
      if inserted > 0 then
        vim.api.nvim_win_set_cursor(0, { cur[1], cur[2] + inserted - 1 })
        vim.fn.search(pat, "w")
        return
      end
    end
    vim.api.nvim_win_set_cursor(0, cur)
    vim.fn.search(pat, "cw")
  end)
  state.origin = vim.api.nvim_win_get_cursor(state.target_win)
  update(false)
end

local function replace_all()
  local pat = pattern()
  if not pat or not writable() then
    return
  end
  local ok, total = pcall(in_target, function()
    local total = vim.fn.searchcount({ pattern = pat, maxcount = 0 }).total or 0
    if total > 0 then
      local view = vim.fn.winsaveview()
      vim.cmd(("keeppatterns %%s/%s/%s/ge"):format(escape(pat, "/"), replacement()))
      vim.fn.winrestview(view)
    end
    return total
  end)
  if ok and total > 0 then
    vim.notify(("Replaced %d occurrence%s"):format(total, total == 1 and "" or "s"))
  end
  update(false)
end

local function focus(input)
  vim.api.nvim_set_current_win(input.win)
  vim.api.nvim_win_set_cursor(input.win, { 1, #text(input.buf) })
  if vim.fn.mode() ~= "i" then
    vim.cmd("startinsert!")
  end
end

function M.close()
  if not state then
    return
  end
  local s = state
  state = nil
  vim.api.nvim_clear_autocmds({ group = group })
  last_find, last_replace = text(s.find.buf), text(s.replace.buf)

  local was_focused = vim.api.nvim_get_current_win() == s.find.win
    or vim.api.nvim_get_current_win() == s.replace.win
  for _, win in ipairs({ s.find.win, s.replace.win }) do
    pcall(vim.api.nvim_win_close, win, true)
  end
  pcall(vim.api.nvim_buf_clear_namespace, s.target_buf, ns, 0, -1)
  if was_focused then
    vim.cmd("stopinsert")
    if vim.api.nvim_win_is_valid(s.target_win) then
      vim.api.nvim_set_current_win(s.target_win)
    end
  end
end

local function create_input(title, row, width, value)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].filetype = "find_replace"
  vim.b[buf].completion = false -- keep blink.cmp out of the inputs
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { value })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "win",
    win = state.target_win,
    anchor = "NE",
    row = row,
    col = vim.api.nvim_win_get_width(state.target_win) - 1,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    zindex = 60,
  })
  -- Don't highlight the search text inside the input itself.
  vim.wo[win].winhighlight = "Search:None,CurSearch:None,IncSearch:None"
  return { buf = buf, win = win }
end

local function set_keymaps()
  local cmd_cr = vim.fn.has("mac") == 1 and "<D-CR>" or "<C-CR>"
  local function map(input, lhs, fn, desc)
    vim.keymap.set({ "i", "n", "s" }, lhs, fn, { buffer = input.buf, nowait = true, desc = desc })
  end
  local function toggle(key)
    return function()
      opts[key] = not opts[key]
      update(true)
    end
  end

  for _, input in ipairs({ state.find, state.replace }) do
    map(input, "<Esc>", M.close, "Close find/replace")
    map(input, "<C-c>", M.close, "Close find/replace")
    map(input, cmd_cr, replace_all, "Replace all")
    map(input, "<A-c>", toggle("case"), "Toggle match case")
    map(input, "<A-w>", toggle("word"), "Toggle whole word")
    map(input, "<A-r>", toggle("regex"), "Toggle regex")
  end
  map(state.find, "<CR>", function() step("w") end, "Next match")
  map(state.find, "<S-CR>", function() step("bw") end, "Previous match")
  map(state.find, "<Tab>", function() focus(state.replace) end, "Go to replace")
  map(state.replace, "<CR>", replace_one, "Replace")
  map(state.replace, "<Tab>", function() focus(state.find) end, "Go to find")
  map(state.replace, "<S-Tab>", function() focus(state.find) end, "Go to find")
end

local function set_autocmds()
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
    group = group,
    buffer = state.find.buf,
    -- Scheduled: Vim restores the search pattern and highlight state after
    -- every autocommand, which would undo what update() sets.
    callback = function()
      vim.schedule(function()
        update(true)
      end)
    end,
  })
  for _, buf in ipairs({ state.find.buf, state.replace.buf }) do
    vim.api.nvim_create_autocmd("WinLeave", {
      group = group,
      buffer = buf,
      callback = function()
        vim.schedule(function()
          if state and not is_ours(vim.api.nvim_get_current_win()) then
            M.close()
          end
        end)
      end,
    })
  end
  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    pattern = { tostring(state.target_win), tostring(state.find.win), tostring(state.replace.win) },
    callback = function()
      vim.schedule(M.close)
    end,
  })
end

-- Open the widget, seeded from the visual selection, else the word under the
-- cursor, else whatever was searched last time.
function M.open()
  local mode = vim.fn.mode()
  local seed, origin
  if mode:match("^[vV\22]") then
    local v, c = vim.fn.getpos("v"), vim.fn.getpos(".")
    seed = vim.fn.getregion(v, c, { type = mode })[1]
    local first = (v[2] < c[2] or (v[2] == c[2] and v[3] <= c[3])) and v or c
    origin = { first[2], first[3] - 1 }
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  end

  if state then
    if is_ours(vim.api.nvim_get_current_win()) then
      focus(state.find)
      return
    end
    M.close()
  end

  seed = seed or vim.fn.expand("<cword>")
  if seed == "" then
    seed = last_find
  end

  local target_win = vim.api.nvim_get_current_win()
  state = {
    target_win = target_win,
    target_buf = vim.api.nvim_win_get_buf(target_win),
    origin = origin or vim.api.nvim_win_get_cursor(target_win),
  }
  local width = math.max(20, math.min(50, vim.api.nvim_win_get_width(target_win) - 4))
  state.find = create_input("Find", 0, width, seed)
  state.replace = create_input("Replace", 3, width, last_replace)

  set_keymaps()
  set_autocmds()
  update(true)

  -- Select the seed (select mode) so typing overwrites it, like VS Code.
  vim.api.nvim_set_current_win(state.find.win)
  if seed ~= "" then
    vim.api.nvim_feedkeys(vim.keycode("<Esc>0vg_<C-g>"), "n", false)
  else
    vim.cmd("startinsert!")
  end
end

return M
