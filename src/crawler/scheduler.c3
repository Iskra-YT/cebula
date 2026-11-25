module cebula::crawler::scheduler;

import cebula::crawler::url_utils;

extern fn int usleep(uint usec) @cname("usleep");

String last_host = "";
bool has_last_host = false;

// Requests are processed sequentially, so politeness is enforced per host.
fn void before_request(String url, int robots_delay_ms, int configured_delay_ms)
{
    String host = url_utils::get_host(url);
    int delay = configured_delay_ms > robots_delay_ms ? configured_delay_ms : robots_delay_ms;
    if (delay < 0) delay = 0;
    if (has_last_host && last_host == host && delay > 0) (void)usleep((uint)(delay * 1000));
    has_last_host = true;
    last_host = host;
}

fn void reset()
{
    has_last_host = false;
    last_host = "";
}
