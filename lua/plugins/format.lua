return {
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        ["sql"] = { "sql_formatter" },
        -- 走 PATH 上的 gofumpt（打过无点依赖补丁的 fork），不用 gopls 内置的
        -- 上游版本，否则 go-common/... 会被反复提到标准库那一组。
        ["go"] = { "gofumpt" },
      },
      formatters = {
        gofumpt = {
          -- gofumpt 读 stdin 时按 cwd 找 go.mod 来决定哪些无点路径不是标准库，
          -- 而 neovim 的 cwd 不一定在模块里，所以显式定位到 go.mod 所在目录。
          cwd = function(_, ctx)
            return vim.fs.root(ctx.dirname, { "go.mod" })
          end,
        },
      },
    },
  },
}
