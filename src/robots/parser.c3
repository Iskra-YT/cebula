module cebula::robots::parser;

import std::io;
import std::core::string;

struct Rule {
    bool is_allow; // true=Allow, false=Disallow
    String path;
}

struct RobotsRules {
    Rule[] rules;
    String[] sitemaps;
    int crawl_delay_ms; // -1 if not set
}

fn RobotsRules parse_robots(String content, String ua_name) {
    RobotsRules rr;
    rr.rules = {};
    rr.sitemaps = {};
    rr.crawl_delay_ms = -1;

    // Very simplified: collect rules from sections matching * or ua_name
    // For brevity, just parse all Disallow/Allow lines globally if no sections? Or do basic section handling.
    // This is a simplification.
    usz i = 0;
    bool in_relevant = true; // simplify: apply all rules
    while (i < content.len) {
        // read line
        usz line_start = i;
        while (i < content.len && content[i] != '\n' && content[i] != '\r') i++;
        String line = content[line_start..i-1];
        // skip \r\n
        if (i < content.len && content[i] == '\r') i++;
        if (i < content.len && content[i] == '\n') i++;

        // trim leading spaces
        usz ls = 0;
        while (ls < line.len && (line[ls] == ' ' || line[ls] == '\t')) ls++;
        String trimmed = line[ls..];
        if (trimmed.len == 0) continue;
        // comment
        if (trimmed[0] == '#') continue;

        // find colon
        usz colon = 0;
        while (colon < trimmed.len && trimmed[colon] != ':') colon++;
        if (colon >= trimmed.len) continue;
        String key = trimmed[0..colon-1];
        String val = trimmed[colon+1..];
        // trim val
        usz vs = 0;
        while (vs < val.len && (val[vs] == ' ' || val[vs] == '\t')) vs++;
        val = val[vs..];

        // lowercase key compare (naive)
        if (eq_ignore_case(key, "user-agent")) {
            // simplified: if contains ua_name or is *, set relevant
            if (contains_ignore_case(val, ua_name) || val == "*") {
                in_relevant = true;
            } else {
                in_relevant = false;
            }
        } else if (in_relevant && eq_ignore_case(key, "disallow")) {
            // add rule
        } else if (in_relevant && eq_ignore_case(key, "allow")) {
            // add rule
        } else if (eq_ignore_case(key, "sitemap")) {
            // record sitemap
        }
    }
    return rr;
}

fn bool eq_ignore_case(String a, String b) {
    if (a.len != b.len) return false;
    for (usz i = 0; i < a.len; i++) {
        char ca = a[i]; char cb = b[i];
        if (ca >= 'A' && ca <= 'Z') ca = (char)(ca + 32);
        if (cb >= 'A' && cb <= 'Z') cb = (char)(cb + 32);
        if (ca != cb) return false;
    }
    return true;
}

fn bool contains_ignore_case(String haystack, String needle) {
    if (needle.len > haystack.len) return false;
    for (usz i = 0; i + needle.len <= haystack.len; i++) {
        bool match = true;
        for (usz j = 0; j < needle.len; j++) {
            char ca = haystack[i+j]; char cb = needle[j];
            if (ca >= 'A' && ca <= 'Z') ca = (char)(ca + 32);
            if (cb >= 'A' && cb <= 'Z') cb = (char)(cb + 32);
            if (ca != cb) { match = false; break; }
        }
        if (match) return true;
    }
    return false;
}
