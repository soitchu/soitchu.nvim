-- The explorer marks the current file with the list's cursor line. Unfocused,
-- snacks hard-codes the editor's CursorLine for it, which in this theme is one
-- shade off the background, so you can't tell which file is open. Swap in a
-- group of our own (colors in plugins/vscode.lua).
local function patch_unfocused_cursorline()
  local List = require("snacks.picker.core.list")
  local update_cursorline = List.update_cursorline
  List.update_cursorline = function(self)
    update_cursorline(self)
    if self.win:win_valid() and not self.picker:is_focused() then
      Snacks.util.wo(self.win.win, {
        winhighlight = Snacks.util.winhl(vim.wo[self.win.win].winhighlight, {
          CursorLine = "SnacksPickerListCursorLineNC",
        }),
      })
    end
  end
end

return {
  {
    "folke/snacks.nvim",
    opts = function()
      patch_unfocused_cursorline()
    end,
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          files = {
            hidden = true,
            -- ~/app is not a git repo (the repos are the worktrees under
            -- branches/*), and fd/rg only apply .gitignore when they are inside
            -- one. Without this, searching from ~/app returns every node_modules
            -- file. Pinning cmd keeps the flag valid (it is fd/rg-only).
            cmd = "fd",
            args = { "--no-require-git" },
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
      -- sessions are auto-restored by persistence.nvim instead
      dashboard = {
        enabled = false,
      },
    },
  },
}
