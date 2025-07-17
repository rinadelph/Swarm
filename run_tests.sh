
#!/bin/bash

# Define log files
SERVER_LOG="mock_server.log"
NVIM_LOG="nvim_output.log"

# Clean up previous logs
rm -f $SERVER_LOG $NVIM_LOG

# Start the mock server in the background, redirecting its stdout/stderr to a log file
python3 mock_claude_server.py > $SERVER_LOG 2>&1 &
SERVER_PID=$!

# Give the server a moment to start
sleep 1

# Create a dummy file for Neovim
echo "This is a dummy file for testing." > dummy.txt

# Start Neovim in headless mode, opening the dummy file
# and redirecting its messages to NVIM_LOG
nvim --headless -u nvim-swarm-modern.lua dummy.txt << EOF
:set nomore
:redir > ${NVIM_LOG}
:silent! ClaudeConnect
:sleep 2
:lua print(vim.inspect(require('nvim-gemini-ccide.tools').get_handler('getCurrentSelection')({}))) 
:redir END
:qa!
EOF

# Wait for Neovim to exit
sleep 1

# Kill the server
kill $SERVER_PID

# Clean up dummy file
rm -f dummy.txt

echo "Tests finished. Check $SERVER_LOG and $NVIM_LOG for output."
