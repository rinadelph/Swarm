use std::io::{self, Write};

pub fn test_banner_rendering() {
    println!("Testing banner rendering at different terminal sizes:\n");
    
    // Test different terminal sizes
    let test_sizes = vec![
        (80, 24, "Standard terminal"),
        (120, 30, "Wide terminal"),
        (50, 20, "Medium terminal"),
        (30, 15, "Narrow terminal"),
        (20, 10, "Very narrow terminal"),
    ];
    
    for (cols, rows, description) in test_sizes {
        println!("=== {} ({}x{}) ===", description, cols, rows);
        render_test_banner(cols, rows);
        println!();
    }
}

fn render_test_banner(cols: u16, rows: u16) {
    let banner_lines = vec![
        "███████╗██╗    ██╗ █████╗ ██████╗ ███╗   ███╗",
        "██╔════╝██║    ██║██╔══██╗██╔══██╗████╗ ████║",
        "███████╗██║ █╗ ██║███████║██████╔╝██╔████╔██║",
        "╚════██║██║███╗██║██╔══██║██╔══██╗██║╚██╔╝██║",
        "███████║╚███╔███╔╝██║  ██║██║  ██║██║ ╚═╝ ██║",
        "╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝",
    ];

    let medium_banner_lines = vec![
        "███ █   █ █▀▀█ █▀▀█ █▀▄▀█",
        "▀▀█ █▄█▄█ █▄▄█ █▄▄▀ █ ▀ █",
        "▀▀▀ ▀ ▀ ▀ ▀  ▀ ▀ ▀▀ ▀   ▀",
    ];

    let small_banner_lines = vec!["S W A R M"];
    
    let (lines_to_use, start_row) = if cols >= 50 && rows >= 12 {
        (&banner_lines, 2)
    } else if cols >= 30 && rows >= 8 {
        (&medium_banner_lines, 3)
    } else {
        (&small_banner_lines, 4)
    };
    
    // Calculate the maximum line width for proper centering
    let max_width = lines_to_use.iter().map(|line| line.len()).max().unwrap_or(0);
    
    println!("Selected banner: {} lines, max width: {}", lines_to_use.len(), max_width);
    
    // Show what would be rendered
    if max_width <= cols as usize {
        println!("✓ Banner fits, rendering:");
        for (i, line) in lines_to_use.iter().enumerate() {
            let col = (cols as usize).saturating_sub(line.len()) / 2;
            println!("  Row {}: {} spaces + '{}'", start_row + i, col, line);
        }
    } else {
        println!("✗ Banner too wide, using fallback: 'SWARM'");
        let fallback = "SWARM";
        let col = (cols as usize).saturating_sub(fallback.len()) / 2;
        println!("  Row {}: {} spaces + '{}'", start_row, col, fallback);
    }
    
    // Show subtitle
    let subtitle = "Terminal Workspace for Developers";
    let subtitle_row = start_row + lines_to_use.len() + 1;
    
    if subtitle.len() <= cols as usize {
        let subtitle_col = (cols as usize).saturating_sub(subtitle.len()) / 2;
        println!("  Subtitle row {}: {} spaces + '{}'", subtitle_row, subtitle_col, subtitle);
    } else {
        println!("  Subtitle: too wide, not shown");
    }
}

pub fn create_clean_banner() -> Vec<&'static str> {
    // Create a cleaner banner without problematic Unicode
    vec![
        " ███████  ██     ██  █████  ████████  ██████  ██",
        " ██       ██     ██ ██   ██ ██    ██ ██    ██ ██",
        " ███████  ██  █  ██ ███████ ████████ ██    ██ ██",
        "      ██  ██ ███ ██ ██   ██ ██   ██  ██    ██ ██",
        " ███████   ███ ███  ██   ██ ██    ██  ██████  ██",
    ]
}

pub fn test_clean_banner() {
    println!("Testing clean banner:");
    let clean_banner = create_clean_banner();
    
    for line in &clean_banner {
        println!("'{}' (length: {})", line, line.len());
    }
    
    let max_width = clean_banner.iter().map(|line| line.len()).max().unwrap_or(0);
    println!("Max width: {}", max_width);
}