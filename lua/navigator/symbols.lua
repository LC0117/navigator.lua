local gui = require "navigator.gui"
local M = {}
local log = require "navigator.util".log
local verbose = require "navigator.util".trace
local lsphelper = require "navigator.lspwrapper"
local locations_to_items = lsphelper.locations_to_items
local clone = require "guihua.util".clone
local symbol_kind = require "navigator.lspclient.lspkind".symbol_kind
function M.document_symbols(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = {includeDeclaration = true}
  params.query = ""
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 5000)
  local locations = {}
  log(results_lsp)
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
    end
  end
  local lines = {}

  for _, loc in ipairs(locations) do
    table.insert(lines, string.format("%s:%s:%s", loc.filename, loc.lnum, loc.text))
  end
  local cmd = table.concat(lines, "\n")
  if #lines > 0 then
    gui.new_list_view({data = lines})
  else
    print("symbols not found")
  end
end

function M.workspace_symbols(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = {includeDeclaration = true}
  params.query = ""
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 15000)

  log(results_lsp)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result) or {})
    end
  end
  local lines = {}

  for _, loc in ipairs(locations) do
    table.insert(lines, string.format("%s:%s:%s", loc.filename, loc.lnum, loc.text))
  end
  if #lines > 0 then
    gui.new_list_view({data = lines})
  else
    print("symbols not found")
  end
end

function M.document_symbol_handler(err, _, result, _, bufnr)
  if err then
    print(bufnr, "failed to get document symbol")
  end

  if not result or vim.tbl_isempty(result) then
    print(bufnr, "symbol not found for buf")
    return
  end
  -- log(result)
  local locations = {}
  local fname = vim.fn.expand("%:p:f")
  local uri = vim.uri_from_fname(fname)
  -- vim.list_extend(locations, vim.lsp.util.symbols_to_items(result) or {})
  -- log(locations)
  for i = 1, #result do
    local item = {}
    item.kind = result[i].kind
    local kind = symbol_kind(item.kind)
    item.name = result[i].name
    item.range = result[i].range
    item.uri = uri
    item.selectionRange = result[i].selectionRange
    item.detail = result[i].detail or ''
    if item.detail == '()' then item.detail = 'func' end

    item.lnum = result[i].range.start.line + 1
    item.text = "[" .. kind .. "]" .. item.detail  .. " " .. item.name

    item.filename = fname

    table.insert(locations, item)
    if result[i].children ~= nil then
      for _, c in pairs (result[i].children) do
        local child = {}
        child.kind = c.kind
        child.name = c.name
        child.range = c.range
        local ckind = symbol_kind(child.kind)
        child.selectionRange = c.selectionRange
        child.fname = fname
        child.uri = uri
        child.lnum = c.range.start.line + 1
        child.detail = c.detail or ''
        child.text = "   [" .. ckind .. "] " .. child.detail .. " " .. child.name
        table.insert(locations, child)
      end
    end
  end
  verbose(locations)
  -- local items = locations_to_items(locations)
  gui.new_list_view({items = locations, prompt = true, rawdata = true, api = '華 '})

  -- if locations == nil or vim.tbl_isempty(locations) then
  --   print "References not found"
  --   return
  -- end
  -- local items = locations_to_items(locations)
  -- gui.new_list_view({items = items})
  -- local filename = vim.api.nvim_buf_get_name(bufnr)
  -- local  items = vim.lsp.util.symbols_to_items(result, bufnr)
  -- local data = {}
  -- for i, item in pairs(action.items) do
  --   data[i] = item.text
  --   if filename ~= item.filename then
  --     local cwd = vim.fn.getcwd(0) .. "/"
  --     local add = util.get_relative_path(cwd, item.filename)
  --     data[i] = data[i] .. " - " .. add
  --   end
  --   item.text = nil
  -- end
  -- opts.data = data
end

function M.workspace_symbol_handler(err, _, result, _, bufnr)
  if err then
    print(bufnr, "failed to get workspace symbol")
  end
  if not result or vim.tbl_isempty(result) then
    print(bufnr, "symbol not found for buf")
    return
  end
  log(result)
  local locations = {}
  for i = 1, #result do
    local item = result[i].location or {}
    item.kind = result[i].kind
    item.containerName = result[i].containerName
    item.name = result[i].name
    item.text = result[i].name
    if #item.containerName > 0 then
      item.text = item.text:gsub(item.containerName, "", 1)
    end
    table.insert(locations, item)
  end
  local items = locations_to_items(locations)
  gui.new_list_view({items = items, prompt = true, api = '華 '})

  -- if locations == nil or vim.tbl_isempty(locations) then
  --   print "References not found"
  --   return
  -- end
  -- local items = locations_to_items(locations)
  -- gui.new_list_view({items = items})
  -- local filename = vim.api.nvim_buf_get_name(bufnr)
  -- local  items = vim.lsp.util.symbols_to_items(result, bufnr)
  -- local data = {}
  -- for i, item in pairs(action.items) do
  --   data[i] = item.text
  --   if filename ~= item.filename then
  --     local cwd = vim.fn.getcwd(0) .. "/"
  --     local add = util.get_relative_path(cwd, item.filename)
  --     data[i] = data[i] .. " - " .. add
  --   end
  --   item.text = nil
  -- end
  -- opts.data = data
end

return M