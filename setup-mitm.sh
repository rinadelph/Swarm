#!/bin/bash

# Setup script for MITM proxy environment for Claude Code reverse engineering

echo "Setting up MITM proxy environment for Claude Code..."

# Install mitmproxy if not already installed
if ! command -v mitmproxy &> /dev/null; then
    echo "Installing mitmproxy..."
    pip install mitmproxy
fi

# Create directories
mkdir -p mitm-claude/{certs,captures,scripts,logs}

# Generate and install certificates
echo "Setting up MITM certificates..."
cd mitm-claude

# Start mitmproxy briefly to generate certificates
timeout 5 mitmproxy > /dev/null 2>&1 || true

# Export certificate location
export MITM_CERT_DIR="$HOME/.mitmproxy"

# Instructions for certificate installation
cat << EOF > certs/CERTIFICATE_SETUP.md
# MITM Proxy Certificate Setup

The mitmproxy CA certificate has been generated at:
~/.mitmproxy/mitmproxy-ca-cert.pem

## Linux Certificate Installation:

1. Copy certificate to system store:
   sudo cp ~/.mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
   sudo update-ca-certificates

2. For Node.js/npm (Claude Code uses Node):
   export NODE_EXTRA_CA_CERTS=~/.mitmproxy/mitmproxy-ca-cert.pem

3. For system-wide SSL:
   export SSL_CERT_FILE=~/.mitmproxy/mitmproxy-ca-cert.pem
   export REQUESTS_CA_BUNDLE=~/.mitmproxy/mitmproxy-ca-cert.pem

EOF

echo "Certificate setup instructions written to mitm-claude/certs/CERTIFICATE_SETUP.md"