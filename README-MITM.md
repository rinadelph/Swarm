# Claude Code MITM Proxy Setup

This setup allows you to intercept and analyze Claude Code's API requests, specifically for reverse engineering the `/ide` command.

## Quick Start

1. Run the test environment in tmux:
   ```bash
   ./run-test-tmux.sh
   ```

2. In the tmux session, navigate to window 3 (claude-test) and run:
   ```bash
   ./launch-claude-proxy.sh /ide
   ```

## Components

- **setup-mitm.sh**: Installs mitmproxy and sets up certificates
- **launch-claude-proxy.sh**: Launches Claude Code with proxy settings (port 9234)
- **analyze_requests.py**: MITM script that captures and logs API requests
- **run-test-tmux.sh**: Creates a tmux session with multiple monitoring windows

## Tmux Windows

- Window 0: Setup
- Window 1: Proxy logs
- Window 2: API request monitor
- Window 3: Claude test commands
- Window 4: Analysis

## Captured Data

- API requests/responses: `mitm-claude/logs/api_requests/`
- Full traffic captures: `mitm-claude/captures/`
- Proxy logs: `mitm-claude/logs/mitmproxy.log`

## Certificate Setup

If you get SSL errors, install the MITM certificate:
```bash
sudo cp ~/.mitmproxy/mitmproxy-ca-cert.pem /usr/local/share/ca-certificates/mitmproxy-ca-cert.crt
sudo update-ca-certificates
```

## Web Interface

Access the mitmproxy web interface at: http://localhost:8081