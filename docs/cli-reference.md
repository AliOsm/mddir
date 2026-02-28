# CLI Reference

## Overview

```bash
mddir <command> [args] [flags]
```

## Core Commands

### `mddir add COLLECTION URL [URL...]`

Fetch web pages and save them to a collection. If the collection doesn't exist, it's created automatically.

```bash
# Save a single page
mddir add ruby https://docs.ruby-lang.org/en/3.3/String.html

# Save multiple pages at once
mddir add ruby https://example.com/fibers https://example.com/procs

# With cookie authentication
mddir add docs https://private.example.com/page --cookies ~/cookies.txt
```

For each URL, mddir:
1. Sends an HTTP GET with `Accept: text/markdown, text/html`
2. If the server returns markdown (Cloudflare), uses it directly
3. Otherwise, extracts article content with readability and converts to markdown
4. Saves the `.md` file with YAML frontmatter to the collection

Duplicate URLs within a collection are detected and skipped.

Output indicates which conversion path was used:

```
Saved: understanding-ruby-fibers-a1b2c3.md → ruby (cloudflare)
Saved: ruby-procs-and-lambdas-f7e8d9.md → ruby (local)
```

### `mddir search [COLLECTION] QUERY`

Search entries for a query string. Searches markdown content only (frontmatter is skipped).

```bash
# Search all collections
mddir search "concurrency patterns"

# Search within a specific collection
mddir search ruby "freeze"
```

Output is structured for both human and agent consumption:

```
Found 4 matches in 2 files

[ruby] Understanding Ruby Fibers
  understanding-ruby-fibers-a1b2c3.md
  https://example.com/fibers
  Line 12: Ruby fibers are primitives for implementing light weight cooperative...
  Line 45: ...you can pause a fiber and resume it later, making them ideal for...
```

### `mddir ls [COLLECTION]`

List collections or entries within a collection.

```bash
# List all collections
mddir ls
```

```
ruby            3 entries
ai-research     2 entries
devops          1 entry
```

```bash
# List entries in a collection
mddir ls ruby
```

```
ruby (3 entries)

  1. Understanding Ruby Fibers
     A deep dive into Ruby's fiber concurrency primitive.
     understanding-ruby-fibers-a1b2c3.md
     https://example.com/fibers

  2. Metaprogramming Patterns in Ruby
     How to use Ruby's metaprogramming features responsibly.
     metaprogramming-patterns-d4e5f6.md
     https://example.com/metaprogramming
```

### `mddir open`

Start the web UI server and open it in the default browser.

```bash
mddir open
```

Uses `open` (macOS), `xdg-open` (Linux), or `start` (Windows) to launch the browser.

### `mddir serve`

Start the web UI server without opening a browser.

```bash
mddir serve
```

```
mddir server running at http://localhost:7768
Press Ctrl+C to stop
```

## Management Commands

### `mddir rm COLLECTION [ENTRY]`

Remove a collection or a single entry.

```bash
# Remove an entire collection (with confirmation prompt)
mddir rm ruby

# Remove an entry by index number (from mddir ls output)
mddir rm ruby 2

# Remove an entry by filename
mddir rm ruby understanding-ruby-fibers-a1b2c3
```

Entries can be identified by their **index number** (1-based, from `mddir ls`) or by **filename** (with or without `.md`).

### `mddir collection create NAME`

Create a new empty collection.

```bash
mddir collection create ruby
```

Collection names are slugified: lowercased, non-alphanumeric characters replaced with hyphens, consecutive hyphens collapsed.

### `mddir reindex`

Rebuild the global index from per-collection indexes.

```bash
mddir reindex
```

```
Reindexed 3 collections, 6 entries
```

Useful if the global index drifts out of sync after manual file edits.

### `mddir config`

Open the configuration file (`~/.mddir.yml`) in your editor.

```bash
mddir config
```

## Flags

| Flag | Applies to | Description |
|---|---|---|
| `--cookies PATH` | `add` | Path to a Netscape cookies.txt file for authenticated fetching |
