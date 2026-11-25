module cebula::cli::commands;

import std::io;
import cebula::cli::arguments;

const String VERSION = "0.1.0";
const String NAME = "cebula";

fn void print_help() {
    io::printn("cebula - A web crawler written in C3");
    io::printn("");
    io::printn("Usage:");
    io::printn("  cebula crawl <url> [options]");
    io::printn("  cebula fetch <url> [options]");
    io::printn("  cebula version");
    io::printn("  cebula help");
    io::printn("");
    io::printn("Options for crawl:");
    io::printn("  --max-depth <n>     Maximum crawl depth (default: 3)");
    io::printn("  --max-pages <n>     Maximum pages to fetch (default: 100)");
    io::printn("  --no-same-domain    Also follow links outside the seed site");
    io::printn("  --no-robots         Ignore robots.txt (use responsibly)");
    io::printn("  --timeout <sec>     Request timeout in seconds (default: 10)");
    io::printn("  --delay-ms <n>      Minimum delay between requests to the same host");
    io::printn("  --user-agent <ua>   Custom User-Agent header");
    io::printn("  --max-body-kb <n>   Maximum response body size in KiB (default: 5120)");
    io::printn("  --output <file>     Write JSON output to file instead of stdout");
    io::printn("");
    io::printn("Options for fetch:");
    io::printn("  Status and response headers go to stderr; the body goes to stdout or --output.");
    io::printn("  --timeout <sec>     Request timeout in seconds (default: 10)");
    io::printn("  --user-agent <ua>   Custom User-Agent header");
    io::printn("  --max-body-kb <n>   Maximum response body size in KiB (default: 5120)");
    io::printn("  --output <file>     Write the response body to file instead of stdout");
}
fn void print_version() {
    io::printfn("%s %s", NAME, VERSION);
}
