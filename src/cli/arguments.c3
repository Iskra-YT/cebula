module cebula::cli::arguments;

struct CrawlOptions {
    String url;
    int max_depth;
    int max_pages;
    bool same_domain;
    bool follow_robots;
    int timeout_sec;
    int delay_ms;
    String user_agent;
    usz max_body_bytes;
    String output_path; // empty means stdout
    bool has_output_path;
}

fn CrawlOptions default_crawl_options(String url)
{
    CrawlOptions opt;
    opt.url = url;
    opt.max_depth = 3;
    opt.max_pages = 100;
    opt.same_domain = true;
    opt.follow_robots = true;
    opt.timeout_sec = 10;
    opt.delay_ms = 0;
    opt.user_agent = "cebula";
    opt.max_body_bytes = 5 * 1024 * 1024;
    opt.output_path = "";
    opt.has_output_path = false;
    return opt;
}
