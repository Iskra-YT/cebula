module cebula::crawler::url_utils;

import std::collections::list;
import std::io;

// C3 ranges are inclusive on both ends. All helpers in this module use
// exclusive end indices to avoid off-by-one mistakes.
const usz NOT_FOUND = usz::max;

fn String sub(String s, usz from, usz to)
{
    if (from >= s.len || to <= from) return "";
    if (to > s.len) to = s.len;
    return s[from..to - 1];
}

fn usz find_char(String s, char c, usz from)
{
    for (usz i = from; i < s.len; i++)
    {
        if (s[i] == c) return i;
    }
    return NOT_FOUND;
}

fn char lower_char(char c)
{
    return (c >= 'A' && c <= 'Z') ? (char)(c + 32) : c;
}

fn bool eq_ignore_case(String a, String b)
{
    if (a.len != b.len) return false;
    for (usz i = 0; i < a.len; i++)
    {
        if (lower_char(a[i]) != lower_char(b[i])) return false;
    }
    return true;
}

fn bool starts_with_ignore_case(String s, String prefix)
{
    if (s.len < prefix.len) return false;
    return eq_ignore_case(sub(s, 0, prefix.len), prefix);
}

fn bool contains_ignore_case(String haystack, String needle)
{
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;
    for (usz i = 0; i + needle.len <= haystack.len; i++)
    {
        if (eq_ignore_case(sub(haystack, i, i + needle.len), needle)) return true;
    }
    return false;
}

fn String lower_copy(String s)
{
    DString out;
    out.init(tmem);
    for (usz i = 0; i < s.len; i++) out.append_char(lower_char(s[i]));
    return out.str_view();
}

fn String trim(String s)
{
    usz start = 0;
    while (start < s.len && (s[start] == ' ' || s[start] == '\t' || s[start] == '\r' || s[start] == '\n')) start++;
    usz end = s.len;
    while (end > start && (s[end - 1] == ' ' || s[end - 1] == '\t' || s[end - 1] == '\r' || s[end - 1] == '\n')) end--;
    return sub(s, start, end);
}

fn bool is_http_or_https(String url)
{
    return starts_with_ignore_case(url, "http://") || starts_with_ignore_case(url, "https://");
}

fn String strip_fragment(String url)
{
    usz hash = find_char(url, '#', 0);
    return hash == NOT_FOUND ? url : sub(url, 0, hash);
}

fn String get_scheme(String url)
{
    usz sep = find_char(url, ':', 0);
    if (sep == NOT_FOUND || sep + 3 > url.len) return "";
    if (url[sep + 1] != '/' || url[sep + 2] != '/') return "";
    return lower_copy(sub(url, 0, sep));
}

fn String get_host(String url)
{
    String scheme = get_scheme(url);
    if (scheme.len == 0) return "";
    usz start = scheme.len + 3;
    usz end = start;
    while (end < url.len && url[end] != '/' && url[end] != '?' && url[end] != '#') end++;
    String authority = sub(url, start, end);
    usz at = find_char(authority, '@', 0);
    if (at != NOT_FOUND) authority = sub(authority, at + 1, authority.len);
    usz colon = find_char(authority, ':', 0);
    if (colon != NOT_FOUND) authority = sub(authority, 0, colon);
    return lower_copy(authority);
}

fn String get_authority(String url)
{
    String scheme = get_scheme(url);
    if (scheme.len == 0) return "";
    usz start = scheme.len + 3;
    usz end = start;
    while (end < url.len && url[end] != '/' && url[end] != '?' && url[end] != '#') end++;
    String authority = sub(url, start, end);
    usz at = find_char(authority, '@', 0);
    if (at != NOT_FOUND) authority = sub(authority, at + 1, authority.len);
    return lower_copy(authority);
}

fn String get_origin(String url)
{
    String scheme = get_scheme(url);
    if (scheme.len == 0) return "";
    DString out;
    out.init(tmem);
    out.append(scheme);
    out.append("://");
    out.append(get_authority(url));
    return out.str_view();
}

fn bool same_site(String a, String b)
{
    String host_a = get_host(a);
    String host_b = get_host(b);
    if (host_a.len == 0 || host_b.len == 0) return false;
    if (host_a == host_b) return true;
    if (host_b.len <= host_a.len + 1) return false;
    if (host_b[host_b.len - host_a.len - 1] != '.') return false;
    return eq_ignore_case(sub(host_b, host_b.len - host_a.len, host_b.len), host_a);
}

