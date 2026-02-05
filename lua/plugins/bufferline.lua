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
    end,
  },
}
