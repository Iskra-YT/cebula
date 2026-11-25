module cebula::output::json_out;

import std::io;
import std::core::string;
import cebula::models::result;
import cebula::models::page;
import cebula::network::response;

fn String json_escape(String s) {
    DString out;
    out.init(mem);
    for (usz i = 0; i < s.len; i++) {
        char c = s[i];
        switch (c) {
            case '"': out.append(`\"`);
            case '\\': out.append(`\\`);
            case '\n': out.append(`\n`);
            case '\r': out.append(`\r`);
            case '\t': out.append(`\t`);
            default:
                if (c < 0x20) {
                    out.appendf(`\u%04x`, (int)c);
                } else {
                    out.append_char(c);
                }
        }
    }
    return out.str_view();
}

fn String render_result(result::CrawlResult cr, page::Page p, response::HttpResponse resp) {
    DString j;
    j.init(mem);
    j.append("{\n");
    // crawler
    j.append("  \"crawler\": {\n");
    j.appendf("    \"name\": \"%s\",\n", json_escape(cr.crawler.name));
    j.appendf("    \"version\": \"%s\"\n", json_escape(cr.crawler.version));
    j.append("  },\n");
    // task
    j.append("  \"task\": {\n");
    j.appendf("    \"seed\": \"%s\",\n", json_escape(cr.task.seed));
    j.appendf("    \"status\": \"%s\",\n", json_escape(cr.task.status));
    j.append("    \"started_at\": null,\n");
    j.append("    \"finished_at\": null\n");
    j.append("  },\n");
    // statistics
    j.append("  \"statistics\": {\n");
    j.appendf("    \"pages_discovered\": %d,\n", cr.stats.pages_discovered);
    j.appendf("    \"pages_crawled\": %d,\n", cr.stats.pages_crawled);
    j.appendf("    \"pages_failed\": %d,\n", cr.stats.pages_failed);
    j.appendf("    \"resources_discovered\": %d\n", cr.stats.resources_discovered);
    j.append("  },\n");
    // pages
    j.append("  \"pages\": [\n");
    j.append("    {\n");
    j.appendf("      \"url\": \"%s\",\n", json_escape(p.url));
    j.appendf("      \"status_code\": %d,\n", p.status_code);
    if (p.content_type.len > 0) {
        j.appendf("      \"content_type\": \"%s\",\n", json_escape(p.content_type));
    } else {
        j.append("      \"content_type\": null,\n");
    }
    j.appendf("      \"depth\": %d,\n", p.depth);
    if (p.has_discovered_from && p.discovered_from.len > 0) {
        j.appendf("      \"discovered_from\": \"%s\",\n", json_escape(p.discovered_from));
    } else {
        j.append("      \"discovered_from\": null,\n");
    }
    if (p.title.len > 0) {
        j.appendf("      \"title\": \"%s\",\n", json_escape(p.title));
    } else {
        j.append("      \"title\": \"\",\n");
    }
    if (p.has_description && p.description.len > 0) {
        j.appendf("      \"description\": \"%s\",\n", json_escape(p.description));
    } else {
        j.append("      \"description\": null,\n");
    }
    if (p.has_canonical_url && p.canonical_url.len > 0) {
        j.appendf("      \"canonical_url\": \"%s\",\n", json_escape(p.canonical_url));
    } else {
        j.append("      \"canonical_url\": null,\n");
    }
    if (p.has_language && p.language.len > 0) {
        j.appendf("      \"language\": \"%s\",\n", json_escape(p.language));
    } else {
        j.append("      \"language\": null,\n");
    }
    j.append("      \"headings\": [],\n");
    j.append("      \"links\": [],\n");
    j.append("      \"images\": []\n");
    j.append("    }\n");
    j.append("  ],\n");
    // resources
    j.append("  \"resources\": [],\n");
    // errors
    j.append("  \"errors\": []\n");
    j.append("}\n");
    return j.str_view();
}