fn String clean_path(String path)
{
    List{String} parts;
    parts.init(tmem);
    usz i = 0;
    while (i < path.len)
    {
        usz slash = find_char(path, '/', i);
        usz end = slash == NOT_FOUND ? path.len : slash;
        String seg = sub(path, i, end);
        if (seg.len > 0 && seg != ".")
        {
            if (seg == "..")
            {
                if ((usz)parts.len() > 0) (void)parts.pop();
            }
            else
            {
                parts.push(seg);
            }
        }
        if (slash == NOT_FOUND) break;
        i = slash + 1;
    }

    DString out;
    out.init(tmem);
    out.append('/');
    for (usz k = 0; k < (usz)parts.len(); k++)
    {
        if (k > 0) out.append('/');
        out.append(parts[(sz)k]);
    }
    if (path.len > 0 && path[path.len - 1] == '/' && (usz)parts.len() > 0)
    {
        if (out.str_view()[out.str_view().len - 1] != '/') out.append('/');
    }
    return out.str_view();
}

fn String normalize_url(String url)
{
    String s = strip_fragment(trim(url));
    if (s.len == 0) return "";
    for (usz k = 0; k < s.len; k++)
    {
        char ch = s[k];
        if (ch <= 0x20 || ch == '"' || ch == '\'' || ch == '<' || ch == '>' || ch == '\\') return "";
    }
    usz sep = find_char(s, ':', 0);
    if (sep == NOT_FOUND || sep + 2 >= s.len || s[sep + 1] != '/' || s[sep + 2] != '/') return "";
    String scheme = lower_copy(sub(s, 0, sep));
    if (scheme != "http" && scheme != "https") return "";

    usz auth_start = sep + 3;
    usz auth_end = auth_start;
    while (auth_end < s.len && s[auth_end] != '/' && s[auth_end] != '?') auth_end++;
    String authority = sub(s, auth_start, auth_end);
    if (authority.len == 0 || find_char(authority, '@', 0) != NOT_FOUND) return "";

    String host = authority;
    usz colon = find_char(authority, ':', 0);
    if (colon != NOT_FOUND)
    {
        host = sub(authority, 0, colon);
        String port = sub(authority, colon + 1, authority.len);
        bool default_port = (scheme == "http" && port == "80") || (scheme == "https" && port == "443");
        if (!default_port) host = sub(authority, 0, authority.len);
    }
    host = lower_copy(host);
    if (host.len == 0) return "";

    String rest = sub(s, auth_end, s.len);
    String path = rest;
    String query = "";
    usz q = find_char(rest, '?', 0);
    if (q != NOT_FOUND)
    {
        path = sub(rest, 0, q);
        query = sub(rest, q, rest.len);
    }
    path = path.len == 0 ? "/" : clean_path(path);

    DString out;
    out.init(tmem);
    out.append(scheme);
    out.append("://");
    out.append(host);
    out.append(path);
    out.append(query);
    return out.str_view();
}

fn String path_of(String url)
{
    String s = strip_fragment(trim(url));
    usz auth_start = 0;
    usz sep = find_char(s, ':', 0);
    if (sep != NOT_FOUND && sep + 2 < s.len && s[sep + 1] == '/' && s[sep + 2] == '/')
    {
        auth_start = sep + 3;
        while (auth_start < s.len && s[auth_start] != '/') auth_start++;
    }
    String path = sub(s, auth_start, s.len);
    return path.len == 0 ? "/" : path;
}

fn bool is_special_scheme(String href)
{
    String s = trim(href);
    usz colon = find_char(s, ':', 0);
    if (colon == NOT_FOUND || colon > 20) return false;
    String scheme = lower_copy(sub(s, 0, colon));
    return scheme == "mailto" || scheme == "javascript" || scheme == "data" || scheme == "tel" ||
           scheme == "file" || scheme == "about" || scheme == "ftp";
}

fn String resolve_url(String base, String href)
{
    String h = trim(href);
    if (h.len == 0 || is_special_scheme(h)) return "";
    if (is_http_or_https(h)) return normalize_url(h);
    if (h[0] == '#') return "";

    String origin = get_origin(base);
    if (origin.len == 0) return "";

    DString candidate;
    candidate.init(tmem);
    if (h[0] == '/' && h.len > 1 && h[1] == '/')
    {
        candidate.append(get_scheme(base));
        candidate.append(":");
        candidate.append(h);
    }
    else if (h[0] == '/')
    {
        candidate.append(origin);
        candidate.append(h);
    }
    else if (h[0] == '?')
    {
        String base_no_frag = strip_fragment(base);
        usz q = find_char(base_no_frag, '?', 0);
        candidate.append(q == NOT_FOUND ? base_no_frag : sub(base_no_frag, 0, q));
        candidate.append(h);
    }
    else
    {
        String base_path_raw = path_of(base);
        usz q = find_char(base_path_raw, '?', 0);
        String base_path = q == NOT_FOUND ? base_path_raw : sub(base_path_raw, 0, q);
        usz slash = 0;
        for (usz i = 0; i < base_path.len; i++)
        {
            if (base_path[i] == '/') slash = i;
        }
        candidate.append(origin);
        candidate.append(sub(base_path, 0, slash + 1));
        candidate.append(h);
    }
    return normalize_url(candidate.str_view());
}
