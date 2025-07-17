# Swarm Architecture and Development Guide

This guide explains how Swarm (Zellij fork) works internally, including its window management system, keybinding architecture, and plugin system.

## Table of Contents
1. [Core Architecture Overview](#core-architecture-overview)
2. [Keybinding System](#keybinding-system)
3. [Window Management](#window-management)
4. [Plugin System](#plugin-system)
5. [Client-Server Architecture](#client-server-architecture)
6. [Event Flow](#event-flow)
7. [Modifying Swarm](#modifying-swarm)

## Core Architecture Overview

Swarm follows a client-server architecture with plugins running in WASM:

```
┌─────────────────────────────────────────────────────────┐
│                     User Input                          │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│                 Swarm Client                            │
│  - Terminal I/O                                         │
│  - Raw input capture                                    │
│  - Rendering                                            │
└─────────────────────┬───────────────────────────────────┘
                      │ IPC (Unix Socket)
┌─────────────────────▼───────────────────────────────────┐
│                 Swarm Server                            │
│  - Session management                                   │
│  - Tab/Pane orchestration                              │
│  - Plugin management                                    │
│  - PTY management                                       │
└─────────────────────┬───────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────┐
│              WASM Plugin Runtime                        │
│  - Isolated plugin execution                            │
│  - Event dispatch                                       │
│  - State management                                     │
└─────────────────────────────────────────────────────────┘
```

## Keybinding System

### 1. Input Modes

Swarm uses a modal system defined in `/zellij-utils/src/data.rs`:

```rust
pub enum InputMode {
    Normal,
    Locked,
    Pane,
    Tab,
    Resize,
    Scroll,
    EnterSearch,
    Search,
    Session,
    Move,
    Prompt,
    Tmux,
    Swarm,  // Our custom mode
}
```

### 2. Keybinding Configuration

Keybindings are defined in KDL format in config files:

```kdl
// Global keybindings
shared_except "locked" {
    bind "Ctrl a" {
        SwitchToMode "Swarm"
    }
}

// Mode-specific keybindings
swarm {
    bind "1" {
        LaunchOrFocusPlugin "session-manager" {
            floating true
            move_to_focused_tab true
        }
        SwitchToMode "Normal"
    }
}
```

### 3. Keybinding Processing Flow

```
User Press Key → Client Captures → Send to Server → Route Action
                                                    ↓
                                              Check Current Mode
                                                    ↓
                                              Find Keybinding
                                                    ↓
                                              Execute Actions
```

Key files:
- `/zellij-server/src/route.rs` - Main action router
- `/zellij-utils/src/input/keybinds.rs` - Keybinding definitions
- `/zellij-utils/src/input/config.rs` - Config parsing

### 4. Adding New Keybindings

1. Define in config file (KDL):
```kdl
bind "Ctrl x" {
    // Actions here
}
```

2. Or define a new action in `/zellij-utils/src/input/actions.rs`:
```rust
pub enum Action {
    // ... existing actions
    MyNewAction(String),
}
```

3. Handle in `/zellij-server/src/route.rs`:
```rust
Action::MyNewAction(param) => {
    // Implementation
}
```

## Window Management

### 1. Core Concepts

- **Session**: Top-level container, one per Swarm instance
- **Tab**: Container for panes, like browser tabs
- **Pane**: Individual terminal or plugin view
- **Floating Pane**: Overlay pane that floats above others

### 2. Pane Types

```rust
pub enum PaneId {
    Terminal(u32),     // Regular terminal
    Plugin(u32),       // Plugin pane
}
```

### 3. Layout System

Swarm uses a tree-based layout system:
- Panes can be split horizontally or vertically
- Each split creates a new node in the layout tree
- Floating panes exist outside the tree

### 4. Plugin Windows

Plugins can be displayed as:
- **Tiled**: Part of the layout tree
- **Floating**: Overlay window
- **Background**: No UI, runs in background

Example launching a floating plugin:
```rust
LaunchOrFocusPlugin(plugin_alias, 
    should_float: true,      // Makes it floating
    move_to_focused_tab: true,
    should_open_in_place: false,
    skip_cache: false
)
```

## Plugin System

### 1. Plugin Structure

Every plugin must:
- Be compiled to WASM
- Implement the `SwarmPlugin` trait
- Use `register_plugin!` macro
- Be built as a binary (not library)

Basic plugin template:
```rust
use zellij_tile::prelude::*;

#[derive(Default)]
struct State {
    // Plugin state
}

register_plugin!(State);

impl SwarmPlugin for State {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        // Initialize
    }
    
    fn update(&mut self, event: Event) -> bool {
        // Handle events, return true to re-render
    }
    
    fn render(&mut self, rows: usize, cols: usize) {
        // Draw UI
    }
}
```

### 2. Plugin API

Plugins can:
- **Subscribe to events**: `subscribe(&[EventType::Key, EventType::TabUpdate])`
- **Open terminals**: `open_terminal(cmd)` or `open_command_pane(cmd)`
- **Create tabs**: `new_tab(name, cwd)`
- **Switch focus**: `focus_tab(index)`, `focus_pane_with_id(id)`
- **Hide themselves**: `hide_self()`

### 3. Plugin Registration

Plugins must be registered in multiple places:

1. **Asset map** (`/zellij-utils/src/consts.rs`):
```rust
add_plugin!(assets, "my-plugin.wasm");
```

2. **Plugin list** (`/zellij-utils/src/input/plugins.rs`):
```rust
|| tag == "my-plugin"
```

3. **Build system** (`/xtask/src/main.rs`):
```rust
WorkspaceMember {
    crate_name: "default-plugins/my-plugin",
    build: true,
},
```

4. **Config file**:
```kdl
plugins {
    my-plugin location="swarm:my-plugin"
}
```

## Client-Server Architecture

### 1. Communication

Client and server communicate via Unix domain sockets:
- Client sends: User input, terminal size changes
- Server sends: Render instructions, terminal output

### 2. Server Components

- **Route**: Action dispatcher
- **Screen**: Tab/pane manager
- **Pty**: Terminal process manager
- **PluginManager**: WASM runtime manager

### 3. Threading Model

Server uses multiple threads:
- Main thread: Coordination
- PTY thread: Terminal I/O
- Plugin thread: WASM execution
- Background thread: Async tasks

## Event Flow

### 1. User Input Flow

```
1. User presses key
2. Client captures in os_input_output.rs
3. Sends ClientToServerMsg::Key
4. Server routes in route.rs
5. Checks keybindings for current mode
6. Executes associated actions
7. Updates state
8. Sends render instructions back
```

### 2. Plugin Event Flow

```
1. Event occurs (key, resize, etc.)
2. Server notifies plugin thread
3. Plugin update() called
4. Plugin modifies state
5. If update() returns true, render() called
6. Plugin output sent to client
```

## Modifying Swarm

### Common Modifications

#### 1. Adding a New Mode

1. Add to `InputMode` enum in `data.rs`
2. Add keybindings in config
3. Handle mode switching in `route.rs`
4. Update status bar in `status-bar` plugin

#### 2. Adding a New Action

1. Define in `actions.rs`
2. Parse in config parser
3. Handle in `route.rs`
4. Add to keybinding config

#### 3. Creating Background Processes

For background processes (like MCP servers):

```rust
// Don't create a visible tab
let cmd = CommandToRun {
    path: PathBuf::from("command"),
    args: vec!["arg1".to_string()],
    cwd: Some(PathBuf::from("/path")),
};

// Run in background
run_command_background(cmd, env_vars);
```

#### 4. Managing External Processes

To run processes in tmux instead of Swarm tabs:

```rust
// Launch in tmux
let tmux_cmd = format!("tmux new-session -d -s {} '{}'", 
    session_name, command);
std::process::Command::new("sh")
    .arg("-c")
    .arg(&tmux_cmd)
    .spawn();
```

### Best Practices

1. **State Management**: Keep plugin state minimal and serializable
2. **Error Handling**: Plugins should never panic
3. **Performance**: Minimize renders, batch updates
4. **UI Consistency**: Follow existing UI patterns
5. **Debug Logging**: Use `/tmp/swarm_debug.log` for debugging

### Debug Techniques

1. **Add debug logs**:
```rust
eprintln!("Debug: {}", message);  // Goes to stderr
```

2. **File logging**:
```rust
use std::fs::OpenOptions;
use std::io::Write;

if let Ok(mut file) = OpenOptions::new()
    .create(true)
    .append(true)
    .open("/tmp/swarm_debug.log") {
    writeln!(file, "Debug: {}", message);
}
```

3. **Check plugin logs**: Swarm captures plugin stderr

## Next Steps

This guide provides the foundation for understanding and modifying Swarm. Key areas to explore:

1. **Protocol Buffers**: Used for IPC communication
2. **Layout Algorithm**: How panes are sized and positioned
3. **Rendering Pipeline**: How terminal output is processed
4. **Session Persistence**: How state is saved/restored

Remember to always:
- Test changes thoroughly
- Update documentation
- Follow existing code patterns
- Consider backwards compatibility