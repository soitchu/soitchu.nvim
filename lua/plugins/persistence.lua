return {
  "folke/persistence.nvim",
  lazy = false,
  opts = {},
  init = function()
    vim.api.nvim_create_autocmd("VimEnter", {
      nested = true,
      callback = function()
        if vim.fn.argc() == 0 then
          require("persistence").load({ last = true })
        end
      end,
    })
  end,
}
