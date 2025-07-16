use std::collections::BTreeMap;
use zellij_tile::prelude::*;
use serde::{Serialize, Deserialize};

// MCP Server Types
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
enum McpType {
    Stdio,
    Http { port: u16 },
}

// MCP Server Configuration
#[derive(Debug, Clone, Serialize, Deserialize)]
struct McpConfig {
    name: String,
    mcp_type: McpType,
    command: String,
    args: Vec<String>,
    env_vars: BTreeMap<String, String>,
    working_dir: Option<String>,
}

// Running MCP Instance
#[derive(Debug, Clone, Serialize, Deserialize)]
struct McpInstance {
    config: McpConfig,
    tab_name: String,
    pane_id: Option<PaneId>,
    status: McpStatus,
    started_at: String,
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
}

// Input modes for Add/Edit MCP screen
#[derive(Debug, Clone, PartialEq)]
enum InputField {
    Name,
    Type,
    Command,
    Args,
    Port,
    WorkingDir,
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

impl Default for McpConfig {
    fn default() -> Self {
        McpConfig {
            name: String::new(),
            mcp_type: McpType::Stdio,
            command: String::new(),
            args: Vec::new(),
            env_vars: BTreeMap::new(),
            working_dir: None,
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
                // Enter terminal for selected MCP
                if let Some((_, instance)) = self.instances.iter().nth(self.selected_index) {
                    if let Some(pane_id) = instance.pane_id {
                        focus_pane_with_id(pane_id, true);
                        hide_self();
                    }
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
                // Launch selected MCP
                if let Some(config) = self.configs.get(self.selected_index) {
                    self.launch_mcp(config.clone());
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
    
    fn launch_mcp(&mut self, config: McpConfig) {
        // Create a unique tab name
        let tab_name = format!("MCP: {}", config.name);
        
        // Build command to run
        let mut command_to_run = CommandToRun {
            path: std::path::PathBuf::from(config.command.clone()),
            args: config.args.clone(),
            ..Default::default()
        };
        
        // Set working directory if specified
        if let Some(cwd) = &config.working_dir {
            command_to_run.cwd = Some(std::path::PathBuf::from(cwd));
        }
        
        // Create new tab
        new_tab(Some(tab_name.clone()), config.working_dir.clone());
        
        // Open command pane in the new tab with environment variables
        open_command_pane_background(command_to_run, config.env_vars.clone());
        
        // Create instance record
        let instance = McpInstance {
            config: config.clone(),
            tab_name,
            pane_id: None, // Will be updated when we get tab update
            status: McpStatus::Running,
            started_at: chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string(),
        };
        
        self.instances.insert(config.name.clone(), instance);
        self.success_message = Some(format!("Launched MCP: {}", config.name));
        
        // Switch to current MCPs screen
        self.screen = Screen::CurrentMcps;
    }
    
    fn stop_selected_mcp(&mut self) {
        if let Some((name, _)) = self.instances.iter().nth(self.selected_index) {
            let name = name.clone();
            // TODO: Send kill signal to the pane/tab
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
            InputField::Type => {
                // Handle type selection
            }
            InputField::Command => {
                self.editing_config.command = self.input_buffer.clone();
            }
            InputField::Args => {
                self.editing_config.args = self.input_buffer
                    .split_whitespace()
                    .map(String::from)
                    .collect();
            }
            InputField::Port => {
                if let Ok(port) = self.input_buffer.parse::<u16>() {
                    self.editing_config.mcp_type = McpType::Http { port };
                }
            }
            InputField::WorkingDir => {
                self.editing_config.working_dir = if self.input_buffer.is_empty() {
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
        }
    }
    
    fn next_input_field(&mut self) {
        self.save_current_field();
        
        self.input_field = match self.input_field {
            InputField::Name => InputField::Type,
            InputField::Type => InputField::Command,
            InputField::Command => InputField::Args,
            InputField::Args => {
                match self.editing_config.mcp_type {
                    McpType::Http { .. } => InputField::Port,
                    McpType::Stdio => InputField::WorkingDir,
                }
            }
            InputField::Port => InputField::WorkingDir,
            InputField::WorkingDir => InputField::EnvVars,
            InputField::EnvVars => InputField::Name,
        };
        
        self.load_field_to_buffer();
    }
    
    fn prev_input_field(&mut self) {
        self.save_current_field();
        
        self.input_field = match self.input_field {
            InputField::Name => InputField::EnvVars,
            InputField::Type => InputField::Name,
            InputField::Command => InputField::Type,
            InputField::Args => InputField::Command,
            InputField::Port => InputField::Args,
            InputField::WorkingDir => {
                match self.editing_config.mcp_type {
                    McpType::Http { .. } => InputField::Port,
                    McpType::Stdio => InputField::Args,
                }
            }
            InputField::EnvVars => InputField::WorkingDir,
        };
        
        self.load_field_to_buffer();
    }
    
    fn load_field_to_buffer(&mut self) {
        self.input_buffer = match self.input_field {
            InputField::Name => self.editing_config.name.clone(),
            InputField::Type => match self.editing_config.mcp_type {
                McpType::Stdio => "stdio".to_string(),
                McpType::Http { .. } => "http".to_string(),
            },
            InputField::Command => self.editing_config.command.clone(),
            InputField::Args => self.editing_config.args.join(" "),
            InputField::Port => {
                match self.editing_config.mcp_type {
                    McpType::Http { port } => port.to_string(),
                    _ => String::new(),
                }
            }
            InputField::WorkingDir => self.editing_config.working_dir.clone().unwrap_or_default(),
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
                    if let Some(instance) = self.instances.get_mut(mcp_name) {
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
        self.configs = vec![
            McpConfig {
                name: "Claude Desktop MCP".to_string(),
                mcp_type: McpType::Stdio,
                command: "npx".to_string(),
                args: vec!["-y".to_string(), "@modelcontextprotocol/server-everything".to_string()],
                env_vars: BTreeMap::new(),
                working_dir: None,
            },
            McpConfig {
                name: "Python MCP Server".to_string(),
                mcp_type: McpType::Http { port: 8080 },
                command: "python".to_string(),
                args: vec!["-m".to_string(), "mcp_server".to_string()],
                env_vars: BTreeMap::from([
                    ("MCP_PORT".to_string(), "8080".to_string()),
                ]),
                working_dir: Some("/home/user/mcp-servers".to_string()),
            },
        ];
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
                McpType::Http { .. } => "http",
            };
            
            let status_str = match &instance.status {
                McpStatus::Running => "Running",
                McpStatus::Stopped => "Stopped",
                McpStatus::Failed(_) => "Failed",
            };
            
            let port_str = match &instance.config.mcp_type {
                McpType::Http { port } => port.to_string(),
                _ => "-".to_string(),
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
                McpType::Http { port } => format!("http:{}", port),
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
        let type_str = match &self.editing_config.mcp_type {
            McpType::Stdio => "stdio".to_string(),
            McpType::Http { .. } => "http".to_string(),
        };
        let args_str = self.editing_config.args.join(" ");
        
        let fields = vec![
            ("Name", InputField::Name, &self.editing_config.name),
            ("Type", InputField::Type, &type_str),
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
        
        // Port field (only for HTTP type)
        if let McpType::Http { port } = &self.editing_config.mcp_type {
            let is_current = self.input_field == InputField::Port;
            let prefix = if is_current { "> " } else { "  " };
            
            print!("{}{:>12}: ", prefix, "Port");
            
            if is_current {
                print!("{}_", self.input_buffer);
            } else {
                print!("{}", port);
            }
            println!();
        }
        
        // Working directory
        let is_current = self.input_field == InputField::WorkingDir;
        let prefix = if is_current { "> " } else { "  " };
        
        print!("{}{:>12}: ", prefix, "Working Dir");
        
        if is_current {
            print!("{}_", self.input_buffer);
        } else {
            print!("{}", self.editing_config.working_dir.as_ref().unwrap_or(&String::new()));
        }
        println!();
        
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
        println!("Tab: Next field | Shift+Tab: Previous field | Enter: Save field | Esc: Cancel");
    }
    
    fn render_footer(&self) {
        let help = match &self.screen {
            Screen::MainMenu => "Select option (1-3) or press 'q' to quit",
            Screen::CurrentMcps => "↑↓: Navigate | Enter: Terminal | s: Stop | r: Restart | b: Back",
            Screen::LaunchMcp => "↑↓: Navigate | Enter: Launch | e: Edit | d: Delete | b: Back",
            Screen::AddMcp | Screen::EditMcp(_) => "Tab: Next | Enter: Save field | Esc: Cancel",
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