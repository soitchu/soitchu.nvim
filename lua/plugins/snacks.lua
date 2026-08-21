return {
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
}
