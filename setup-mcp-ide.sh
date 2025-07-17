#!/bin/bash
# Setup script for Neovim MCP IDE Integration

echo "🔧 Setting up Neovim MCP IDE Integration..."

# Check dependencies
echo "📦 Checking dependencies..."

# Check Python 3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed."
    echo "   Install with: sudo apt-get install python3"
    exit 1
fi

# Check required Python packages
python3 -c "import asyncio, websockets, json, sys, os, uuid, threading, time" 2>/dev/null
if [ $? -ne 0 ]; then
    echo "❌ Missing Python packages. Installing..."
    pip3 install websockets
fi

# Check Neovim
if ! command -v nvim &> /dev/null; then
    echo "❌ Neovim is required but not installed."
    echo "   Install with: sudo apt-get install neovim"
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p ~/.claude/ide/
mkdir -p ~/.config/nvim/

# Clean up any stale lock files
echo "🧹 Cleaning up stale lock files..."
for lockfile in ~/.claude/ide/*.lock; do
    if [ -f "$lockfile" ]; then
        # Check if the PID in the lock file is still running
        if [ -f "$lockfile" ]; then
            pid=$(grep -o '"pid":[0-9]*' "$lockfile" | cut -d: -f2)
            if [ ! -z "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
                echo "   Removing stale lock file: $lockfile"
                rm "$lockfile"
            fi
        fi
    fi
done

# Make Python scripts executable
echo "🔑 Setting permissions..."
chmod +x /home/alejandro/VPS/CCIde/nvim-gemini-ccide/mcp_server_robust.py
chmod +x /home/alejandro/VPS/CCIde/nvim-gemini-ccide/test_ipc_server.py
chmod +x /home/alejandro/VPS/CCIde/nvim-gemini-ccide/simple_monitor.py
chmod +x /home/alejandro/VPS/CCIde/nvim-gemini-ccide/continuous_ipc_monitor.py

# Create alias for easy launch
echo "🚀 Creating launch alias..."
if ! grep -q "alias nvim-mcp" ~/.bashrc; then
    echo "alias nvim-mcp='nvim -u /home/alejandro/VPS/CCIde/nvim-swarm-modern.lua'" >> ~/.bashrc
    echo "   Added 'nvim-mcp' alias to ~/.bashrc"
fi

# Test the setup
echo "🧪 Testing setup..."
cd /home/alejandro/VPS/CCIde

# Clear any existing debug log
echo '=== MCP Debug Log ===' > /tmp/nvim_mcp_debug.log

echo ""
echo "✅ Setup complete!"
echo ""
echo "📖 Usage:"
echo "   1. Start Neovim: nvim-mcp (or nvim -u nvim-swarm-modern.lua)"
echo "   2. MCP server will auto-start"
echo "   3. In Claude, use /ide to connect"
echo "   4. Check status in Neovim: <Space>m?"
echo ""
echo "📚 Documentation: /home/alejandro/VPS/CCIde/MCP_IDE_INTEGRATION.md"
echo ""
echo "🔍 Debug log: tail -f /tmp/nvim_mcp_debug.log"
echo ""
echo "💡 Tip: Source your bashrc to use the alias immediately:"
echo "   source ~/.bashrc"