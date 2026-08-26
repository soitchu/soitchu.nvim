return {
  "iamcco/markdown-preview.nvim",
  cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
  ft = { "markdown", "markdown.mdx" },
  init = function()
    -- plugin/mkdp.vim gates its (buffer-local) commands on an exact
    -- `index(g:mkdp_filetypes, &filetype)` match, so the compound filetype
    -- used for .mdx has to be listed explicitly.
    vim.g.mkdp_filetypes = { "markdown", "markdown.mdx" }
  end,
  build = function()
    require("lazy").load({ plugins = { "markdown-preview.nvim" } })
    vim.fn["mkdp#util#install"]()
  end,
  keys = {
    {
      "<leader>cp",
      ft = { "markdown", "markdown.mdx" },
      "<cmd>MarkdownPreviewToggle<cr>",
      desc = "Markdown Preview",
    },
  },
  config = function()
    vim.cmd([[do FileType]])
  end,
}
