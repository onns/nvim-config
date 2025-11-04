-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

require("config.go_keymaps")

function SaveHttpResp()
  -- 获取当前时间并格式化为时间戳
  local timestamp = os.date("%Y%m%d%H%M%S")

  -- 获取当前文件的目录路径
  local current_path = vim.fn.expand("%:p:h")

  -- 定位到 rest.nvim 的响应缓冲区
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[bufnr].filetype == "httpResult" then
      -- 设置保存文件的完整路径，包含时间戳
      local filename = current_path .. "/log/response_" .. timestamp .. ".txt"
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("w " .. filename)
      end)
      print("Response saved to " .. filename)
      break
    end
  end
end

-- vim.api.nvim_set_keymap("n", "<leader>rr", "<cmd>Rest run<cr>", { noremap = true, silent = true })

function GetLSPRootDir()
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      return client.config.root_dir
    end
  end
  return nil -- 返回 nil 如果没有找到 gopls 或者 gopls 没有根目录
end

function GoToPathAndLine(input)
  if not input or input == "" then
    return
  end

  -- 只切第一个 :
  local file, line = input:match("^([^:]+):?(%d*)$")

  -- 工作目录优先级
  local pwd = vim.fn.getcwd()
  local goplsRootDir = GetLSPRootDir()
  if goplsRootDir then
    pwd = goplsRootDir
  end

  local path = vim.fs.joinpath(pwd, file)

  if line ~= "" then
    -- 显式指定行号才跳转
    vim.cmd(("edit +%d %s"):format(tonumber(line), vim.fn.fnameescape(path)))
  else
    -- 不指定行号 → 使用 Neovim 的上次光标位置
    vim.cmd(("edit %s"):format(vim.fn.fnameescape(path)))
  end
end

function ExportExpandToClipboard()
  local pwd = vim.fn.getcwd()
  local goplsRootDir = GetLSPRootDir()
  if goplsRootDir then
    pwd = goplsRootDir
  end
  local rf = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  local expanded = string.sub(rf, string.len(pwd .. "/") + 1)
  vim.fn.setreg("+", expanded)
  print("Expanded path copied to clipboard: " .. expanded)
end

local function check_spelling()
  -- 保存当前文件
  vim.cmd("write")

  -- 获取当前文件的路径
  local current_file = vim.fn.expand("%:p")
  print("Spell check in: " .. current_file)

  -- 构建CSpell命令
  local command = 'cspell --config /Users/onns/.onns/weiyun/code/config/vim/cspell.yaml -r "/Users/onns" '
    .. current_file

  -- 在新的终端窗口中执行CSpell
  vim.cmd("split | terminal " .. command)
end

-- 将Lua函数绑定到Neovim命令
vim.api.nvim_create_user_command("SpellCheck", check_spelling, {})

function InsertGitBranch()
  local cwd = vim.fn.getcwd()
  local git_branch_cmd = "git -C " .. cwd .. " branch --show-current"
  local handle = io.popen(git_branch_cmd)
  local git_branch = handle:read("*a")
  handle:close()
  git_branch = git_branch:gsub("%s+$", "")
  if git_branch ~= "" then
    -- vim.api.nvim_put({ git_branch }, "", false, true)
    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local todo_info = "TODO: onns " .. git_branch .. " "
    vim.api.nvim_buf_set_lines(0, line_num - 1, line_num - 1, false, { todo_info })
    require("mini.comment").toggle_lines(line_num, line_num)
    local buf = vim.api.nvim_get_current_buf() -- 获取当前缓冲区的句柄
    local lines = vim.api.nvim_buf_get_lines(buf, line_num - 1, line_num, false)
    if #lines > 0 then
      local line_length = #lines[1]
      vim.api.nvim_command("startinsert")
      vim.api.nvim_win_set_cursor(0, { line_num, line_length })
    end
  end
end

function JumpToFunctionName()
  -- 获取光标处的 node
  local node = vim.treesitter.get_node()
  if not node then
    return
  end

  -- 向上遍历父节点
  while node do
    local t = node:type()
    if t == "function_declaration" or t == "method_declaration" then
      -- 遍历当前函数声明的所有子节点
      for child in node:iter_children() do
        local ct = child:type()
        if
          (t == "function_declaration" and ct == "identifier")
          or (t == "method_declaration" and ct == "field_identifier")
        then
          local start_row, start_col = child:range()
          vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
          return
        end
      end
    end
    node = node:parent()
  end
end

