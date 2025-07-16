# Swarm Update and Installation Guide

This guide covers how to properly build, install, and update Swarm with its plugins.

## Table of Contents
1. [Build Process Overview](#build-process-overview)
2. [Step-by-Step Update Process](#step-by-step-update-process)
3. [Installation Locations](#installation-locations)
4. [Troubleshooting](#troubleshooting)
5. [MCP Manager Plugin Issues](#mcp-manager-plugin-issues)

## Build Process Overview

Swarm uses a two-step build process:
1. **Build plugins first** - All plugins must be compiled to WASM format
2. **Build main binary** - The main swarm executable that embeds the plugins

## Step-by-Step Update Process

### 1. Clean Previous Builds (Optional)
```bash
# Remove old build artifacts
rm -rf target/wasm32-wasip1/release/*.wasm
rm -rf target/release/swarm
```

### 2. Build All Plugins
```bash
# This builds all plugins and copies them to assets directory
cargo xtask build --plugins-only --release
```

**Note**: If a plugin fails to build as WASM, build it manually:
```bash
cd default-plugins/my-custom-manager
cargo build --release --target wasm32-wasip1
cp ../../target/wasm32-wasip1/release/my_custom_manager.wasm ../../zellij-utils/assets/plugins/my-custom-manager.wasm
cd ../..
```

### 3. Build Main Binary
```bash
# This embeds all plugins from assets directory into the binary
cargo build --release -p swarm
```

### 4. Install the Binary

Swarm can be installed in multiple locations. Check current installations:
```bash
# Find all swarm installations
type -a swarm

# Check versions
/home/alejandro/.local/bin/swarm --version
/usr/local/bin/swarm --version
```

#### Local User Installation
```bash
# Install to user's local bin (no sudo required)
cp target/release/swarm ~/.local/bin/swarm
```

#### System-Wide Installation
```bash
# Install system-wide (requires sudo)
echo "YOUR_SUDO_PASSWORD" | sudo -S cp target/release/swarm /usr/local/bin/swarm

# Or create a script:
cat > /tmp/update_swarm.sh << 'EOF'
#!/bin/bash
echo "YOUR_SUDO_PASSWORD" | sudo -S cp /home/alejandro/VPS/zellij/target/release/swarm /usr/local/bin/swarm
EOF
chmod +x /tmp/update_swarm.sh
/tmp/update_swarm.sh
```

### 5. Verify Installation
```bash
# Check which binary is being used
which swarm

# Verify version
swarm --version
```

## Installation Locations

Swarm typically exists in these locations (in PATH order):
1. `/home/alejandro/.local/bin/swarm` - User installation (takes precedence)
2. `/home/alejandro/bin/swarm` - Alternative user installation
3. `/usr/local/bin/swarm` - System-wide installation

The first one found in PATH is the one that will be executed.

## Troubleshooting

### Debug Logging
Swarm creates debug logs at `/tmp/swarm_debug.log`. To view:
```bash
tail -f /tmp/swarm_debug.log
```

### Common Issues

1. **Plugin not loading**: 
   - Check if the WASM file exists in `zellij-utils/assets/plugins/`
   - Verify the plugin is listed in `zellij-utils/src/consts.rs`
   - Ensure the plugin alias is correct in config files

2. **Wrong version running**:
   - Kill all swarm processes: `pkill -f swarm`
   - Check PATH order: `echo $PATH | tr ':' '\n' | grep bin`
   - Remove old binaries if needed

3. **Configuration errors**:
   - User config: `~/.config/swarm/config.kdl`
   - Default config: `zellij-utils/assets/config/default.kdl`

## MCP Manager Plugin Issues

### Current Status
The MCP manager plugin (my-custom-manager) is being triggered according to debug logs but may not be displaying properly.

### Root Cause
The plugin was correctly triggered but wasn't rendering. Added debug output to verify plugin execution.

### Debug Steps
1. Check if plugin WASM exists:
   ```bash
   ls -la zellij-utils/assets/plugins/my-custom-manager.wasm
   ```

2. Verify plugin is properly embedded:
   ```bash
   # The binary should be large (50+ MB) if plugins are embedded
   ls -lh target/release/swarm
   ```

3. Test in a clean environment:
   ```bash
   # Kill existing sessions
   pkill -f swarm
   
   # Start fresh
   swarm
   
   # Press Esc to exit welcome screen
   # Press Ctrl+a to enter Swarm mode
   # Press 2 to launch MCP manager
   ```

4. Check logs for errors:
   ```bash
   grep -i error /tmp/swarm_debug.log
   grep -i "my-custom-manager" /tmp/swarm_debug.log
   ```

### Plugin Configuration
The plugin should be aliased in config files:
```kdl
plugins {
    // ... other plugins ...
    my-custom-manager location="swarm:my-custom-manager"
}
```

And bound to a key:
```kdl
swarm {
    bind "2" {
        LaunchOrFocusPlugin "my-custom-manager" {
            floating true
            move_to_focused_tab true
        }
        SwitchToMode "Normal"
    }
}
```

### Troubleshooting Plugin Display Issues

If a plugin is being triggered (shown in debug logs) but not displaying:

1. **Add debug output to render method**:
   ```rust
   fn render(&mut self, rows: usize, cols: usize) {
       print!("\u{1b}[2J\u{1b}[H"); // Clear screen and reset cursor
       println!("Plugin is running!");
       // ... rest of render code
   }
   ```

2. **Check plugin trait implementation**:
   - Must implement `SwarmPlugin` trait (not `ZellijPlugin`)
   - Must use `register_plugin!` macro

3. **Verify floating window settings**:
   - `floating true` in keybinding config
   - Plugin should handle window sizing properly

4. **Common rendering issues**:
   - Not clearing screen properly
   - Using wrong ANSI escape sequences
   - Not flushing output

## Complete Rebuild Process

For a complete clean rebuild:
```bash
# 1. Clean everything
cargo clean

# 2. Build plugins
cargo xtask build --plugins-only --release

# 3. Manually build problematic plugins if needed
cd default-plugins/my-custom-manager
cargo build --release --target wasm32-wasip1
cp ../../target/wasm32-wasip1/release/my_custom_manager.wasm ../../zellij-utils/assets/plugins/my-custom-manager.wasm
cd ../..

# 4. Build main binary
cargo build --release -p swarm

# 5. Install
cp target/release/swarm ~/.local/bin/swarm
echo "YOUR_PASSWORD" | sudo -S cp target/release/swarm /usr/local/bin/swarm

# 6. Verify
swarm --version
```

## Notes

- Always build plugins before the main binary
- The main binary embeds all plugins from the assets directory
- Configuration changes don't require rebuilding
- Use debug logs to troubleshoot issues
- Make sure to update all installation locations for consistency