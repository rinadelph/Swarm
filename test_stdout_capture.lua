-- Test stdout capture issue

local job = vim.fn.jobstart({'python3', '/home/alejandro/VPS/CCIde/test_stdout_issue.py'}, {
  on_stdout = function(_, data, _)
    print("STDOUT data received:")
    for i, line in ipairs(data) do
      print(string.format("  [%d] '%s'", i, line))
    end
  end,
  on_stderr = function(_, data, _) 
    print("STDERR data received:")
    for i, line in ipairs(data) do
      print(string.format("  [%d] '%s'", i, line))
    end
  end,
  on_exit = function(_, code)
    print("Job exited with code:", code)
  end,
  stdout_buffered = false,  -- Try unbuffered
  stderr_buffered = false,
})

print("Started job:", job)