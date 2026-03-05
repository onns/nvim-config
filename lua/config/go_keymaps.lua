function LiveGrepWithExtension(extension)
  require("fzf-lua").live_grep({
    additional_args = function(opts)
      return { "--glob", "*." .. extension }
    end,
  })
end

function LiveGrepUp(n)
  local bufnr = vim.api.nvim_get_current_buf()
  local full_path = vim.api.nvim_buf_get_name(bufnr)
  local file_path = vim.fs.dirname(full_path)

  -- 获取系统路径分隔符
  local path_sep = package.config:sub(1, 1)
  local components = {}

  -- 分割路径为组件
  for component in string.gmatch(file_path, "[^" .. path_sep .. "]+") do
    table.insert(components, component)
  end

  -- 计算向上 n 级的路径
  local up_n = #components - n
  if up_n < 1 then
    up_n = 1
  end -- 确保不会超出根目录

  local new_cwd = path_sep
  for i = 1, up_n do
    new_cwd = new_cwd .. components[i] .. (i < up_n and path_sep or "")
  end

  print("search under: " .. new_cwd)

  -- 使用 fzf-lua 执行 live_grep
  require("fzf-lua").live_grep({
    cwd = new_cwd,
    rg_opts = "--column --line-number --no-heading --color=always --smart-case --no-ignore --hidden",
  })
end

vim.api.nvim_create_user_command(
  "LgUp",
  function(opts)
    local n = tonumber(opts.args) or 0
    LiveGrepUp(n)
  end,
  { nargs = 1 } -- 命令接受一个参数
)

function TodoWithCWD()
  local pwd = vim.fn.getcwd()
  local goplsRootDir = GetLSPRootDir()
  if goplsRootDir then
    pwd = goplsRootDir
  end
  print("TodoFzfLua at : " .. pwd)
  vim.cmd(string.format("TodoFzfLua cwd=%s", pwd))
end

-- 待定列表
local targets = { "cmd", "CHANGELOG.md", "go.mod", ".git" }

-- 检查文件或目录是否存在
local function file_exists(path)
  local ok, err, code = os.rename(path, path)
  if not ok then
    if code == 13 then
      -- Permission denied, but it exists
      return true
    end
  end
  return ok, err
end

-- 从当前路径向上查找目标文件或目录
local function find_upwards()
  -- 获取当前文件的路径
  local path = vim.fn.expand("%:p:h")

  while path and path ~= "" do
    -- 检查目标文件或目录是否在当前路径
    for _, target in pairs(targets) do
      local fullpath = path .. "/" .. target
      if file_exists(fullpath) then
        return path
      end
    end

    -- 移动到上一级目录
    path = vim.fn.fnamemodify(path, ":h")
  end
  return nil
end

function TodoWithProject()
  local pwd = vim.fn.getcwd()
  local projectDir = find_upwards()
  if projectDir then
    pwd = projectDir
  end
  print("TodoFzfLua at : " .. pwd)
  vim.cmd(string.format("TodoFzfLua cwd=%s", pwd))
end

vim.api.nvim_set_keymap("n", "\\fp", ":lua TodoWithProject()<CR>", { noremap = true })

vim.api.nvim_create_user_command("LgExtension", function(opts)
  LiveGrepWithExtension(opts.args)
end, { nargs = 1 })

vim.api.nvim_set_keymap("n", "\\fc", ":lua TodoWithCWD()<CR>", { noremap = true })

local go_decl_patterns = {
  { kind = "method", pattern = "^%s*func%s*%b()%s*([%w_]+)%s*%(" },
  { kind = "func", pattern = "^%s*func%s+([%w_]+)%s*%(" },
  { kind = "type", pattern = "^%s*type%s+([%w_]+)%s+" },
  { kind = "var", pattern = "^%s*var%s+([%w_]+)%s" },
  { kind = "const", pattern = "^%s*const%s+([%w_]+)%s" },
}

local function normalize_dir(dir)
  return vim.fs.normalize(vim.fn.fnamemodify(dir, ":p"))
end

local function resolve_target_dir(input_dir)
  if input_dir and input_dir ~= "" then
    return normalize_dir(input_dir)
  end
  local current_file = vim.api.nvim_buf_get_name(0)
  return normalize_dir(vim.fn.fnamemodify(current_file, ":h"))
end

