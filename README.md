# cebula

`cebula` is a small web crawler written in C3. It walks a site starting from a seed URL, respects `robots.txt`, extracts page metadata, links, images and downloadable resources, and emits a single JSON document.

## Features

- Breadth-first crawl with URL normalization, fragment stripping and duplicate detection.
- Depth and page limits (`--max-depth`, `--max-pages`).
- Same-site restriction by default (`--no-same-domain` to disable).
- `robots.txt` support: `Allow`/`Disallow` (longest prefix wins), `Crawl-delay`, `Sitemap`.
- HTML extraction: `<title>`, meta description, canonical URL, `<html lang>`, headings, links (with anchor text), images (with alt text) and resources (`pdf`, `docx`, `xlsx`, `pptx`, `txt`).
- Per-host request spacing (`--delay-ms`, plus `Crawl-delay` from `robots.txt`).
- HTTP errors, timeouts and robots denials are reported in `errors[]`; process exit code is non-zero when no page could be fetched.
- JSON written to stdout or to `--output <file>`; diagnostics always go to stderr.
- No shell interpolation: `curl` is executed with an argument vector, so URLs cannot inject commands.

## Requirements

- C3 compiler (`c3c`) 0.8.x.
- `curl` available on `PATH` (used as the HTTP transport).
- No external C3 library dependencies are required.

## Build

```bash
c3c build
c3c test
```

## Usage

```bash
cebula help
cebula version
cebula crawl https://example.com
cebula crawl https://example.com --max-depth 2 --max-pages 50
cebula crawl https://example.com --no-same-domain --delay-ms 500
cebula crawl https://example.com --output result.json
```

### Options for `crawl`

| Option | Default | Meaning |
| --- | --- | --- |
| `--max-depth <n>` | `3` | Maximum link depth from the seed page. |
| `--max-pages <n>` | `100` | Maximum number of pages fetched (successful + failed). |
| `--no-same-domain` | off | Follow links to other hosts too. |
| `--same-domain` | on | Restore the default restriction. |
| `--no-robots` | off | Ignore `robots.txt` (use responsibly). |
| `--timeout <sec>` | `10` | Per-request timeout. |
| `--delay-ms <n>` | `0` | Minimum delay between requests to the same host. |
| `--user-agent <ua>` | `cebula/0.1 (+web crawler)` | User-Agent header. |
| `--max-body-kb <n>` | `5120` | Maximum response body size. |
| `--output <file>` | stdout | Where to write the JSON result. |

Invalid flags and non-integer values fail with exit code `2` and a message on stderr.

## JSON output

```json
{
  "crawler": { "name": "cebula", "version": "0.1.0" },
  "task": {
    "seed": "https://example.com/",
    "status": "completed | completed_with_errors | failed",
    "started_at": "2026-01-02T10:11:12Z",
    "finished_at": "2026-01-02T10:11:13Z"
  },
  "statistics": {
    "pages_discovered": 12,
    "pages_crawled": 10,
    "pages_failed": 2,
    "resources_discovered": 1
  },
  "pages": [
    {
      "url": "https://example.com/",
      "status_code": 200,
      "content_type": "text/html; charset=utf-8",
      "depth": 0,
      "discovered_from": null,
      "title": "Example Domain",
      "description": null,
      "canonical_url": null,
      "language": "en",
      "headings": [{ "level": 1, "text": "Welcome" }],
      "links": [{ "href": "/next", "anchor_text": "Next", "absolute_url": "https://example.com/next", "is_internal": true }],
      "images": [{ "src": "/logo.png", "alt": "Logo", "absolute_url": "https://example.com/logo.png" }]
    }
  ],
  "resources": [{ "url": "https://example.com/doc.pdf", "kind": "pdf" }],
  "errors": [{ "url": "https://example.com/missing", "kind": "http_status", "message": "HTTP status" }]
}
```

`errors[].kind` is one of `invalid_url`, `dns`, `connect`, `timeout`, `tls`, `redirect`, `too_large`, `http_status`, `robots`, `fetch` or `parse`.

## Tests

Unit tests cover URL normalization/resolution, HTML extraction, robots parsing and JSON escaping:

```bash
c3c test
```

An end-to-end test against a local fixture site (multi-page crawl, robots block, 404, JSON output file) is available:

```bash
bash test/integration.sh
```

It needs `python3` and `curl` and uses a free local port, so it does not touch the public internet.

## Current limitations

- Fetching is sequential; politeness is per host but there is no parallel worker pool yet.
- HTML parsing is pragmatic, not a full HTML5 parser. Malformed markup may be skipped.
- JavaScript-rendered content is not executed.
- Resources are discovered and reported, but not downloaded.

## License

Apache-2.0. See `LICENSE`.
