-- Diffview loads every file you step through as a real, *listed* buffer (see
-- File:_create_local_buffer -- it runs `:edit` on each one, and explicitly
-- re-lists buffers that were already unlisted). Browsing a 44-file changeset
-- therefore fills the barbar tabline with 44 entries as you go.
--
-- So: unlist each buffer diffview opens as soon as it hits a window, and wipe
-- those buffers when the view closes. Buffers that were already open before
-- the view opened are left completely alone.
local buffers_before_view = nil
local buffers_opened_by_view = {}

local function snapshot_listed_buffers()
  local set = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buflisted then
      set[buf] = true
    end
  end
  return set
end

local function unlist_if_new(bufnr)
  if not buffers_before_view or buffers_before_view[bufnr] then
    return -- it predates the view; not ours to touch
  end
  if vim.api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buftype == "" then
    buffers_opened_by_view[bufnr] = true
    vim.bo[bufnr].buflisted = false
  end
end

local function close_buffers_opened_by_view()
  -- Anything still on screen (e.g. a file opened with `gf`) is in use -- keep it.
  local visible = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    visible[vim.api.nvim_win_get_buf(win)] = true
  end

  for buf in pairs(buffers_opened_by_view) do
    if vim.api.nvim_buf_is_valid(buf) and not visible[buf] and not vim.bo[buf].modified then
      pcall(vim.api.nvim_buf_delete, buf, {})
    end
  end

  buffers_before_view = nil
  buffers_opened_by_view = {}
end

-- Diffview only refreshes when Neovim writes a buffer or .git/index changes,
-- so edits made elsewhere (a docker container, another editor) leave it stale.
-- Poll once a second while a diffview tab is in front. A refresh re-opens the
-- current file -- folds snap shut and the cursor jumps -- so only refresh when
-- the working tree really changed: compare `git status` plus the size and
-- mtime of every file it lists against the previous tick.
local uv = vim.uv or vim.loop
local POLL_MS = 1000

---@type { timer: uv.uv_timer_t, root: string?, signature: string?, busy: boolean }?
local poll = nil

local function stop_polling()
  if poll then
    poll.timer:stop()
    poll.timer:close()
    poll = nil
  end
end

