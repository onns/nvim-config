local gopls_socket = "/tmp/gopls-daemon-socket"
local gopls_remote_addr = "unix;" .. gopls_socket
local gopls_cmd = table.concat({
  "if ! gopls -remote='" .. gopls_remote_addr .. "' remote sessions >/dev/null 2>&1; then",
  "  rm -f '" .. gopls_socket .. "'",
  "  nohup gopls -listen='" .. gopls_remote_addr .. "' -listen.timeout=1m >/dev/null 2>&1 &",
  "  for _ in 1 2 3 4 5 6 7 8 9 10; do",
  "    gopls -remote='" .. gopls_remote_addr .. "' remote sessions >/dev/null 2>&1 && break",
  "    sleep 0.1",
  "  done",
  "fi",
  "exec gopls -remote='" .. gopls_remote_addr .. "'",
}, "\n")

return {
  -- {
  --   "onns/bookmarks.nvim",
  --   keys = {},
  --   lazy = false,
  --   branch = "main",
  --   dependencies = { "nvim-web-devicons" },
  --   config = function()
  --     require("bookmarks").setup()
  --     require("telescope").load_extension("bookmarks")
  --   end,
  -- },
  {
    "git@github.com:navarasu/onedark.nvim.git",
    lazy = false,
    config = function()
      require("onedark").setup({
        style = "darker",
      })
      require("onedark").load()
    end,
  },
  {
    "olimorris/onedarkpro.nvim",
    priority = 1000, -- Ensure it loads first
  },
  {
    "git@github.com:junegunn/fzf.git",
  },
  {
    "stevearc/aerial.nvim",
    opts = {},
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<leader>t",
        "<cmd>AerialToggle<cr>",
        desc = "AerialToggle",
      },
    },
  },
  {
    "git@github.com:mhinz/vim-startify.git",
    lazy = false,
  },
  {
    "git@github.com:wakatime/vim-wakatime.git",
  },
  {
    "buoto/gotests-vim",
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        gopls = {
          cmd = { "sh", "-c", gopls_cmd },
          settings = {
            gopls = {
              gofumpt = true,
            },
          },
        },
      },
    },
  },
  {
    "tpope/vim-fugitive",
  },
  {
    "blacklight/nvim-http",
  },
  {
    "voldikss/vim-floaterm",
  },
}
