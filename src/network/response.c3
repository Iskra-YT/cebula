module cebula::network::response;

struct HttpResponse {
    int status_code;
    String content_type;
    String body;
    String final_url;
    bool ok;
    String error_kind;
    String error_message;
    usz bytes_downloaded;
    String[] headers; // raw header lines from every response, including redirects
}
