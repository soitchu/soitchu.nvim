return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        files = {
          hidden = true,
        },
        explorer = {
          hidden = true,
          layout = {
            preset = "sidebar",
            width = 30,
          },
        },
      },
    },
    dashboard = {
      enabled = vim.fn.argc() ~= 0,
    },
  },
}
