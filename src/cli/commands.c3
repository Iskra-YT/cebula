module cebula::cli::commands;

import std::io;
import cebula::cli::arguments;

const String VERSION = "0.1.0";
const String NAME = "CEBULA";

fn void print_help() {
    io::printn("CEBULA - A web crawler written in C3");
    io::printn("");
    io::printn("Usage:");
    io::printn("  cebula crawl <url> [options]");
    io::printn("  cebula version");
    io::printn("  cebula help");
    io::printn("");
    io::printn("Options for crawl:");
    io::printn("  --max-depth <n>     Maximum crawl depth (default: 3)");
    io::printn("  --max-pages <n>     Maximum pages to crawl (default: 100)");
    io::printn("  --same-domain       Restrict to same domain (default: enabled)");
    io::printn("  --timeout <sec>     Request timeout in seconds (default: 10)");
    io::printn("  --output <file>     Write JSON output to file instead of stdout");
}

fn void print_version() {
    io::printfn("%s %s", NAME, VERSION);
}
