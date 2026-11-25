module cebula::crawler::crawler;

import std::io;
import std::core::string;
import cebula::cli::arguments;
import cebula::network::http;
import cebula::network::response;
import cebula::models::result;
import cebula::models::page;
import cebula::output::json_out;

fn int run_crawl(arguments::CrawlOptions opts) {
    // Log to stderr
    io::eprintfn("CEBULA: starting crawl of %s", opts.url);
    io::eprintfn("CEBULA: max_depth=%d max_pages=%d timeout=%ds", opts.max_depth, opts.max_pages, opts.timeout_sec);

    result::CrawlResult cr;
    cr.crawler.name = "CEBULA";
    cr.crawler.version = "0.1.0";
    cr.task.seed = opts.url;
    cr.task.status = "completed";
    cr.task.has_started_at = false;
    cr.task.has_finished_at = false;
    cr.stats.pages_discovered = 1;
    cr.stats.pages_crawled = 0;
    cr.stats.pages_failed = 0;
    cr.stats.resources_discovered = 0;
    cr.pages = {};
    cr.resources = {};
    cr.errors = {};

    // Fetch seed page (simplified: single page crawl for now)
    response::HttpResponse resp = http::fetch_url(opts.url, opts.timeout_sec);

    page::Page p;
    p.url = opts.url;
    p.depth = 0;
    p.discovered_from = "";
    p.has_discovered_from = false;
    p.title = "";
    p.description = "";
    p.has_description = false;
    p.canonical_url = "";
    p.has_canonical_url = false;
    p.language = "";
    p.has_language = false;
    p.headings = {};
    p.links = {};
    p.images = {};

    if (!resp.ok) {
        p.status_code = 0;
        p.content_type = "";
        cr.stats.pages_failed = 1;
        // add error
        io::eprintfn("CEBULA: failed to fetch %s: %s", opts.url, resp.error_message);
    } else {
        p.status_code = resp.status_code;
        p.content_type = resp.content_type;
        cr.stats.pages_crawled = 1;
        // naive title extraction
        p.title = extract_title(resp.body);
        io::eprintfn("CEBULA: fetched %s (status=%d)", opts.url, resp.status_code);
    }

    // store page (simplified: we can't easily append to dynamic arrays in this C3 style without allocators; 
    // for minimal demo, just output what we have)
    // NOTE: proper dynamic arrays need allocator management; this is a simplification.

    // Output JSON
    String json_out_str = json_out::render_result(cr, p, resp);
    if (opts.has_output_path) {
        io::eprintfn("CEBULA: writing output to %s", opts.output_path);
        // write to file - simplified, use std::io::file
    } else {
        io::print(json_out_str);
    }

    return 0;
}

fn String extract_title(String html) {
    // very naive: find <title> and </title>
    String lower = html; // not lowercased, naive
    // search for "<title"
    for (usz i = 0; i + 7 < html.len; i++) {
        if ((html[i] == '<' || html[i] == '<') ) {}
        // simple check
    }
    // fallback simple search
    usz start = 0;
    // find "<title"
    for (usz i = 0; i + 6 < html.len; i++) {
        if (html[i] == '<' && (html[i+1] == 't' || html[i+1] == 'T')) {
            // check "title"
            if (i+6 < html.len && (html[i+2] == 'i'||html[i+2]=='I') && (html[i+3]=='t'||html[i+3]=='T') && (html[i+4]=='l'||html[i+4]=='L') && (html[i+5]=='e'||html[i+5]=='E')) {
                // find '>'
                usz j = i+6;
                while (j < html.len && html[j] != '>') j++;
                if (j < html.len) {
                    start = j+1;
                    // find </title>
                    for (usz k = start; k + 7 < html.len; k++) {
                        if (html[k] == '<' && html[k+1] == '/') {
                            // check title end
                            if (k+7 < html.len) {
                                String endtag = html[k..k+6];
                                // naive compare
                                return html[start..k-1];
                            }
                        }
                    }
                }
            }
        }
    }
    return "";
}