local function collect_go_files(dir)
  local files = {}
  for name, typ in vim.fs.dir(dir) do
    if typ == "file" and name:match("%.go$") and not name:match("_test%.go$") then
      table.insert(files, vim.fs.joinpath(dir, name))
    end
  end
  table.sort(files)
  return files
end

local function strip_comments(line, in_block_comment)
  local s = line
  while true do
    if in_block_comment then
      local block_end = s:find("%*/", 1, false)
      if not block_end then
        return "", true
      end
      s = s:sub(block_end + 2)
      in_block_comment = false
    else
      local line_comment = s:find("//", 1, true)
      local block_start = s:find("/%*", 1, false)
      if line_comment and (not block_start or line_comment < block_start) then
        s = s:sub(1, line_comment - 1)
        return s, false
      end
      if block_start then
        local block_end = s:find("%*/", block_start + 2, false)
        if block_end then
          s = s:sub(1, block_start - 1) .. s:sub(block_end + 2)
        else
          s = s:sub(1, block_start - 1)
          return s, true
        end
      else
        return s, false
      end
    end
  end
end

local function extract_decl(line)
  for _, rule in ipairs(go_decl_patterns) do
    local name = line:match(rule.pattern)
    if name and name ~= "" then
      return name, rule.kind
    end
  end
  return nil, nil
end

local function parse_go_decls_from_file(filename, items)
  local lines = vim.fn.readfile(filename)
  local in_block_comment = false

  for lnum, raw in ipairs(lines) do
    local line
    line, in_block_comment = strip_comments(raw, in_block_comment)
    local name, kind = extract_decl(line)
    if name then
      local col = line:find(name, 1, true) or 1
      table.insert(items, {
        filename = filename,
        lnum = lnum,
        col = col,
        text = string.format("%s [%s]", name, kind),
      })
    end
  end
end

local function sort_decl_items(items)
  table.sort(items, function(a, b)
    if a.filename == b.filename then
      if a.lnum == b.lnum then
        return a.col < b.col
      end
      return a.lnum < b.lnum
    end
    return a.filename < b.filename
  end)
end

local function show_go_decls_fzf(items, target_dir)
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.fn.setqflist({}, " ", {
      title = "GoDeclsDir " .. target_dir,
      items = items,
    })
    vim.cmd("copen")
    return
  end

  local lines = {}
  for _, item in ipairs(items) do
    local rel = item.filename
    if vim.startswith(item.filename, target_dir .. "/") then
      rel = item.filename:sub(#target_dir + 2)
    end
    table.insert(lines, string.format("%s:%d:%d: %s", rel, item.lnum, item.col, item.text))
  end

  fzf.fzf_exec(lines, {
    prompt = "GoDeclsDir> ",
    cwd = target_dir,
    previewer = "builtin",
    fzf_opts = {
      ["--delimiter"] = ":",
      ["--nth"] = "1,4..",
      ["--tiebreak"] = "index",
      ["--preview-window"] = "right,60%,border-left,+{2}+3/3,~3",
    },
    actions = {
      ["default"] = function(selected)
        local entry = selected and selected[1]
        if not entry then
          return
        end
        local rel, lnum, col = entry:match("^(.+):(%d+):(%d+):")
        if not rel then
          return
        end
        local path = rel
        if not vim.startswith(rel, "/") then
          path = vim.fs.joinpath(target_dir, rel)
        end
        vim.cmd(("edit +%d %s"):format(tonumber(lnum), vim.fn.fnameescape(path)))
        vim.api.nvim_win_set_cursor(0, { tonumber(lnum), tonumber(col) - 1 })
      end,
    },
  })
end

local function go_decls_dir(input_dir)
  local target_dir = resolve_target_dir(input_dir)
  local files = collect_go_files(target_dir)
  if #files == 0 then
    vim.notify("GoDeclsDir: no .go files in " .. target_dir, vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, filename in ipairs(files) do
    parse_go_decls_from_file(filename, items)
  end

  if #items == 0 then
    vim.notify("GoDeclsDir: no declarations in " .. target_dir, vim.log.levels.INFO)
    return
  end

  sort_decl_items(items)
  show_go_decls_fzf(items, target_dir)
end

vim.api.nvim_create_user_command("GoDeclsDir", function(opts)
  go_decls_dir(opts.args)
end, { nargs = "?" })

vim.api.nvim_set_keymap("n", "<C-g>", ":GoDeclsDir<CR>", { noremap = true, silent = true })
