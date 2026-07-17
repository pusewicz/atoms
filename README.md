# atoms

Single-header C23 libraries ("atoms") — small, drop-in, STB-style.

| Atom | Summary | Source |
|------|---------|--------|
| **atom_log** | Column-aligned leveled logging | [`src/atom_log/`](src/atom_log/) |

## Install

**From a GitHub Release** (recommended):

```bash
curl -fsSL -o atom_log.h \
  https://github.com/pusewicz/atoms/releases/download/atom_log-v0.1.0/atom_log.h
```

**From source** (needs Ruby/Rake and a C23 compiler):

```bash
git clone https://github.com/pusewicz/atoms.git
cd atoms
rake dist          # → dist/atom_log.h
```

## Use

```c
#define ATOM_LOG_IMPLEMENTATION
#include "atom_log.h"

int main(void) {
  atom_log_init();
  atom_log_info("booted %d", 42);
  return 0;
}
```

## Documentation

- Per-atom narrative: `src/<lib>/README.md`
- Generated API site (after release): <https://pusewicz.github.io/atoms/>
- Agent / contributor rules: [`AGENTS.md`](AGENTS.md)

## Develop

```bash
bundle install     # rake, commonmarker (GFM), rouge
bundle exec rake test          # amalgamate + run suites
bundle exec rake docs          # GFM markdown + Rouge-highlighted static docs
bundle exec rake docs:serve    # build + serve at http://127.0.0.1:4000
bundle exec rake version:check
```

## License

[Zlib](LICENSE) — see the file at a specific commit SHA for the text that applied to a given release.
