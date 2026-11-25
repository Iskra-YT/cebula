module cebula::crawler::visited;

import std::collections::set;
import std::hash::fnv32a;

struct UrlKey {
    String url;
}

fn uint UrlKey.hash(&self)
{
    return fnv32a::hash(self.url);
}

fn bool UrlKey.equals(&self, UrlKey other)
{
    return self.url == other.url;
}

struct VisitedSet {
    set::HashSet{UrlKey} urls;
}

fn void VisitedSet.init(&self)
{
    self.urls.init(tmem);
}

fn bool VisitedSet.add(&self, String url)
{
    UrlKey key = { .url = url };
    return self.urls.add(key);
}

fn bool VisitedSet.contains(&self, String url)
{
    UrlKey key = { .url = url };
    return self.urls.contains(key);
}