function GetGoImportPath()
  local current_file = vim.api.nvim_buf_get_name(0)
  local current_path = vim.fn.fnamemodify(current_file, ":h")
  local go_mod_path = vim.fn.findfile("go.mod", current_path .. ";")
  if go_mod_path == "" then
    return
  end

  local go_mod_content = vim.fn.readfile(go_mod_path)
  local module_name = nil
  for _, line in ipairs(go_mod_content) do
    module_name = line:match("^module%s+(%S+)")
    if module_name then
      break
    end
  end
  if not module_name then
    return
  end

  local module_root = vim.fn.fnamemodify(go_mod_path, ":h")

  local package_path = string.sub(current_path, string.len(module_root .. "/") + 1)

  local import_package_name = module_name .. "/" .. package_path
  vim.fn.setreg("+", import_package_name)
  print("Import path copied to clipboard: " .. import_package_name)
end

local function _set_cursor(node)
  if not node then
    return
  end
  local start_row, start_col = node:range()
  vim.api.nvim_win_set_cursor(0, { start_row + 1, start_col })
end

local function find_function_call_node(start_node, reverse)
  local stack = { start_node }
  local result = nil

  while #stack > 0 do
    local node = table.remove(stack)
    if node:type() == "call_expression" then
      result = node
      if not reverse then
        return result
      end
    end

    -- 将子节点反向压栈，保证遍历顺序一致
    local children = {}
    for child in node:iter_children() do
      table.insert(children, 1, child)
    end
    for _, child in ipairs(children) do
      table.insert(stack, child)
    end
  end

  return result
end

-- 获取当前光标所在节点
local function get_node_at_cursor()
  return vim.treesitter.get_node()
end

-- 跳到下一个函数调用
function JumpToNextFuncCall()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  for _ = 1, 1000 do
    local sibling = node:next_sibling()
    if not sibling then
      node = node:parent()
    else
      node = sibling
      local call = find_function_call_node(node, false)
      if call then
        _set_cursor(call)
        return
      end
    end
    if not node then
      break
    end
  end
end

-- 跳到上一个函数调用
function JumpToLastFuncCall()
  local node = get_node_at_cursor()
  if not node then
    return
  end

  for _ = 1, 1000 do
    local sibling = node:prev_sibling()
    if not sibling then
      node = node:parent()
    else
      node = sibling
      local call = find_function_call_node(node, true)
      if call then
        _set_cursor(call)
        return
      end
    end
    if not node then
      break
    end
  end
end

vim.api.nvim_set_keymap("n", "]oc", "<cmd>lua JumpToNextFuncCall()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "[oc", "<cmd>lua JumpToLastFuncCall()<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "\\fz", ":Neotree reveal reveal_force_cwd<CR>", { noremap = true })

vim.api.nvim_set_keymap("n", "\\rp", "<Plug>RestNvimPreview", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "\\rr", "<Plug>RestNvim", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "\\rs", ":lua SaveHttpResp()<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap(
  "n",
  "\\gt",
  ':lua GoToPathAndLine(vim.fn.input("Enter path and line: "))<CR>',
  { noremap = true }
)
vim.api.nvim_set_keymap("n", "\\pr", ":lua ExportExpandToClipboard()<CR>", { noremap = true })

vim.keymap.set("v", "\\pj", function()
  -- 获取选区范围
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  -- 对每一行进行替换
  for lnum = start_line, end_line do
    local line = vim.fn.getline(lnum)
    local replaced =
      string.gsub(line, [[([%w_]+) = (%d+).*;]], [[%1 = %2 [(gogoproto.jsontag) = '%1', json_name = '%1'];]])
    if replaced ~= line then
      vim.fn.setline(lnum, replaced)
    end
  end
end, { noremap = true, silent = true })

vim.keymap.set("v", "\\pf", function()
  -- 获取选区范围
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end

  -- 对每一行进行替换
  for lnum = start_line, end_line do
    local line = vim.fn.getline(lnum)
    local replaced = string.gsub(
      line,
      [[([%w_]+) = (%d+).*;]],
      [[%1 = %2 [(gogoproto.moretags) = 'form:"%1"', (gogoproto.jsontag) = '%1', json_name = '%1'];]]
    )
    if replaced ~= line then
      vim.fn.setline(lnum, replaced)
    end
  end
end, { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "\\pi", ":lua GetGoImportPath()<CR>", { noremap = true })

vim.api.nvim_set_keymap(
  "n",
  "\\fm",
  ":lua require('bookmarks').toggle_bookmarks()<CR>",
  { noremap = true, silent = true }
)

vim.api.nvim_set_keymap("n", "\\ig", ":lua InsertGitBranch()<CR>", { noremap = true })

vim.api.nvim_set_keymap("n", "[on", "<cmd>lua JumpToFunctionName()<CR>", { noremap = true, silent = true })

vim.api.nvim_set_keymap("n", "\\aq", ":FloatermNew<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "\\aa", ":FloatermToggle!<CR>", { noremap = true, silent = true })
