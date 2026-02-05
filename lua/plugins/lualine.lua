return {
  "nvim-lualine/lualine.nvim",
  opts = function(_, opts)
    local modified_count = 0

    local function update_git_modified()
      vim.fn.jobstart({ "git", "diff", "--name-only" }, {
        stdout_buffered = true,
        on_stdout = function(_, data)
          if data then
            local count = 0
            for _, line in ipairs(data) do
              if line ~= "" then count = count + 1 end
            end
            modified_count = count
          end
        end,
      })
    end

    -- Update on save, focus, and startup
    vim.api.nvim_create_autocmd({ "BufWritePost", "FocusGained", "VimEnter" }, {
      callback = update_git_modified,
    })

    -- Update every second
    local timer = vim.uv.new_timer()
    timer:start(0, 1000, vim.schedule_wrap(update_git_modified))

    local function git_modified_count()
      if modified_count > 0 then
        return " " .. modified_count
      end
      return ""
    end

    -- Override sections to remove copilot, progress, and time
    opts.sections.lualine_x = {
      {
        git_modified_count,
        color = { fg = "#e5c07b" },
        on_click = function()
          vim.cmd("DiffviewOpen HEAD")
        end,
      },
      {
        "diagnostics",
        on_click = function()
          vim.cmd("Trouble diagnostics toggle")
        end,
      },
    }
    opts.sections.lualine_y = { "filetype" }
    opts.sections.lualine_z = { "location" }
  end,
}
