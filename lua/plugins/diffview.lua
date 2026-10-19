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

-- Diffview only refreshes when Neovim writes a buffer or .git/index changes.
-- Edits made elsewhere (another editor, a docker container) touch neither, so
-- the view goes stale until something else runs `git status`. So watch the
-- repo ourselves: on any file change, reload on-screen files that changed on
-- disk and re-read the file list. A slow poll backs the watcher up in case an
-- event gets lost.
local uv = vim.uv or vim.loop
local REFRESH_GAP_MS = 1000 -- at most one refresh per second, however busy the repo
local POLL_MS = 5000

---@type { root: string, fs_event: uv.uv_fs_event_t, poll: uv.uv_timer_t, pending: uv.uv_timer_t, last: integer }?
local watch = nil

local function stop_watching()
  if not watch then
    return
  end
  for _, handle in ipairs({ watch.fs_event, watch.poll, watch.pending }) do
    if not handle:is_closing() then
      handle:stop()
      handle:close()
    end
  end
  watch = nil
end

-- Returns false when now is a bad time and the refresh should be retried.
local function refresh()
  local lib = require("diffview.lib")
  if not next(lib.views) then
    stop_watching()
    return true
  end
  -- Another tab: diffview re-reads the file list itself on tab enter.
  if not lib.get_current_view() then
    return true
  end
  -- Don't yank things around mid-edit or mid-command.
  if vim.api.nvim_get_mode().mode ~= "n" then
    return false
  end
  watch.last = uv.now()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].buftype == "" and not vim.bo[buf].modified then
      vim.cmd.checktime(buf)
    end
  end
  vim.cmd("DiffviewRefresh")
  return true
end

-- Throttle rather than debounce: a dev server rewriting build output nonstop
-- would starve a debounce forever, while this still refreshes once a second.
local function schedule_refresh(delay)
  if not watch or watch.pending:is_active() then
    return
  end
  delay = delay or math.max(100, REFRESH_GAP_MS - (uv.now() - watch.last))
  watch.pending:start(delay, 0, vim.schedule_wrap(function()
    if watch and not refresh() then
      schedule_refresh(500)
    end
  end))
end

local function watch_view(view)
  local root = view and view.adapter and view.adapter.ctx.toplevel
  if not root or (watch and watch.root == root) then
    return
  end
  stop_watching()
  watch = {
    root = root,
    fs_event = uv.new_fs_event(),
    poll = uv.new_timer(),
    pending = uv.new_timer(),
    last = 0,
  }
  -- Recursive watching is native on macOS (FSEvents). .git/ churns on every
  -- git command, including the ones a refresh runs, so ignore it; diffview
  -- already watches .git/index itself.
  watch.fs_event:start(root, { recursive = true }, function(err, filename)
    if err or not filename or filename == ".git" or filename:sub(1, 5) == ".git/" then
      return
    end
    schedule_refresh()
  end)
  watch.poll:start(POLL_MS, POLL_MS, vim.schedule_wrap(function()
    if watch then
      refresh()
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
              stop_watching()
            end
          end)
        end,
        -- Several views can be open in different repos; watch the one in front.
        view_enter = watch_view,
        diff_buf_win_enter = function(bufnr)
          unlist_if_new(bufnr)
        end,
        view_opened = function(view)
          buffers_before_view = buffers_before_view or snapshot_listed_buffers()
          watch_view(view)
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
