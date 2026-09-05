-- Review the current branch's PR with diffview: the whole PR as one diff, or
-- commit by commit. The PR is detected with `gh`, so the base branch comes from
-- the PR itself rather than being guessed.

--- Repo root for the current buffer, falling back to cwd. Resolving from the
--- buffer (not cwd) matters under Neovide, which launches from ~ or /.
---@return string?
local function repo_root()
  local name = vim.api.nvim_buf_get_name(0)
  local from = name ~= "" and vim.fs.dirname(name) or (vim.uv or vim.loop).cwd()
  return vim.fs.root(from, ".git")
end

---@class PrInfo
---@field number integer
---@field state string
---@field title string
---@field baseRefName string
---@field headRefName string
---@field url string

--- Ask `gh` for the PR whose head is the checked-out branch.
---@param root string
---@return PrInfo?, string? err
local function pr_info(root)
  if vim.fn.executable("gh") == 0 then
    return nil, "gh is not installed"
  end
  local cmd = { "gh", "pr", "view", "--json", "number,state,title,baseRefName,headRefName,url" }
  local res = vim.system(cmd, { cwd = root, text = true }):wait()

  if res.code ~= 0 then
    local err = vim.trim(res.stderr or "")
    return nil, err ~= "" and err or "no pull request for this branch"
  end
  local ok, data = pcall(vim.json.decode, res.stdout)
  if not ok or type(data) ~= "table" or not data.number then
    return nil, "could not parse the gh response"
  end
  return data
end

--- Resolve the PR base to a rev diffview can use, preferring the remote-tracking
--- ref since the local branch is often stale.
---@param root string
---@param base string
local function base_rev(root, base)
  local remote = "origin/" .. base
  local res = vim.system({ "git", "rev-parse", "--verify", "--quiet", remote }, { cwd = root }):wait()
  return res.code == 0 and remote or base
end

---@param what "diff"|"commits"
local function review(what)
  local root = repo_root()
  if not root then
    vim.notify("Not inside a git repository", vim.log.levels.WARN)
    return
  end

  local pr, err = pr_info(root)
  if not pr then
    vim.notify("PR review: " .. err, vim.log.levels.WARN)
    return
  end

  local base = base_rev(root, pr.baseRefName)
  local C = "-C=" .. vim.fn.fnameescape(root)

  if what == "commits" then
    -- Two-dot range: just the commits this branch adds on top of the base.
    vim.cmd(("DiffviewFileHistory %s --range=%s..HEAD"):format(C, base))
  else
    -- Three-dot: diff against the merge base, i.e. what the PR actually
    -- changes, ignoring anything that landed on the base since branching.
    vim.cmd(("DiffviewOpen %s %s...HEAD"):format(C, base))
  end

  vim.notify(("#%d %s  (%s ← %s)"):format(pr.number, pr.title, pr.baseRefName, pr.headRefName))
end

vim.api.nvim_create_user_command("PrReview", function()
  review("diff")
end, { desc = "Review the current branch's PR as one diff" })

vim.api.nvim_create_user_command("PrCommits", function()
  review("commits")
end, { desc = "Review the current branch's PR commit by commit" })

return {
  {
    "sindrets/diffview.nvim",
    -- stylua: ignore
    keys = {
      { "<leader>gr", function() review("diff") end, desc = "Review PR (full diff)" },
      { "<leader>gc", function() review("commits") end, desc = "Review PR (commit by commit)" },
    },
  },
}
