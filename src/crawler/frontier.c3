module cebula::crawler::frontier;

import std::collections::deque;
import cebula::crawler::visited;

struct UrlItem {
    String url;
    int depth;
    String discovered_from;
}

struct Frontier {
    deque::Deque{UrlItem} queue;
    visited::VisitedSet seen;
}

fn void Frontier.init(&self)
{
    self.queue.init(tmem);
    self.seen.init();
}

fn bool Frontier.offer(&self, UrlItem item)
{
    if (item.url.len == 0) return false;
    if (!self.seen.add(item.url)) return false;
    self.queue.push(item);
    return true;
}

fn UrlItem? Frontier.poll(&self)
{
    return self.queue.pop_first();
}

fn sz Frontier.len(&self)
{
    return self.queue.len();
}
