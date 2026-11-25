module cebula::models::page;

import std::io;

struct Heading {
    int level;        // 1..6
    String text;
}

struct Image {
    String src;
    String alt;
    String absolute_url;
}

struct Link {
    String href;
    String anchor_text;
    String absolute_url;
    bool is_internal;
}

struct Resource {
    String url;
    String kind; // pdf, docx, xlsx, pptx, txt (best effort)
}

struct Page {
    String url;
    int status_code;
    String content_type;
    int depth;
    String discovered_from; // nullable represented as empty string? better use DString/option pattern; keep simple
    bool has_discovered_from;

    String title;
    String description;      // nullable
    bool has_description;
    String canonical_url;    // nullable
    bool has_canonical_url;
    String language;         // nullable
    bool has_language;

    Heading[] headings;
    Link[] links;
    Image[] images;
}
