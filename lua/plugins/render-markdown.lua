return {
  "MeanderingProgrammer/render-markdown.nvim",
  -- markdown.mdx matches "markdown" component-wise, so .mdx files render too
  ft = { "markdown", "markdown.mdx", "codecompanion" },
  opts = {
    code = {
      sign = false,
      width = "block",
      right_pad = 1,
    },
    heading = {
      sign = false,
      icons = {},
    },
    checkbox = {
      enabled = false,
    },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)
    Snacks.toggle({
      name = "Render Markdown",
      get = require("render-markdown").get,
      set = require("render-markdown").set,
    }):map("<leader>um")
  end,
}
