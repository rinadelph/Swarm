#!/bin/bash
echo "Testing MCP Manager Plugin"
echo "=========================="
echo ""
echo "This will launch swarm in debug mode."
echo "Follow these steps to test the MCP manager:"
echo ""
echo "1. Press Esc to exit the welcome screen"
echo "2. Press Ctrl+a to enter Swarm mode" 
echo "3. Press 2 to launch MCP Manager"
echo ""
echo "If it fails, check the debug output and:"
echo "- Look for 'Failed to load plugin' errors"
echo "- Check which plugin failed to load"
echo "- Look for any keybinding errors"
echo ""
echo "Press Enter to start swarm in debug mode..."
read

RUST_LOG=warn swarm