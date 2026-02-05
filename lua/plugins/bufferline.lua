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
    highlights = function(config)
      return require("vscode.colors").get_colors()
        and {
          fill = { bg = "#181818" },
          background = { bg = "#181818", fg = "#6e6e6e" },
          buffer_selected = { bg = "#1f1f1f", fg = "#ffffff", bold = true },
          buffer_visible = { bg = "#181818", fg = "#6e6e6e" },
          close_button = { bg = "#181818", fg = "#6e6e6e" },
          close_button_selected = { bg = "#1f1f1f", fg = "#ffffff" },
          close_button_visible = { bg = "#181818", fg = "#6e6e6e" },
          modified = { bg = "#181818" },
          modified_selected = { bg = "#1f1f1f" },
          modified_visible = { bg = "#181818" },
          separator = { bg = "#181818", fg = "#181818" },
          separator_selected = { bg = "#1f1f1f", fg = "#181818" },
          separator_visible = { bg = "#181818", fg = "#181818" },
          indicator_selected = { bg = "#1f1f1f", fg = "#1f1f1f" },
          duplicate = { bg = "#181818", fg = "#6e6e6e" },
          duplicate_selected = { bg = "#1f1f1f", fg = "#ffffff" },
          duplicate_visible = { bg = "#181818", fg = "#6e6e6e" },
        }
        or {}
    end,
  },
}
