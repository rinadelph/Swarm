use std::env;

fn main() {
    println!("Banner Rendering Test\n");
    
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
        test_banner_rendering(cols, rows);
        println!();
    }
    
    // Test with clean banner
    println!("=== Testing Clean Banner ===");
    test_clean_banner();
}

fn test_banner_rendering(cols: u16, rows: u16) {
    // New sleek minimal banner
    let banner_lines = vec![
        "┌─┐  ┬ ┬  ┌─┐  ┬─┐  ┌┬┐",
        "└─┐  ││││  ├─┤  ├┬┘  ││││",
        "└─┘  └┴┘  ┴ ┴  ┴└─  ┴ ┴",
    ];

    let medium_banner_lines = vec![
        "╔═╗ ╦ ╦ ╔═╗ ╦═╗ ╔╦╗",
        "╚═╗ ║║║ ╠═╣ ╠╦╝ ║║║",
        "╚═╝ ╚╩╝ ╩ ╩ ╩╚═ ╩ ╩",
    ];

    let small_banner_lines = vec!["[ S W A R M ]"];
    
    let (lines_to_use, start_row) = if cols >= 40 && rows >= 10 {
        (&banner_lines, 2)
    } else if cols >= 25 && rows >= 8 {
        (&medium_banner_lines, 3)
    } else {
        (&small_banner_lines, 4)
    };
    
    let max_width = lines_to_use.iter().map(|line| line.len()).max().unwrap_or(0);
    
    println!("Selected banner: {} lines, max width: {}", lines_to_use.len(), max_width);
    
    // Check each character in the first line to see what's causing issues
    if !lines_to_use.is_empty() {
        let first_line = lines_to_use[0];
        println!("First line analysis:");
        for (i, ch) in first_line.chars().enumerate() {
            let char_width = unicode_width::UnicodeWidthChar::width(ch).unwrap_or(0);
            if char_width != 1 {
                println!("  Char {} at pos {}: '{}' (width: {})", i, i, ch, char_width);
            }
        }
    }
    
    if max_width <= cols as usize {
        println!("✓ Banner fits");
        for (i, line) in lines_to_use.iter().enumerate() {
            let col = (cols as usize).saturating_sub(line.len()) / 2;
            println!("  Row {}: pos {} + '{}'", start_row + i, col, line);
        }
    } else {
        println!("✗ Banner too wide, using fallback");
    }
}

fn test_clean_banner() {
    // Create a simple ASCII banner that won't have Unicode issues
    let clean_banner = vec![
        "  SSS   W   W   AAA   RRR   M   M",
        " S   S  W   W  A   A  R  R  MM MM",
        "  SSS   W W W  AAAAA  RRR   M M M",
        "     S  WW WW  A   A  R R   M   M",
        "  SSS   W   W  A   A  R  R  M   M",
    ];
    
    println!("Clean banner analysis:");
    for (i, line) in clean_banner.iter().enumerate() {
        println!("Line {}: '{}' (length: {})", i, line, line.len());
        // Check for any non-ASCII characters
        for ch in line.chars() {
            if !ch.is_ascii() {
                println!("  Non-ASCII char found: '{}'", ch);
            }
        }
    }
    
    let max_width = clean_banner.iter().map(|line| line.len()).max().unwrap_or(0);
    println!("Max width: {}", max_width);
}