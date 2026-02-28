# Data Storage

## Directory Layout

All data lives under `~/.mddir/` by default (configurable via `base_dir`):

```
~/.mddir/
├── search.db                              # SQLite full-text search database
├── index.yml                              # Global summary index
├── ruby/
│   ├── index.yml                          # Per-collection manifest
│   ├── string-a1b2c3.md
│   └── array-d4e5f6.md
└── golang/
    ├── index.yml
    └── concurrency-patterns-f7a8b9.md
```

## Collections

Each collection is a folder containing an `index.yml` manifest and `.md` entry files. Collections are created automatically when you first `add` a URL to them, or explicitly with `mddir collection create`.

## Entry Files

Each entry is a self-contained `.md` file with YAML frontmatter:

```markdown
---
url: https://example.com/article
title: "Understanding Ruby Fibers"
description: "A deep dive into Ruby's fiber concurrency primitive."
slug: understanding-ruby-fibers-a1b2c3
saved_at: "2026-02-27T10:30:00Z"
conversion: local
token_count: 1830
token_estimated: true
---

# Understanding Ruby Fibers

Article content in markdown...
```

Files carry their own provenance metadata, so they remain useful even if copied out of mddir or opened in another tool.

## Collection Index

Each collection has an `index.yml` file that tracks metadata for all entries:

```yaml
- url: https://example.com/fibers
  title: Understanding Ruby Fibers
  description: "A deep dive into Ruby's fiber concurrency primitive."
  filename: understanding-ruby-fibers-a1b2c3.md
  slug: understanding-ruby-fibers-a1b2c3
  saved_at: "2026-02-27T10:30:00Z"
  conversion: cloudflare
  token_count: 2140
  token_estimated: false
```

This lets the CLI and web UI display entry details without reading every markdown file.

## Global Index

The global `~/.mddir/index.yml` is a lightweight summary of all collections:

```yaml
collections:
  ruby:
    entry_count: 3
    last_added: "2026-02-27T10:32:00Z"
  ai-research:
    entry_count: 2
    last_added: "2026-02-26T15:00:00Z"
total_entries: 5
last_updated: "2026-02-27T10:32:00Z"
```

It enables fast listing without scanning every collection directory. It's rebuilt automatically on every mutation and can be regenerated with `mddir reindex`.

## Filename Convention

Entry filenames follow the pattern:

```
<slugified-title>-<6-char-sha256-of-url>.md
```

For example, a page titled "Understanding Ruby Fibers" from `https://example.com/fibers` becomes:

```
understanding-ruby-fibers-a1b2c3.md
```

The 6-character hash suffix (derived from the SHA256 of the URL) ensures uniqueness while keeping filenames readable.
