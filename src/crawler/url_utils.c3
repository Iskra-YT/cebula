module cebula::crawler::url_utils;

import std::io;
import std::core::string;

fn bool starts_with_ignore_case(String s, String prefix) {
    if (s.len < prefix.len) return false;
    // simple ascii case-insensitive check for prefix
    for (usz i = 0; i < prefix.len; i++) {
        char a = s[i];
        char b = prefix[i];
        if (a >= 'A' && a <= 'Z') a = (char)(a + 32);
        if (b >= 'A' && b <= 'Z') b = (char)(b + 32);
        if (a != b) return false;
    }
    return true;
}

fn bool is_http_or_https(String url) {
    return starts_with_ignore_case(url, "http://") || starts_with_ignore_case(url, "https://");
}

fn bool has_fragment(String url) {
    if (url.len == 0) return false;
    usz i = url.len;
    while (i > 0) {
        i--;
        if (url[i] == '#') return true;
        if (url[i] == '?') break;
    }
    return false;
}

fn String strip_fragment(String url) {
    for (usz i = 0; i < url.len; i++) {
        if (url[i] == '#') {
            return url[:i];
        }
    }
    return url;
}

fn bool is_absolute_url(String url) {
    return starts_with_ignore_case(url, "http://") || starts_with_ignore_case(url, "https://");
}

fn String get_scheme(String url) {
    if (starts_with_ignore_case(url, "https://")) return "https";
    if (starts_with_ignore_case(url, "http://")) return "http";
    return "";
}
