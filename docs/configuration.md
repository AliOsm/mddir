# Configuration

## Config File

Settings live in `~/.mddir.yml`. Run `mddir config` to open it in your editor.

If the file doesn't exist, it's created with default values when you first run `mddir config`.

## Options

| Option | Default | Description |
|---|---|---|
| `base_dir` | `~/.mddir` | Where collections are stored |
| `port` | `7768` | Web UI server port |
| `editor` | `$EDITOR` or `vi` | Editor used by `mddir config` |
| `user_agent` | Chrome UA string | User-Agent header sent with all HTTP requests |

## Example Config

```yaml
base_dir: ~/.mddir
port: 7768
editor: vim
user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
```

## Environment Variables

| Variable | Used by |
|---|---|
| `$EDITOR` | Fallback editor for `mddir config` (if not set in config file) |

## Notes

- The `user_agent` defaults to a standard Chrome browser string. Many sites block generic bot User-Agents or serve degraded content, so a real browser UA avoids unnecessary friction.
- If `$EDITOR` is not set and no editor is configured, mddir falls back to `vi`.
