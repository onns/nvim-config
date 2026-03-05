-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 拼写检查
-- vim.opt.spell = true
-- vim.opt.spelllang = "en_us"

-- vim.api.nvim_set_keymap('n', 'gd', ':GoDef<CR>', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', 'gr', ':GoReferrers', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', 'gm', ':GoImplements', { noremap = true, silent = true })
-- vim.api.nvim_set_keymap("n", "<C-g>", ":GoDeclsDir<CR>", { silent = true })
-- vim.api.nvim_set_keymap("i", "<C-g> <esc>", ":<C-u>GoDeclsDir<CR>", { silent = true })
-- vim.api.nvim_set_keymap('n', 'gd', "<Plug>(coc-definition)", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', 'gr', "<Plug>(coc-references)", { noremap = true, silent = true })
-- vim.api.nvim_set_keymap('n', 'gm', "<Plug>(coc-implementation)", { noremap = true, silent = true })

-- tagbar 打开后自动聚焦
-- vim.g.tagbar_autofocus = 1

vim.opt.wrap = true

vim.g.startify_files_number = 20
-- 打开文件不改变cwd
vim.g.startify_change_to_dir = 0

vim.opt.list = true
vim.opt.listchars = {
  tab = "▸\\ ", -- 设置Tab显示为一个小三角后跟一个空格
  trail = "·", -- 设置行尾空格显示为中点
  extends = ">", -- 当文本超出屏幕视图时在右边界显示
  precedes = "<", -- 当文本超出屏幕视图时在左边界显示
  nbsp = "␣", -- 不断行空格的显示
}

-- 设置剪贴板使用系统剪贴板
vim.opt.clipboard = "unnamedplus"
vim.g.snacks_animate = false

if os.getenv("SSH_TTY") ~= nil then
  vim.g.clipboard = {
    name = "OSC 52",
    copy = {
      ["+"] = require("vim.ui.clipboard.osc52").copy("+"),
      ["*"] = require("vim.ui.clipboard.osc52").copy("*"),
    },
    paste = {
      ["+"] = require("vim.ui.clipboard.osc52").paste("+"),
      ["*"] = require("vim.ui.clipboard.osc52").paste("*"),
    },
  }
end

vim.g.floaterm_height = 0.2
vim.g.floaterm_position = "bottom"
