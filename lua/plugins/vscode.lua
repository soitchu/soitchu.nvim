return {
  "Mofiqul/vscode.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    style = "dark",
  },
  config = function(_, opts)
    require("vscode").setup(opts)
    vim.cmd("colorscheme vscode")
  end,
}
