# Swarm (Zellij) Plugin Development Guide

This guide documents everything learned from creating custom plugins for Swarm (formerly Zellij), including troubleshooting keybindings, understanding the plugin architecture, and building custom plugins.

## Table of Contents
1. [Plugin Architecture Overview](#plugin-architecture-overview)
2. [Troubleshooting Keybindings](#troubleshooting-keybindings)
3. [Creating a Custom Plugin](#creating-a-custom-plugin)
4. [Build System Integration](#build-system-integration)
5. [Configuration Management](#configuration-management)
6. [Common Issues and Solutions](#common-issues-and-solutions)
7. [Development Workflow](#development-workflow)

## Plugin Architecture Overview

### Key Components

1. **Plugin Source**: Located in `/default-plugins/`
2. **Compiled WASM**: Located in `/zellij-utils/assets/plugins/`
3. **API**: Built on the `SwarmPlugin` trait from `zellij-tile` crate
4. **Registration**: Uses the `register_plugin!` macro
5. **Configuration**: Defined in KDL format in config files

### Plugin System Architecture

```
┌─────────────────────────────────────────┐
│         User Config (config.kdl)        │
│  - Plugin aliases                       │
│  - Keybindings                         │
└────────────────┬───────────────────────┘
                 │
┌────────────────▼───────────────────────┐
│        Swarm Core (Rust)               │
│  - Keybinding processor                │
│  - Plugin loader                       │
│  - WASM runtime                        │
└────────────────┬───────────────────────┘
                 │
┌────────────────▼───────────────────────┐
│    WASM Plugins (.wasm files)          │
│  - Compiled from Rust                  │
│  - Embedded in binary                  │
│  - Loaded at runtime                   │
└────────────────────────────────────────┘
```

## Troubleshooting Keybindings

### The Ctrl+a Issue

During development, we encountered an issue where `Ctrl+a` wasn't working to launch the session manager. Here's what we learned:

#### 1. Configuration Loading Hierarchy

```
1. Embedded default config (compile-time)
2. User config (~/.config/swarm/config.kdl)
3. CLI-specified config (--config flag)
```

#### 2. Debug Logging Implementation

To troubleshoot keybinding issues, we added debug logging:

```rust
// In zellij-server/src/route.rs
if let Ok(mut file) = std::fs::OpenOptions::new()
    .create(true)
    .append(true)
    .open("/tmp/swarm_debug.log") {
    use std::io::Write;
    let _ = writeln!(file, "[{}] DEBUG: Key received: {:?}, raw_bytes: {:?}, kitty: {}", 
        std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap().as_secs(),
        key, raw_bytes, is_kitty_keyboard_protocol);
}
```

#### 3. Common Keybinding Issues

1. **Syntax Errors**: Semicolons after plugin configuration blocks
   ```kdl
   // ❌ Wrong
   bind "Ctrl a" {
       LaunchOrFocusPlugin "session-manager" {
           floating true
           move_to_focused_tab true
       };  // <- This semicolon causes issues
   }

   // ✅ Correct
   bind "Ctrl a" {
       LaunchOrFocusPlugin "session-manager" {
           floating true
           move_to_focused_tab true
       }
   }
   ```

2. **Scope Issues**: Keybindings must be in the correct scope
   ```kdl
   // Ensure keybindings are in shared_except sections that exclude
   // the modes where they shouldn't work
   shared_except "locked" "tab" {
       bind "Ctrl a" { /* ... */ }
   }
   ```

3. **Configuration Precedence**: User configs with `clear-defaults=true` completely override defaults

## Creating a Custom Plugin

### Step 1: Create Plugin Directory Structure

```bash
mkdir -p default-plugins/my-custom-manager/src
```

### Step 2: Create Cargo.toml

```toml
[package]
name = "my-custom-manager"
version = "0.0.6"
authors = ["Your Name <your@email.com>"]
edition = "2018"

[lib]
crate-type = ["cdylib"]  # Important: Must be cdylib for WASM

[dependencies]
ansi_term = "0.12.1"
zellij-tile = { path = "../../zellij-tile" }
unicode-width = "0.1.10"
```

### Step 3: Create Plugin Implementation (src/lib.rs)

```rust
use std::collections::BTreeMap;
use zellij_tile::prelude::*;

#[derive(Default)]
struct State {
    message: String,
    colors: Colors,
}

register_plugin!(State);

impl SwarmPlugin for State {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        // Subscribe to events we care about
        subscribe(&[
            EventType::ModeUpdate,
            EventType::Key,
        ]);
        self.message = "Welcome to My Custom Manager!".to_string();
    }

    fn update(&mut self, event: Event) -> bool {
        let mut should_render = false;
        match event {
            Event::ModeUpdate(mode_info) => {
                self.colors = Colors::new(mode_info.style.colors);
                should_render = true;
            },
            Event::Key(key) => {
                should_render = self.handle_key(key);
            },
            _ => (),
        };
        should_render
    }

    fn render(&mut self, rows: usize, cols: usize) {
        // Clear screen
        println!("\u{1b}[2J");
        
        // Center the message
        let message_row = rows / 2;
        let message_col = (cols.saturating_sub(self.message.len())) / 2;
        
        // Print centered message
        println!("\u{1b}[{};{}H{}", message_row, message_col, self.message);
        
        // Print instructions
        let instructions = "Press 'q' to close, 'h' for help";
        let instr_row = message_row + 2;
        let instr_col = (cols.saturating_sub(instructions.len())) / 2;
        println!("\u{1b}[{};{}H{}", instr_row, instr_col, instructions);
    }
}

impl State {
    fn handle_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Char('q') if key.has_no_modifiers() => {
                // Close the plugin
                hide_self();
                false
            },
            BareKey::Char('h') if key.has_no_modifiers() => {
                self.message = "Help: This is a custom manager plugin!".to_string();
                true
            },
            BareKey::Esc if key.has_no_modifiers() => {
                hide_self();
                false
            },
            _ => false,
        }
    }
}

// Helper struct for colors
#[derive(Default, Copy, Clone)]
struct Colors {
    pub palette: Styling,
}

impl Colors {
    fn new(palette: Styling) -> Self {
        Colors { palette }
    }
}
```

## Build System Integration

### Step 1: Add to Workspace (Cargo.toml)

```toml
[workspace]
members = [
    # ... other members ...
    "default-plugins/my-custom-manager",
]
```

### Step 2: Add to xtask Build System

Edit `xtask/src/main.rs`:

```rust
WorkspaceMember {
    crate_name: "default-plugins/my-custom-manager",
    build: true,
},
```

### Step 3: Add to Asset Map

Edit `zellij-utils/src/consts.rs`:

```rust
lazy_static! {
    pub static ref ASSET_MAP: HashMap<PathBuf, Vec<u8>> = {
        let mut assets = std::collections::HashMap::new();
        // ... other plugins ...
        add_plugin!(assets, "my-custom-manager.wasm");
        assets
    };
}
```

### Important: Fix Build System Paths

The xtask build system may have hardcoded paths. Update these:

1. In `xtask/src/main.rs`:
   ```rust
   fn asset_dir() -> PathBuf {
       crate::project_root().join("zellij-utils").join("assets")
   }
   ```

2. In `xtask/src/build.rs`:
   ```rust
   let swarm_utils_basedir = crate::project_root().join("zellij-utils");
   ```

## Configuration Management

### Plugin Configuration

Add to `~/.config/swarm/config.kdl`:

```kdl
plugins {
    // ... other plugins ...
    my-custom-manager location="swarm:my-custom-manager"
}
```

### Keybinding Configuration

```kdl
shared_except "locked" "tab" {
    bind "Ctrl m" {
        LaunchOrFocusPlugin "my-custom-manager" {
            floating true
            move_to_focused_tab true
        }
    }
}
```

### Configuration Parameters

Plugins can receive configuration:

```kdl
my-custom-manager location="swarm:my-custom-manager" {
    custom_param "value"
    another_param true
}
```

Access in plugin:

```rust
fn load(&mut self, configuration: BTreeMap<String, String>) {
    if let Some(param) = configuration.get("custom_param") {
        // Use parameter
    }
}
```

## Common Issues and Solutions

### 1. Plugin Not Building as WASM

**Issue**: Error about undefined `host_run_plugin_command`

**Solution**: Ensure `crate-type = ["cdylib"]` in Cargo.toml

### 2. Configuration Not Taking Effect

**Issue**: Changes to config.kdl not working

**Causes**:
- Embedded config at compile time
- User config with `clear-defaults=true`
- Syntax errors (extra semicolons)

**Solution**: Check all configuration files and rebuild if necessary

### 3. Build Errors with xtask

**Issue**: "No such file or directory" errors

**Solution**: Update hardcoded paths from "swarm-utils" to "zellij-utils"

### 4. Keybinding Conflicts

**Issue**: Keybinding not working or conflicting

**Solution**: Check scope with debug logging, ensure proper `shared_except` usage

## Development Workflow

### 1. Initial Setup

```bash
# Create plugin directory
mkdir -p default-plugins/my-plugin/src

# Create Cargo.toml and lib.rs
# Add to workspace and build system
```

### 2. Build Process

```bash
# Build all plugins
cargo xtask build --plugins-only --release

# Build main binary
cargo build --release -p swarm

# Install
sudo cp target/release/swarm /usr/local/bin/swarm
```

### 3. Testing

```bash
# Kill existing processes
pkill -f swarm

# Run with debug logging
swarm

# Check debug logs
tail -f /tmp/swarm_debug.log
```

### 4. Iteration Cycle

1. Edit plugin code
2. Build plugins: `cargo xtask build --plugins-only --release`
3. Build main binary: `cargo build --release -p swarm`
4. Install and test
5. Check debug logs if issues occur

## Advanced Plugin Features

### 1. Plugin Communication

Plugins can communicate via pipes:

```rust
// Send message to another plugin
pipe_message_to_plugin(
    MessageToPlugin::new("other-plugin")
        .with_payload("data")
);
```

### 2. Workers

For background tasks:

```rust
register_worker!(
    MyWorker,
    my_worker,
    MY_WORKER
);
```

### 3. Persistent State

Plugins maintain state between renders:

```rust
#[derive(Default)]
struct State {
    counter: usize,
    // ... other fields
}
```

### 4. UI Components

Use the `zellij_tile::ui_components` for common UI elements:
- Borders
- Lists
- Text styling
- Input fields

## Best Practices

1. **Always use `hide_self()`** to close plugins properly
2. **Return `true` from `update()`** only when re-render is needed
3. **Subscribe only to needed events** to reduce overhead
4. **Use proper error handling** - plugins shouldn't panic
5. **Test with debug logging** during development
6. **Document configuration options** in plugin README
7. **Follow existing plugin patterns** for consistency

## Conclusion

Creating plugins for Swarm involves understanding:
- The WASM-based plugin architecture
- The build system (xtask)
- Configuration management (KDL)
- Keybinding system and scopes
- Debug techniques for troubleshooting

With this knowledge, you can create powerful custom plugins to extend Swarm's functionality!