return {
  "zbirenbaum/copilot.lua",
  cmd = "Copilot",
  event = "InsertEnter",
  opts = {
    suggestion = {
      enabled = true,
      auto_trigger = true,
      keymap = {
        accept = false, -- handled manually below
        accept_word = "<C-Right>",
        accept_line = "<C-Down>",
        next = "<M-]>",
        prev = "<M-[>",
        dismiss = "<C-]>",
      },
    },
    panel = {
      enabled = true,
    },
    filetypes = {
      markdown = true,
      help = false,
    },
  },
  config = function(_, opts)
    require("copilot").setup(opts)
    -- Tab: accept suggestion or fall back to normal tab
    vim.keymap.set("i", "<Tab>", function()
      if require("copilot.suggestion").is_visible() then
        require("copilot.suggestion").accept()
      else
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Tab>", true, false, true), "n", false)
      end
    end, { desc = "Accept Copilot or Tab" })
  end,
}
