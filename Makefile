# Swarm Development Makefile

.PHONY: install dev test clean

# Full install with all plugins (use this!)
install:
	@./install

# Development build (fast, debug mode)  
dev:
	@echo "⚡ Fast dev build..."
	@cargo build --bin swarm && pkill -f swarm 2>/dev/null || true && cp ./target/debug/swarm ~/.local/bin/swarm && echo "✅ Updated!"

# Test banner rendering
test:
	@cargo run --bin test_banner

# Clean build artifacts
clean:
	@cargo clean && echo "🧹 Cleaned"