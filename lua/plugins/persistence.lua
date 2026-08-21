-- Wipe diffview's revision buffers (diffview://...) so they never end up in a
-- session. `sessionoptions` includes "buffers", which stores buffer *names*
-- but not their contents. On restore those buffers come back empty, and
-- diffview's File.create_buffer reuses any existing buffer matching the name
-- without repopulating it -- so the left side of every affected diff renders
-- blank and the whole file shows up as added.
local function wipe_diffview_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):match("^diffview://") then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

return {
  "folke/persistence.nvim",
  lazy = false,
  opts = {},
  init = function()
    -- Keep them out of sessions we write from now on...
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceSavePre",
      callback = wipe_diffview_buffers,
    })
    -- ...and clean up any that an already-saved session drags back in.
    vim.api.nvim_create_autocmd("User", {
      pattern = "PersistenceLoadPost",
      callback = wipe_diffview_buffers,
    })

    vim.api.nvim_create_autocmd("VimEnter", {
      nested = true,
      callback = function()
        if vim.fn.argc() == 0 then
          require("persistence").load()
        end
      end,
    })
  end,
}