-- `git status` alone misses further edits to a file that is already
-- modified, so fold each listed file's size and mtime in as well.
local function tree_signature(root, status)
  local parts = { status }
  for entry in status:gmatch("[^%z]+") do
    local path = entry:sub(4)
    local stat = uv.fs_stat(root .. "/" .. path)
    if stat then
      parts[#parts + 1] = ("%s:%d:%d.%d"):format(path, stat.size, stat.mtime.sec, stat.mtime.nsec)
    end
  end
  return table.concat(parts, "\n")
end

local function poll_tick()
  local lib = require("diffview.lib")
  if not next(lib.views) then
    stop_polling()
    return
  end
  local view = lib.get_current_view()
  if poll.busy or not view or not view.adapter then
    return
  end
  local root = view.adapter.ctx.toplevel
  if root ~= poll.root then
    poll.root, poll.signature = root, nil
  end

  poll.busy = true
  vim.system(
    { "git", "-C", root, "status", "--porcelain=v1", "-z", "--untracked-files=all" },
    -- Keep git from rewriting .git/index, which diffview watches and would
    -- answer with exactly the refresh this is trying to avoid.
    { text = true, env = { GIT_OPTIONAL_LOCKS = "0" } },
    function(res)
      local signature = res.code == 0 and tree_signature(root, res.stdout) or nil
      vim.schedule(function()
        if not poll then
          return
        end
        poll.busy = false
        if not signature or poll.root ~= root or poll.signature == signature then
          return
        end
        if poll.signature == nil then
          poll.signature = signature -- first look: just take a baseline
          return
        end
        -- Wait for normal mode on this view; the signature stays stale, so
        -- the next tick tries again.
        if lib.get_current_view() ~= view or vim.api.nvim_get_mode().mode ~= "n" then
          return
        end
        poll.signature = signature
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
            vim.cmd.checktime(buf)
          end
        end
        vim.cmd("DiffviewRefresh")
      end)
    end
  )
end

local function start_polling()
  if poll then
    return
  end
  poll = { timer = uv.new_timer(), busy = false }
  poll.timer:start(POLL_MS, POLL_MS, vim.schedule_wrap(function()
    if poll then
      poll_tick()
    end
  end))
end

return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory" },
  opts = function()
    local actions = require("diffview.actions")
    return {
      keymaps = {
        view = {
          { "n", "-", actions.toggle_stage_entry, { desc = "Toggle stage" } },
          { "n", "s", actions.stage_all, { desc = "Stage all" } },
          { "n", "u", actions.unstage_all, { desc = "Unstage all" } },
        },
      },
      view = {
        default = {
          layout = "diff2_horizontal",
        },
        merge_tool = {
          layout = "diff3_horizontal",
        },
        file_history = {
          layout = "diff2_horizontal",
        },
      },
      file_panel = {
        -- flat list of files instead of a directory tree ("i" toggles)
        listing_style = "list",
        win_config = {
          position = "left",
          width = 35,
        },
      },
      hooks = {
        diff_buf_read = function()
          vim.opt_local.scrollbind = true
          vim.opt_local.cursorbind = false
          vim.opt_local.foldenable = true
          vim.opt_local.foldmethod = "diff"
          vim.opt_local.foldlevel = 0

          -- Make changes more obvious
          vim.api.nvim_set_hl(0, "DiffAdd", { bg = "#2e4b2e", bold = true })
          vim.api.nvim_set_hl(0, "DiffDelete", { bg = "#4b2e2e", bold = true })
          vim.api.nvim_set_hl(0, "DiffChange", { bg = "#3b3b1f", bold = true })
          vim.api.nvim_set_hl(0, "DiffText", { bg = "#5f5f00", bold = true, underline = true })
        end,
        view_closed = function(view)
          close_buffers_opened_by_view(view)
          -- The closed view is dropped from the list after this hook runs.
          vim.schedule(function()
            if not next(require("diffview.lib").views) then
              stop_polling()
            end
          end)
        end,
        diff_buf_win_enter = function(bufnr)
          unlist_if_new(bufnr)
        end,
        view_opened = function()
          buffers_before_view = buffers_before_view or snapshot_listed_buffers()
          start_polling()
          -- Fix file panel colors
          vim.api.nvim_set_hl(0, "DiffviewFilePanelTitle", { fg = "#cccccc", bold = true })
          vim.api.nvim_set_hl(0, "DiffviewFilePanelCounter", { fg = "#cccccc" })
          vim.api.nvim_set_hl(0, "DiffviewStatusModified", { fg = "#e5c07b", bg = "none" })
          vim.api.nvim_set_hl(0, "DiffviewStatusAdded", { fg = "#6a9955", bg = "none" })
          vim.api.nvim_set_hl(0, "DiffviewStatusDeleted", { fg = "#f44747", bg = "none" })
          vim.api.nvim_set_hl(0, "DiffviewFilePanelInsertions", { fg = "#6a9955", bg = "none" })
          vim.api.nvim_set_hl(0, "DiffviewFilePanelDeletions", { fg = "#f44747", bg = "none" })
          vim.api.nvim_set_hl(0, "DiffviewFolderSign", { fg = "#cccccc" })
          vim.api.nvim_set_hl(0, "DiffviewFolderName", { fg = "#cccccc" })
          -- Dim the trailing parent path so the filename reads first.
          -- Defaults to Comment, which vscode.nvim renders as green (#6a9955).
          vim.api.nvim_set_hl(0, "DiffviewFilePanelPath", { fg = "#6b6b6b", italic = true })
        end,
      },
    }
  end,
}
