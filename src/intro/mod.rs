use std::io::{self, stdout, Write};
use termion::event::Key;
use termion::input::TermRead;
use termion::raw::IntoRawMode;
use termion::{clear, cursor, terminal_size};

#[derive(Debug, Clone, Copy)]
enum IntroScreen {
    Welcome,
    GettingStarted,
    KeyBindings,
}

pub struct IntroApp {
    current_screen: IntroScreen,
    selected_option: usize,
}

impl IntroApp {
    pub fn new() -> Self {
        Self {
            current_screen: IntroScreen::Welcome,
            selected_option: 0,
        }
    }

    pub fn run(&mut self) -> io::Result<IntroAction> {
        let _stdout = stdout().into_raw_mode()?;
        
        loop {
            self.render()?;
            
            for c in io::stdin().keys() {
                match c? {
                    Key::Esc => {
                        match self.current_screen {
                            IntroScreen::Welcome => return Ok(IntroAction::StartTerminal),
                            _ => {
                                self.current_screen = IntroScreen::Welcome;
                                self.selected_option = 0;
                            }
                        }
                    }
                    Key::Up => {
                        if self.selected_option > 0 {
                            self.selected_option -= 1;
                        }
                    }
                    Key::Down => {
                        let max_options = match self.current_screen {
                            IntroScreen::Welcome => 3,
                            _ => 0,
                        };
                        if self.selected_option < max_options {
                            self.selected_option += 1;
                        }
                    }
                    Key::Char('\n') => {
                        match self.current_screen {
                            IntroScreen::Welcome => {
                                match self.selected_option {
                                    0 => self.current_screen = IntroScreen::GettingStarted,
                                    1 => self.current_screen = IntroScreen::KeyBindings,
                                    2 => return Ok(IntroAction::SessionManager),
                                    3 => return Ok(IntroAction::StartTerminal),
                                    _ => {}
                                }
                            }
                            IntroScreen::GettingStarted | IntroScreen::KeyBindings => {
                                self.current_screen = IntroScreen::Welcome;
                                self.selected_option = 0;
                            }
                        }
                    }
                    Key::Char('1') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            self.current_screen = IntroScreen::GettingStarted;
                        }
                    }
                    Key::Char('2') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            self.current_screen = IntroScreen::KeyBindings;
                        }
                    }
                    Key::Char('3') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            return Ok(IntroAction::SessionManager);
                        }
                    }
                    Key::Char('4') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            return Ok(IntroAction::StartTerminal);
                        }
                    }
                    _ => {}
                }
                self.render()?;
            }
        }
    }

    fn render(&self) -> io::Result<()> {
        print!("{}{}", clear::All, cursor::Goto(1, 1));
        
        match self.current_screen {
            IntroScreen::Welcome => self.render_welcome_screen()?,
            IntroScreen::GettingStarted => self.render_getting_started()?,
            IntroScreen::KeyBindings => self.render_keybindings()?,
        }
        
        stdout().flush()?;
        Ok(())
    }

    fn render_welcome_screen(&self) -> io::Result<()> {
        let (cols, rows) = terminal_size()?;
        
        self.render_swarm_banner(cols, rows)?;
        self.render_welcome_menu(cols, rows)?;
        
        Ok(())
    }

    fn render_swarm_banner(&self, cols: u16, rows: u16) -> io::Result<()> {
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
        
        let (banner_to_use, is_small) = if cols > 100 && rows > 12 {
            (banner, false)
        } else if cols > 50 && rows > 8 {
            (medium_banner, false)
        } else {
            (small_banner, true)
        };
        
        let banner_lines: Vec<&str> = banner_to_use.lines().collect();
        let start_row = if is_small { 3 } else { 2 };
        
        for (i, line) in banner_lines.iter().enumerate() {
            if !line.trim().is_empty() {
                let col = (cols as usize).saturating_sub(line.len()) / 2;
                print!("{}\x1b[96m{}\x1b[0m", 
                       cursor::Goto((col + 1) as u16, (start_row + i) as u16), 
                       line);
            }
        }
        
        // Subtitle
        let subtitle = "Terminal Workspace for Developers";
        let subtitle_row = start_row + banner_lines.len() + 1;
        let subtitle_col = (cols as usize).saturating_sub(subtitle.len()) / 2;
        print!("{}\x1b[37m{}\x1b[0m", 
               cursor::Goto((subtitle_col + 1) as u16, subtitle_row as u16), 
               subtitle);
        
        Ok(())
    }

    fn render_welcome_menu(&self, cols: u16, rows: u16) -> io::Result<()> {
        let banner_height = if cols > 100 && rows > 12 {
            8
        } else if cols > 50 && rows > 8 {
            7
        } else {
            3
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
        let title_col = (cols as usize).saturating_sub(title.len()) / 2;
        print!("{}\x1b[1;37m{}\x1b[0m", 
               cursor::Goto((title_col + 1) as u16, menu_start_row as u16), 
               title);
        
        // Menu items
        for (i, item) in menu_items.iter().enumerate() {
            let row = menu_start_row + 2 + i;
            let col = (cols as usize).saturating_sub(item.len()) / 2;
            
            if i == self.selected_option {
                print!("{}\x1b[1;96m> {}\x1b[0m", 
                       cursor::Goto((col.saturating_sub(2)) as u16, row as u16), 
                       item);
            } else {
                print!("{}\x1b[37m  {}\x1b[0m", 
                       cursor::Goto(col as u16, row as u16), 
                       item);
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
                let col = (cols as usize).saturating_sub(instr.len()) / 2;
                print!("{}\x1b[90m{}\x1b[0m", 
                       cursor::Goto((col + 1) as u16, (instr_start_row + i) as u16), 
                       instr);
            }
        }
        
        Ok(())
    }

    fn render_getting_started(&self) -> io::Result<()> {
        let (cols, _rows) = terminal_size()?;
        
        let title = "Getting Started with Swarm";
        let title_col = (cols as usize).saturating_sub(title.len()) / 2;
        print!("{}\x1b[1;96m{}\x1b[0m", cursor::Goto((title_col + 1) as u16, 2), title);
        
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
            let col = if line.starts_with('•') || line.starts_with('[') {
                (cols as usize).saturating_sub(line.len()) / 2
            } else {
                (cols as usize).saturating_sub(line.len()) / 2
            };
            
            let color = if line.starts_with('•') {
                "\x1b[93m" // Yellow for bullet points
            } else if line.starts_with('[') {
                "\x1b[90m" // Gray for instructions
            } else {
                "\x1b[37m" // White for regular text
            };
            
            print!("{}{}{}\x1b[0m", cursor::Goto((col + 1) as u16, row as u16), color, line);
        }
        
        Ok(())
    }

    fn render_keybindings(&self) -> io::Result<()> {
        let (cols, _rows) = terminal_size()?;
        
        let title = "Essential Key Bindings";
        let title_col = (cols as usize).saturating_sub(title.len()) / 2;
        print!("{}\x1b[1;96m{}\x1b[0m", cursor::Goto((title_col + 1) as u16, 2), title);
        
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
            let col = 4; // Left-aligned for better readability
            
            let color = if line.ends_with(':') {
                "\x1b[1;93m" // Bold yellow for section headers
            } else if line.starts_with("  ") {
                "\x1b[96m" // Cyan for key bindings
            } else if line.starts_with('[') {
                "\x1b[90m" // Gray for instructions
            } else {
                "\x1b[37m" // White for regular text
            };
            
            print!("{}{}{}\x1b[0m", cursor::Goto(col, row as u16), color, line);
        }
        
        Ok(())
    }
}

#[derive(Debug)]
pub enum IntroAction {
    StartTerminal,
    SessionManager,
}