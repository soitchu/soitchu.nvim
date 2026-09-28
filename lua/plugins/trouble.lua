return {
  "folke/trouble.nvim",
  opts = {
    modes = {
      -- `gr` opens references as a floating list with its own preview pane to
      -- the right, matching how the Snacks picker used to look. Trouble's
      -- default `preview = { type = "main" }` renders into the editor window
      -- *behind* the float, which is invisible while the float is up.
      lsp_references = {
        -- Global default is focus = false, so the float would open behind the
        -- cursor. Set it on the mode so it wins however the command is invoked.
        focus = true,
        -- <esc> defaults to "cancel", which only dismisses the preview and
        -- leaves the list up. Close the whole view instead.
        keys = { ["<esc>"] = "close" },
        -- Float positions are fractions of the *leftover* space, so the
        -- fractions below are chosen to land the pair symmetrically at
        -- 5%-49% and 51%-95% of the editor, with a 2% gutter between them.
        win = {
          type = "float",
          relative = "editor",
          border = "rounded",
          title = " References ",
          title_pos = "center",
          position = { 0.5, 0.09 },
          size = { width = 0.44, height = 0.7 },
          zindex = 200,
        },
        preview = {
          type = "float",
          relative = "editor",
          border = "rounded",
          title = " Preview ",
          title_pos = "center",
          position = { 0.5, 0.91 },
          size = { width = 0.44, height = 0.7 },
          zindex = 200,
        },
      },
    },
  },
}
