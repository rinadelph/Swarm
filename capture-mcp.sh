#!/bin/bash
# Capture MCP communication

# Monitor for new connections
watch -n 1 'netstat -anp 2>/dev/null | grep -E "(claude|node)" | grep ESTABLISHED'
