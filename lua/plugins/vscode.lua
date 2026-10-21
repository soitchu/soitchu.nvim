return {
  "Mofiqul/vscode.nvim",
  lazy = false,
  priority = 1000,
  opts = {
    style = "dark",
    -- The theme's float background (#202020) is one shade off the editor's
    -- (#1F1F1F), so popups blend into the code. Use VS Code's own hover
    -- widget colors instead.
    group_overrides = {
      NormalFloat = { bg = "#252526" },
      FloatBorder = { fg = "#454545", bg = "#252526" },
      -- Explorer's current file, VS Code's list selection colors: focused
      -- (activeSelectionBackground) and not (inactiveSelectionBackground).
      SnacksPickerListCursorLine = { bg = "#04395E" },
      SnacksPickerListCursorLineNC = { bg = "#37373D" },
    },
  },
  config = function(_, opts)
    require("vscode").setup(opts)
    vim.cmd("colorscheme vscode")
  end,
}
