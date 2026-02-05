return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<C-g>", "<cmd>DiffviewOpen HEAD<cr>", desc = "Diff view" },
  },
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
        view_opened = function()
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
        end,
      },
    }
  end,
}
