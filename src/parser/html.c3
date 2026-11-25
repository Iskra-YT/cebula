module cebula::parser::html;

import std::collections::list;
import cebula::crawler::url_utils;
import cebula::models::page;

const usz NOT_FOUND = usz::max;

fn bool is_space(char c)
{
    return c == ' ' || c == '\t' || c == '\r' || c == '\n' || c == '\f';
}

fn bool starts_ci_at(String s, usz at, String value)
{
    if (at + value.len > s.len) return false;
    return url_utils::eq_ignore_case(url_utils::sub(s, at, at + value.len), value);
}

fn usz find_ci(String s, String needle, usz from)
{
    if (needle.len == 0 || needle.len > s.len) return NOT_FOUND;
    for (usz i = from; i + needle.len <= s.len; i++)
    {
        if (url_utils::eq_ignore_case(url_utils::sub(s, i, i + needle.len), needle)) return i;
    }
    return NOT_FOUND;
}

fn bool tag_at(String s, usz at, String tag)
{
    if (at >= s.len || s[at] != '<') return false;
    if (at + tag.len + 1 >= s.len) return false;
    if (!starts_ci_at(s, at + 1, tag)) return false;
    char boundary = s[at + 1 + tag.len];
    return is_space(boundary) || boundary == '>' || boundary == '/';
}

fn usz skip_hidden(String s, usz at)
{
    if (starts_ci_at(s, at, "<!--"))
    {
        usz end = find_ci(s, "-->", at + 4);
        return end == NOT_FOUND ? s.len : end + 3;
    }
    if (tag_at(s, at, "script") || tag_at(s, at, "style"))
    {
        String tag = tag_at(s, at, "script") ? "script" : "style";
        DString close;
        close.init(tmem);
        close.append("</");
        close.append(tag);
        usz end = find_ci(s, close.str_view(), at + 1);
        return end == NOT_FOUND ? s.len : end + tag.len + 2;
    }
    return at;
}

fn usz find_tag(String s, String tag, usz from)
{
    usz i = from;
    while (i < s.len)
    {
        usz lt = url_utils::find_char(s, '<', i);
        if (lt == NOT_FOUND) return NOT_FOUND;
        usz skipped = skip_hidden(s, lt);
        if (skipped > lt)
        {
            i = skipped;
            continue;
        }
        if (tag_at(s, lt, tag)) return lt;
        i = lt + 1;
    }
    return NOT_FOUND;
}

fn usz tag_end(String s, usz from)
{
    return url_utils::find_char(s, '>', from);
}

fn String tag_body(String s, usz tag_start, usz closing)
{
    if (closing == NOT_FOUND || closing <= tag_start + 1) return "";
    return url_utils::sub(s, tag_start + 1, closing);
}

fn String tag_content(String s, String tag, usz from, usz* after = null)
{
    usz open = find_tag(s, tag, from);
    if (open == NOT_FOUND)
    {
        if (after != null) *after = from;
        return "";
    }
    usz close_open = tag_end(s, open);
    if (close_open == NOT_FOUND)
    {
        if (after != null) *after = s.len;
        return "";
    }
    DString close_tag;
    close_tag.init(tmem);
    close_tag.append("</");
    close_tag.append(tag);
    usz close = find_ci(s, close_tag.str_view(), close_open + 1);
    if (close == NOT_FOUND)
    {
        if (after != null) *after = close_open + 1;
        return "";
    }
    if (after != null) *after = close + tag.len + 2;
    return url_utils::sub(s, close_open + 1, close);
}

fn String attr(String body, String name)
{
    usz i = 0;
    while (i < body.len)
    {
        while (i < body.len && is_space(body[i])) i++;
        usz name_end = i + name.len;
        if (name_end > body.len || !url_utils::eq_ignore_case(url_utils::sub(body, i, name_end), name))
        {
            i++;
            continue;
        }
        usz j = name_end;
        while (j < body.len && is_space(body[j])) j++;
        if (j >= body.len || body[j] != '=')
        {
            i = name_end;
            continue;
        }
        j++;
        while (j < body.len && is_space(body[j])) j++;
        if (j >= body.len)
        {
            i = name_end;
            continue;
        }
        char quote = body[j];
        if (quote == '"' || quote == '\'')
        {
            usz end = url_utils::find_char(body, quote, j + 1);
            return end == NOT_FOUND ? "" : url_utils::sub(body, j + 1, end);
        }
        usz end = j;
        while (end < body.len && !is_space(body[end]) && body[end] != '/') end++;
        return url_utils::sub(body, j, end);
    }
    return "";
}

