#!/bin/bash
set -euo pipefail

# Swarm Terminal Workspace Installer
# Quick and easy installation script for Swarm

REPO_URL="https://github.com/alejandro/swarm"
INSTALL_DIR="$HOME/.local/bin"
BINARY_NAME="swarm"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_colored() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Create install directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

print_colored "$BLUE" "🚀 Installing Swarm Terminal Workspace..."

# Check if Rust/Cargo is installed
if ! command -v cargo &> /dev/null; then
    print_colored "$YELLOW" "⚠️  Cargo not found. Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

# Build and install
print_colored "$BLUE" "🔨 Building Swarm from source..."
cargo build --release --no-default-features --features "vendored_curl,web_server_capability"

# Copy binary
cp target/release/swarm "$INSTALL_DIR/swarm"

# Create symlinks for short commands
ln -sf "$INSTALL_DIR/swarm" "$INSTALL_DIR/sm"

# Make sure it's executable
chmod +x "$INSTALL_DIR/swarm"

print_colored "$GREEN" "✅ Swarm installed successfully!"
print_colored "$BLUE" "📍 Binary location: $INSTALL_DIR/swarm"

# Check if install directory is in PATH
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    print_colored "$YELLOW" "⚠️  $INSTALL_DIR is not in your PATH"
    print_colored "$YELLOW" "   Add this line to your shell config (.bashrc, .zshrc, etc.):"
    print_colored "$YELLOW" "   export PATH=\"\$PATH:$INSTALL_DIR\""
    echo ""
fi

print_colored "$GREEN" "🎉 Installation complete!"
print_colored "$BLUE" "Usage:"
print_colored "$BLUE" "  swarm       # Start Swarm terminal workspace"
print_colored "$BLUE" "  sm          # Short command alias"
print_colored "$BLUE" "  swarm --help # Show all available options"
print_colored "$BLUE" "  swarm setup --dump-config # Show default configuration"
echo ""
print_colored "$BLUE" "🔥 Welcome to Swarm - The Ultimate Terminal Workspace!"

# Test installation
if command -v swarm &> /dev/null; then
    print_colored "$GREEN" "✅ 'swarm' command is available"
else
    print_colored "$RED" "❌ 'swarm' command not found. Check your PATH."
fi

if command -v sm &> /dev/null; then
    print_colored "$GREEN" "✅ 'sm' short command is available"
else
    print_colored "$RED" "❌ 'sm' command not found. Check your PATH."
fi