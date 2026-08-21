-- Resolve a language server binary on the *host*, preferring $PATH and falling
-- back to Mason. See the note on `cmd` below for why this matters.
local function host_bin(name)
  local path = vim.fn.exepath(name)
  if path ~= "" then
    return path
  end
  return vim.fn.stdpath("data") .. "/mason/bin/" .. name
end

return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      vtsls = { enabled = false },

      -- lspconfig's tsgo/biome definitions prefer `<root>/node_modules/.bin/<bin>`
      -- when it exists. Under branches/*, node_modules is installed inside the
      -- Linux dev container, so those are linux-arm64 builds that die instantly
      -- on macOS ("Unable to resolve @typescript/native-preview-darwin-arm64").
      -- Pin both to the host binary instead.
      tsgo = {
        cmd = { host_bin("tsgo"), "--lsp", "--stdio" },
      },
      biome = {
        cmd = { host_bin("biome"), "lsp-proxy" },
      },
    },
  },
}
