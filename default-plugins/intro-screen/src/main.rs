use zellij_tile::prelude::*;
use std::collections::BTreeMap;

#[derive(Debug)]
enum IntroScreen {
    Welcome,
    GettingStarted,
    KeyBindings,
    SessionManager,
}

impl Default for IntroScreen {
    fn default() -> Self {
        IntroScreen::Welcome
    }
}

#[derive(Debug)]
struct IntroApp {
    current_screen: IntroScreen,
    selected_option: usize,
    rows: usize,
    cols: usize,
}

impl Default for IntroApp {
    fn default() -> Self {
        IntroApp {
            current_screen: IntroScreen::Welcome,
            selected_option: 0,
            rows: 0,
            cols: 0,
        }
    }
}

register_plugin!(IntroApp);

impl SwarmPlugin for IntroApp {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        subscribe(&[
            EventType::Key,
            EventType::Mouse,
        ]);
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::Key(key) => self.handle_key(key),
            Event::Mouse(mouse_event) => self.handle_mouse(mouse_event),
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        self.rows = rows;
        self.cols = cols;
        
        match self.current_screen {
            IntroScreen::Welcome => self.render_welcome_screen(),
            IntroScreen::GettingStarted => self.render_getting_started(),
            IntroScreen::KeyBindings => self.render_keybindings(),
            IntroScreen::SessionManager => self.launch_session_manager(),
        }
    }
}

impl IntroApp {
    fn handle_key(&mut self, key: KeyWithModifier) -> bool {
        match key.bare_key {
            BareKey::Esc => {
                match self.current_screen {
                    IntroScreen::Welcome => {
                        // Exit to normal terminal
                        new_tab(None::<String>, None::<String>);
                        close_self();
                    }
                    _ => {
                        self.current_screen = IntroScreen::Welcome;
                        self.selected_option = 0;
                    }
                }
                true
            }
            BareKey::Enter => {
                match self.current_screen {
                    IntroScreen::Welcome => {
                        match self.selected_option {
                            0 => self.current_screen = IntroScreen::GettingStarted,
                            1 => self.current_screen = IntroScreen::KeyBindings,
                            2 => self.current_screen = IntroScreen::SessionManager,
                            3 => {
                                // Start new terminal session
                                new_tab(None::<String>, None::<String>);
                                close_self();
                            }
                            _ => {}
                        }
                    }
                    IntroScreen::GettingStarted => {
                        if self.selected_option == 0 {
                            self.current_screen = IntroScreen::Welcome;
                            self.selected_option = 0;
                        }
                    }
                    IntroScreen::KeyBindings => {
                        if self.selected_option == 0 {
                            self.current_screen = IntroScreen::Welcome;
                            self.selected_option = 0;
                        }
                    }
                    IntroScreen::SessionManager => {
                        // This will be handled by launching session manager
                    }
                }
                true
            }
            BareKey::Up => {
                if self.selected_option > 0 {
                    self.selected_option -= 1;
                }
                true
            }
            BareKey::Down => {
                let max_options = match self.current_screen {
                    IntroScreen::Welcome => 3,
                    _ => 0,
                };
                if self.selected_option < max_options {
                    self.selected_option += 1;
                }
                true
            }
            BareKey::Char('1') => {
                if matches!(self.current_screen, IntroScreen::Welcome) {
                    self.current_screen = IntroScreen::GettingStarted;
                    true
                } else { false }
            }
            BareKey::Char('2') => {
                if matches!(self.current_screen, IntroScreen::Welcome) {
                    self.current_screen = IntroScreen::KeyBindings;
                    true
                } else { false }
            }
            BareKey::Char('3') => {
                if matches!(self.current_screen, IntroScreen::Welcome) {
                    self.current_screen = IntroScreen::SessionManager;
                    true
                } else { false }
            }
            BareKey::Char('4') => {
                if matches!(self.current_screen, IntroScreen::Welcome) {
                    new_tab(None::<String>, None::<String>);
                    close_self();
                    true
                } else { false }
            }
            _ => false,
        }
    }

    fn handle_mouse(&mut self, _mouse_event: Mouse) -> bool {
        // Mouse handling can be implemented later
        false
    }

