#!/bin/bash

echo "Installing dependencies for Claude MITM testing..."

# Install expect
echo "Installing expect..."
sudo apt-get update
sudo apt-get install -y expect

# Install mitmproxy via pip
echo "Installing mitmproxy..."
pip install --user mitmproxy

# Add pip user bin to PATH if needed
export PATH="$HOME/.local/bin:$PATH"

# Check installations
echo
echo "Checking installations:"
which expect && echo "✓ expect installed" || echo "✗ expect not found"
which mitmproxy && echo "✓ mitmproxy installed" || echo "✗ mitmproxy not found"

echo
echo "Add this to your .bashrc if mitmproxy is not found:"
echo 'export PATH="$HOME/.local/bin:$PATH"'