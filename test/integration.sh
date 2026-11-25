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
REDIRECT_PID=""
cleanup() {
    if [[ -n "$SERVER_PID" ]]; then kill "$SERVER_PID" 2>/dev/null || true; fi
    if [[ -n "$REDIRECT_PID" ]]; then kill "$REDIRECT_PID" 2>/dev/null || true; fi
    rm -rf "$TMP"
}
trap cleanup EXIT

mkdir -p "$SITE/docs" "$SITE/private" "$SITE/bot-blocked"
cat > "$SITE/index.html" <<'HTML'
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>Root &amp; Title</title>
<meta name="description" content="Root page description">
<link rel="canonical" href="/index.html"></head>
<body><h1>Welcome</h1><h2>Subtitle</h2>
<a href="page2.html">Page two</a>
<a href="/docs/guide.pdf">Guide</a>
<a href="/private/secret.html">Secret</a>
<a href="/bot-blocked/page.html">Bot blocked</a>
<a href="javascript:alert(1)">JS</a>
<a href="#local">Fragment</a>
<img src="/logo.png" alt="Logo"></body></html>
HTML
cat > "$SITE/page2.html" <<'HTML'
<html><head><title>Second page</title></head><body><h1>Second</h1>
<a href="/index.html">Back</a><a href="missing.html">Missing</a></body></html>
HTML
cat > "$SITE/robots.txt" <<'ROBOTS'
User-agent: CebulaBot
Disallow: /bot-blocked/

User-agent: *
Disallow: /private/
Crawl-delay: 0
ROBOTS
printf 'secret' > "$SITE/private/secret.html"
printf 'blocked' > "$SITE/bot-blocked/page.html"
printf 'pdf' > "$SITE/docs/guide.pdf"

cd "$ROOT"
"$C3C" build >/dev/null

# A tiny server that records the User-Agent of every request, so the test can
# verify the default header and a custom one end-to-end.
cat > "$TMP/server.py" <<'PY'
import functools, http.server, socketserver, sys

port, directory, log_path = int(sys.argv[1]), sys.argv[2], sys.argv[3]

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        with open(log_path, "a", encoding="utf-8") as f:
            f.write(self.path + "\t" + self.headers.get("User-Agent", "") + "\n")
        return super().do_GET()

    def log_message(self, *args):
        pass

socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", port), functools.partial(Handler, directory=directory)) as server:
    server.serve_forever()
PY
UA_LOG="$TMP/ua.log"
: > "$UA_LOG"
python3 "$TMP/server.py" "$PORT" "$SITE" "$UA_LOG" >"$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 50); do
    if curl -fsS -A 'CebulaBot/0.1' "http://127.0.0.1:$PORT/index.html" -o /dev/null 2>/dev/null; then break; fi
    sleep 0.1
done

RESULT="$TMP/result.json"
"$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html" \
    --max-pages 10 --max-depth 2 --output "$RESULT" >/dev/null 2>"$TMP/crawl.err"

python3 - "$RESULT" "$UA_LOG" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    requests = [line.rstrip("\n").split("\t", 1) for line in f if line.strip()]
assert requests and all(ua == "CebulaBot/0.1" for _, ua in requests), requests
assert any(path == "/robots.txt" for path, _ in requests), requests

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
assert len(seed["links"]) == 4, seed["links"]
assert len(seed["images"]) == 1 and seed["images"][0]["alt"] == "Logo", seed
assert any(p["url"].endswith("/page2.html") for p in d["pages"]), pages
assert not any(p["url"].endswith(".pdf") for p in d["pages"]), "PDF was fetched as a page"
assert not any(p["url"].endswith("/bot-blocked/page.html") for p in d["pages"]), "robots block was ignored"

kinds = {e["kind"] for e in d["errors"]}
assert any(e["kind"] == "robots" and e["url"].endswith("/bot-blocked/page.html") for e in d["errors"]), d["errors"]
assert "robots" in kinds, d["errors"]
assert "http_status" in kinds, d["errors"]
assert d["resources"][0]["kind"] == "pdf", d["resources"]
print("integration: OK")
PY