    fn render_welcome_screen(&self) {
        // Clear screen
        print!("\u{1b}[2J\u{1b}[H");
        
        self.render_swarm_banner();
        self.render_welcome_menu();
    }

    fn render_swarm_banner(&self) {
        let banner = r#"
███████╗██╗    ██╗ █████╗ ██████╗ ███╗   ███╗
██╔════╝██║    ██║██╔══██╗██╔══██╗████╗ ████║  
███████╗██║ █╗ ██║███████║██████╔╝██╔████╔██║
╚════██║██║███╗██║██╔══██║██╔══██╗██║╚██╔╝██║
███████║╚███╔███╔╝██║  ██║██║  ██║██║ ╚═╝ ██║
╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
"#;

        let medium_banner = r#"
 ▗▄▄▖▗▖ ▗▖ ▗▄▖ ▗▄▄▖▗▖  ▗▖
▗▘   ▐▌ ▐▌▗▞▀▖▗▘  ▘▐▛▚▞▜▌  
▝▀▚▖ ▐▌ ▐▌▐▛▀▜▌▝▀▚▖ ▐▌  ▐▌
   ▐▌▐▙▄▟▌▐▌ ▐▌   ▐▌▐▌  ▐▌
▗▄▄▞▘ ▜▛▀▘ ▝▙▄▞▘▗▄▄▞▘▐▌  ▐▌
"#;

        let small_banner = "S W A R M";
        
        let (banner_to_use, is_small) = if self.cols > 100 && self.rows > 12 {
            (banner, false)
        } else if self.cols > 50 && self.rows > 8 {
            (medium_banner, false)
        } else {
            (small_banner, true)
        };
        
        let banner_lines: Vec<&str> = banner_to_use.lines().collect();
        let start_row = if is_small { 3 } else { 2 };
        
        for (i, line) in banner_lines.iter().enumerate() {
            if !line.trim().is_empty() {
                let col = (self.cols.saturating_sub(line.len())) / 2;
                print!("\u{1b}[{};{}H\u{1b}[96m{}\u{1b}[0m", start_row + i, col + 1, line);
            }
        }
        
        // Subtitle
        let subtitle = "Terminal Workspace for Developers";
        let subtitle_row = start_row + banner_lines.len() + 1;
        let subtitle_col = (self.cols.saturating_sub(subtitle.len())) / 2;
        print!("\u{1b}[{};{}H\u{1b}[37m{}\u{1b}[0m", subtitle_row, subtitle_col + 1, subtitle);
    }

    fn render_welcome_menu(&self) {
        // Calculate dynamic menu position based on banner size
        let banner_height = if self.cols > 100 && self.rows > 12 {
            8  // Large banner height
        } else if self.cols > 50 && self.rows > 8 {
            7  // Medium banner height
        } else {
            3  // Small banner height
        };
        let menu_start_row = 3 + banner_height;
        let menu_items = vec![
            "1. Getting Started Guide",
            "2. Key Bindings Reference", 
            "3. Manage Sessions",
            "4. Start New Terminal Session",
        ];
        
        // Menu title
        let title = "Welcome to Swarm! Choose an option:";
        let title_col = (self.cols.saturating_sub(title.len())) / 2;
        print!("\u{1b}[{};{}H\u{1b}[1;37m{}\u{1b}[0m", menu_start_row, title_col + 1, title);
        
        // Menu items
        for (i, item) in menu_items.iter().enumerate() {
            let row = menu_start_row + 2 + i;
            let col = (self.cols.saturating_sub(item.len())) / 2;
            
            if i == self.selected_option {
                print!("\u{1b}[{};{}H\u{1b}[1;96m> {}\u{1b}[0m", row, col.saturating_sub(2), item);
            } else {
                print!("\u{1b}[{};{}H\u{1b}[37m  {}\u{1b}[0m", row, col, item);
            }
        }
        
        // Instructions
        let instructions = vec![
            "",
            "Use ↑/↓ arrows or number keys to navigate",
            "Press Enter to select, Esc to exit to terminal",
        ];
        
        let instr_start_row = menu_start_row + menu_items.len() + 4;
        for (i, instr) in instructions.iter().enumerate() {
            if !instr.is_empty() {
                let col = (self.cols.saturating_sub(instr.len())) / 2;
                print!("\u{1b}[{};{}H\u{1b}[90m{}\u{1b}[0m", instr_start_row + i, col + 1, instr);
            }
        }
    }

