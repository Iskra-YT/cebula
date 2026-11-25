module cebula::robots::parser;

import std::collections::list;
import cebula::crawler::url_utils;

const usz NOT_FOUND = usz::max;

struct Rule {
    bool is_allow;
    String path;
}

struct RobotsRules {
    Rule[] rules;
    String[] sitemaps;
    int crawl_delay_ms; // -1 when not set
}

fn RobotsRules parse_robots(String content, String ua_name)
{
    RobotsRules rr;
    List{String} sitemaps;
    sitemaps.init(tmem);
    List{Rule} rules;
    rules.init(tmem);
    rr.crawl_delay_ms = -1;

    bool group_matches = false;
    bool group_has_agent = false;
    bool group_has_rule = false;
    usz i = 0;

    while (i < content.len)
    {
        usz line_end = i;
        while (line_end < content.len && content[line_end] != '\n' && content[line_end] != '\r') line_end++;
        String line = url_utils::trim(url_utils::sub(content, i, line_end));
        i = line_end;
        while (i < content.len && (content[i] == '\n' || content[i] == '\r')) i++;

        if (line.len == 0 || line[0] == '#') continue;
        usz colon = url_utils::find_char(line, ':', 0);
        if (colon == NOT_FOUND) continue;
        String key = url_utils::lower_copy(url_utils::trim(url_utils::sub(line, 0, colon)));
        String value = url_utils::trim(url_utils::sub(line, colon + 1, line.len));

        if (key == "user-agent")
        {
            if (!group_has_agent || group_has_rule)
            {
                group_matches = value == "*" || (ua_name.len > 0 && url_utils::contains_ignore_case(value, ua_name));
                group_has_agent = true;
                group_has_rule = false;
            }
            else
            {
                if (value == "*" || (ua_name.len > 0 && url_utils::contains_ignore_case(value, ua_name))) group_matches = true;
            }
            continue;
        }

        if (key == "sitemap")
        {
            if (value.len > 0) sitemaps.push(value);
            continue;
        }

        if (!group_matches || value.len == 0) continue;
        group_has_rule = true;

        if (key == "disallow" || key == "allow")
        {
            if (value == "*" && key == "allow")
            {
                Rule rule = { .is_allow = true, .path = "/" };
                rules.push(rule);
                continue;
            }
            Rule rule;
            rule.is_allow = key == "allow";
            rule.path = value;
            rules.push(rule);
        }
        else if (key == "crawl-delay")
        {
            int delay = 0;
            usz digits = 0;
            for (usz j = 0; j < value.len; j++)
            {
                if (value[j] < '0' || value[j] > '9') break;
                delay = delay * 10 + (int)(value[j] - '0');
                digits++;
            }
            if (digits > 0) rr.crawl_delay_ms = delay * 1000;
        }
    }

    rr.rules = rules.array_view();
    rr.sitemaps = sitemaps.array_view();
    return rr;
}

fn bool is_allowed(RobotsRules* rules, String path)
{
    int best_length = -1;
    bool best_allow = true;
    for (usz i = 0; i < rules.rules.len; i++)
    {
        String prefix = rules.rules[i].path;
        if (prefix.len == 0) continue;
        if (prefix.len > path.len) continue;
        if (!url_utils::eq_ignore_case(url_utils::sub(path, 0, prefix.len), prefix)) continue;
        if ((int)prefix.len > best_length || ((int)prefix.len == best_length && rules.rules[i].is_allow))
        {
            best_length = (int)prefix.len;
            best_allow = rules.rules[i].is_allow;
        }
    }
    return best_allow;
}
