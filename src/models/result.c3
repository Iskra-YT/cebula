module cebula::models::result;

import cebula::models::page;

struct CrawlerMeta {
    String name;
    String version;
}

struct TaskInfo {
    String seed;
    String status; // "completed", "failed", etc.
    String started_at; // nullable/optional in schema example null; keep as strings for now
    bool has_started_at;
    String finished_at;
    bool has_finished_at;
}

struct Statistics {
    int pages_discovered;
    int pages_crawled;
    int pages_failed;
    int resources_discovered;
}

struct CrawlError {
    String url;
    String message;
    String kind; // e.g. "fetch", "parse", "robots", "timeout"
}

struct CrawlResult {
    CrawlerMeta crawler;
    TaskInfo task;
    Statistics stats;
    page::Page[] pages;
    page::Resource[] resources;
    CrawlError[] errors;
}
