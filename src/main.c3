module cebula;

import std::io;
import cebula::cli::commands;
import cebula::cli::arguments;
import cebula::crawler::crawler;

fn bool parse_int(String s, int* out)
{
    if (s.len == 0) return false;
    bool negative = false;
    usz start = 0;
    if (s[0] == '-')
    {
        negative = true;
        start = 1;
    }
    if (start >= s.len) return false;
    long value = 0;
    for (usz i = start; i < s.len; i++)
    {
        char c = s[i];
        if (c < '0' || c > '9') return false;
        value = value * 10 + (long)(c - '0');
        if (value > 2_000_000_000L) return false;
    }
    *out = negative ? (int)-value : (int)value;
    return true;
}

fn int usage_error(String message)
{
    io::eprintfn("Error: %s", message);
    io::eprintn("Usage: cebula crawl <url> [options]");
    return 2;
}

fn int main(String[] args)
{
    if (args.len < 2)
    {
        commands::print_help();
        return 0;
    }

    String cmd = args[1];
    if (cmd == "help" || cmd == "--help" || cmd == "-h")
    {
        commands::print_help();
        return 0;
    }
    if (cmd == "version" || cmd == "--version" || cmd == "-v")
    {
        commands::print_version();
        return 0;
    }
    if (cmd != "crawl")
    {
        io::eprintfn("Unknown command: %s", cmd);
        commands::print_help();
        return 2;
    }
    if (args.len < 3) return usage_error("missing URL for crawl command");

    arguments::CrawlOptions opts = arguments::default_crawl_options(args[2]);
    usz i = 3;
    while (i < args.len)
    {
        String a = args[i];
        if (a == "--no-same-domain")
        {
            opts.same_domain = false;
            i++;
            continue;
        }
        if (a == "--same-domain")
        {
            opts.same_domain = true;
            i++;
            continue;
        }
        if (a == "--no-robots")
        {
            opts.follow_robots = false;
            i++;
            continue;
        }

        if (i + 1 >= args.len) return usage_error("missing value for option");

        String value = args[i + 1];
        int parsed = 0;
        if (a == "--max-depth")
        {
            if (!parse_int(value, &parsed)) return usage_error("--max-depth requires an integer");
            opts.max_depth = parsed;
        }
        else if (a == "--max-pages")
        {
            if (!parse_int(value, &parsed)) return usage_error("--max-pages requires an integer");
            opts.max_pages = parsed;
        }
        else if (a == "--timeout")
        {
            if (!parse_int(value, &parsed)) return usage_error("--timeout requires an integer");
            opts.timeout_sec = parsed;
        }
        else if (a == "--delay-ms")
        {
            if (!parse_int(value, &parsed)) return usage_error("--delay-ms requires an integer");
            opts.delay_ms = parsed;
        }
        else if (a == "--max-body-kb")
        {
            if (!parse_int(value, &parsed) || parsed < 1 || parsed > 1_000_000) return usage_error("--max-body-kb requires a value in KiB");
            opts.max_body_bytes = (usz)parsed * 1024;
        }
        else if (a == "--user-agent")
        {
            opts.user_agent = value;
        }
        else if (a == "--output")
        {
            if (value.len == 0) return usage_error("--output requires a file path");
            opts.output_path = value;
            opts.has_output_path = true;
        }
        else
        {
            io::eprintfn("Error: unknown option: %s", a);
            return 2;
        }
        i += 2;
    }

    return crawler::run_crawl(opts);
}
