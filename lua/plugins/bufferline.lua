-- Hovering a barbar tab shows that buffer's path, relative to the cwd, in a
-- small float under the tabline, like VS Code's tab tooltip.
local function setup_tab_hover()
  vim.o.mousemoveevent = true

  local tooltip = { win = nil, buf = nil, bufnr = nil }
  local cache = { tabline = nil, spans = {} }

  -- Map tabline screen columns to buffers by walking barbar's 'tabline'
  -- string: `%N@handler@` starts a click region for buffer N (0 ends it),
  -- `%#Group#` is a highlight, `%%` a literal percent, the rest is text.
  local function tab_spans()
    local tabline = vim.o.tabline
    if cache.tabline == tabline then
      return cache.spans
    end
    local spans, col, bufnr, i = {}, 0, nil, 1
    local function add_text(text)
      local width = vim.fn.strdisplaywidth(text)
      local last = spans[#spans]
      if bufnr and last and last.bufnr == bufnr and last.stop == col then
        last.stop = col + width
      elseif bufnr then
        spans[#spans + 1] = { bufnr = bufnr, start = col, stop = col + width }
      end
      col = col + width
    end
    while i <= #tabline do
      if tabline:sub(i, i) == "%" then
        local nxt = tabline:sub(i + 1, i + 1)
        local n, stop = tabline:match("^(%d+)@[^@]*@()", i + 1)
        if nxt == "#" then
          local close = tabline:find("#", i + 2, true)
          if not close then
            break
          end
          i = close + 1
        elseif n then
          bufnr = tonumber(n) > 0 and tonumber(n) or nil
          i = stop
        elseif nxt == "%" then
          add_text("%")
          i = i + 2
        else
          i = i + 2 -- %T, %X, %= and friends: no width
        end
      else
        local char = tabline:match("^[%z\1-\127\194-\244][\128-\191]*", i) or tabline:sub(i, i)
        add_text(char)
        i = i + #char
      end
    end
    cache.tabline, cache.spans = tabline, spans
    return spans
  end

  local function hide()
    if tooltip.win and vim.api.nvim_win_is_valid(tooltip.win) then
      vim.api.nvim_win_close(tooltip.win, true)
    end
    tooltip.win, tooltip.bufnr = nil, nil
  end

  local function show(span)
    if tooltip.bufnr == span.bufnr and tooltip.win and vim.api.nvim_win_is_valid(tooltip.win) then
      return
    end
    hide()
    local name = vim.api.nvim_buf_is_valid(span.bufnr) and vim.api.nvim_buf_get_name(span.bufnr) or ""
    if name == "" then
      return
    end
    local text = " " .. vim.fn.fnamemodify(name, ":~:.") .. " "
    if not (tooltip.buf and vim.api.nvim_buf_is_valid(tooltip.buf)) then
      tooltip.buf = vim.api.nvim_create_buf(false, true)
    end
    vim.api.nvim_buf_set_lines(tooltip.buf, 0, -1, false, { text })
    local width = math.min(vim.fn.strdisplaywidth(text), vim.o.columns - 2)
    tooltip.win = vim.api.nvim_open_win(tooltip.buf, false, {
      relative = "editor",
      row = 1,
      col = math.max(0, math.min(span.start, vim.o.columns - width - 2)),
      width = width,
      height = 1,
      style = "minimal",
      border = "rounded",
      focusable = false,
      zindex = 250,
      noautocmd = true,
    })
    -- Same look as the hover popups: VS Code's widget colors, rounded border.
    vim.wo[tooltip.win].winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder"
    tooltip.bufnr = span.bufnr
  end

  local function update()
    local pos = vim.fn.getmousepos()
    if pos.screenrow == 1 and vim.o.showtabline > 0 then
      local col = pos.screencol - 1
      for _, span in ipairs(tab_spans()) do
        if col >= span.start and col < span.stop then
          return show(span)
        end
      end
    end
    hide()
  end

  -- Watch keys instead of mapping <MouseMove>, so nothing else sees a mapping;
  -- any other key (typing, clicking) dismisses the tooltip.
  local mouse_move = vim.keycode("<MouseMove>")
  vim.on_key(function(key)
    if key == mouse_move then
      vim.schedule(update)
    elseif tooltip.win then
      vim.schedule(hide)
    end
  end, vim.api.nvim_create_namespace("barbar_tab_hover"))
end

-- Closing a tab focuses the tab you were on before it, walking back through
-- the full history like VS Code does. Barbar's own focus_on_close = "previous"
-- only knows the alternate buffer (#), which is one step deep: close two tabs
-- in a row and the second falls back to the tab on the right.
local function setup_focus_recent_on_close()
  local recent = {} -- most recently entered first

  local function forget(bufnr)
    for i = #recent, 1, -1 do
      if recent[i] == bufnr then
        table.remove(recent, i)
      end
    end
  end

  local group = vim.api.nvim_create_augroup("barbar_recent_buffers", { clear = true })
  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    callback = function(args)
      if vim.bo[args.buf].buflisted and vim.bo[args.buf].buftype == "" then
        forget(args.buf)
        table.insert(recent, 1, args.buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    group = group,
    callback = function(args)
      forget(args.buf)
    end,
  })

  -- Only land on tabs backed by a file on disk, never a [No Name] scratch
  -- buffer or one named after a file that was never written.
  local function is_saved_file(bufnr, closing)
    if bufnr == closing or not vim.api.nvim_buf_is_valid(bufnr) then
      return false
    end
    if not vim.bo[bufnr].buflisted or vim.bo[bufnr].buftype ~= "" then
      return false
    end
    local name = vim.api.nvim_buf_get_name(bufnr)
    return name ~= "" and (vim.uv or vim.loop).fs_stat(name) ~= nil
  end

  -- Every barbar close (BufferClose, the tab's ×, right-click) asks this:
  -- the most recently used saved file, else the first one in the tab bar.
  local state = require("barbar.state")
  local focus_on_close = state.get_focus_on_close
  state.get_focus_on_close = function(closing)
    for _, list in ipairs({ recent, state.buffers }) do
      for _, bufnr in ipairs(list) do
        if is_saved_file(bufnr, closing) then
          return bufnr
        end
      end
    end
    return focus_on_close(closing)
  end
end

-- When two tabs share a file name, barbar adds just enough parent folders to
-- tell them apart (cxt/package.json). Show each one's full path from the cwd
-- instead (packages/cxt/package.json). Paths too long for a tab lose their
-- *start*, so the file name always stays visible.
local function setup_relative_clash_names()
  local buffer = require("barbar.buffer")
  local get_unique_names, format_name = buffer.get_unique_names, buffer.format_name
  local max_length = require("barbar.config").options.maximum_length

  -- Barbar only calls this for a group of tabs whose names clash.
  buffer.get_unique_names = function(bufnrs)
    local paths = {}
    for i, bufnr in ipairs(bufnrs) do
      local name = vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr)
      if not name or name == "" then
        return get_unique_names(bufnrs) -- a terminal or scratch buffer: barbar's way
      end
      paths[i] = vim.fn.fnamemodify(name, ":~:.")
    end
    return paths
  end

  buffer.format_name = function(name)
    if vim.api.nvim_strwidth(name) <= max_length or not name:find("/") then
      return format_name(name)
    end
    return "…" .. vim.fn.strcharpart(name, vim.fn.strchars(name) - (max_length - 1))
  end
end

return {
  -- Disable bufferline
  { "akinsho/bufferline.nvim", enabled = false },

  -- Add barbar
  {
    "romgrk/barbar.nvim",
    dependencies = {
      "nvim-tree/nvim-web-devicons",
    },
    init = function()
      vim.g.barbar_auto_setup = false
    end,
    opts = {
      animation = true,
      tabpages = true,
      clickable = true,
      icons = {
        buffer_index = false,
        filetype = { enabled = true },
        button = "×",
        separator = { left = "", right = "" },
        inactive = { separator = { left = "", right = "" } },
      },
      highlight_visible = false,
    },
    config = function(_, opts)
      require("barbar").setup(opts)
      -- Right-click (two-finger tap) to close buffer
      vim.keymap.set("n", "<RightMouse>", function()
        local mouse = vim.fn.getmousepos()
        if mouse.screenrow == 1 then
          vim.cmd("BufferClose")
        end
      end, { desc = "Close buffer on right-click" })
      setup_tab_hover()
      setup_focus_recent_on_close()
      setup_relative_clash_names()
    end,
  },
}
