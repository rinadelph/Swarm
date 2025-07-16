#!/bin/bash
echo "Testing MCP Manager in Swarm v0.0.9"
echo "==================================="
echo ""
echo "1. Starting swarm..."
swarm &
SWARM_PID=$!
sleep 3

echo "2. Swarm is running. Instructions:"
echo "   - Press Esc to exit the welcome screen"
echo "   - Press Ctrl+a to enter Swarm mode"
echo "   - Press 2 to launch MCP Manager"
echo ""
echo "3. The MCP Manager should show:"
echo "   - Main menu with options"
echo "   - Navigation with arrow keys"
echo "   - Press 'q' to close the plugin"
echo ""
echo "Press any key to continue when ready to test..."
read -n 1

# Wait for swarm to finish
wait $SWARM_PID
echo "Test complete!"