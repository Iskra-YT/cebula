module cebula::robots::robots;

import std::collections::list;
import cebula::robots::parser;
import cebula::network::http;
import cebula::network::response;
import cebula::crawler::url_utils;

struct RobotsEntry {
    String host;
    parser::RobotsRules rules;
}

struct RobotsCache {
    List{RobotsEntry} entries;
}

fn void RobotsCache.init(&self)
{
    self.entries.init(tmem);
}

fn parser::RobotsRules* entry_for(RobotsCache* cache, String url, String user_agent, int timeout_sec)
{
    String host = url_utils::get_authority(url);
    if (host.len == 0) return null;

    for (usz i = 0; i < (usz)cache.entries.len(); i++)
    {
        if (cache.entries[(sz)i].host == host)
        {
            RobotsEntry* found = cache.entries.get_ref((sz)i);
            return &found.rules;
        }
    }

    parser::RobotsRules rules;
    rules.rules = {};
    rules.sitemaps = {};
    rules.crawl_delay_ms = -1;

    String scheme = url_utils::get_scheme(url);
    if (scheme.len > 0)
    {
        DString robots_url;
        robots_url.init(tmem);
        robots_url.append(scheme);
        robots_url.append("://");
        robots_url.append(host);
        robots_url.append("/robots.txt");

        response::HttpResponse resp = http::fetch_url(robots_url.str_view(), timeout_sec, user_agent, 256 * 1024);
        if (resp.ok) rules = parser::parse_robots(resp.body, user_agent);
    }

    RobotsEntry entry;
    entry.host = host;
    entry.rules = rules;
    cache.entries.push(entry);
    RobotsEntry* added = cache.entries.get_ref((sz)(cache.entries.len() - 1));
    return &added.rules;
}

fn bool is_allowed(RobotsCache* cache, String url, String user_agent, int timeout_sec)
{
    parser::RobotsRules* rules = entry_for(cache, url, user_agent, timeout_sec);
    if (rules == null) return true;
    return parser::is_allowed(rules, url_utils::path_of(url));
}

fn int crawl_delay_ms(RobotsCache* cache, String url, String user_agent, int timeout_sec)
{
    parser::RobotsRules* rules = entry_for(cache, url, user_agent, timeout_sec);
    if (rules == null) return -1;
    return rules.crawl_delay_ms;
}
