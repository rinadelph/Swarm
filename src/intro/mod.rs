use std::io::{self, stdout, Write};
use termion::event::Key;
use termion::input::TermRead;
use termion::raw::IntoRawMode;
use termion::{clear, cursor, terminal_size};

#[cfg(test)]
mod test_banner;

#[derive(Debug, Clone, Copy)]
enum IntroScreen {
    Welcome,
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
        
        // Clear entire terminal immediately when intro starts
        print!("\x1b[2J");        // Clear entire screen
        print!("\x1b[3J");        // Clear scrollback buffer
        print!("\x1b[H");         // Move cursor to home position
        print!("\x1b[0m");        // Reset all formatting
        stdout().flush()?;
        
        let mut last_size = terminal_size()?;
        let mut exit_action: Option<IntroAction> = None;
        
        loop {
            // Check for terminal resize and re-render if needed
            let current_size = terminal_size()?;
            if current_size != last_size {
                print!("{}{}", clear::All, clear::AfterCursor);
                stdout().flush()?;
                last_size = current_size;
            }
            
            self.render()?;
            
            for c in io::stdin().keys() {
                match c? {
                    Key::Esc => {
                        match self.current_screen {
                            IntroScreen::Welcome => {
                                exit_action = Some(IntroAction::StartTerminal);
                                break;
                            },
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
                            IntroScreen::Welcome => 2,
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
                                    0 => {
                                        exit_action = Some(IntroAction::LaunchProject);
                                        break;
                                    },
                                    1 => {
                                        exit_action = Some(IntroAction::StartTerminal);
                                        break;
                                    },
                                    2 => {
                                        exit_action = Some(IntroAction::Settings);
                                        break;
                                    },
                                    _ => {}
                                }
                            }
                            _ => {
                                // All other screens, return to welcome
                                self.current_screen = IntroScreen::Welcome;
                                self.selected_option = 0;
                            }
                        }
                    }
                    Key::Char('1') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            exit_action = Some(IntroAction::LaunchProject);
                            break;
                        }
                    }
                    Key::Char('2') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            exit_action = Some(IntroAction::StartTerminal);
                            break;
                        }
                    }
                    Key::Char('3') => {
                        if matches!(self.current_screen, IntroScreen::Welcome) {
                            exit_action = Some(IntroAction::Settings);
                            break;
                        }
                    }
                    _ => {}
                }
                if exit_action.is_some() {
                    break;
                }
                self.render()?;
            }
            
            if let Some(action) = exit_action {
                // Clean up screen before exiting
                print!("{}", clear::All);
                stdout().flush()?;
                print!("{}", clear::BeforeCursor);
                stdout().flush()?;
                print!("{}", clear::AfterCursor);
                stdout().flush()?;
                
                // Reset cursor and ensure clean state
                print!("{}{}", cursor::Goto(1, 1), cursor::Show);
                stdout().flush()?;
                
                // Additional clearing
                print!("\x1b[2J\x1b[H\x1b[3J"); // Clear screen, home cursor, clear scrollback
                stdout().flush()?;
                
                return Ok(action);
            }
        }
    }

    fn render(&self) -> io::Result<()> {
        // More aggressive screen clearing
        print!("{}{}{}", clear::All, clear::AfterCursor, cursor::Goto(1, 1));
        stdout().flush()?;  // Ensure clear is flushed before rendering
        
        match self.current_screen {
            IntroScreen::Welcome => self.render_welcome_screen()?,
            _ => {} // No other screens needed for simplified menu
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
        // LARGE - Proper FIGlet-style SWARM banner (105+ cols, 7 lines)
        let large_banner_lines = vec![
            " ░▒▓███████▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░  ░▒▓██████▓▒░  ░▒▓███████▓▒░  ░▒▓██████████████▓▒░",
            "░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
            "░▒▓█▓▒░        ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
            " ░▒▓██████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓████████▓▒░ ░▒▓███████▓▒░  ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
            "       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
            "       ░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
            "░▒▓███████▓▒░   ░▒▓█████████████▓▒░   ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░ ░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░",
        ];

        // MEDIUM - Readable SWARM in blocks (42 cols)
        let medium_banner_lines = vec![
            "███ █ █ ███ ███ █ █",
            "█   █ █ █ █ █ █ ███",
            "███ ███ ███ ██  █ █",
            "  █ █ █ █ █ █ █ █ █",
            "███ █ █ █ █ █ █ █ █",
            "",
        ];

        // SMALL - Compact SWARM (25+ cols)
        let small_banner_lines = vec![
            "███ █ █ ███ ███ █ █",
            "█   █ █ █ █ █ █ ███",
            "███ ███ ███ ██  ███",
            "  █ █ █ █ █ █ █ █ █",
            "███ █ █ █ █ █ █ █ █",
            "",
        ];

        // MICRO - Minimal (under 30 cols)
        let micro_banner_lines = vec![
            "[ S W A R M ]",
            "",
        ];
        
        // Center banner vertically - use more space from top
        let banner_start_row = (rows as usize).saturating_sub(20).max(2) / 2;
        let (lines_to_use, start_row) = (&large_banner_lines, banner_start_row);  // Always use large banner
        
        // Calculate the maximum line width for proper centering
        let max_width = lines_to_use.iter().map(|line| line.len()).max().unwrap_or(0);
        
        // Always display the banner, properly centered
        for (i, line) in lines_to_use.iter().enumerate() {
            let line_width = line.chars().count(); // Use char count for proper width
            let col = if line_width <= cols as usize {
                (cols as usize - line_width) / 2
            } else {
                0
            };
            print!("{}\x1b[96m{}\x1b[0m", 
                   cursor::Goto((col + 1) as u16, (start_row + i) as u16), 
                   line);
        }
        
        // Subtitle - always show, properly centered
        let subtitle = "Terminal Workspace for Developers";
        let subtitle_row = start_row + lines_to_use.len() + 3;
        let subtitle_width = subtitle.chars().count();
        let subtitle_col = if subtitle_width <= cols as usize {
            (cols as usize - subtitle_width) / 2
        } else {
            0
        };
        print!("{}\x1b[37m{}\x1b[0m", 
               cursor::Goto((subtitle_col + 1) as u16, subtitle_row as u16), 
               subtitle);
        
        Ok(())
    }

    fn render_welcome_menu(&self, cols: u16, rows: u16) -> io::Result<()> {
        let banner_height = 14;  // Push menu further down (7 lines + 7 for spacing/subtitle)
        let menu_start_row = 2 + banner_height;
        
        let menu_items = vec![
            "1. Launch a Project",
            "2. Launch Terminal Session",
            "3. Settings",
        ];
        
        // Menu title
        let title = "Welcome to Swarm! Choose an option:";
        let title_width = title.chars().count();
        let title_col = if title_width <= cols as usize {
            (cols as usize - title_width) / 2
        } else {
            0
        };
        print!("{}\x1b[1;37m{}\x1b[0m", 
               cursor::Goto((title_col + 1) as u16, menu_start_row as u16), 
               title);
        
        // Menu items
        for (i, item) in menu_items.iter().enumerate() {
            let row = menu_start_row + 2 + i;
            let item_width = item.chars().count();
            let col = if item_width <= cols as usize {
                (cols as usize - item_width) / 2
            } else {
                0
            };
            
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
                let instr_width = instr.chars().count();
                let col = if instr_width <= cols as usize {
                    (cols as usize - instr_width) / 2
                } else {
                    0
                };
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
    LaunchProject,
    Settings,
}