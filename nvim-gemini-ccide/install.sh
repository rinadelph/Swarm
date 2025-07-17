#!/bin/bash

echo "=== Claude Code Neovim Plugin Installer ==="

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check Python
echo -e "\n${YELLOW}Checking Python...${NC}"
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓ Python 3 found${NC}"
else
    echo -e "${RED}✗ Python 3 not found. Please install Python 3.${NC}"
    exit 1
fi

# Install websocket-client
echo -e "\n${YELLOW}Installing Python dependencies...${NC}"
pip install websocket-client --user || {
    echo -e "${RED}Failed to install websocket-client${NC}"
    echo "Try: pip install websocket-client"
    exit 1
}
echo -e "${GREEN}✓ Dependencies installed${NC}"

# Make bridge executable
chmod +x websocket_bridge.py
echo -e "${GREEN}✓ WebSocket bridge configured${NC}"

# Create example configuration
echo -e "\n${YELLOW}Creating example configuration...${NC}"
cat > example_config.lua << 'EOF'
-- Add this to your Neovim configuration

-- Using packer.nvim
use {
  'your-path/nvim-claude-code',
  config = function()
    require('nvim-gemini-ccide').setup({
      auto_connect = true,
      auto_connect_delay = 2000,
      keymaps = true,
      keymaps_prefix = "<leader>c",
      debug = false,
    })
  end
}

-- Or using lazy.nvim
{
  'your-path/nvim-claude-code',
  config = function()
    require('nvim-gemini-ccide').setup({
      auto_connect = true,
      auto_connect_delay = 2000,
      keymaps = true,
      keymaps_prefix = "<leader>c",
      debug = false,
    })
  end
}

-- Or manual setup in init.lua
-- require('nvim-gemini-ccide').setup()
EOF

echo -e "${GREEN}✓ Example configuration created: example_config.lua${NC}"

# Test VS Code connection
echo -e "\n${YELLOW}Checking VS Code connection...${NC}"
if ls ~/.claude/ide/*.lock 2>/dev/null; then
    echo -e "${GREEN}✓ VS Code lock files found${NC}"
    ls -la ~/.claude/ide/*.lock
else
    echo -e "${YELLOW}⚠ No VS Code lock files found${NC}"
    echo "  Make sure VS Code with Claude Code extension is running"
fi

# Installation instructions
echo -e "\n${GREEN}Installation complete!${NC}"
echo -e "\nNext steps:"
echo "1. Copy this plugin to your Neovim plugins directory"
echo "2. Add the configuration from example_config.lua to your init.lua"
echo "3. Make sure VS Code with Claude Code extension is running"
echo "4. Restart Neovim and run :ClaudeConnect"
echo ""
echo "To test the plugin:"
echo "  ./test_plugin.sh"
echo ""
echo "For more information, see README.md"