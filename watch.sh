#!/bin/bash

# Simple file watcher for Swarm development
# Watches for changes and automatically rebuilds and installs

echo "👀 Watching for changes in src/... (Ctrl+C to stop)"
echo "Will auto-rebuild and install on file changes"

# Use inotifywait if available, otherwise fall back to basic polling
if command -v inotifywait &> /dev/null; then
    echo "Using inotifywait for efficient watching..."
    while true; do
        inotifywait -r -e modify,create,delete src/ 2>/dev/null
        echo "🔄 Changes detected, rebuilding..."
        make quick
        echo "⏰ $(date): Ready for testing"
    done
else
    echo "Using basic polling (install inotify-tools for better performance)..."
    LAST_CHANGE=0
    while true; do
        CURRENT=$(find src/ -name "*.rs" -type f -exec stat -c %Y {} \; | sort -nr | head -1)
        if [ "$CURRENT" != "$LAST_CHANGE" ]; then
            echo "🔄 Changes detected, rebuilding..."
            make quick
            echo "⏰ $(date): Ready for testing"
            LAST_CHANGE=$CURRENT
        fi
        sleep 2
    done
fi