return {
  "stevearc/conform.nvim",
  opts = {
    formatters = {
      biome = {
        command = vim.fn.stdpath("data") .. "/mason/bin/biome",
      },
    },
  },
}
