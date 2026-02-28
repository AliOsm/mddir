# Agent Integration

mddir is designed to work as a knowledge retrieval tool for AI agents. All content lives under `~/.mddir/` as plain markdown files with YAML frontmatter.

## Frontmatter Format

Every saved entry includes structured metadata:

```yaml
---
url: https://example.com/article
title: Article Title
description: A description of the article.
slug: article-title-a1b2c3
saved_at: "2026-02-27T10:30:00Z"
conversion: cloudflare
token_count: 1523
token_estimated: false
---
```

### Fields

| Field | Description |
|---|---|
| `url` | The original source URL |
| `title` | Page title extracted from the source |
| `description` | From `<meta name="description">` or Cloudflare frontmatter |
| `slug` | Unique identifier, used as part of the filename |
| `saved_at` | UTC ISO 8601 timestamp when the entry was saved |
| `conversion` | `cloudflare` or `local` — which conversion path was used |
| `token_count` | Token count for the content |
| `token_estimated` | `false` if from Cloudflare's `x-markdown-tokens` header (accurate), `true` if computed locally (approximate) |

## Searching from Agents

Agents can search the knowledge base using the CLI:

```bash
# Search all collections
mddir search "concurrency patterns"

# Search within a specific collection
mddir search ruby "freeze"
```

Output is structured for parsing:

```
Found 4 matches in 2 files

[ruby] Understanding Ruby Fibers
  understanding-ruby-fibers-a1b2c3.md
  https://example.com/fibers
  Line 12: Ruby fibers are primitives for implementing light weight cooperative...
  Line 45: ...you can pause a fiber and resume it later, making them ideal for...
```

## Token Counts

mddir tracks token counts for each entry to help agents estimate context usage:

- **Cloudflare entries** — Token count comes from the `x-markdown-tokens` HTTP header. These are accurate (`token_estimated: false`).
- **Local entries** — Token count is estimated as `character_count / 4`. These are approximate (`token_estimated: true`).

## Example Agent Workflow

1. **Save relevant pages** to a collection:
   ```bash
   mddir add research https://example.com/paper1 https://example.com/paper2
   ```

2. **Search for specific information**:
   ```bash
   mddir search research "attention mechanism"
   ```

3. **Read a specific entry** by its file path:
   ```bash
   cat ~/.mddir/research/attention-is-all-you-need-7f8e9d.md
   ```

4. **List available entries** to understand what's saved:
   ```bash
   mddir ls research
   ```

All entries are self-contained `.md` files, so agents can also read them directly from the filesystem without using the CLI.
