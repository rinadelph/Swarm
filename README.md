<h1 align="center">
  <br>
  <img src="https://raw.githubusercontent.com/swarm-org/swarm/main/assets/logo.png" alt="logo" width="200">
  <br>
  Swarm
  <br>
  <br>
</h1>

<p align="center">
  <a href="https://discord.gg/CrUAFH3"><img alt="Discord Chat" src="https://img.shields.io/discord/771367133715628073?color=5865F2&label=discord&style=flat-square"></a>
  <a href="https://matrix.to/#/#swarm_general:matrix.org"><img alt="Matrix Chat" src="https://img.shields.io/matrix/swarm_general:matrix.org?color=1d7e64&label=matrix%20chat&style=flat-square&logo=matrix"></a>
  <a href="https://swarm.dev/documentation/"><img alt="Swarm documentation" src="https://img.shields.io/badge/swarm-documentation-fc0060?style=flat-square"></a>
</p>

<p align="center">
  <img src="https://raw.githubusercontent.com/swarm-org/swarm/main/assets/demo.gif" alt="demo">
</p>

<h4 align="center">
  [<a href="https://swarm.dev/documentation/installation">Installation</a>]
  [<a href="https://swarm.dev/screencasts/">Screencasts & Tutorials</a>]
  [<a href="https://swarm.dev/documentation/configuration">Configuration</a>]
  [<a href="https://swarm.dev/documentation/layouts">Layouts</a>]
  [<a href="https://swarm.dev/documentation/faq">FAQ</a>]
</h4>

# What is this?

[Swarm](#origin-of-the-name) is a terminal workspace designed for vibecoders who thrive in command-line environments. Built on the robust foundation of Zellij, Swarm transforms your terminal into a powerful development ecosystem with modern tooling and collaborative features.

## 🚀 Version 0.0.10 Released!

### What's New:
- **MCP Manager Plugin**: A powerful plugin for managing Model Context Protocol servers
  - Dynamic argument configuration for each MCP type
  - Template-based setup (Agent MCP, FileSystem, Git, Python, Node.js)
  - Smart command building with proper flag handling
  - Directory browser for path arguments (Ctrl+D)
  - Background tmux session management
  - Python virtual environment support
- **Architecture Documentation**: Comprehensive guides for understanding and extending Swarm
- **Plugin Development Guide**: Learn how to create your own Swarm plugins

### Coming Soon:
- **Full MCP Integration**: Native support for Claude and other AI assistants
- **Agent Orchestration**: Manage multiple AI agents working in parallel
- **Enhanced Collaboration**: Real-time code sharing and pair programming features

Swarm is crafted for developers who demand both simplicity and sophistication - delivering an exceptional out-of-the-box experience while providing advanced customization for power users. Whether you're coding solo or collaborating with a team, Swarm adapts to your workflow.

Swarm features include deep customizability through layouts, true multiplayer collaboration, innovative UX elements like floating and stacked panes, and an extensible plugin system supporting any language that compiles to WebAssembly. From beginners taking their first steps in terminal-based development to seasoned vibecoders orchestrating complex workflows, Swarm empowers every type of developer.

You can get started by installing Swarm using our easy installation script.

For more details about our future plans, read about upcoming features in our [roadmap](#roadmap).

## How do I install it?

The easiest way to install Swarm is using our installation script:

```bash
# Quick install
bash install-swarm.sh
```

Or install with `cargo`:

```bash
cargo install --locked swarm
```

After installation, you can use either command:
- `swarm` - Full command
- `sm` - Short alias

#### Installing from `main`
Installing Swarm from the `main` branch is not recommended. This branch represents pre-release code and may contain unstable features.

## How do I start a development environment?

* Clone the project
* In the project folder, for debug builds run: `cargo xtask run`
* To run all tests: `cargo xtask test`

For more build commands, see [CONTRIBUTING.md](CONTRIBUTING.md).

## Configuration
For configuring Swarm, edit your `~/.config/swarm/config.kdl` file. See the example configuration in the `example/` directory.

## About issues in this repository
Issues in this repository, whether open or closed, do not necessarily indicate a problem or a bug in the software. They only indicate that the reporter wanted to communicate their experiences or thoughts to the maintainers. The Swarm maintainers do their best to go over and reply to all issue reports, but unfortunately cannot promise these will always be dealt with or even read. Your understanding is appreciated.

## Roadmap
Presented here is the project roadmap, divided into three main sections.

These are issues that are either being actively worked on or are planned for the near future.

***If you'll click on the image, you'll be led to an SVG version of it on the website where you can directly click on every issue***

[![roadmap](https://github.com/swarm-org/swarm/assets/795598/9c5b573b-20f5-41c6-908b-6b21c5fd456e)](https://swarm.dev/roadmap)

## Origin of the Name

Swarm represents the collaborative nature of terminal workspaces - like a swarm of efficient processes working together in harmony. Multiple panes, tabs, and plugins coordinate seamlessly to create a powerful development environment where the whole becomes greater than the sum of its parts.

Built on the proven architecture of Zellij, Swarm inherits robust terminal multiplexing capabilities while adding modern enhancements and vibecoder-focused features that make terminal-based development more intuitive and productive.

## License

MIT

## Sponsored by
<a href="https://terminaltrove.com/"><img src="https://avatars.githubusercontent.com/u/121595180?s=200&v=4" width="80px"></a>
