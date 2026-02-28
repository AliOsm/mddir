# Getting Started

## Prerequisites

mddir requires **Ruby >= 3.2.0**.

## Installing Ruby

If you don't have Ruby installed, [mise](https://mise.jdx.dev) is the easiest way to get it:

```bash
mise use --global ruby@3
```

## Install mddir

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
