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
    end,
  },
}
