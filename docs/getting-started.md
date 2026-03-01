# Getting Started

## Installation

### Homebrew (macOS)

The easiest way to install mddir on macOS:

```bash
brew install AliOsm/tap/mddir
```

This taps the repository and installs the latest version. To upgrade later:

```bash
brew upgrade mddir
```

### Standalone Binary (macOS & Linux)

Download the latest binary for your platform from the [GitHub releases page](https://github.com/AliOsm/mddir/releases). Available binaries:

- **macOS arm64** (Apple Silicon)
- **Linux arm64**
- **Linux amd64**

#### macOS

```bash
# Remove the quarantine flag set by macOS
xattr -d com.apple.quarantine mddir

# Make it executable
chmod +x mddir

# Move it to your PATH
sudo mv mddir /usr/local/bin/
```

#### Linux

```bash
# Make it executable
chmod +x mddir

# Move it to your PATH
sudo mv mddir /usr/local/bin/
```

### RubyGems

If you prefer installing via RubyGems, mddir requires **Ruby >= 3.2.0**.

If you don't have Ruby installed, [mise](https://mise.jdx.dev) is the easiest way to get it:

```bash
mise use --global ruby@3
```

Then install the gem:

```bash
gem install mddir
```

## Quick Start

Save a web page to a collection:

```bash
mddir add ruby https://docs.ruby-lang.org/en/3.3/String.html
```

List your collections:

```bash
mddir ls
```

Search across everything:

```bash
mddir search "freeze"
```

Open the built-in web UI:

```bash
mddir open
```

## Next Steps

- [CLI Reference](/cli-reference) — Full command reference
- [Web UI](/web-ui) — Browse and read saved pages
- [Agent Integration](/agent-integration) — Use mddir with AI agents
- [Configuration](/configuration) — Customize settings