# fetch: one request only, headers/status on stderr, body on stdout or in a file.
REDIRECT_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
python3 - "$REDIRECT_PORT" "$PORT" <<'PY' >"$TMP/redirect.log" 2>&1 &
import http.server, sys

redirect_port, target_port = int(sys.argv[1]), int(sys.argv[2])

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(302)
        self.send_header("Location", f"http://127.0.0.1:{target_port}/page2.html")
        self.end_headers()

    def log_message(self, *args):
        pass

http.server.HTTPServer(("127.0.0.1", redirect_port), Handler).serve_forever()
PY
REDIRECT_PID=$!
for _ in $(seq 1 50); do
    if curl -s -o /dev/null "http://127.0.0.1:$REDIRECT_PORT/" 2>/dev/null; then break; fi
    sleep 0.1
done

FETCH_BODY="$TMP/fetched.html"
"$ROOT/build/cebula" fetch "http://127.0.0.1:$PORT/page2.html" \
    --output "$FETCH_BODY" >"$TMP/fetch.out" 2>"$TMP/fetch.err"
"$ROOT/build/cebula" fetch "http://127.0.0.1:$PORT/page2.html" \
    >"$TMP/fetch-stdout.out" 2>"$TMP/fetch-stdout.err"
"$ROOT/build/cebula" fetch "http://127.0.0.1:$REDIRECT_PORT/" \
    >"$TMP/fetch-redirect.out" 2>"$TMP/fetch-redirect.err"

python3 - "$FETCH_BODY" "$TMP/fetch.out" "$TMP/fetch.err" "$TMP/fetch-stdout.out" "$TMP/fetch-redirect.err" <<'PY'
import pathlib, sys

body_file, out_file, err_file, stdout_file, redirect_err = map(
    lambda p: pathlib.Path(p).read_text(encoding="utf-8"), sys.argv[1:])
assert "Second page" in body_file, body_file
assert out_file == "", out_file
assert "status 200" in err_file, err_file
assert "header:" in err_file, err_file
assert "content-type" in err_file.lower(), err_file
assert "Second page" in stdout_file, stdout_file
assert "302" in redirect_err, redirect_err
assert "status 200" in redirect_err, redirect_err
assert "Location:" in redirect_err, redirect_err
print("integration fetch: OK")
PY

kill "$REDIRECT_PID" 2>/dev/null || true
REDIRECT_PID=""

# A custom UA of exactly "CebulaBot" must also be sent and honoured by robots.txt.
CUSTOM_RESULT="$TMP/custom.json"
"$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html" \
    --user-agent 'CebulaBot' --max-pages 4 --max-depth 1 --output "$CUSTOM_RESULT" >/dev/null 2>"$TMP/custom.err"
python3 - "$CUSTOM_RESULT" "$UA_LOG" <<'PY'
import json, sys

with open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
with open(sys.argv[2], encoding="utf-8") as f:
    agents = [line.rstrip("\n").split("\t", 1)[1] for line in f if line.strip()]
assert any(ua == "CebulaBot" for ua in agents), agents
assert any(e["kind"] == "robots" and e["url"].endswith("/bot-blocked/page.html") for e in d["errors"]), d["errors"]
print("user-agent: OK")
PY

# Negative cases: validation, no shell injection, no phantom output file.
if "$ROOT/build/cebula" crawl "not a url" >/dev/null 2>&1; then
    echo "invalid URL was accepted" >&2; exit 1
fi
if "$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html" --max-depth abc >/dev/null 2>&1; then
    echo "invalid --max-depth was accepted" >&2; exit 1
fi
if "$ROOT/build/cebula" fetch "not a url" >/dev/null 2>&1; then
    echo "invalid fetch URL was accepted" >&2; exit 1
fi
MARKER="$TMP/pwned"
"$ROOT/build/cebula" crawl "http://127.0.0.1:$PORT/index.html\"; touch $MARKER; echo \"" --max-pages 1 >/dev/null 2>&1 || true
if [[ -e "$MARKER" ]]; then
    echo "command injection succeeded" >&2; exit 1
fi
