return {
  "akinsho/bufferline.nvim",
  opts = {
    options = {
      tab_size = 20,
      indicator = {
        style = "none",
      },
      always_show_bufferline = true,
      separator_style = { "", "" },
      offsets = {
        { padding = 1 },
      },
    },
    highlights = {
      fill = { bg = "none" },
      background = { bg = "none" },
      buffer_selected = { bg = "none", bold = true },
    },
  },
}
