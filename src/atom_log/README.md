# atom_log

Column-aligned leveled logging for C23 — a thin wrapper over SDL3's log
system.

```
HH:MM:SS.mmm  INFO  src/game/ui.c:416                 message
```

atom_log installs a custom SDL log output function, so `atom_log_*` macros
and native `SDL_Log*` calls share one column layout. Requires SDL3
(`SDL3/SDL_log.h` on the include path; link `SDL3`).

## Quick start

```c
#define ATOM_LOG_IMPLEMENTATION
#include "atom_log.h"

int main(void) {
  atom_log_init();
  atom_log_info("booted %d", 42);
  return 0;
}
```

Install the latest released header from [`dist/atom_log.h`](../../dist/atom_log.h) (raw URL: `https://raw.githubusercontent.com/pusewicz/atoms/main/dist/atom_log.h`), pin a version via a [GitHub Release](https://github.com/pusewicz/atoms/releases), or build locally with `rake amalgamate` → `build/amalgam/atom_log.h`.

## Optional defines

| Define | Effect |
|--------|--------|
| `ATOM_LOG_IMPLEMENTATION` | Emit function bodies (once per program) |
| `ATOM_LOG_SHORT_NAMES` | Also define `log_info` / `fatal` / … |
| `ATOM_LOG_NO_COLOR` | Compile out ANSI color |
| `ATOM_LOG_PATH_MARKER` | Path component promoted to relative (default `"src"`) |
| `ATOM_LOG_STATIC` | Static linkage for single-TU embed |

## API summary

- `atom_log_init` — color detect, clear SDL prefixes, install the line formatter
- `atom_log_set_level` — minimum level (delegates to SDL; call after init)
- `atom_log_set_output` — send formatted lines to a custom writer
- `atom_log_message` / `atom_log_trace`…`atom_log_error` — emit lines
- `atom_log_fatal` / `atom_fatal` — log CRITICAL via SDL and abort

Full reference is generated into the docs site from comments on `public.h`.

## Examples

| File | Notes |
|------|--------|
| [`examples/hello.c`](examples/hello.c) | atom_log + native `SDL_Log` in one layout (needs SDL3) |

```bash
rake example:atom_log
```

## Develop

```bash
rake test:atom_log      # needs SDL3
rake example:atom_log
rake docs
```
