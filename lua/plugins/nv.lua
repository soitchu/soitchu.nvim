-- Integration with the `nv` branch tooling in ~/app (see ~/app/index.ts).
--
-- Branches are not git worktrees: each standalone branch is a full directory
-- copy under ~/app/branches/<name-with-slashes-dashed>, and a branch may
-- instead be "light" or a gh-stack member, in which case it has no directory
-- of its own and rides its host branch's. Every action here ends by pointing
-- nvim's cwd at whichever directory the branch actually lives in.

local APP_DIR = vim.fn.expand("~/app")
local DB = APP_DIR .. "/branches/branch_states.db"

---@class NvBranch
---@field name string
---@field active boolean
---@field host string?  host branch for light/stack branches
---@field stack boolean

---@return NvBranch[]
local function list_branches()
  if vim.fn.executable("sqlite3") == 0 or vim.fn.filereadable(DB) == 0 then
    return {}
  end
  local out = vim.fn.systemlist({
    "sqlite3",
    "-separator",
    "\t",
    DB,
    "SELECT name, is_active, COALESCE(host_branch,''), COALESCE(is_stack,0) "
      .. "FROM Branches ORDER BY is_active DESC, last_used_at DESC;",
  })
  if vim.v.shell_error ~= 0 then
    return {}
  end

  local branches = {}
  for _, line in ipairs(out) do
    local name, active, host, stack = line:match("^(.-)\t(.-)\t(.-)\t(.*)$")
    if name and name ~= "" then
      branches[#branches + 1] = {
        name = name,
        active = active == "1",
        host = host ~= "" and host or nil,
        stack = stack == "1",
      }
    end
  end
  return branches
end

--- Directory a branch's files actually live in. Light/stack branches have none
--- of their own, so they resolve to their host's (utils.ts: normalizeBranchName
--- turns `a/b` into `a-b`).
---@param branch NvBranch
local function branch_dir(branch)
  local owner = branch.host or branch.name
  return APP_DIR .. "/branches/" .. owner:gsub("/", "-")
end

--- Wherever the `current` symlink points, fully resolved.
local function current_dir()
  return vim.uv.fs_realpath(APP_DIR .. "/current")
end

--- Tear the workspace down after moving to a different branch: buffers, windows
--- and tabpages all still point into the previous branch's tree. Buffers with
--- unsaved changes are deliberately kept -- the old branch dir still exists, so
--- that work is still savable and must not be discarded silently.
local function reset_workspace()
  vim.cmd("silent! tabonly")
  vim.cmd("silent! only")

  local kept = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted then
      if vim.bo[buf].modified then
        kept = kept + 1
      else
        pcall(vim.api.nvim_buf_delete, buf, {})
      end
    end
  end

  if kept > 0 then
    local msg = ("nv: kept %d buffer%s with unsaved changes"):format(kept, kept == 1 and "" or "s")
    vim.notify(msg, vim.log.levels.WARN)
  end

  Snacks.picker.explorer()
end

---@param dir string?
local function cd(dir)
  if not dir or vim.fn.isdirectory(dir) == 0 then
    vim.notify("nv: no such directory: " .. tostring(dir), vim.log.levels.WARN)
    return
  end
  vim.cmd.cd(vim.fn.fnameescape(dir))
  vim.notify("cwd: " .. vim.fn.fnamemodify(dir, ":~"))
end

--- Run an `nv` subcommand in a floating terminal. These are interactive (`new`
--- prompts) and slow (container start, proxy rewiring), so they need a real
--- terminal rather than vim.system. `after` runs only on a clean exit.
---@param args string[]
---@param after? fun()
local function run(args, after)
  local term = Snacks.terminal.open(vim.list_extend({ "bun", "index.ts" }, args), {
    cwd = APP_DIR,
    interactive = true,
    win = { position = "float", title = " nv " .. table.concat(args, " ") .. " " },
  })
  if after then
    term:on("TermClose", function()
      local status = type(vim.v.event) == "table" and vim.v.event.status or 0
      if status == 0 then
        vim.schedule(after)
      end
    end, { buf = true })
  end
end

--- Pick a branch, then hand it to `action`.
---@param title string
---@param action fun(branch: NvBranch)
local function pick(title, action)
  local branches = list_branches()
  if #branches == 0 then
    vim.notify("nv: no branches found (is " .. DB .. " readable?)", vim.log.levels.WARN)
    return
  end

  local items = {}
  for i, b in ipairs(branches) do
    local kind = b.stack and " (stack → " .. (b.host or "?") .. ")"
      or b.host and " (light → " .. b.host .. ")"
      or ""
    items[#items + 1] = {
      idx = i,
      score = 0,
      text = b.name,
      display = (b.active and "● " or "  ") .. b.name .. kind,
      branch = b,
    }
  end

  Snacks.picker({
    title = title,
    items = items,
    format = function(item)
      return { { item.display } }
    end,
    preview = "none",
    confirm = function(picker, item)
      picker:close()
      if item then
        action(item.branch)
      end
    end,
  })
end

-- `checkout`, not `switch`: switch ends by attaching a container shell, which
-- would hijack the terminal. checkout does the same swap and exits.
local function switch_branch(branch)
  run({ "checkout", branch.name }, function()
    cd(current_dir())
    reset_workspace()
  end)
end

-- `start` brings a container up without making it active, so the `current`
-- symlink does not move -- cd to the branch's own directory instead.
local function start_branch(branch)
  run({ "start", branch.name }, function()
    cd(branch_dir(branch))
    reset_workspace()
  end)
end

-- Pure cd: jump to a branch's files without touching containers or the
-- `current` symlink. Useful for reading another branch while yours stays active.
local function open_branch(branch)
  cd(branch_dir(branch))
  reset_workspace()
end

vim.api.nvim_create_user_command("NvSwitch", function(opts)
  if opts.args ~= "" then
    switch_branch({ name = opts.args })
  else
    pick("nv switch", switch_branch)
  end
end, {
  nargs = "?",
  desc = "Switch branch via nv, then cd to it",
  complete = function(lead)
    local names = {}
    for _, b in ipairs(list_branches()) do
      if b.name:find(lead, 1, true) == 1 then
        names[#names + 1] = b.name
      end
    end
    return names
  end,
})

return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>n", group = "notifications / nv" },
        { "<leader>nv", group = "nv" },
      },
    },
  },
  {
    "folke/snacks.nvim",
    -- stylua: ignore
    keys = {
      -- <leader>n was Notification History; moved so <leader>nv is free.
      { "<leader>n", false },
      { "<leader>nn", function() Snacks.picker.notifications() end, desc = "Notification History" },

      { "<leader>nvs", function() pick("nv switch", switch_branch) end, desc = "Switch branch" },
      { "<leader>nvS", function() pick("nv start", start_branch) end, desc = "Start branch container" },
      { "<leader>nvn", function() run({ "new" }, function() cd(current_dir()) reset_workspace() end) end, desc = "New branch" },
      { "<leader>nvo", function() pick("nv open (cd only)", open_branch) end, desc = "Open branch dir (cd only)" },
      { "<leader>nvd", function() cd(current_dir()) end, desc = "cd to current branch dir" },
    },
  },
}
