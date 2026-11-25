module cebula::output::json_out;

import std::io;
import cebula::models::result;
import cebula::models::page;

fn void append_json_string(DString* out, String s)
{
    out.append('"');
    for (usz i = 0; i < s.len; i++)
    {
        char c = s[i];
        switch (c)
        {
            case '"': out.append("\\\"");
            case '\\': out.append("\\\\");
            case '\n': out.append("\\n");
            case '\r': out.append("\\r");
            case '\t': out.append("\\t");
            case '\b': out.append("\\b");
            case '\f': out.append("\\f");
            default:
                if (c < 0x20)
                {
                    out.appendf("\\u%04x", (int)c);
                }
                else
                {
                    out.append_char(c);
                }
        }
    }
    out.append('"');
}

fn String json_escape(String s)
{
    DString out;
    out.init(tmem);
    append_json_string(&out, s);
    return out.str_view();
}

fn void append_optional_string(DString* out, String value, bool has_value)
{
    if (has_value && value.len > 0)
    {
        append_json_string(out, value);
    }
    else
    {
        out.append("null");
    }
}

fn String render_result(result::CrawlResult* cr)
{
    DString j;
    j.init(tmem);
    j.append("{\n");

    j.append("  \"crawler\": {\n    \"name\": ");
    append_json_string(&j, cr.crawler.name);
    j.append(",\n    \"version\": ");
    append_json_string(&j, cr.crawler.version);
    j.append("\n  },\n");

    j.append("  \"task\": {\n    \"seed\": ");
    append_json_string(&j, cr.task.seed);
    j.append(",\n    \"status\": ");
    append_json_string(&j, cr.task.status);
    j.append(",\n    \"started_at\": ");
    append_optional_string(&j, cr.task.started_at, cr.task.has_started_at);
    j.append(",\n    \"finished_at\": ");
    append_optional_string(&j, cr.task.finished_at, cr.task.has_finished_at);
    j.append("\n  },\n");

    j.appendf("  \"statistics\": {\n    \"pages_discovered\": %d,\n    \"pages_crawled\": %d,\n    \"pages_failed\": %d,\n    \"resources_discovered\": %d\n  },\n",
              cr.stats.pages_discovered, cr.stats.pages_crawled, cr.stats.pages_failed, cr.stats.resources_discovered);

    j.append("  \"pages\": [");
    for (usz i = 0; i < cr.pages.len; i++)
    {
        page::Page* p = &cr.pages[i];
        if (i > 0) j.append(',');
        j.append("\n    {\n      \"url\": ");
        append_json_string(&j, p.url);
        j.appendf(",\n      \"status_code\": %d,\n      \"content_type\": ", p.status_code);
        append_optional_string(&j, p.content_type, p.content_type.len > 0);
        j.appendf(",\n      \"depth\": %d,\n      \"discovered_from\": ", p.depth);
        append_optional_string(&j, p.discovered_from, p.has_discovered_from);
        j.append(",\n      \"title\": ");
        append_json_string(&j, p.title);
        j.append(",\n      \"description\": ");
        append_optional_string(&j, p.description, p.has_description);
        j.append(",\n      \"canonical_url\": ");
        append_optional_string(&j, p.canonical_url, p.has_canonical_url);
        j.append(",\n      \"language\": ");
        append_optional_string(&j, p.language, p.has_language);

        j.append(",\n      \"headings\": [");
        for (usz h = 0; h < p.headings.len; h++)
        {
            if (h > 0) j.append(',');
            j.appendf("\n        { \"level\": %d, \"text\": ", p.headings[h].level);
            append_json_string(&j, p.headings[h].text);
            j.append(" }");
        }
        if (p.headings.len > 0) j.append("\n      ");
        j.append("],\n      \"links\": [");
        for (usz l = 0; l < p.links.len; l++)
        {
            page::Link* link = &p.links[l];
            if (l > 0) j.append(',');
            j.append("\n        { \"href\": ");
            append_json_string(&j, link.href);
            j.append(", \"anchor_text\": ");
            append_json_string(&j, link.anchor_text);
            j.append(", \"absolute_url\": ");
            append_json_string(&j, link.absolute_url);
            j.append(", \"is_internal\": ");
            j.append(link.is_internal ? "true" : "false");
            j.append(" }");
        }
        if (p.links.len > 0) j.append("\n      ");
        j.append("],\n      \"images\": [");
        for (usz m = 0; m < p.images.len; m++)
        {
            page::Image* image = &p.images[m];
            if (m > 0) j.append(',');
            j.append("\n        { \"src\": ");
            append_json_string(&j, image.src);
            j.append(", \"alt\": ");
            append_json_string(&j, image.alt);
            j.append(", \"absolute_url\": ");
            append_json_string(&j, image.absolute_url);
            j.append(" }");
        }
        if (p.images.len > 0) j.append("\n      ");
        j.append("]\n    }");
    }
    if (cr.pages.len > 0) j.append("\n  ");
    j.append("],\n");

    j.append("  \"resources\": [");
    for (usz i = 0; i < cr.resources.len; i++)
    {
        if (i > 0) j.append(',');
        j.append("\n    { \"url\": ");
        append_json_string(&j, cr.resources[i].url);
        j.append(", \"kind\": ");
        append_json_string(&j, cr.resources[i].kind);
        j.append(" }");
    }
    if (cr.resources.len > 0) j.append("\n  ");
    j.append("],\n");

    j.append("  \"errors\": [");
    for (usz i = 0; i < cr.errors.len; i++)
    {
        if (i > 0) j.append(',');
        j.append("\n    { \"url\": ");
        append_json_string(&j, cr.errors[i].url);
        j.append(", \"kind\": ");
        append_json_string(&j, cr.errors[i].kind);
        j.append(", \"message\": ");
        append_json_string(&j, cr.errors[i].message);
        j.append(" }");
    }
    if (cr.errors.len > 0) j.append("\n  ");
    j.append("]\n}\n");
    return j.str_view();
}
