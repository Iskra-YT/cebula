module cebula;

import std::io;
import cebula::cli::commands;
import cebula::cli::arguments;
import cebula::crawler::crawler;

fn int main(String[] args) {
    if (args.len < 2) {
        commands::print_help();
        return 0;
    }

    String cmd = args[1];

    if (cmd == "help" || cmd == "--help" || cmd == "-h") {
        commands::print_help();
        return 0;
    }
    if (cmd == "version" || cmd == "--version" || cmd == "-v") {
        commands::print_version();
        return 0;
    }
    if (cmd == "crawl") {
        if (args.len < 3) {
            io::eprintn("Error: missing URL for crawl command");
            io::eprintn("Usage: cebula crawl <url> [options]");
            return 1;
        }
        String url = args[2];
        arguments::CrawlOptions opts = arguments::default_crawl_options(url);

        // parse simple options
        usz i = 3;
        while (i < args.len) {
            String a = args[i];
            if (a == "--max-depth" && i + 1 < args.len) {
                i++;
                // naive parse int
                opts.max_depth = parse_int(args[i]);
            } else if (a == "--max-pages" && i + 1 < args.len) {
                i++;
                opts.max_pages = parse_int(args[i]);
            } else if (a == "--same-domain") {
                opts.same_domain = true;
            } else if (a == "--timeout" && i + 1 < args.len) {
                i++;
                opts.timeout_sec = parse_int(args[i]);
            } else if (a == "--output" && i + 1 < args.len) {
                i++;
                opts.output_path = args[i];
                opts.has_output_path = true;
            } else {
                io::eprintfn("Unknown or incomplete option: %s", a);
                return 1;
            }
            i++;
        }

        return crawler::run_crawl(opts);
    }

    io::eprintfn("Unknown command: %s", cmd);
    commands::print_help();
    return 1;
}

fn int parse_int(String s) {
    int val = 0;
    bool neg = false;
    usz start = 0;
    if (s.len > 0 && s[0] == '-') { neg = true; start = 1; }
    for (usz j = start; j < s.len; j++) {
        char c = s[j];
        if (c < '0' || c > '9') break;
        val = val * 10 + (int)(c - '0');
    }
    return neg ? -val : val;
}
