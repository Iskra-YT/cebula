module cebula::fetch::fetch;

import std::io;
import std::io::file;
import cebula::cli::arguments;
import cebula::crawler::url_utils;
import cebula::network::http;
import cebula::network::response;

// Single-resource download: one request, no parsing, no frontier, no site walk.
fn int run_fetch(arguments::FetchOptions opts)
{
    @pool()
    {
        if (opts.timeout_sec < 1 || opts.max_body_bytes == 0)
        {
            io::eprintn("Error: invalid fetch limits (timeout/body size)");
            return 2;
        }

        String url = url_utils::normalize_url(opts.url);
        if (url.len == 0)
        {
            io::eprintn("Error: fetch requires a valid http:// or https:// URL");
            return 2;
        }

        response::HttpResponse resp = http::fetch_url(url, opts.timeout_sec, opts.user_agent, opts.max_body_bytes);

        io::eprintfn("cebula: GET %s", url);
        io::eprintfn("cebula: status %d -> %s", resp.status_code, resp.final_url);
        for (usz i = 0; i < resp.headers.len; i++)
        {
            io::eprintfn("cebula: header: %s", resp.headers[i]);
        }
        if (!resp.ok)
        {
            io::eprintfn("cebula: fetch failed (%s: %s)", resp.error_kind, resp.error_message);
        }

        if (resp.body.len > 0)
        {
            if (opts.has_output_path)
            {
                if (try file::save(opts.output_path, (char[])resp.body))
                {
                    io::eprintfn("cebula: wrote %s (%d bytes)", opts.output_path, resp.bytes_downloaded);
                }
                else
                {
                    io::eprintfn("cebula: could not write %s", opts.output_path);
                    return 1;
                }
            }
            else
            {
                io::print(resp.body);
            }
        }

        return resp.ok ? 0 : 1;
    };
}
