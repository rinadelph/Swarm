use std::collections::BTreeMap;
use zellij_tile::prelude::*;
use serde::{Serialize, Deserialize};
use std::process;

// MCP Server Types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum McpType {
    Stdio,
    Http,  // Port will be dynamic argument
    Sse,   // Server-sent events
}

// MCP Template Types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum McpTemplate {
    Custom,
    AgentMcp,       // uv run -m agent_mcp.cli --port X --project-dir Y
    PythonProject,  // Generic Python project with venv
    NodeProject,    // Generic Node.js project  
    GlobalNpx,      // npx commands
    FileSystem,     // filesystem MCP
    GitMcp,         // git MCP
}

// Dynamic argument definition
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
struct ArgDefinition {
    name: String,           // e.g., "port", "project-dir"
    flag: String,           // e.g., "--port", "--project-dir"
    value_type: ArgType,    // Type of value
    default: Option<String>, // Default value
    required: bool,         // Is this required?
    description: String,    // Help text
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum ArgType {
    String,
    Number,
    Port,      // Special handling for ports
    Directory, // Can use directory browser
    File,      // Can use file browser
    Boolean,   // Flag argument
}

// MCP Server Configuration
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
struct McpConfig {
    name: String,
    mcp_type: McpType,
    template: McpTemplate,
    command: String,
    base_args: Vec<String>,  // Static args like "-m", "agent_mcp.cli"
    dynamic_args: Vec<ArgDefinition>, // Dynamic arguments
    arg_values: BTreeMap<String, String>, // Actual values for dynamic args
    env_vars: BTreeMap<String, String>,
    working_dir: Option<String>,
    activation_script: Option<String>, // For Python venv activation
}

// Running MCP Instance
#[derive(Debug, Clone, Serialize, Deserialize)]
struct McpInstance {
    config: McpConfig,
    tab_name: String,
    pane_id: Option<PaneId>,
    status: McpStatus,
    started_at: String,
    actual_port: Option<u16>, // Store the actual port used at launch
}

#[derive(Debug, Clone, Serialize, Deserialize)]
enum McpStatus {
    Running,
    Stopped,
    Failed(String),
}

// Screen states
#[derive(Debug, Clone, PartialEq)]
enum Screen {
    MainMenu,
    CurrentMcps,
    LaunchMcp,
    AddMcp,
    EditMcp(String),
    ConfigureArgs(McpConfig), // Configure dynamic arguments before launch
    BrowseDirectory { 
        return_field: InputField,
        return_arg: Option<String>, // For dynamic arg directory browsing
        current_path: String,
        entries: Vec<String>,
        selected_index: usize,
    },
}

// Input modes for Add/Edit MCP screen
#[derive(Debug, Clone, PartialEq)]
enum InputField {
    Name,
    Template,
    Type,
    Command,
    Args,
    Port,
    WorkingDir,
    ActivationScript,
    EnvVars,
}

#[derive(Default)]
struct State {
    screen: Screen,
    configs: Vec<McpConfig>,
    instances: BTreeMap<String, McpInstance>,
    selected_index: usize,
    input_buffer: String,
    input_field: InputField,
    editing_config: McpConfig,
    editing_arg_index: usize, // Which dynamic arg is being edited
    rows: usize,
    cols: usize,
    error_message: Option<String>,
    success_message: Option<String>,
}

register_plugin!(State);

impl Default for Screen {
    fn default() -> Self {
        Screen::MainMenu
    }
}

impl Default for InputField {
    fn default() -> Self {
        InputField::Name
    }
}

impl Default for McpTemplate {
    fn default() -> Self {
        McpTemplate::Custom
    }
}

impl Default for McpConfig {
    fn default() -> Self {
        McpConfig {
            name: String::new(),
            mcp_type: McpType::Stdio,
            template: McpTemplate::Custom,
            command: String::new(),
            base_args: Vec::new(),
            dynamic_args: Vec::new(),
            arg_values: BTreeMap::new(),
            env_vars: BTreeMap::new(),
            working_dir: None,
            activation_script: None,
        }
    }
}

impl SwarmPlugin for State {
    fn load(&mut self, configuration: BTreeMap<String, String>) {
        // Subscribe to events
        subscribe(&[
            EventType::Key,
            EventType::TabUpdate,
            EventType::PaneUpdate,
        ]);

        // Load saved configurations
        self.load_configs();
        
        // Set initial screen based on configuration
        if let Some(screen) = configuration.get("initial_screen") {
            match screen.as_str() {
                "current" => self.screen = Screen::CurrentMcps,
                "launch" => self.screen = Screen::LaunchMcp,
                "add" => self.screen = Screen::AddMcp,
                _ => self.screen = Screen::MainMenu,
            }
        }
    }

    fn update(&mut self, event: Event) -> bool {
        let mut should_render = false;
        
        match event {
            Event::Key(key) => {
                should_render = self.handle_key(key);
            }
            Event::TabUpdate(tabs) => {
                // Update MCP instance statuses based on tab info
                self.update_instance_status(tabs);
                should_render = true;
            }
            _ => {}
        }
        
        should_render
    }

    fn render(&mut self, rows: usize, cols: usize) {
        self.rows = rows;
        self.cols = cols;
        
        // Clear screen
        print!("\u{1b}[2J\u{1b}[H");
        
        // Debug: Show that plugin is running
        println!("MCP Manager Plugin v0.0.9 - Running!");
        println!("Screen size: {}x{}", cols, rows);
        println!("");
        
        // Render header
        self.render_header();
        
        // Render content based on current screen
        match &self.screen {
            Screen::MainMenu => self.render_main_menu(),
            Screen::CurrentMcps => self.render_current_mcps(),
            Screen::LaunchMcp => self.render_launch_mcp(),
            Screen::AddMcp | Screen::EditMcp(_) => self.render_add_edit_mcp(),
            Screen::ConfigureArgs(_) => self.render_configure_args(),
            Screen::BrowseDirectory { .. } => self.render_browse_directory(),
        }
        
        // Render footer with help
        self.render_footer();
        
        // Render messages
        self.render_messages();
    }
}

impl State {
    fn handle_key(&mut self, key: KeyWithModifier) -> bool {
        // Clear messages on any key press
        self.error_message = None;
        self.success_message = None;
        
        match &self.screen {
            Screen::MainMenu => self.handle_main_menu_key(key),
            Screen::CurrentMcps => self.handle_current_mcps_key(key),
            Screen::LaunchMcp => self.handle_launch_mcp_key(key),
            Screen::AddMcp | Screen::EditMcp(_) => self.handle_add_edit_mcp_key(key),
            Screen::ConfigureArgs(_) => self.handle_configure_args_key(key),
            Screen::BrowseDirectory { .. } => self.handle_browse_directory_key(key),
        }
    }
    
