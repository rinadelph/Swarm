use ansi_term::{
    unstyled_len, ANSIString, ANSIStrings,
    Color::{Fixed, RGB},
    Style,
};

use crate::LinePart;
use zellij_tile::prelude::*;
use zellij_tile_utils::palette_match;

macro_rules! strings {
    ($ANSIStrings:expr) => {{
        let strings: &[ANSIString] = $ANSIStrings;

        let ansi_strings = ANSIStrings(strings);

        LinePart {
            part: format!("{}", ansi_strings),
            len: unstyled_len(&ansi_strings),
        }
    }};
}

pub fn swarm_setup_check_full(help: &ModeInfo) -> LinePart {
    // Tip: Having issues with Swarm? Try running "swarm setup --check"
    let orange_color = palette_match!(help.style.colors.text_unselected.emphasis_0);

    strings!(&[
        Style::new().paint(" Tip: "),
        Style::new().paint("Having issues with Swarm? Try running "),
        Style::new()
            .fg(orange_color)
            .bold()
            .paint("swarm setup --check"),
    ])
}

pub fn swarm_setup_check_medium(help: &ModeInfo) -> LinePart {
    // Tip: Run "swarm setup --check" to find issues
    let orange_color = palette_match!(help.style.colors.text_unselected.emphasis_0);

    strings!(&[
        Style::new().paint(" Tip: "),
        Style::new().paint("Run "),
        Style::new()
            .fg(orange_color)
            .bold()
            .paint("swarm setup --check"),
        Style::new().paint(" to find issues"),
    ])
}

pub fn swarm_setup_check_short(help: &ModeInfo) -> LinePart {
    // Run "swarm setup --check" to find issues
    let orange_color = palette_match!(help.style.colors.text_unselected.emphasis_0);

    strings!(&[
        Style::new().paint(" Run "),
        Style::new()
            .fg(orange_color)
            .bold()
            .paint("swarm setup --check"),
        Style::new().paint(" to find issues"),
    ])
}
