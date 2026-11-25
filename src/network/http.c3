module cebula::network::http;

import std::io;
import std::core::string;
import std::io::file;
import cebula::network::response;

extern fn int system(char* command);

fn response::HttpResponse fetch_url(String url, int timeout_sec) {
    response::HttpResponse res;
    res.status_code = 0;
    res.content_type = "";
    res.body = "";
    res.final_url = url;
    res.ok = false;
    res.error_message = "";

    String tmpbody = "/tmp/cebula_body_tmp.txt";
    String tmpheaders = "/tmp/cebula_headers_tmp.txt";

    DString cmd;
    cmd.init(mem);
    defer cmd.free();
    cmd.appendf("curl -s -L --max-redirs 5 --max-time %d -D \"%s\" -o \"%s\" \"%s\" 2>/tmp/cebula_curl_err.txt", timeout_sec, tmpheaders, tmpbody, url);

    int rc = system((char*)cmd.str_view().ptr);
    if (rc != 0) {
        res.error_message = "curl failed or timed out";
        return res;
    }

    if (file::exists(tmpbody)) {
        if (try data = file::load(mem, tmpbody)) {
            res.body = (String)data;
        } else {
            res.body = "";
        }
    } else {
        res.body = "";
    }

    res.status_code = 200;
    res.content_type = "text/html";
    if (file::exists(tmpheaders)) {
        if (try hdata = file::load(mem, tmpheaders)) {
            String hstr = (String)hdata;
            res.status_code = parse_last_status(hstr);
            res.content_type = parse_content_type(hstr);
        }
    }

    res.ok = true;
    return res;
}

fn int parse_last_status(String headers) {
    int last_code = 0;
    usz i = 0;
    while (i < headers.len) {
        if (i + 5 <= headers.len) {
            if (headers[i] == 'H' && headers[i+1] == 'T' && headers[i+2] == 'T' && headers[i+3] == 'P' && headers[i+4] == '/') {
                usz j = i + 5;
                while (j < headers.len && headers[j] != ' ') j++;
                if (j < headers.len && headers[j] == ' ') {
                    j++;
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
        while (i < headers.len && headers[i] != '\n') i++;
        i++;
    }
    if (last_code == 0) return 200;
    return last_code;
}

fn String parse_content_type(String headers) {
    String needle = "content-type:";
    usz i = 0;
    while (i + needle.len <= headers.len) {
        bool match = true;
        for (usz k = 0; k < needle.len; k++) {
            char c = headers[i+k];
            if (c >= 'A' && c <= 'Z') c = (char)(c + 32);
            if (c != needle[k]) { match = false; break; }
        }
        if (match) {
            usz vstart = i + needle.len;
            while (vstart < headers.len && (headers[vstart] == ' ' || headers[vstart] == '\t')) vstart++;
            usz vend = vstart;
            while (vend < headers.len && headers[vend] != '\r' && headers[vend] != '\n') vend++;
            return headers[vstart..vend-1];
        }
        i++;
    }
    return "text/html";
}
