-- Simple test to verify IPC works at all

local job_id

-- Simple echo server that looks for NVIM_REQUEST
local echo_server = [[
import sys
while True:
    line = sys.stdin.readline()
    if not line:
        break
    print(f"[ECHO] Got: {line.strip()}", file=sys.stderr)
    # Echo back
    sys.stdout.write(f"ECHO: {line}")
    sys.stdout.flush()
]]

-- Write script
vim.fn.writefile(vim.split(echo_server, '\n'), '/tmp/echo_test.py')

-- Start job
job_id = vim.fn.jobstart({'python3', '/tmp/echo_test.py'}, {
  on_stdout = function(_, data)
    print("STDOUT:", vim.inspect(data))
  end,
  on_stderr = function(_, data)
    print("STDERR:", vim.inspect(data))
  end,
  on_exit = function()
    print("Process exited")
  end
})

print("Started job:", job_id)

-- Send test data
vim.defer_fn(function()
  print("Sending test...")
  vim.fn.chansend(job_id, "Hello from Neovim\n")
end, 100)

-- Stop after 1 second
vim.defer_fn(function()
  vim.fn.jobstop(job_id)
  vim.fn.delete('/tmp/echo_test.py')
end, 1000)