fn String meta_content(String html, String key_name, String key_value)
{
    usz pos = 0;
    while (pos < html.len)
    {
        usz open = find_tag(html, "meta", pos);
        if (open == NOT_FOUND) return "";
        usz close = tag_end(html, open);
        if (close == NOT_FOUND) return "";
        String body = tag_body(html, open, close);
        String key = attr(body, key_name);
        if (url_utils::eq_ignore_case(key, key_value))
        {
            return attr(body, "content");
        }
        pos = close + 1;
    }
    return "";
}

fn void append_utf8(DString* out, uint cp)
{
    if (cp < 0x80)
    {
        out.append_char((char)cp);
    }
    else if (cp < 0x800)
    {
        out.append_char((char)(0xC0 | (cp >> 6)));
        out.append_char((char)(0x80 | (cp & 0x3F)));
    }
    else if (cp < 0x10000)
    {
        out.append_char((char)(0xE0 | (cp >> 12)));
        out.append_char((char)(0x80 | ((cp >> 6) & 0x3F)));
        out.append_char((char)(0x80 | (cp & 0x3F)));
    }
    else
    {
        out.append_char((char)(0xF0 | (cp >> 18)));
        out.append_char((char)(0x80 | ((cp >> 12) & 0x3F)));
        out.append_char((char)(0x80 | ((cp >> 6) & 0x3F)));
        out.append_char((char)(0x80 | (cp & 0x3F)));
    }
}

fn String decode_entities(String s)
{
    if (s.len == 0) return "";
    DString out;
    out.init(tmem);
    usz i = 0;
    while (i < s.len)
    {
        if (s[i] != '&')
        {
            out.append_char(s[i]);
            i++;
            continue;
        }
        usz semi = url_utils::find_char(s, ';', i + 1);
        if (semi == NOT_FOUND || semi - i > 12)
        {
            out.append_char(s[i]);
            i++;
            continue;
        }
        String entity = url_utils::sub(s, i, semi + 1);
        if (entity == "&amp;") { out.append_char('&'); }
        else if (entity == "&lt;") { out.append_char('<'); }
        else if (entity == "&gt;") { out.append_char('>'); }
        else if (entity == "&quot;") { out.append_char('"'); }
        else if (entity == "&apos;" || entity == "&#39;") { out.append_char('\''); }
        else if (entity == "&nbsp;") { out.append_char(' '); }
        else if (entity.len > 3 && entity[1] == '#')
        {
            bool hex = entity[2] == 'x' || entity[2] == 'X';
            usz start = hex ? 3 : 2;
            uint cp = 0;
            bool valid = start + 1 < entity.len;
            for (usz j = start; j < entity.len - 1; j++)
            {
                char c = entity[j];
                uint digit = 0;
                if (c >= '0' && c <= '9') { digit = (uint)(c - '0'); }
                else if (hex && c >= 'a' && c <= 'f') { digit = (uint)(c - 'a' + 10); }
                else if (hex && c >= 'A' && c <= 'F') { digit = (uint)(c - 'A' + 10); }
                else { valid = false; break; }
                cp = cp * (hex ? 16 : 10) + digit;
            }
            if (valid && cp > 0 && cp <= 0x10FFFF) { append_utf8(&out, cp); }
            else { out.append(entity); }
        }
        else
        {
            out.append(entity);
        }
        i = semi + 1;
    }
    return out.str_view();
}

fn String clean_text(String s)
{
    DString out;
    out.init(tmem);
    bool pending_space = false;
    for (usz i = 0; i < s.len; i++)
    {
        char c = s[i];
        if (is_space(c))
        {
            if (out.str_view().len > 0) pending_space = true;
            continue;
        }
        if (pending_space)
        {
            out.append_char(' ');
            pending_space = false;
        }
        out.append_char(c);
    }
    return decode_entities(out.str_view());
}

fn String page_title(String html)
{
    return clean_text(tag_content(html, "title", 0));
}

fn String meta_description(String html)
{
    String value = meta_content(html, "name", "description");
    if (value.len == 0) value = meta_content(html, "property", "og:description");
    return clean_text(value);
}

