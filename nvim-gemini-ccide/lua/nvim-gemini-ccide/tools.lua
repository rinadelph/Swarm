-- nvim-gemini-ccide/lua/nvim-gemini-ccide/tools.lua

local M = {}

local registered_tools = {}
local tool_handlers = {}

-- Register tools from Claude Code
function M.register(tools_list)
  registered_tools = {}
  vim.notify("Claude Code: Available tools:", vim.log.levels.INFO)
  
  for _, tool in ipairs(tools_list) do
    registered_tools[tool.name] = tool
    vim.notify("  • " .. tool.name .. (tool.description and (": " .. tool.description) or ""), vim.log.levels.INFO)
  end
end

function M.get_registered_tools()
  return registered_tools
end

function M.get_handler(method_name)
  return tool_handlers[method_name]
end

-- Tool implementations for Neovim to respond to Claude Code

-- Get current selection
tool_handlers['getCurrentSelection'] = function(params)
  local mode = vim.fn.mode()
  local text = ""
  local selection = nil
  
  if mode == 'v' or mode == 'V' or mode == '' then
    -- Visual mode - get current selection
    -- Use 'v' for visual start and '.' for current cursor position
    local start_pos = vim.fn.getpos('v')
    local end_pos = vim.fn.getpos('.')
    
    -- Ensure start is before end
    if start_pos[2] > end_pos[2] or (start_pos[2] == end_pos[2] and start_pos[3] > end_pos[3]) then
      start_pos, end_pos = end_pos, start_pos
    end
    
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)
    
    if mode == 'v' then
      -- Character-wise visual
      if #lines == 1 then
        lines[1] = lines[1]:sub(start_pos[3], end_pos[3])
      else
        lines[1] = lines[1]:sub(start_pos[3])
        lines[#lines] = lines[#lines]:sub(1, end_pos[3])
      end
    end
    
    text = table.concat(lines, '\n')
    selection = {
      start = { line = start_pos[2] - 1, character = start_pos[3] - 1 },
      ["end"] = { line = end_pos[2] - 1, character = end_pos[3] - 1 },
      isEmpty = false
    }
  else
    -- Not in visual mode - check if there's a previous selection
    local last_start = vim.fn.getpos("'<")
    local last_end = vim.fn.getpos("'>")
    
    -- Check if marks are valid (not at position 0,0)
    if last_start[2] > 0 and last_end[2] > 0 then
      -- There was a previous selection, but we're not in visual mode now
      selection = {
        isEmpty = true
      }
    else
      -- No selection
      selection = {
        isEmpty = true
      }
    end
  end
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          text = text,
          filePath = vim.api.nvim_buf_get_name(0),
          selection = selection
        })
      }
    }
  }
end

-- Get open editors
tool_handlers['getOpenEditors'] = function(params)
  local editors = {}
  
  -- Get all buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" then
        table.insert(editors, {
          uri = "file://" .. name,
          filePath = name,
          languageId = vim.bo[buf].filetype
        })
      end
    end
  end
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          editors = editors
        })
      }
    }
  }
end

-- Get workspace folders
tool_handlers['getWorkspaceFolders'] = function(params)
  local folders = {}
  
  -- Try to get from LSP clients
  local clients = vim.lsp.get_active_clients()
  for _, client in ipairs(clients) do
    if client.config.root_dir then
      table.insert(folders, {
        uri = "file://" .. client.config.root_dir,
        name = vim.fn.fnamemodify(client.config.root_dir, ":t")
      })
    end
  end
  
  -- If no LSP, use current working directory
  if #folders == 0 then
    local cwd = vim.fn.getcwd()
    table.insert(folders, {
      uri = "file://" .. cwd,
      name = vim.fn.fnamemodify(cwd, ":t")
    })
  end
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          folders = folders
        })
      }
    }
  }
end

-- Get diagnostics
tool_handlers['getDiagnostics'] = function(params)
  local diagnostics = {}
  
  if params.uri and params.uri ~= "" and params.uri ~= "file://" then
    -- Get diagnostics for specific file
    local ok, bufnr = pcall(vim.uri_to_bufnr, params.uri)
    if ok and bufnr then
      local diags = vim.diagnostic.get(bufnr)
      
      for _, diag in ipairs(diags) do
        table.insert(diagnostics, {
          severity = diag.severity,
          message = diag.message,
          source = diag.source,
          range = {
            start = { line = diag.lnum, character = diag.col },
            ["end"] = { line = diag.end_lnum or diag.lnum, character = diag.end_col or diag.col }
          }
        })
      end
    end
  else
    -- Get all diagnostics
    local diags = vim.diagnostic.get()
    
    for _, diag in ipairs(diags) do
      local bufnr = diag.bufnr
      local uri = vim.uri_from_bufnr(bufnr)
      
      table.insert(diagnostics, {
        uri = uri,
        severity = diag.severity,
        message = diag.message,
        source = diag.source,
        range = {
          start = { line = diag.lnum, character = diag.col },
          ["end"] = { line = diag.end_lnum or diag.lnum, character = diag.end_col or diag.col }
        }
      })
    end
  end
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode(diagnostics)
      }
    }
  }
end

-- Check if document is dirty
tool_handlers['checkDocumentDirty'] = function(params)
  local uri = params.uri
  local bufnr = vim.uri_to_bufnr(uri)
  local modified = vim.bo[bufnr].modified
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          isDirty = modified
        })
      }
    }
  }
end

-- Save document
tool_handlers['saveDocument'] = function(params)
  local uri = params.uri
  local bufnr = vim.uri_to_bufnr(uri)
  
  -- Save the buffer
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd('write')
  end)
  
  return {
    content = {
      {
        type = "text",
        text = "Document saved"
      }
    }
  }
end

-- Open file
tool_handlers['openFile'] = function(params)
  local filePath = params.filePath
  if not filePath then
    return {
      content = {
        {
          type = "text",
          text = vim.json.encode({
            error = "No filePath provided"
          })
        }
      }
    }
  end
  
  -- Open the file
  vim.cmd('edit ' .. vim.fn.fnameescape(filePath))
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          success = true,
          filePath = filePath
        })
      }
    }
  }
end

-- Close all diff tabs
tool_handlers['closeAllDiffTabs'] = function(params)
  local closed_count = 0
  
  -- Iterate through all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local diff = vim.api.nvim_win_get_option(win, 'diff')
    
    if diff then
      -- Close the diff window
      vim.api.nvim_win_close(win, false)
      closed_count = closed_count + 1
    end
  end
  
  return {
    content = {
      {
        type = "text",
        text = vim.json.encode({
          closedCount = closed_count
        })
      }
    }
  }
end

return M