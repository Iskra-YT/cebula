#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
C3C="${C3C:-}"
if [[ -z "$C3C" ]]; then
    if command -v c3c >/dev/null 2>&1; then C3C=c3c
    elif [[ -x "$HOME/.c3/c3c" ]]; then C3C="$HOME/.c3/c3c"
    else echo "c3c not found (set C3C=/path/to/c3c)" >&2; exit 1; fi
fi

TMP="$(mktemp -d)"
SITE="$TMP/site"
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
SERVER_PID=""
cleanup() {
    if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null || true; fi
    rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$SITE/docs" "$SITE/private"
cat > "$SITE/index.html" <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Root &amp; Title</title>
<meta name="description" content="Root page description">
<link rel="canonical" href="/index.html"></head>
<body><h1>Welcome</h1><h2>Subtitle</h2>
<a href="page2.html">Page two</a>
<a href="/docs/guide.pdf">Guide</a>
<a href="/private/secret.html">Secret</a>
<a href="javascript:alert(1)">JS</a>
<a href="#local">Fragment</a>
<img src="/logo.png" alt="Logo"></body></html>
HTML
cat > "$SITE/page2.html" <<'HTML'
<html><head><title>Second page</title></head><body><h1>Second</h1>
<a href="/index.html">Back</a><a href="missing.html">Missing</a></body></html>
HTML
printf 'User-agent: *\nDisallow: /private/\nCrawl-delay: 0\n' > "$SITE/robots.txt"
printf 'secret' > "$SITE/private/secret.html"
printf 'pdf' > "$SITE/docs/guide.pdf"

cd "$ROOT"
"$C3C" build >/dev/null

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$SITE" >"$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
    if curl -fsS "http://127.0.0.1:$PORT/index.html" -o /dev/null 2>/dev/null; then break; fi
    sleep 0.1
done

RESULT="$TMP/result.json"
"$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html" \
    --max-pages 10 --max-depth 2 --output "$RESULT" >/dev/null 2>"$TMP/crawl.err"

python3 - "$RESULT" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)

assert d["crawler"]["name"] == "cebula", d["crawler"]
assert d["task"]["status"] == "completed_with_errors", d["task"]
assert d["task"]["started_at"] and d["task"]["finished_at"], d["task"]
assert d["statistics"]["pages_crawled"] == 2, d["statistics"]
assert d["statistics"]["pages_failed"] == 1, d["statistics"]

pages = {p["url"]: p for p in d["pages"]}
seed = next(p for p in d["pages"] if p["url"].endswith("/index.html"))
assert seed["title"] == "Root & Title", seed
assert seed["description"] == "Root page description", seed
assert seed["language"] == "en", seed
assert [h["text"] for h in seed["headings"]] == ["Welcome", "Subtitle"], seed
assert len(seed["links"]) == 3, seed["links"]
assert len(seed["images"]) == 1 and seed["images"][0]["alt"] == "Logo", seed
assert any(p["url"].endswith("/page2.html") for p in d["pages"]), pages
assert not any(p["url"].endswith(".pdf") for p in d["pages"]), "PDF was fetched as a page"

kinds = {e["kind"] for e in d["errors"]}
assert "robots" in kinds, d["errors"]
assert "http_status" in kinds, d["errors"]
assert d["resources"][0]["kind"] == "pdf", d["resources"]
print("integration: OK")
PY

# Negative cases: validation, no shell injection, no phantom output file.
if "$ROOT/build/cebula" crawl "not a url" >/dev/null 2>&1; then
    echo "invalid URL was accepted" >&2; exit 1
fi
if "$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html" --max-depth abc >/dev/null 2>&1; then
    echo "invalid --max-depth was accepted" >&2; exit 1
fi
MARKER="$TMP/pwned"
"$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html\"; touch $MARKER; echo \"" --max-pages 1 >/dev/null 2>&1 || true
if [[ -e "$MARKER" ]]; then
    echo "command injection succeeded" >&2; exit 1
fi
