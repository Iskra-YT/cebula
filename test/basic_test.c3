module cebula::test;

import std::core::test;
import cebula::crawler::url_utils;
import cebula::parser::html;
import cebula::robots::parser;
import cebula::output::json_out;
import cebula::models::page;

fn void test_normalize_url() @test
{
    @pool()
    {
        test::eq("https://example.com/", url_utils::normalize_url("HTTPS://Example.COM:443"));
        test::eq("http://example.com/a/b", url_utils::normalize_url("http://example.com/a/./b#frag"));
        test::eq("http://example.com/b", url_utils::normalize_url("http://example.com/a/../b"));
        test::eq("http://example.com/", url_utils::normalize_url("http://example.com:80"));
        test::eq("http://example.com:8080/x", url_utils::resolve_url("http://example.com:8080/a", "/x"));
        test::eq("", url_utils::normalize_url("not a url"));
        test::eq("", url_utils::normalize_url("ftp://example.com"));
        test::eq("", url_utils::normalize_url("http://example.com/a\"b"));
    };
}

fn void test_resolve_url() @test
{
    @pool()
    {
        String base = "https://example.com/dir/page.html?x=1";
        test::eq("https://example.com/dir/other.html", url_utils::resolve_url(base, "other.html"));
        test::eq("https://example.com/root", url_utils::resolve_url(base, "/root"));
        test::eq("https://cdn.example.com/x", url_utils::resolve_url(base, "//cdn.example.com/x"));
        test::eq("https://example.com/dir/page.html?y=2", url_utils::resolve_url(base, "?y=2"));
        test::eq("", url_utils::resolve_url(base, "javascript:alert(1)"));
        test::eq("", url_utils::resolve_url(base, "#section"));
    };
}

fn void test_same_site() @test
{
    @pool()
    {
        test::eq(true, url_utils::same_site("https://example.com/a", "http://blog.example.com/b"));
        test::eq(false, url_utils::same_site("https://example.com/a", "https://evil-example.com/b"));
    };
}

fn void test_html_extraction() @test
{
    @pool()
    {
        String sample = "<html lang=\"en\"><head><title>Hello &amp; World</title>"
                        "<meta name=\"description\" content=\"Desc here\">"
                        "<link rel=\"canonical\" href=\"/index.html\"></head>"
                        "<body><h1>Welcome</h1><h2>More</h2>"
                        "<a href=\"page2.html\">Page two</a>"
                        "<a href=\"doc.pdf\">PDF</a>"
                        "<a href=\"javascript:alert(1)\">JS</a>"
                        "<img src=\"/img.png\" alt=\"Picture\"></body></html>";
        String base = "https://example.com/dir/page.html";
        test::eq("Hello & World", html::page_title(sample));
        test::eq("Desc here", html::meta_description(sample));
        test::eq("en", html::language(sample));
        test::eq("/index.html", html::canonical_url(sample));

        page::Heading[] headings = html::headings(sample);
        test::eq(2, (int)headings.len);
        test::eq("Welcome", headings[0].text);
        test::eq(1, headings[0].level);

        page::Link[] links = html::links(sample, base);
        test::eq(2, (int)links.len);
        test::eq("https://example.com/dir/page2.html", links[0].absolute_url);
        test::eq("Page two", links[0].anchor_text);
        test::eq(true, links[0].is_internal);

        page::Image[] images = html::images(sample, base);
        test::eq(1, (int)images.len);
        test::eq("Picture", images[0].alt);

        page::Resource[] resources = html::resources(sample, base);
        test::eq(1, (int)resources.len);
        test::eq("pdf", resources[0].kind);
    };
}

fn void test_html_skips_hidden_text() @test
{
    @pool()
    {
        String sample = "<html><head><!-- <title>Fake</title> --><title>Real</title>"
                        "<script>var x = '<a href=\"/bad\">bad</a>';</script></head>"
                        "<body><a href=\"/good\">Good</a></body></html>";
        test::eq("Real", html::page_title(sample));
        page::Link[] links = html::links(sample, "https://example.com/");
        test::eq(1, (int)links.len);
        test::eq("https://example.com/good", links[0].absolute_url);
    };
}

fn void test_robots() @test
{
    @pool()
    {
        String content = "User-agent: CebulaBot\nDisallow: /bot-blocked/\n\n"
                         "User-agent: *\nDisallow: /private/\nAllow: /private/public\n"
                         "Crawl-delay: 2\nSitemap: https://example.com/sitemap.xml\n\n"
                         "User-agent: BadBot\nDisallow: /\n";
        parser::RobotsRules rules = parser::parse_robots(content, "CebulaBot/0.1");
        test::eq(2000, rules.crawl_delay_ms);
        test::eq(1, (int)rules.sitemaps.len);
        test::eq(false, parser::is_allowed(&rules, "/bot-blocked/page"));
        test::eq(false, parser::is_allowed(&rules, "/private/secret"));
        test::eq(true, parser::is_allowed(&rules, "/private/public/page"));
        test::eq(true, parser::is_allowed(&rules, "/public"));

        // "User-agent: CebulaBot" also matches a crawler identifying as CebulaBot.
        parser::RobotsRules short_ua = parser::parse_robots(content, "CebulaBot");
        test::eq(false, parser::is_allowed(&short_ua, "/bot-blocked/page"));

        // Unrelated crawlers only see the wildcard group.
        parser::RobotsRules other_ua = parser::parse_robots(content, "OtherBot/1.0");
        test::eq(true, parser::is_allowed(&other_ua, "/bot-blocked/page"));
        test::eq(false, parser::is_allowed(&other_ua, "/private/secret"));
    };
}

fn void test_robots_version_rule() @test
{
    @pool()
    {
        String content = "User-agent: CebulaBot/0.1\nDisallow: /v1/\n";
        parser::RobotsRules rules = parser::parse_robots(content, "CebulaBot");
        test::eq(false, parser::is_allowed(&rules, "/v1/page"));
        test::eq(true, parser::is_allowed(&rules, "/v2/page"));

        parser::RobotsRules lower = parser::parse_robots(content, "cebulabot/0.1");
        test::eq(false, parser::is_allowed(&lower, "/v1/page"));
    };
}

fn void test_json_escape() @test
{
    @pool()
    {
        test::eq("\"a\\\"b\\\\c\\n\"", json_out::json_escape("a\"b\\c\n"));
        test::eq("\"ok\"", json_out::json_escape("ok"));
    };
}
