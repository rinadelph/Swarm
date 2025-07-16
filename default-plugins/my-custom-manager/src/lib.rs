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