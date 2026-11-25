module cebula::crawler::crawler;

import std::io;
import std::io::file;
import std::collections::list;
import std::time::datetime;
import cebula::cli::arguments;
import cebula::crawler::frontier;
import cebula::crawler::scheduler;
import cebula::crawler::url_utils;
import cebula::models::result;
import cebula::models::page;
import cebula::network::http;
import cebula::network::response;
import cebula::output::json_out;
import cebula::parser::html;
import cebula::robots::robots;

fn String timestamp()
{
    return datetime::now().format(tmem, datetime::DateTimeFormat.RFC3339);
}

fn bool is_html(String content_type)
{
    if (content_type.len == 0) return true;
    return url_utils::contains_ignore_case(content_type, "html");
}

fn void add_error(List{result::CrawlError}* errors, String url, String kind, String message)
{
    result::CrawlError err;
    err.url = url;
    err.kind = kind;
    err.message = message;
    errors.push(err);
}

fn page::Page make_page(frontier::UrlItem item, response::HttpResponse* resp)
{
    page::Page p;
    p.url = item.url;
    p.status_code = resp.status_code;
    p.content_type = resp.content_type;
    p.depth = item.depth;
    p.has_discovered_from = item.discovered_from.len > 0;
    p.discovered_from = item.discovered_from;
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
    return p;
}

fn int run_crawl(arguments::CrawlOptions opts)
{
    @pool()
    {
        if (opts.max_depth < 0 || opts.max_pages < 1 || opts.timeout_sec < 1 || opts.delay_ms < 0 || opts.max_body_bytes == 0)
        {
            io::eprintn("Error: invalid crawl limits (depth/pages/timeout/delay/body size)");
            return 2;
        }

        String seed = url_utils::normalize_url(opts.url);
        if (seed.len == 0)
        {
            io::eprintn("Error: seed must be a valid http:// or https:// URL");
            return 2;
        }

        io::eprintfn("cebula: crawling %s (depth=%d pages=%d timeout=%ds)", seed, opts.max_depth, opts.max_pages, opts.timeout_sec);

        result::CrawlResult cr;
        cr.crawler.name = "cebula";
        cr.crawler.version = "0.1.0";
        cr.task.seed = seed;
        cr.task.status = "running";
        cr.task.started_at = timestamp();
        cr.task.has_started_at = true;
        cr.task.finished_at = "";
        cr.task.has_finished_at = false;
        cr.stats.pages_discovered = 1;
        cr.stats.pages_crawled = 0;
        cr.stats.pages_failed = 0;
        cr.stats.resources_discovered = 0;
        cr.pages = {};
        cr.resources = {};
        cr.errors = {};

        List{page::Page} pages;
        pages.init(tmem);
        List{page::Resource} resources;
        resources.init(tmem);
        List{result::CrawlError} errors;
        errors.init(tmem);

        frontier::Frontier queue;
        queue.init();
        frontier::UrlItem seed_item;
        seed_item.url = seed;
        seed_item.depth = 0;
        seed_item.discovered_from = "";
        (void)queue.offer(seed_item);

        robots::RobotsCache robots_cache;
        robots_cache.init();
        scheduler::reset();

        int discovered = 1;
        while ((cr.stats.pages_crawled + cr.stats.pages_failed) < opts.max_pages && queue.len() > 0)
        {
            frontier::UrlItem? next = queue.poll();
            if (try frontier::UrlItem item = next)
            {
                if (item.depth > opts.max_depth) continue;
                if (opts.same_domain && !url_utils::same_site(seed, item.url)) continue;

                if (opts.follow_robots && !robots::is_allowed(&robots_cache, item.url, opts.user_agent, opts.timeout_sec))
                {
                    add_error(&errors, item.url, "robots", "Blocked by robots.txt");
                    continue;
                }

                int robots_delay = opts.follow_robots ? robots::crawl_delay_ms(&robots_cache, item.url, opts.user_agent, opts.timeout_sec) : -1;
                scheduler::before_request(item.url, robots_delay, opts.delay_ms);

                response::HttpResponse resp = http::fetch_url(item.url, opts.timeout_sec, opts.user_agent, opts.max_body_bytes);
                page::Page p = make_page(item, &resp);

                if (resp.ok)
                {
                    cr.stats.pages_crawled++;
                    io::eprintfn("cebula: [%d] %s (%d)", cr.stats.pages_crawled, item.url, resp.status_code);

                    if (is_html(resp.content_type))
                    {
                        String base = resp.final_url.len > 0 ? resp.final_url : item.url;
                        p.title = html::page_title(resp.body);
                        String description = html::meta_description(resp.body);
                        if (description.len > 0)
                        {
                            p.description = description;
                            p.has_description = true;
                        }
                        String canonical = html::canonical_url(resp.body);
                        if (canonical.len > 0)
                        {
                            String absolute = url_utils::resolve_url(base, canonical);
                            p.canonical_url = absolute.len > 0 ? absolute : canonical;
                            p.has_canonical_url = true;
                        }
                        String lang = html::language(resp.body);
                        if (lang.len > 0)
                        {
                            p.language = lang;
                            p.has_language = true;
                        }
                        p.headings = html::headings(resp.body);
                        p.links = html::links(resp.body, base);
                        p.images = html::images(resp.body, base);

                        page::Resource[] found_resources = html::resources(resp.body, base);
                        for (usz r = 0; r < found_resources.len; r++)
                        {
                            bool duplicate = false;
                            for (usz k = 0; k < (usz)resources.len(); k++)
                            {
                                if (resources[(sz)k].url == found_resources[r].url)
                                {
                                    duplicate = true;
                                    break;
                                }
                            }
                            if (duplicate) continue;
                            resources.push(found_resources[r]);
                            discovered++;
                        }

                        for (usz l = 0; l < p.links.len; l++)
                        {
                            if (opts.same_domain && !p.links[l].is_internal) continue;
                            if (html::resource_kind(p.links[l].absolute_url).len > 0) continue;
                            frontier::UrlItem next_item;
                            next_item.url = p.links[l].absolute_url;
                            next_item.depth = item.depth + 1;
                            next_item.discovered_from = item.url;
                            if (queue.offer(next_item)) discovered++;
                        }
                    }
                }
                else
                {
                    cr.stats.pages_failed++;
                    add_error(&errors, item.url, resp.error_kind, resp.error_message);
                    io::eprintfn("cebula: failed %s (%s: %s)", item.url, resp.error_kind, resp.error_message);
                }

                pages.push(p);
            }
            else
            {
                break;
            }
        }

        cr.stats.pages_discovered = discovered;
        cr.stats.resources_discovered = (int)resources.len();
        cr.pages = pages.array_view();
        cr.resources = resources.array_view();
        cr.errors = errors.array_view();
        cr.task.finished_at = timestamp();
        cr.task.has_finished_at = true;
        cr.task.status = cr.stats.pages_crawled == 0 ? "failed" :
                          (cr.stats.pages_failed > 0 ? "completed_with_errors" : "completed");

        String json = json_out::render_result(&cr);
        if (opts.has_output_path)
        {
            if (try file::save(opts.output_path, (char[])json))
            {
                io::eprintfn("cebula: wrote %s", opts.output_path);
            }
            else
            {
                io::eprintfn("cebula: could not write %s", opts.output_path);
                return 1;
            }
        }
        else
        {
            io::print(json);
        }

        return cr.stats.pages_crawled > 0 ? 0 : 1;
    };
}
