module cebula::cli::arguments;

struct CrawlOptions {
    String url;
    int max_depth;
    int max_pages;
    bool same_domain;
    int timeout_sec;
    String output_path; // empty means stdout
    bool has_output_path;
}

fn CrawlOptions default_crawl_options(String url) {
    CrawlOptions opt;
    opt.url = url;
    opt.max_depth = 3;
    opt.max_pages = 100;
    opt.same_domain = true;
    opt.timeout_sec = 10;
    opt.output_path = "";
    opt.has_output_path = false;
    return opt;
}
