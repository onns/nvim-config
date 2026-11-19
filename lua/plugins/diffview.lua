local function review_context()
  local view = require("diffview.lib").get_current_view()
  local cwd = vim.fn.getcwd()
  if view and view.adapter then
    cwd = view.adapter.ctx.toplevel
  elseif vim.bo.buftype == "" and vim.api.nvim_buf_get_name(0) ~= "" then
    cwd = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
  end

  local function git(args)
    local result = vim.system(vim.list_extend({ "git", "-C", cwd }, args), { text = true }):wait()
    if result.code == 0 then
      return vim.trim(result.stdout)
    end
  end

  local root = git({ "rev-parse", "--show-toplevel" })
  if not root then
    vim.notify("Current buffer is not in a Git repository", vim.log.levels.WARN)
    return
  end

  -- Prefer the remote's declared default, then fall back to conventional names.
  local candidates = { "origin/main", "origin/master", "main", "master" }
  local remote_head = git({ "symbolic-ref", "--quiet", "--short", "refs/remotes/origin/HEAD" })
  if remote_head then
    table.insert(candidates, 1, remote_head)
  end
  for _, branch in ipairs(candidates) do
    if git({ "rev-parse", "--verify", "--quiet", branch .. "^{commit}" }) then
      return root, branch
    end
  end
  return root
end

local function open_review(root, base)
  require("diffview").open({ base .. "...HEAD", "-C=" .. root })
end

return {
  {
    "dlyongemallo/diffview-plus.nvim",
    main = "diffview",
    cmd = { "DiffviewOpen", "DiffviewClose", "DiffviewToggleFiles", "DiffviewFileHistory" },
    keys = {
      {
        "\\dm",
        function()
          local root, base = review_context()
          if root and base then
            open_review(root, base)
          elseif root then
            vim.notify("No default branch found; use \\db to choose a base branch", vim.log.levels.WARN)
          end
        end,
        desc = "Review branch against default branch",
      },
      {
        "\\db",
        function()
          local root, default_base = review_context()
          if not root then
            return
          end
          vim.ui.input({ prompt = "Review base branch: ", default = default_base or "" }, function(base)
            if base and vim.trim(base) ~= "" then
              open_review(root, vim.trim(base))
            end
          end)
        end,
        desc = "Review branch against another branch",
      },
      {
        "\\dq",
        "<cmd>DiffviewClose<cr>",
        desc = "Close diff review",
      },
    },
    opts = {
      enhanced_diff_hl = true,
      file_panel = {
        listing_style = "tree",
      },
    },
  },
}
