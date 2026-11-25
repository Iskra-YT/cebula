module cebula::network::http;

import std::io;
import std::core::string;
import std::io::file;
import cebula::network::response;

extern fn int system(char* command) @extern("system");

fn response::HttpResponse fetch_url(String url, int timeout_sec) {
    response::HttpResponse res;
    res.status_code = 0;
    res.content_type = "";
    res.body = "";
    res.final_url = url;
    res.ok = false;
    res.error_message = "";

    // Use curl to fetch; write body to temp file and headers to another
    // This is a pragmatic workaround
    String tmpbody = "/tmp/cebula_body_tmp.txt";
    String tmpheaders = "/tmp/cebula_headers_tmp.txt";

    // Build command (very simplified; escaping is weak but OK for basic URLs)
    // Note: in production need proper escaping
    DString cmd;
    cmd.init(mem);
    defer cmd.free();
    cmd.appendf("curl -s -L --max-redirs 5 --max-time %d -D \"%s\" -o \"%s\" \"%s\" 2>/tmp/cebula_curl_err.txt", timeout_sec, tmpheaders, tmpbody, url);

    int rc = system((char*)cmd.str_view().ptr);
    if (rc != 0) {
        res.error_message = "curl failed or timed out";
        return res;
    }

    // read body
    if (file::exists(tmpbody)) {
        String? bodystr = (String)file::load_new(mem, tmpbody);
        if (try b = bodystr) {
            res.body = b;
        } else {
            res.body = "";
        }
    } else {
        res.body = "";
    }

    // read headers to extract status and content-type (simple parse of last status line)
    res.status_code = 200; // default assumption if we got body
    res.content_type = "text/html";
    if (file::exists(tmpheaders)) {
        String? hstr = (String)file::load_new(mem, tmpheaders);
        if (try h = hstr) {
            // naive parse: look for "HTTP/..." lines, take last
            // split by lines
            // very rough
            res.status_code = parse_last_status(h);
            res.content_type = parse_content_type(h);
        }
    }

    res.ok = true;
    return res;
}

fn int parse_last_status(String headers) {
    // look for lines starting with HTTP/
    int last_code = 0;
    usz i = 0;
    while (i < headers.len) {
        // find line start
        if (i + 5 <= headers.len) {
            // check "HTTP/"
            if (headers[i] == 'H' && headers[i+1] == 'T' && headers[i+2] == 'T' && headers[i+3] == 'P' && headers[i+4] == '/') {
                // find space, then code
                usz j = i + 5;
                while (j < headers.len && headers[j] != ' ') j++;
                if (j < headers.len && headers[j] == ' ') {
                    j++;
                    // parse 3 digits
                    int code = 0;
                    int digits = 0;
                    while (j < headers.len && headers[j] >= '0' && headers[j] <= '9' && digits < 3) {
                        code = code * 10 + (int)(headers[j] - '0');
                        j++; digits++;
                    }
                    if (digits == 3) last_code = code;
                }
            }
        }
        // next line
        while (i < headers.len && headers[i] != '\n') i++;
        i++;
    }
    if (last_code == 0) return 200;
    return last_code;
}

fn String parse_content_type(String headers) {
    // find "Content-Type:" (case-insensitive naive)
    String needle = "content-type:";
    usz i = 0;
    while (i + needle.len <= headers.len) {
        // compare case-insensitively
        bool match = true;
        for (usz k = 0; k < needle.len; k++) {
            char c = headers[i+k];
            if (c >= 'A' && c <= 'Z') c = (char)(c + 32);
            if (c != needle[k]) { match = false; break; }
        }
        if (match) {
            // extract value until \r or \n
            usz vstart = i + needle.len;
            // skip space
            while (vstart < headers.len && (headers[vstart] == ' ' || headers[vstart] == '\t')) vstart++;
            usz vend = vstart;
            while (vend < headers.len && headers[vend] != '\r' && headers[vend] != '\n') vend++;
            return headers[vstart..vend-1];
        }
        i++;
    }
    return "text/html";
}
