return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<C-g>", "<cmd>DiffviewOpen HEAD<cr>", desc = "Diff view" },
  },
  opts = {
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
    },
  },
}