fn String canonical_url(String html)
{
    usz pos = 0;
    while (pos < html.len)
    {
        usz open = find_tag(html, "link", pos);
        if (open == NOT_FOUND) return "";
        usz close = tag_end(html, open);
        if (close == NOT_FOUND) return "";
        String body = tag_body(html, open, close);
        String rel = attr(body, "rel");
        if (url_utils::eq_ignore_case(rel, "canonical")) return url_utils::trim(attr(body, "href"));
        pos = close + 1;
    }
    return "";
}

fn String language(String html)
{
    usz open = find_tag(html, "html", 0);
    if (open == NOT_FOUND) return "";
    usz close = tag_end(html, open);
    if (close == NOT_FOUND) return "";
    return url_utils::trim(attr(tag_body(html, open, close), "lang"));
}

fn page::Heading[] headings(String html)
{
    List{page::Heading} result;
    result.init(tmem);
    for (int level = 1; level <= 6; level++)
    {
        DString name;
        name.init(tmem);
        name.appendf("h%d", level);
        usz pos = 0;
        while (pos < html.len)
        {
            usz after = pos;
            String text = clean_text(tag_content(html, name.str_view(), pos, &after));
            if (after <= pos) break;
            if (text.len > 0)
            {
                page::Heading h;
                h.level = level;
                h.text = text;
                result.push(h);
            }
            pos = after;
        }
    }
    return result.array_view();
}

fn page::Link[] links(String html, String base_url)
{
    List{page::Link} result;
    result.init(tmem);
    usz pos = 0;
    while (pos < html.len)
    {
        usz open = find_tag(html, "a", pos);
        if (open == NOT_FOUND) break;
        usz close = tag_end(html, open);
        if (close == NOT_FOUND) break;
        String body = tag_body(html, open, close);
        String href = url_utils::trim(attr(body, "href"));
        usz after = close + 1;
        String anchor = clean_text(tag_content(html, "a", pos, &after));
        if (after <= pos) after = close + 1;
        if (href.len > 0 && href[0] != '#' && !url_utils::is_special_scheme(href))
        {
            String absolute = url_utils::resolve_url(base_url, href);
            if (absolute.len > 0)
            {
                page::Link link;
                link.href = href;
                link.anchor_text = anchor;
                link.absolute_url = absolute;
                link.is_internal = url_utils::same_site(base_url, absolute);
                result.push(link);
            }
        }
        pos = after;
    }
    return result.array_view();
}

fn page::Image[] images(String html, String base_url)
{
    List{page::Image} result;
    result.init(tmem);
    usz pos = 0;
    while (pos < html.len)
    {
        usz open = find_tag(html, "img", pos);
        if (open == NOT_FOUND) break;
        usz close = tag_end(html, open);
        if (close == NOT_FOUND) break;
        String body = tag_body(html, open, close);
        String src = url_utils::trim(attr(body, "src"));
        if (src.len > 0 && !url_utils::is_special_scheme(src))
        {
            String absolute = url_utils::resolve_url(base_url, src);
            if (absolute.len > 0)
            {
                page::Image image;
                image.src = src;
                image.alt = clean_text(attr(body, "alt"));
                image.absolute_url = absolute;
                result.push(image);
            }
        }
        pos = close + 1;
    }
    return result.array_view();
}

fn String resource_kind(String url)
{
    usz dot = 0;
    for (usz i = 0; i < url.len; i++)
    {
        if (url[i] == '/') { dot = 0; }
        else if (url[i] == '.') { dot = i; }
        else if (dot > 0 && (url[i] == '?' || url[i] == '#')) { break; }
    }
    if (dot == 0) return "";
    String ext = url_utils::sub(url, dot + 1, url.len);
    ext = url_utils::lower_copy(ext);
    if (ext == "pdf" || ext == "docx" || ext == "xlsx" || ext == "pptx" || ext == "txt") return ext;
    return "";
}

fn page::Resource[] resources(String html, String base_url)
{
    List{page::Resource} result;
    result.init(tmem);
    page::Link[] all_links = links(html, base_url);
    for (usz i = 0; i < all_links.len; i++)
    {
        String kind = resource_kind(all_links[i].absolute_url);
        if (kind.len == 0) continue;
        bool duplicate = false;
        for (usz j = 0; j < (usz)result.len(); j++)
        {
            if (result[(sz)j].url == all_links[i].absolute_url)
            {
                duplicate = true;
                break;
            }
        }
        if (duplicate) continue;
        page::Resource resource;
        resource.url = all_links[i].absolute_url;
        resource.kind = kind;
        result.push(resource);
    }
    return result.array_view();
}
