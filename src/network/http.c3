module cebula::network::http;

import std::io;
import std::collections::list;
import std::os::process;
import cebula::network::response;
import cebula::crawler::url_utils;

const String META_BEGIN = "__cebula_META_BEGIN__";
const usz NOT_FOUND = usz::max;
const int CONNECT_TIMEOUT_SEC = 5;
const usz EXTRA_BUFFER_BYTES = 16 * 1024;

extern fn int usleep(uint usec) @cname("usleep");

fn usz last_index_of(String hay, String needle)
{
    if (needle.len == 0 || needle.len > hay.len) return NOT_FOUND;
    usz found = NOT_FOUND;
    for (usz i = 0; i + needle.len <= hay.len; i++)
    {
        if (url_utils::sub(hay, i, i + needle.len) == needle) found = i;
    }
    return found;
}

fn String next_line(String s, usz* pos)
{
    if (*pos >= s.len) return "";
    usz end = *pos;
    while (end < s.len && s[end] != '\n' && s[end] != '\r') end++;
    String line = url_utils::sub(s, *pos, end);
    *pos = end;
    if (*pos < s.len && s[*pos] == '\r') (*pos)++;
    if (*pos < s.len && s[*pos] == '\n') (*pos)++;
    return url_utils::trim(line);
}

fn String raw_line(String s, usz* pos)
{
    usz start = *pos;
    usz end = start;
    while (end < s.len && s[end] != '\n' && s[end] != '\r') end++;
    String line = url_utils::sub(s, start, end);
    *pos = end;
    if (*pos < s.len && s[*pos] == '\r') (*pos)++;
    if (*pos < s.len && s[*pos] == '\n') (*pos)++;
    return line;
}

// curl --dump-header - writes every response's headers before the body.
// Split those blocks off so callers see headers without them polluting body.
fn void split_headers(String payload, List{String}* headers, String* body)
{
    usz pos = 0;
    bool in_headers = false;
    while (pos < payload.len)
    {
        usz body_start = pos;
        String line = url_utils::trim(raw_line(payload, &pos));
        if (url_utils::starts_with_ignore_case(line, "HTTP/"))
        {
            in_headers = true;
            headers.push(line);
            continue;
        }
        if (!in_headers)
        {
            *body = url_utils::sub(payload, body_start, payload.len);
            return;
        }
        if (line.len == 0)
        {
            in_headers = false;
            usz peek = pos;
            String next = url_utils::trim(raw_line(payload, &peek));
            if (url_utils::starts_with_ignore_case(next, "HTTP/")) continue;
            *body = url_utils::sub(payload, pos, payload.len);
            return;
        }
        headers.push(line);
    }
    *body = "";
}

fn int parse_status(String line)
{
    int code = 0;
    usz digits = 0;
    for (usz i = 0; i < line.len && digits < 3; i++)
    {
        if (line[i] < '0' || line[i] > '9') break;
        code = code * 10 + (int)(line[i] - '0');
        digits++;
    }
    return digits == 3 ? code : 0;
}

fn usz parse_size(String line)
{
    usz size = 0;
    usz digits = 0;
    for (usz i = 0; i < line.len; i++)
    {
        if (line[i] < '0' || line[i] > '9') break;
        size = size * 10 + (usz)(line[i] - '0');
        digits++;
    }
    return digits > 0 ? size : 0;
}

fn String curl_error_kind(int rc)
{
    switch (rc)
    {
        case 3: return "invalid_url";
        case 6: return "dns";
        case 7: return "connect";
        case 28: return "timeout";
        case 35: return "tls";
        case 47: return "redirect";
        case 60: return "tls";
        case 63: return "too_large";
        default: return "fetch";
    }
}

fn String curl_error_message(int rc)
{
    switch (rc)
    {
        case 3: return "Malformed URL";
        case 6: return "Could not resolve host";
        case 7: return "Could not connect to host";
        case 28: return "Request timed out";
        case 35: return "TLS handshake failed";
        case 47: return "Too many redirects";
        case 60: return "TLS certificate verification failed";
        case 63: return "Response body exceeds the size limit";
        default: return "curl failed with code";
    }
}