    fn render_getting_started(&self) {
        print!("\u{1b}[2J\u{1b}[H");
        
        let title = "Getting Started with Swarm";
        let title_col = (self.cols.saturating_sub(title.len())) / 2;
        print!("\u{1b}[{};{}H\u{1b}[1;96m{}\u{1b}[0m", 2, title_col + 1, title);
        
        let content = vec![
            "",
            "Swarm is a powerful terminal workspace that helps you:",
            "",
            "• Manage multiple terminal sessions",
            "• Split your terminal into panes and tabs",
            "• Detach and reattach to sessions",
            "• Customize your workspace with layouts",
            "• Use plugins to extend functionality",
            "",
            "Quick Tips:",
            "• Ctrl+O: Open session mode",
            "• Ctrl+P: Open pane mode", 
            "• Ctrl+T: Open tab mode",
            "• Ctrl+N: Open resize mode",
            "• Ctrl+S: Open scroll mode",
            "",
            "For more detailed help, visit: https://github.com/rinadelph/zellij",
            "",
            "[Press Enter to return to main menu]",
        ];
        
        let start_row = 4;
        for (i, line) in content.iter().enumerate() {
            let row = start_row + i;
            if row < self.rows.saturating_sub(2) {
                let col = if line.starts_with('•') || line.starts_with('[') {
                    (self.cols.saturating_sub(line.len())) / 2
                } else {
                    (self.cols.saturating_sub(line.len())) / 2
                };
                
                let color = if line.starts_with('•') {
                    "\u{1b}[93m" // Yellow for bullet points
                } else if line.starts_with('[') {
                    "\u{1b}[90m" // Gray for instructions
                } else {
                    "\u{1b}[37m" // White for regular text
                };
                
                print!("\u{1b}[{};{}H{}{}\u{1b}[0m", row, col + 1, color, line);
            }
        }
    }

    fn render_keybindings(&self) {
        print!("\u{1b}[2J\u{1b}[H");
        
        let title = "Essential Key Bindings";
        let title_col = (self.cols.saturating_sub(title.len())) / 2;
        print!("\u{1b}[{};{}H\u{1b}[1;96m{}\u{1b}[0m", 2, title_col + 1, title);
        
        let content = vec![
            "",
            "Session Management:",
            "  Ctrl+O W     - Session manager",
            "  Ctrl+O D     - Detach session",
            "",
            "Panes:",
            "  Ctrl+P N     - New pane",
            "  Ctrl+P D     - New pane down",
            "  Ctrl+P R     - New pane right", 
            "  Ctrl+P X     - Close pane",
            "  Ctrl+P F     - Toggle fullscreen",
            "",
            "Tabs:",
            "  Ctrl+T N     - New tab",
            "  Ctrl+T X     - Close tab",
            "  Ctrl+T →/←   - Switch tabs",
            "",
            "Resize Mode:",
            "  Ctrl+N       - Enter resize mode",
            "  H/J/K/L      - Resize panes",
            "",
            "[Press Enter to return to main menu]",
        ];
        
        let start_row = 4;
        for (i, line) in content.iter().enumerate() {
            let row = start_row + i;
            if row < self.rows.saturating_sub(2) {
                let col = 4; // Left-aligned for better readability
                
                let color = if line.ends_with(':') {
                    "\u{1b}[1;93m" // Bold yellow for section headers
                } else if line.starts_with("  ") {
                    "\u{1b}[96m" // Cyan for key bindings
                } else if line.starts_with('[') {
                    "\u{1b}[90m" // Gray for instructions
                } else {
                    "\u{1b}[37m" // White for regular text
                };
                
                print!("\u{1b}[{};{}H{}{}\u{1b}[0m", row, col, color, line);
            }
        }
    }

    fn launch_session_manager(&self) {
        // Launch the session manager plugin
        run_command(&["swarm", "action", "launch-or-focus-plugin", "session-manager", "--floating", "true"], BTreeMap::new());
        close_self();
    }
}