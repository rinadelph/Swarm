#!/bin/bash

# Swarm Auto-Deploy Script
# Builds, installs, and deploys Swarm to system PATH

set -e  # Exit on any error

echo "🚀 Starting Swarm Auto-Deploy..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "Cargo.toml" ] || [ ! -d "default-plugins" ]; then
    print_error "This script must be run from the Swarm project root directory!"
    exit 1
fi

# Get current version
VERSION=$(grep '^version = ' Cargo.toml | head -1 | sed 's/version = "\(.*\)"/\1/')
print_status "Building Swarm version $VERSION"

# Clean previous builds
print_status "Cleaning previous builds..."
cargo clean

# Build release version
print_status "Building Swarm in release mode..."
cargo build --release

# Check if build was successful
if [ ! -f "target/release/swarm" ]; then
    print_error "Build failed! Binary not found at target/release/swarm"
    exit 1
fi

print_success "Build completed successfully!"

# Get sudo password for installation
print_status "Installing to system PATH (requires sudo)..."

# Install to /usr/local/bin
if sudo cp target/release/swarm /usr/local/bin/; then
    print_success "Swarm binary installed to /usr/local/bin/swarm"
else
    print_error "Failed to install Swarm binary!"
    exit 1
fi

# Create short alias
if sudo ln -sf /usr/local/bin/swarm /usr/local/bin/sm; then
    print_success "Short alias 'sm' created"
else
    print_warning "Failed to create short alias 'sm'"
fi

# Remove old versions from ~/.local/bin if they exist
if [ -f "$HOME/.local/bin/swarm" ]; then
    print_status "Removing old version from ~/.local/bin..."
    rm -f "$HOME/.local/bin/swarm" "$HOME/.local/bin/sm"
    print_success "Old versions removed"
fi

# Verify installation
if command -v swarm >/dev/null 2>&1; then
    INSTALLED_VERSION=$(swarm --version | cut -d' ' -f2)
    if [ "$INSTALLED_VERSION" = "$VERSION" ]; then
        print_success "Swarm v$VERSION successfully installed and verified!"
    else
        print_warning "Version mismatch! Expected $VERSION, got $INSTALLED_VERSION"
    fi
else
    print_error "Swarm command not found in PATH after installation!"
    exit 1
fi

# Test basic functionality
print_status "Testing basic functionality..."
if swarm --help >/dev/null 2>&1; then
    print_success "Basic functionality test passed!"
else
    print_warning "Basic functionality test failed"
fi

echo
print_success "🎉 Swarm v$VERSION deployment completed successfully!"
echo -e "${GREEN}You can now use:${NC}"
echo -e "  ${BLUE}swarm${NC}     - Full command"
echo -e "  ${BLUE}sm${NC}        - Short alias"
echo -e "  ${BLUE}Ctrl+a${NC}    - Test session manager (new feature)"
echo
print_status "Note: Tip toolbar has been removed and directory-based session naming is active"