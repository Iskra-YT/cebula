module cebula;
import std::io;
import cebula::core;

fn int main(String[] args) {
	if (args.len < 2) {
		io::printn("Usage: cebula <file>");
		return 1;
	}

	if (args[1] == "crawl") {
		if (args.len < 4) {
			io::printn("Usage: cebula crawl <type> <path>");
		}

		return core::crawl(args[2], args[3]);
	}

	return 0;
}
