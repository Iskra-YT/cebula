# CEBULA

CEBULA is a lightweight web crawler written in C3.

## Features (initial)

- CLI commands: `crawl`, `help`, `version`
- Fetches pages over HTTP/HTTPS (via system `curl` in current implementation; see Limitations)
- Outputs crawl results as JSON to stdout
- Configurable max depth, max pages, timeout, output file

## Build

This project uses the C3 compiler (`c3c`) and a `project.json` manifest.

```bash
# Example (if c3c and dependencies are set up):
c3c build
```

Notes:
- Dependencies are managed via `project.json` (`dessert`, `c3web`) and `lib/` contents in this repo.
- The provided `setup.sh`/`bee` files may be placeholders depending on your environment.

## Usage

```bash
cebula help
cebula version
cebula crawl https://example.com
cebula crawl https://example.com --max-depth 2 --max-pages 50 --timeout 10
cebula crawl https://example.com --output out.json
```

## JSON output

The `crawl` command prints a single JSON document to stdout (diagnostics go to stderr). See the task specification for the schema.

## Limitations

- HTML parsing and robots.txt handling are minimal in this initial implementation.
- HTTP fetching currently uses an external `curl` process as a pragmatic fallback in some environments; a native HTTP client integration is planned.
- This is an early scaffold; some edge cases are not fully handled.

## License

Apache-2.0. See `LICENSE`.
