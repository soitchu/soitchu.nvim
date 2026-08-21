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
        view_closed = close_buffers_opened_by_view,
        diff_buf_win_enter = function(bufnr)
          unlist_if_new(bufnr)
        end,
        view_opened = function()
          buffers_before_view = buffers_before_view or snapshot_listed_buffers()
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
