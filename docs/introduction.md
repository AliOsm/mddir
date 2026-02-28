# Introduction

## What is mddir?

mddir is a Ruby gem that fetches web pages, converts them to clean markdown, and organizes them into local collections. It includes full-text search, a built-in web UI, and works with AI agents out of the box. Everything is stored as plain markdown files you own.

## Why mddir?

Saving links is fragile — pages disappear, URLs rot, and bookmarks pile up unread. mddir fetches the actual content, converts it to clean markdown, and stores it locally where it's searchable, grep-friendly, and git-friendly.

## Key Features

- **Cloudflare-first conversion** — Uses Cloudflare's Markdown for Agents when available for high-quality output
- **Local fallback** — Falls back to readability extraction + markdown conversion for universal compatibility
- **Full-text search** — SQLite-powered search across all your saved pages
- **Built-in web UI** — Browse, read, and search from a clean local web interface
- **Agent-friendly** — Structured output with token counts, designed for LLM integration
- **Plain files** — Everything stored as `.md` files with YAML frontmatter under `~/.mddir/`

## How It Works

mddir uses a two-step conversion strategy:

1. **Content negotiation** — Every fetch request includes `Accept: text/markdown, text/html`. Sites behind Cloudflare with Markdown for Agents enabled return clean, server-converted markdown directly.

2. **Local fallback** — If the server returns HTML, mddir extracts the main article content using `ruby-readability` (Mozilla's Readability algorithm), strips away navigation, sidebars, and ads, then converts the clean HTML to markdown with `reverse_markdown`.

The `conversion` field in each entry tracks which path was used, so you always know the quality of the output.

## Screenshots

### Home

![Home](/screenshots/home.png)

### Reader

![Reader](/screenshots/reader.png)