    fn handle_main_menu_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Char('1') if key.has_no_modifiers() => {
                self.screen = Screen::CurrentMcps;
                true
            }
            BareKey::Char('2') if key.has_no_modifiers() => {
                self.screen = Screen::LaunchMcp;
                self.selected_index = 0;
                true
            }
            BareKey::Char('3') if key.has_no_modifiers() => {
                self.screen = Screen::AddMcp;
                self.editing_config = McpConfig::default();
                self.input_buffer.clear();
                self.input_field = InputField::Name;
                true
            }
            BareKey::Char('q') | BareKey::Esc if key.has_no_modifiers() => {
                hide_self();
                false
            }
            _ => false,
        }
    }
    
    fn handle_current_mcps_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Up if key.has_no_modifiers() => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
                true
            }
            BareKey::Down if key.has_no_modifiers() => {
                let max_index = self.instances.len().saturating_sub(1);
                if self.selected_index < max_index {
                    self.selected_index += 1;
                }
                true
            }
            BareKey::Enter if key.has_no_modifiers() => {
                // Attach to tmux session for selected MCP
                if let Some((_, instance)) = self.instances.iter().nth(self.selected_index) {
                    let session_name = instance.tab_name.clone();
                    
                    // Create a new terminal pane to attach to tmux session
                    let attach_cmd = CommandToRun {
                        path: std::path::PathBuf::from("tmux"),
                        args: vec!["attach-session".to_string(), "-t".to_string(), session_name],
                        ..Default::default()
                    };
                    
                    // Open in a new pane
                    open_terminal(attach_cmd.path.to_string_lossy().to_string());
                    open_command_pane(attach_cmd, BTreeMap::new());
                    hide_self();
                }
                true
            }
            BareKey::Char('s') if key.has_no_modifiers() => {
                // Stop selected MCP
                self.stop_selected_mcp();
                true
            }
            BareKey::Char('r') if key.has_no_modifiers() => {
                // Restart selected MCP
                self.restart_selected_mcp();
                true
            }
            BareKey::Char('b') | BareKey::Esc if key.has_no_modifiers() => {
                self.screen = Screen::MainMenu;
                true
            }
            _ => false,
        }
    }
    
    fn handle_launch_mcp_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Up if key.has_no_modifiers() => {
                if self.selected_index > 0 {
                    self.selected_index -= 1;
                }
                true
            }
            BareKey::Down if key.has_no_modifiers() => {
                let max_index = self.configs.len().saturating_sub(1);
                if self.selected_index < max_index {
                    self.selected_index += 1;
                }
                true
            }
            BareKey::Enter if key.has_no_modifiers() => {
                // Configure and launch selected MCP
                if let Some(config) = self.configs.get(self.selected_index) {
                    // Always go through argument configuration
                    self.screen = Screen::ConfigureArgs(config.clone());
                    self.editing_arg_index = 0;
                    self.load_arg_value_to_buffer();
                }
                true
            }
            BareKey::Char('e') if key.has_no_modifiers() => {
                // Edit selected config
                if let Some(config) = self.configs.get(self.selected_index) {
                    self.screen = Screen::EditMcp(config.name.clone());
                    self.editing_config = config.clone();
                    self.input_buffer = config.name.clone();
                    self.input_field = InputField::Name;
                }
                true
            }
            BareKey::Char('d') if key.has_no_modifiers() => {
                // Delete selected config
                if self.selected_index < self.configs.len() {
                    self.configs.remove(self.selected_index);
                    self.save_configs();
                    if self.selected_index > 0 && self.selected_index >= self.configs.len() {
                        self.selected_index -= 1;
                    }
                    self.success_message = Some("Configuration deleted".to_string());
                }
                true
            }
            BareKey::Char('b') | BareKey::Esc if key.has_no_modifiers() => {
                self.screen = Screen::MainMenu;
                true
            }
            _ => false,
        }
    }
    
    fn handle_add_edit_mcp_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Char('d') if key.has_modifiers(&[KeyModifier::Ctrl]) && self.input_field == InputField::WorkingDir => {
                // Ctrl+D on WorkingDir field opens directory browser
                self.open_directory_browser();
                true
            }
            BareKey::Tab if key.has_no_modifiers() => {
                // Move to next field
                self.next_input_field();
                true
            }
            BareKey::Tab if key.has_modifiers(&[KeyModifier::Shift]) => {
                // Move to previous field
                self.prev_input_field();
                true
            }
            BareKey::Enter if key.has_no_modifiers() => {
                // Save current field and potentially submit
                self.save_current_field();
                if self.input_field == InputField::EnvVars {
                    // Last field, save the config
                    self.save_mcp_config();
                } else {
                    self.next_input_field();
                }
                true
            }
            BareKey::Char(c) if key.has_no_modifiers() => {
                self.input_buffer.push(c);
                true
            }
            BareKey::Backspace if key.has_no_modifiers() => {
                self.input_buffer.pop();
                true
            }
            BareKey::Esc if key.has_no_modifiers() => {
                self.screen = Screen::LaunchMcp;
                true
            }
            _ => false,
        }
    }
    
    
    fn handle_configure_args_key(&mut self, key: KeyWithModifier) -> bool {
        let (should_browse, arg_name, should_launch, config_clone) = if let Screen::ConfigureArgs(config) = &self.screen {
            let should_browse = if let Some(arg) = config.dynamic_args.get(self.editing_arg_index) {
                matches!(arg.value_type, ArgType::Directory) && matches!(key.bare_key, BareKey::Char('d')) && key.has_modifiers(&[KeyModifier::Ctrl])
            } else {
                false
            };
            let arg_name = config.dynamic_args.get(self.editing_arg_index).map(|a| a.name.clone());
            let should_launch = matches!(key.bare_key, BareKey::Enter) && key.has_no_modifiers();
            let config_clone = config.clone();
            (should_browse, arg_name, should_launch, config_clone)
        } else {
            return false;
        };
        
        if should_browse {
            if let Some(name) = arg_name {
                self.open_directory_browser_for_arg(name);
            }
            return true;
        }
        
        if should_launch {
            self.launch_mcp(config_clone);
            return true;
        }
        
        if let Screen::ConfigureArgs(config) = &mut self.screen {
            match key.bare_key {
                BareKey::Up if key.has_no_modifiers() => {
                    if self.editing_arg_index > 0 {
                        self.editing_arg_index -= 1;
                        self.load_arg_value_to_buffer();
                    }
                    true
                }
                BareKey::Down if key.has_no_modifiers() => {
                    if self.editing_arg_index < config.dynamic_args.len().saturating_sub(1) {
                        self.editing_arg_index += 1;
                        self.load_arg_value_to_buffer();
                    }
                    true
                }
                BareKey::Char(c) if key.has_no_modifiers() => {
                    self.input_buffer.push(c);
                    // Update the arg value
                    if let Some(arg) = config.dynamic_args.get(self.editing_arg_index) {
                        config.arg_values.insert(arg.name.clone(), self.input_buffer.clone());
                    }
                    true
                }
                BareKey::Backspace if key.has_no_modifiers() => {
                    self.input_buffer.pop();
                    if let Some(arg) = config.dynamic_args.get(self.editing_arg_index) {
                        config.arg_values.insert(arg.name.clone(), self.input_buffer.clone());
                    }
                    true
                }
                BareKey::Tab if key.has_no_modifiers() => {
                    // Move to next argument
                    if self.editing_arg_index < config.dynamic_args.len() - 1 {
                        self.editing_arg_index += 1;
                        self.load_arg_value_to_buffer();
                    }
                    true
                }
                BareKey::Esc if key.has_no_modifiers() => {
                    self.screen = Screen::LaunchMcp;
                    true
                }
                _ => false,
            }
        } else {
            false
        }
    }
    
    fn handle_browse_directory_key(&mut self, key: KeyWithModifier) -> bool {
        if let Screen::BrowseDirectory { selected_index, entries, current_path, return_field: _, return_arg: _ } = &mut self.screen {
            match key.bare_key {
                BareKey::Up if key.has_no_modifiers() => {
                    if *selected_index > 0 {
                        *selected_index -= 1;
                    }
                    true
                }
                BareKey::Down if key.has_no_modifiers() => {
                    if *selected_index < entries.len().saturating_sub(1) {
                        *selected_index += 1;
                    }
                    true
                }
                BareKey::Enter if key.has_no_modifiers() => {
                    if let Some(entry) = entries.get(*selected_index) {
                        if entry == ".." {
                            // Go up one directory
                            if let Some(parent) = std::path::Path::new(current_path).parent() {
                                *current_path = parent.to_string_lossy().to_string();
                                self.refresh_directory_listing();
                            }
                        } else {
                            // Enter selected directory
                            let new_path = format!("{}/{}", current_path, entry);
                            *current_path = new_path;
                            self.refresh_directory_listing();
                        }
                    }
                    true
                }
                BareKey::Char('s') if key.has_no_modifiers() => {
                    // Select current directory
                    self.select_directory();
                    true
                }
                BareKey::Esc if key.has_no_modifiers() => {
                    // Cancel and return to edit screen
                    self.screen = if let Some(name) = self.get_editing_name() {
                        Screen::EditMcp(name)
                    } else {
                        Screen::AddMcp
                    };
                    true
                }
                _ => false,
            }
        } else {
            false
        }
    }
    
    fn launch_mcp(&mut self, config: McpConfig) {
        // Get port from dynamic args if HTTP/SSE
        let port = if matches!(config.mcp_type, McpType::Http | McpType::Sse) {
            config.arg_values.get("port")
                .and_then(|p| p.parse::<u16>().ok())
                .unwrap_or(8080)
        } else {
            0
        };
        
        // Create a unique tmux session name
        let session_name = if port > 0 {
            format!("mcp-{}-{}", config.name.replace(" ", "_").to_lowercase(), port)
        } else {
            format!("mcp-{}", config.name.replace(" ", "_").to_lowercase())
        };
        
        // Build the command with environment variables
        let mut env_vars = config.env_vars.clone();
        
        // For HTTP/SSE servers, add port to env if not already there
        if matches!(config.mcp_type, McpType::Http | McpType::Sse) && port > 0 {
            env_vars.entry("PORT".to_string()).or_insert(port.to_string());
        }
        
        // Build environment variable string
        let env_string = env_vars.iter()
            .map(|(key, value)| format!("{}={}", key, value))
            .collect::<Vec<_>>()
            .join(" ");
        
        // Build the command with base args and dynamic args
        let mut command_parts = vec![config.command.clone()];
        command_parts.extend(config.base_args.clone());
        
        // Add dynamic arguments
        for arg_def in &config.dynamic_args {
            if let Some(value) = config.arg_values.get(&arg_def.name) {
                if !value.is_empty() {
                    if arg_def.flag.is_empty() {
                        // Positional argument
                        command_parts.push(value.clone());
                    } else {
                        // Flag argument
                        command_parts.push(arg_def.flag.clone());
                        if !matches!(arg_def.value_type, ArgType::Boolean) {
                            command_parts.push(value.clone());
                        }
                    }
                }
            } else if arg_def.required {
                self.error_message = Some(format!("Required argument '{}' is missing", arg_def.name));
                return;
            }
        }
        
        let base_command = command_parts.join(" ");
        
        // Handle activation script (e.g., Python venv)
        let command_with_activation = if let Some(activation) = &config.activation_script {
            // Source the activation script before running the command
            format!("source {} && {}", activation, base_command)
        } else {
            base_command
        };
        
        // Combine environment variables and command
        let full_command = if env_string.is_empty() {
            command_with_activation
        } else {
            format!("{} {}", env_string, command_with_activation)
        };
        
        // Build tmux command
        let tmux_cmd = if let Some(cwd) = &config.working_dir {
            format!("tmux new-session -d -s {} -c '{}' '{}'", 
                session_name, cwd, full_command)
        } else {
            format!("tmux new-session -d -s {} '{}'", 
                session_name, full_command)
        };
        
        // Execute tmux command
        let result = process::Command::new("sh")
            .arg("-c")
            .arg(&tmux_cmd)
            .spawn();
        
        match result {
            Ok(_) => {
                // Create instance record
                let actual_port = if matches!(config.mcp_type, McpType::Http | McpType::Sse) {
                    config.arg_values.get("port")
                        .and_then(|p| p.parse::<u16>().ok())
                } else {
                    None
                };
                
                let instance = McpInstance {
                    config: config.clone(),
                    tab_name: session_name.clone(),
                    pane_id: None,
                    status: McpStatus::Running,
                    started_at: chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
                    actual_port,
                };
                
                self.instances.insert(config.name.clone(), instance);
                self.success_message = Some(format!("Launched MCP: {} in tmux session: {}", config.name, session_name));
            }
            Err(e) => {
                self.error_message = Some(format!("Failed to launch MCP: {}", e));
            }
        }
        
        // Switch to current MCPs screen
        self.screen = Screen::CurrentMcps;
    }
    
    fn stop_selected_mcp(&mut self) {
        if let Some((name, instance)) = self.instances.iter().nth(self.selected_index) {
            let name = name.clone();
            let session_name = instance.tab_name.clone();
            
            // Kill the tmux session
            let _ = process::Command::new("tmux")
                .args(&["kill-session", "-t", &session_name])
                .output();
            
            self.instances.remove(&name);
            self.success_message = Some(format!("Stopped MCP: {}", name));
        }
    }
    
    fn restart_selected_mcp(&mut self) {
        if let Some((_, instance)) = self.instances.iter().nth(self.selected_index) {
            let config = instance.config.clone();
            self.stop_selected_mcp();
            self.launch_mcp(config);
        }
    }
    
    fn save_mcp_config(&mut self) {
        if self.editing_config.name.is_empty() {
            self.error_message = Some("Name cannot be empty".to_string());
            return;
        }
        
        if self.editing_config.command.is_empty() {
            self.error_message = Some("Command cannot be empty".to_string());
            return;
        }
        
        // Save current field first
        self.save_current_field();
        
        match &self.screen {
            Screen::EditMcp(old_name) => {
                // Update existing config
                if let Some(index) = self.configs.iter().position(|c| &c.name == old_name) {
                    self.configs[index] = self.editing_config.clone();
                }
            }
            Screen::AddMcp => {
                // Add new config
                self.configs.push(self.editing_config.clone());
            }
            _ => {}
        }
        
        self.save_configs();
        self.success_message = Some("Configuration saved".to_string());
        self.screen = Screen::LaunchMcp;
    }
    
    fn save_current_field(&mut self) {
        match self.input_field {
            InputField::Name => {
                self.editing_config.name = self.input_buffer.clone();
            }
            InputField::Template => {
                // Handle template selection
                match self.input_buffer.to_lowercase().as_str() {
                    "agent" | "agentmcp" | "agent-mcp" => self.editing_config.template = McpTemplate::AgentMcp,
                    "python" => self.editing_config.template = McpTemplate::PythonProject,
                    "node" | "nodejs" => self.editing_config.template = McpTemplate::NodeProject,
                    "npx" | "global" => self.editing_config.template = McpTemplate::GlobalNpx,
                    "filesystem" | "fs" => self.editing_config.template = McpTemplate::FileSystem,
                    "git" => self.editing_config.template = McpTemplate::GitMcp,
                    _ => self.editing_config.template = McpTemplate::Custom,
                }
                // Set defaults based on template
                self.apply_template_defaults();
            }
            InputField::Type => {
                // Handle type selection
                match self.input_buffer.to_lowercase().as_str() {
                    "http" => self.editing_config.mcp_type = McpType::Http,
                    "sse" => self.editing_config.mcp_type = McpType::Sse,
                    _ => self.editing_config.mcp_type = McpType::Stdio,
                }
            }
            InputField::Command => {
                self.editing_config.command = self.input_buffer.clone();
            }
            InputField::Args => {
                self.editing_config.base_args = self.input_buffer
                    .split_whitespace()
                    .map(String::from)
                    .collect();
            }
            InputField::WorkingDir => {
                self.editing_config.working_dir = if self.input_buffer.is_empty() {
                    None
                } else {
                    Some(self.input_buffer.clone())
                };
            }
            InputField::ActivationScript => {
                self.editing_config.activation_script = if self.input_buffer.is_empty() {
                    None
                } else {
                    Some(self.input_buffer.clone())
                };
            }
            InputField::EnvVars => {
                // Parse env vars in KEY=VALUE format
                for line in self.input_buffer.lines() {
                    if let Some((key, value)) = line.split_once('=') {
                        self.editing_config.env_vars.insert(
                            key.trim().to_string(),
                            value.trim().to_string()
                        );
                    }
                }
            }
            InputField::Port => {} // Port is now a dynamic arg
        }
    }
    
    fn next_input_field(&mut self) {
        self.save_current_field();
        
        self.input_field = match self.input_field {
            InputField::Name => InputField::Template,
            InputField::Template => InputField::Type,
            InputField::Type => InputField::Command,
            InputField::Command => InputField::Args,
            InputField::Args => InputField::WorkingDir,
            InputField::WorkingDir => {
                match self.editing_config.template {
                    McpTemplate::PythonProject => InputField::ActivationScript,
                    _ => InputField::EnvVars,
                }
            }
            InputField::ActivationScript => InputField::EnvVars,
            InputField::EnvVars => InputField::Name,
            InputField::Port => InputField::WorkingDir, // Skip port, it's now dynamic
        };
        
        self.load_field_to_buffer();
    }
    
    fn prev_input_field(&mut self) {
        self.save_current_field();
        
        self.input_field = match self.input_field {
            InputField::Name => InputField::EnvVars,
            InputField::Template => InputField::Name,
            InputField::Type => InputField::Template,
            InputField::Command => InputField::Type,
            InputField::Args => InputField::Command,
            InputField::Port => InputField::Args, // Keep for compatibility but not used
            InputField::WorkingDir => InputField::Args,
            InputField::ActivationScript => InputField::WorkingDir,
            InputField::EnvVars => {
                match self.editing_config.template {
                    McpTemplate::PythonProject => InputField::ActivationScript,
                    _ => InputField::WorkingDir,
                }
            }
        };
        
        self.load_field_to_buffer();
    }
    
    fn load_field_to_buffer(&mut self) {
        self.input_buffer = match self.input_field {
            InputField::Name => self.editing_config.name.clone(),
            InputField::Template => match self.editing_config.template {
                McpTemplate::AgentMcp => "agent".to_string(),
                McpTemplate::PythonProject => "python".to_string(),
                McpTemplate::NodeProject => "node".to_string(),
                McpTemplate::GlobalNpx => "npx".to_string(),
                McpTemplate::FileSystem => "filesystem".to_string(),
                McpTemplate::GitMcp => "git".to_string(),
                McpTemplate::Custom => "custom".to_string(),
            },
            InputField::Type => match self.editing_config.mcp_type {
                McpType::Stdio => "stdio".to_string(),
                McpType::Http => "http".to_string(),
                McpType::Sse => "sse".to_string(),
            },
            InputField::Command => self.editing_config.command.clone(),
            InputField::Args => self.editing_config.base_args.join(" "),
            InputField::Port => String::new(), // Port is now a dynamic arg
            InputField::WorkingDir => self.editing_config.working_dir.clone().unwrap_or_default(),
            InputField::ActivationScript => self.editing_config.activation_script.clone().unwrap_or_default(),
            InputField::EnvVars => {
                self.editing_config.env_vars
                    .iter()
                    .map(|(k, v)| format!("{}={}", k, v))
                    .collect::<Vec<_>>()
                    .join("\n")
            }
        };
    }
    
    fn update_instance_status(&mut self, tabs: Vec<TabInfo>) {
        // Update pane IDs based on tab names
        for tab in tabs {
            {
                if tab.name.starts_with("MCP: ") {
                    let mcp_name = tab.name.strip_prefix("MCP: ").unwrap();
                    if let Some(_instance) = self.instances.get_mut(mcp_name) {
                        // Assume first pane in tab is the MCP pane
                        // For now, we'll need a different approach to track pane IDs
                        // This is a limitation we'll need to work around
                    }
                }
            }
        }
    }
    
    fn load_configs(&mut self) {
        // TODO: Load from persistent storage
        // For now, let's add some example configs
        
        // Create a filesystem MCP config
        let mut fs_config = McpConfig::default();
        fs_config.name = "File System MCP".to_string();
        fs_config.template = McpTemplate::FileSystem;
        fs_config.mcp_type = McpType::Stdio;
        fs_config.command = "npx".to_string();
        fs_config.base_args = vec!["-y".to_string(), "@modelcontextprotocol/server-filesystem".to_string()];
        fs_config.dynamic_args = vec![
            ArgDefinition {
                name: "allowed_paths".to_string(),
                flag: "".to_string(),
                value_type: ArgType::Directory,
                default: Some("/home".to_string()),
                required: true,
                description: "Allowed filesystem paths".to_string(),
            }
        ];
        fs_config.arg_values.insert("allowed_paths".to_string(), "/home".to_string());
        
        // Create an agent MCP config
        let mut agent_config = McpConfig::default();
        agent_config.name = "Agent MCP".to_string();
        agent_config.template = McpTemplate::AgentMcp;
        agent_config.mcp_type = McpType::Http;
        agent_config.command = "uv".to_string();
        agent_config.base_args = vec!["run".to_string(), "-m".to_string(), "agent_mcp.cli".to_string()];
        agent_config.dynamic_args = vec![
            ArgDefinition {
                name: "port".to_string(),
                flag: "--port".to_string(),
                value_type: ArgType::Port,
                default: Some("8080".to_string()),
                required: true,
                description: "HTTP server port".to_string(),
            },
            ArgDefinition {
                name: "project_dir".to_string(),
                flag: "--project-dir".to_string(),
                value_type: ArgType::Directory,
                default: None,
                required: true,
                description: "Project directory for agent operations".to_string(),
            }
        ];
        agent_config.arg_values.insert("port".to_string(), "8080".to_string());
        agent_config.working_dir = Some("/home/alejandro/Code/MCP/agent-mcp".to_string());
        
        self.configs = vec![fs_config, agent_config];
    }
    
    fn save_configs(&mut self) {
        // TODO: Save to persistent storage
        // For now, just log
        eprintln!("Saving {} configs", self.configs.len());
    }
    
    fn render_header(&self) {
        let title = "=== MCP Manager ===";
        let padding = (self.cols.saturating_sub(title.len())) / 2;
        println!("{}{}", " ".repeat(padding), title);
        println!("{}", "=".repeat(self.cols));
        println!();
    }
    
    fn render_main_menu(&self) {
        let menu_items = vec![
            ("1", "Current MCPs", "View and manage running MCP servers"),
            ("2", "Launch MCP", "Start a configured MCP server"),
            ("3", "Add MCP", "Configure a new MCP server"),
            ("q", "Quit", "Close the MCP Manager"),
        ];
        
        let start_row = self.rows / 2 - menu_items.len() / 2;
        
        for (i, (key, title, desc)) in menu_items.iter().enumerate() {
            let row = start_row + i;
            print!("\u{1b}[{};{}H", row, 20);
            
            print!("[{}] {} - {}", key, title, desc);
        }
    }
    
    fn render_current_mcps(&self) {
        let title = "Current MCP Servers";
        println!("{}", title);
        println!();
        
        if self.instances.is_empty() {
            let msg = "No MCP servers are currently running";
            let row = self.rows / 2;
            let col = (self.cols.saturating_sub(msg.len())) / 2;
            print!("\u{1b}[{};{}H", row, col);
            println!("{}", msg);
            return;
        }
        
        // Table header
        let headers = ["Name", "Type", "Status", "Port", "Started"];
        let col_widths = [25, 10, 10, 8, 20];
        
        for (i, (header, width)) in headers.iter().zip(&col_widths).enumerate() {
            print!("{:width$}", header, width = width);
            if i < headers.len() - 1 {
                print!(" ");
            }
        }
        println!();
        
        // Table rows
        for (i, (name, instance)) in self.instances.iter().enumerate() {
            let selected = i == self.selected_index;
            let prefix = if selected { "> " } else { "  " };
            
            let type_str = match &instance.config.mcp_type {
                McpType::Stdio => "stdio",
                McpType::Http => "http",
                McpType::Sse => "sse",
            };
            
            let status_str = match &instance.status {
                McpStatus::Running => "Running",
                McpStatus::Stopped => "Stopped",
                McpStatus::Failed(_) => "Failed",
            };
            
            let port_str = match instance.actual_port {
                Some(port) => port.to_string(),
                None => "-".to_string(),
            };
            
            print!("{}{:25} {:10} {:10} {:8} {:20}",
                prefix,
                &name[..name.len().min(25)],
                type_str,
                status_str,
                port_str,
                &instance.started_at
            );
            
            println!();
        }
        
        // Help text
        println!();
        println!("Enter: Open terminal | s: Stop | r: Restart | b: Back");
    }
    
    fn render_launch_mcp(&self) {
        let title = "Launch MCP Server";
        println!("{}", title);
        println!();
        
        if self.configs.is_empty() {
            let msg = "No MCP servers configured. Press 'b' to go back and add one.";
            let row = self.rows / 2;
            let col = (self.cols.saturating_sub(msg.len())) / 2;
            print!("\u{1b}[{};{}H", row, col);
            println!("{}", msg);
            return;
        }
        
        // List configs
        for (i, config) in self.configs.iter().enumerate() {
            let selected = i == self.selected_index;
            let prefix = if selected { "> " } else { "  " };
            
            let type_str = match &config.mcp_type {
                McpType::Stdio => "stdio".to_string(),
                McpType::Http => "http".to_string(),
                McpType::Sse => "sse".to_string(),
            };
            
            println!("{}{} [{}] - {}",
                prefix,
                config.name,
                &type_str,
                config.command
            );
        }
        
        // Help text
        println!();
        println!("Enter: Launch | e: Edit | d: Delete | b: Back");
    }
    
    fn render_add_edit_mcp(&self) {
        let title = match &self.screen {
            Screen::AddMcp => "Add MCP Server",
            Screen::EditMcp(name) => &format!("Edit MCP Server: {}", name),
            _ => "MCP Configuration",
        };
        
        println!("{}", title);
        println!();
        
        // Render form fields
        let template_str = match &self.editing_config.template {
            McpTemplate::AgentMcp => "agent".to_string(),
            McpTemplate::PythonProject => "python".to_string(),
            McpTemplate::NodeProject => "node".to_string(),
            McpTemplate::GlobalNpx => "npx".to_string(),
            McpTemplate::FileSystem => "filesystem".to_string(),
            McpTemplate::GitMcp => "git".to_string(),
            McpTemplate::Custom => "custom".to_string(),
        };
        let type_str = match &self.editing_config.mcp_type {
            McpType::Stdio => "stdio".to_string(),
            McpType::Http => "http".to_string(),
            McpType::Sse => "sse".to_string(),
        };
        let args_str = self.editing_config.base_args.join(" ");
        
        let fields = vec![
            ("Name", InputField::Name, &self.editing_config.name),
            ("Template (agent/fs/git/python/node/npx/custom)", InputField::Template, &template_str),
            ("Type (stdio/http)", InputField::Type, &type_str),
            ("Command", InputField::Command, &self.editing_config.command),
            ("Arguments", InputField::Args, &args_str),
        ];
        
        for (label, field, value) in fields {
            let is_current = self.input_field == field;
            let prefix = if is_current { "> " } else { "  " };
            
            print!("{}{:>12}: ", prefix, label);
            
            if is_current {
                // Show input buffer with cursor
                print!("{}_", self.input_buffer);
            } else {
                print!("{}", value);
            }
            println!();
        }
        
        
        // Working directory
        let is_current = self.input_field == InputField::WorkingDir;
        let prefix = if is_current { "> " } else { "  " };
        
        print!("{}{:>12}: ", prefix, "Working Dir");
        
        if is_current {
            print!("{}_", self.input_buffer);
            println!(" (Ctrl+D to browse)");
        } else {
            println!("{}", self.editing_config.working_dir.as_ref().unwrap_or(&String::new()));
        }
        
        // Activation script (only for Python projects)
        if matches!(self.editing_config.template, McpTemplate::PythonProject) {
            let is_current = self.input_field == InputField::ActivationScript;
            let prefix = if is_current { "> " } else { "  " };
            
            print!("{}{:>12}: ", prefix, "Venv Script");
            
            if is_current {
                println!("{}_", self.input_buffer);
            } else {
                println!("{}", self.editing_config.activation_script.as_ref().unwrap_or(&String::new()));
            }
        }
        
        // Environment variables
        let is_current = self.input_field == InputField::EnvVars;
        let prefix = if is_current { "> " } else { "  " };
        
        println!("{}{:>12}: ", prefix, "Env Vars");
        
        if is_current {
            println!("    (KEY=VALUE format, one per line)");
            for line in self.input_buffer.lines() {
                println!("    {}", line);
            }
            print!("    _");
        } else {
            for (key, value) in &self.editing_config.env_vars {
                println!("    {}={}", key, value);
            }
        }
        
        // Help text
        println!();
        println!();
        println!("Tab: Next field | Shift+Tab: Previous field | Enter: Save field | Ctrl+D: Browse dirs | Esc: Cancel");
    }
    
    fn render_configure_args(&self) {
        if let Screen::ConfigureArgs(config) = &self.screen {
            let title = format!("Configure Arguments for: {}", config.name);
            println!("{}", title);
            println!();
            
            if config.dynamic_args.is_empty() {
                println!("No arguments to configure.");
                println!();
                println!("Press Enter to launch or Esc to cancel");
                return;
            }
            
            // Show the command that will be run
            println!("Command: {} {}", config.command, config.base_args.join(" "));
            if let Some(wd) = &config.working_dir {
                println!("Working Dir: {}", wd);
            }
            println!();
            
            // Show dynamic arguments
            for (i, arg_def) in config.dynamic_args.iter().enumerate() {
                let is_current = i == self.editing_arg_index;
                let prefix = if is_current { "> " } else { "  " };
                
                let current_value = config.arg_values.get(&arg_def.name)
                    .cloned()
                    .or_else(|| arg_def.default.clone())
                    .unwrap_or_default();
                
                print!("{}{:>15}: ", prefix, arg_def.name);
                
                if is_current {
                    print!("{}_", self.input_buffer);
                    if matches!(arg_def.value_type, ArgType::Directory) {
                        print!(" (Ctrl+D to browse)");
                    }
                } else {
                    print!("{}", current_value);
                }
                
                // Show description
                if arg_def.required {
                    print!(" [required]");
                }
                println!(" - {}", arg_def.description);
            }
            
            // Show help
            println!();
            println!("↑↓: Navigate | Tab: Next | Enter: Launch | Ctrl+D: Browse (for directories) | Esc: Cancel");
        }
    }
    
    
    fn render_footer(&self) {
        let help = match &self.screen {
            Screen::MainMenu => "Select option (1-3) or press 'q' to quit",
            Screen::CurrentMcps => "↑↓: Navigate | Enter: Terminal | s: Stop | r: Restart | b: Back",
            Screen::LaunchMcp => "↑↓: Navigate | Enter: Configure | e: Edit | d: Delete | b: Back",
            Screen::AddMcp | Screen::EditMcp(_) => "Tab: Next | Enter: Save field | Ctrl+D: Browse dirs | Esc: Cancel",
            Screen::ConfigureArgs(_) => "↑↓: Navigate | Tab: Next | Enter: Launch | Ctrl+D: Browse | Esc: Cancel",
            Screen::BrowseDirectory { .. } => "↑↓: Navigate | Enter: Enter dir | s: Select current | Esc: Cancel",
        };
        
        let row = self.rows - 1;
        print!("\u{1b}[{};1H", row);
        print!("{}", help);
    }
    
    fn render_messages(&self) {
        let row = self.rows - 3;
        
        if let Some(error) = &self.error_message {
            print!("\u{1b}[{};1H", row);
            print!("Error: {}", error);
        }
        
        if let Some(success) = &self.success_message {
            print!("\u{1b}[{};1H", row);
            print!("✓ {}", success);
        }
    }
    
    fn update_arg_value(&mut self, arg_name: String, value: String) {
        if let Screen::ConfigureArgs(ref mut config) = &mut self.screen {
            config.arg_values.insert(arg_name, value);
        }
    }
    
    fn load_arg_value_to_buffer(&mut self) {
        if let Screen::ConfigureArgs(config) = &self.screen {
            if let Some(arg) = config.dynamic_args.get(self.editing_arg_index) {
                self.input_buffer = config.arg_values.get(&arg.name)
                    .cloned()
                    .or_else(|| arg.default.clone())
                    .unwrap_or_default();
            }
        }
    }
    
    fn open_directory_browser_for_arg(&mut self, arg_name: String) {
        if let Screen::ConfigureArgs(config) = &self.screen {
            let start_path = config.arg_values.get(&arg_name)
                .cloned()
                .or_else(|| config.working_dir.clone())
                .unwrap_or_else(|| std::env::var("HOME").unwrap_or("/home/alejandro".to_string()));
            
            self.screen = Screen::BrowseDirectory {
                return_field: InputField::WorkingDir, // Not used for args
                return_arg: Some(arg_name),
                current_path: start_path.clone(),
                entries: Vec::new(),
                selected_index: 0,
            };
            
            self.refresh_directory_listing();
        }
    }
    
    fn open_directory_browser(&mut self) {
        // Start from working dir if set, otherwise home directory
        let start_path = self.editing_config.working_dir.clone()
            .unwrap_or_else(|| std::env::var("HOME").unwrap_or("/home/alejandro".to_string()));
        
        self.screen = Screen::BrowseDirectory {
            return_field: self.input_field.clone(),
            return_arg: None,
            current_path: start_path.clone(),
            entries: Vec::new(),
            selected_index: 0,
        };
        
        self.refresh_directory_listing();
    }
    
    fn refresh_directory_listing(&mut self) {
        if let Screen::BrowseDirectory { entries, current_path, selected_index, .. } = &mut self.screen {
            entries.clear();
            *selected_index = 0;
            
            // Always add parent directory option
            entries.push("..".to_string());
            
            // Read directory contents
            if let Ok(dir_entries) = std::fs::read_dir(&current_path) {
                let mut dirs: Vec<String> = dir_entries
                    .filter_map(|entry| {
                        entry.ok().and_then(|e| {
                            let path = e.path();
                            if path.is_dir() {
                                path.file_name()
                                    .and_then(|n| n.to_str())
                                    .map(|s| s.to_string())
                            } else {
                                None
                            }
                        })
                    })
                    .collect();
                
                dirs.sort();
                entries.extend(dirs);
            }
        }
    }
    
    fn select_directory(&mut self) {
        if let Screen::BrowseDirectory { current_path, return_arg, .. } = &self.screen {
            let path = current_path.clone();
            let return_arg = return_arg.clone();
            
            if let Some(arg_name) = return_arg {
                // Returning to ConfigureArgs screen with directory for dynamic arg
                self.update_arg_value(arg_name, path);
                self.load_arg_value_to_buffer();
                // Return to ConfigureArgs screen
                if let Some(config) = self.configs.get(self.selected_index).cloned() {
                    self.screen = Screen::ConfigureArgs(config);
                }
            } else {
                // Returning to Edit screen with directory for working_dir field
                self.input_buffer = path;
                self.screen = if let Some(name) = self.get_editing_name() {
                    Screen::EditMcp(name)
                } else {
                    Screen::AddMcp
                };
            }
        }
    }
    
    fn get_editing_name(&self) -> Option<String> {
        match &self.screen {
            Screen::EditMcp(name) => Some(name.clone()),
            Screen::BrowseDirectory { .. } => {
                // Check if we were editing before browsing
                if self.editing_config.name.is_empty() {
                    None
                } else {
                    Some(self.editing_config.name.clone())
                }
            }
            _ => None,
        }
    }
    
    fn apply_template_defaults(&mut self) {
        // Clear existing dynamic args when switching templates
        self.editing_config.dynamic_args.clear();
        self.editing_config.arg_values.clear();
        
        match self.editing_config.template {
            McpTemplate::AgentMcp => {
                self.editing_config.command = "uv".to_string();
                self.editing_config.base_args = vec!["run".to_string(), "-m".to_string(), "agent_mcp.cli".to_string()];
                self.editing_config.mcp_type = McpType::Http;
                
                // Set up dynamic arguments
                self.editing_config.dynamic_args = vec![
                    ArgDefinition {
                        name: "port".to_string(),
                        flag: "--port".to_string(),
                        value_type: ArgType::Port,
                        default: Some("8080".to_string()),
                        required: true,
                        description: "HTTP server port".to_string(),
                    },
                    ArgDefinition {
                        name: "project_dir".to_string(),
                        flag: "--project-dir".to_string(),
                        value_type: ArgType::Directory,
                        default: None,
                        required: true,
                        description: "Project directory for agent operations".to_string(),
                    },
                ];
                
                // Set default values
                self.editing_config.arg_values.insert("port".to_string(), "8080".to_string());
            }
            McpTemplate::FileSystem => {
                self.editing_config.command = "npx".to_string();
                self.editing_config.base_args = vec!["-y".to_string(), "@modelcontextprotocol/server-filesystem".to_string()];
                self.editing_config.mcp_type = McpType::Stdio;
                
                // Filesystem MCP takes paths as positional args, not flags
                self.editing_config.dynamic_args = vec![
                    ArgDefinition {
                        name: "allowed_paths".to_string(),
                        flag: "".to_string(), // Positional argument
                        value_type: ArgType::Directory,
                        default: Some("/home".to_string()),
                        required: true,
                        description: "Allowed filesystem paths (space-separated)".to_string(),
                    },
                ];
                
                self.editing_config.arg_values.insert("allowed_paths".to_string(), "/home".to_string());
            }
            McpTemplate::GitMcp => {
                self.editing_config.command = "npx".to_string();
                self.editing_config.base_args = vec!["-y".to_string(), "@modelcontextprotocol/server-git".to_string()];
                self.editing_config.mcp_type = McpType::Stdio;
                
                self.editing_config.dynamic_args = vec![
                    ArgDefinition {
                        name: "repo_path".to_string(),
                        flag: "--repo".to_string(),
                        value_type: ArgType::Directory,
                        default: None,
                        required: true,
                        description: "Git repository path".to_string(),
                    },
                ];
            }
            McpTemplate::PythonProject => {
                if self.editing_config.command.is_empty() {
                    self.editing_config.command = "python".to_string();
                }
                if self.editing_config.base_args.is_empty() {
                    self.editing_config.base_args = vec!["main.py".to_string()];
                }
                // Python projects can have custom args, but we don't pre-define them
            }
            McpTemplate::NodeProject => {
                if self.editing_config.command.is_empty() {
                    self.editing_config.command = "npm".to_string();
                }
                if self.editing_config.base_args.is_empty() {
                    self.editing_config.base_args = vec!["start".to_string()];
                }
            }
            McpTemplate::GlobalNpx => {
                if self.editing_config.command.is_empty() {
                    self.editing_config.command = "npx".to_string();
                }
                self.editing_config.working_dir = None;
            }
            McpTemplate::Custom => {
                // No defaults for custom
            }
        }
    }
    
    fn render_browse_directory(&self) {
        if let Screen::BrowseDirectory { current_path, entries, selected_index, .. } = &self.screen {
            let title = "Browse Directory";
            println!("{}", title);
            println!();
            
            println!("Current: {}", current_path);
            println!();
            
            // Show directory entries
            let start_idx = selected_index.saturating_sub(10);
            let end_idx = (start_idx + 20).min(entries.len());
            
            for (i, entry) in entries[start_idx..end_idx].iter().enumerate() {
                let actual_idx = start_idx + i;
                let selected = actual_idx == *selected_index;
                let prefix = if selected { "> " } else { "  " };
                
                if entry == ".." {
                    println!("{}[Parent Directory]", prefix);
                } else {
                    println!("{}{}/", prefix, entry);
                }
            }
            
            // Help text
            println!();
            println!("↑↓: Navigate | Enter: Enter directory | s: Select current | Esc: Cancel");
        }
    }
}

// Add chrono feature for timestamps

mod chrono {
    use std::time::{SystemTime, UNIX_EPOCH};
    
    pub struct Local;
    
    impl Local {
        pub fn now() -> DateTime {
            DateTime(SystemTime::now())
        }
    }
    
    pub struct DateTime(SystemTime);
    
    impl DateTime {
        pub fn format(&self, _fmt: &str) -> String {
            let secs = self.0.duration_since(UNIX_EPOCH).unwrap().as_secs();
            let hours = (secs / 3600) % 24;
            let minutes = (secs / 60) % 60;
            let seconds = secs % 60;
            format!("{:02}:{:02}:{:02}", hours, minutes, seconds)
        }
    }
}