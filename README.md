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

[Swarm](#origin-of-the-name) is a workspace aimed at developers, ops-oriented people and anyone who loves the terminal. Similar programs are sometimes called "Terminal Multiplexers".

Swarm is designed around the philosophy that one must not sacrifice simplicity for power, taking pride in its great experience out of the box as well as the advanced features it places at its users' fingertips.

Swarm is geared toward beginner and power users alike - allowing deep customizability, personal automation through layouts, true multiplayer collaboration, unique UX features such as floating and stacked panes, and a plugin system allowing one to create plugins in any language that compiles to WebAssembly.

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

## License

MIT

## Sponsored by
<a href="https://terminaltrove.com/"><img src="https://avatars.githubusercontent.com/u/121595180?s=200&v=4" width="80px"></a>
