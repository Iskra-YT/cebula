module cebula::network::response;

struct HttpResponse {
    int status_code;
    String content_type;
    String body;
    String final_url;
    bool ok;
    String error_message;
}
