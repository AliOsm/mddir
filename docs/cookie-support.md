# Cookie Support

## When You Need Cookies

Some web pages require authentication to access — paywalled articles, private documentation, internal wikis. mddir supports passing a cookies file to fetch these pages.

## Usage

```bash
mddir add docs https://private.example.com/page --cookies ~/cookies.txt
```

The `--cookies` flag accepts a path to a Netscape cookies.txt file. Cookies are sent with every HTTP request made during that `add` command.

## Supported Format

mddir uses the **Netscape cookies.txt** format (tab-separated), which is the standard format used by browsers and tools like `curl`.

Each line contains:

```
domain	flag	path	secure	expiry	name	value
```

Example:

```
.example.com	TRUE	/	TRUE	0	session_id	abc123
.example.com	TRUE	/	FALSE	1735689600	auth_token	xyz789
```

## Exporting Cookies from Browsers

To get a cookies.txt file from your browser:

1. Install a cookies export extension (e.g., "Get cookies.txt LOCALLY" for Chrome/Firefox)
2. Navigate to the site you want to save pages from
3. Export the cookies for that domain
4. Save the file (e.g., `~/cookies.txt`)

Then use it with mddir:

```bash
mddir add docs https://private.example.com/article --cookies ~/cookies.txt
```