fn response::HttpResponse fetch_url(String url, int timeout_sec, String user_agent, usz max_body_bytes)
{
    response::HttpResponse res;
    res.status_code = 0;
    res.content_type = "";
    res.body = "";
    res.final_url = url;
    res.ok = false;
    res.error_kind = "";
    res.error_message = "";
    res.bytes_downloaded = 0;
    res.headers = {};

    String normalized = url_utils::normalize_url(url);
    if (normalized.len == 0)
    {
        res.error_kind = "invalid_url";
        res.error_message = "Only valid http/https URLs are supported";
        return res;
    }

    DString timeout_str;
    timeout_str.init(tmem);
    timeout_str.appendf("%d", timeout_sec);
    DString limit_str;
    limit_str.init(tmem);
    limit_str.appendf("%d", (int)max_body_bytes);

    String ua = user_agent.len > 0 ? user_agent : "CebulaBot/0.1";
    String[20] cmd = {
        "curl", "--silent", "--show-error", "--location", "--max-redirs", "5",
        "--max-time", timeout_str.str_view(), "--connect-timeout", "5", "--compressed",
        "--max-filesize", limit_str.str_view(), "--user-agent", ua,
        "--dump-header", "-",
        "--write-out", "\n__cebula_META_BEGIN__\n%{http_code}\n%{url_effective}\n%{content_type}\n%{size_download}\n__cebula_META_END__\n",
        ""
    };
    usz count = 20;
    cmd[count - 1] = normalized;

    Process? spawned = process::spawn(cmd[0..count - 1], SpawnOptions.INHERIT_ENV, {},
                                      process::INHERIT, process::CAPTURE, process::INHERIT);
    if (try Process p = spawned)
    {
        defer (void)p.destroy();

        usz capacity = max_body_bytes + EXTRA_BUFFER_BYTES;
        char[] buf = mem::talloc_array(char, (sz)capacity);
        usz used = 0;
        while (used < capacity)
        {
            sz? n = p.read_stdout(buf.ptr + used, (sz)(capacity - used));
            if (try sz n2 = n)
            {
                if (n2 == 0) break;
                used += (usz)n2;
            }
            else
            {
                res.error_kind = "fetch";
                res.error_message = "Failed to read response body";
                return res;
            }
        }

        int rc = 0;
        if (try int joined = p.join())
        {
            rc = joined;
        }
        else
        {
            res.error_kind = "fetch";
            res.error_message = "Failed to wait for curl";
            return res;
        }

        String output = used > 0 ? (String)buf[:used - 1] : "";
        usz marker = last_index_of(output, META_BEGIN);
        if (marker == NOT_FOUND)
        {
            if (rc != 0)
            {
                res.error_kind = curl_error_kind(rc);
                res.error_message = curl_error_message(rc);
            }
            else
            {
                res.error_kind = "parse";
                res.error_message = "Missing response metadata";
            }
            return res;
        }

        String payload = url_utils::sub(output, 0, marker);
        while (payload.len > 0 && (payload[payload.len - 1] == '\n' || payload[payload.len - 1] == '\r'))
        {
            payload = url_utils::sub(payload, 0, payload.len - 1);
        }

        List{String} headers;
        headers.init(tmem);
        String body;
        split_headers(payload, &headers, &body);
        res.headers = headers.array_view();

        usz pos = marker + META_BEGIN.len;
        while (pos < output.len && (output[pos] == '\n' || output[pos] == '\r')) pos++;
        String status_line = next_line(output, &pos);
        String final_url_line = next_line(output, &pos);
        String content_type_line = next_line(output, &pos);
        String size_line = next_line(output, &pos);

        res.status_code = parse_status(status_line);
        res.final_url = final_url_line.len > 0 ? final_url_line : normalized;
        res.content_type = content_type_line;
        res.body = body;
        res.bytes_downloaded = body.len;
        if (size_line.len > 0)
        {
            usz size = parse_size(size_line);
            if (size > 0) res.bytes_downloaded = size;
        }

        if (rc != 0)
        {
            res.error_kind = curl_error_kind(rc);
            res.error_message = curl_error_message(rc);
            return res;
        }
        if (res.status_code < 200 || res.status_code >= 300)
        {
            res.error_kind = "http_status";
            res.error_message = "HTTP status";
            return res;
        }
        res.ok = true;
        return res;
    }
    else
    {
        res.error_kind = "curl_missing";
        res.error_message = "Unable to start curl";
        return res;
    }
}
