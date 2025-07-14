#!/bin/bash

# Fast development install script for Swarm
set -e

echo "🚀 Building Swarm..."

# Build in debug mode for speed
cargo build

echo "📦 Installing to ~/.local/bin/swarm..."

# Kill any running swarm processes
pkill -f swarm 2>/dev/null || true
sleep 0.5

# Copy new binary
cp ./target/debug/swarm ~/.local/bin/swarm
chmod +x ~/.local/bin/swarm

echo "✅ Swarm installed successfully!"
echo "🔧 Run 'swarm' to test"

# Optional: Create sm alias
if ! command -v sm &> /dev/null; then
    echo "🔗 Creating 'sm' alias..."
    ln -sf ~/.local/bin/swarm ~/.local/bin/sm
fi

echo "🎉 Ready to use: swarm or sm"