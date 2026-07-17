# atom_log

Column-aligned leveled logging for C23.

```
HH:MM:SS.mmm  INFO  src/game/ui.c:416                 message
```

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

Install the amalgamated header from a [GitHub Release](https://github.com/pusewicz/atoms/releases) or build locally with `rake dist` → `dist/atom_log.h`.

## Optional defines

| Define | Effect |
|--------|--------|
| `ATOM_LOG_IMPLEMENTATION` | Emit function bodies (once per program) |
| `ATOM_LOG_SDL` | SDL3 log backend + multi-module location packing |
| `ATOM_LOG_SHORT_NAMES` | Also define `log_info` / `fatal` / … |
| `ATOM_LOG_NO_COLOR` | Compile out ANSI colour |
| `ATOM_LOG_PATH_MARKER` | Path component promoted to relative (default `"src"`) |
| `ATOM_LOG_STATIC` | Static linkage for single-TU embed |

## API summary

- `atom_log_init` — colour detect, default stderr sink (and SDL install if enabled)
- `atom_log_set_level` — runtime minimum level
- `atom_log_set_output` — custom line writer
- `atom_log_message` / `atom_log_trace`…`atom_log_error` — emit lines
- `atom_log_fatal` / `atom_fatal` — log CRITICAL and abort

Full reference is generated into the docs site from comments on `public.h`.

## Examples

| File | Notes |
|------|--------|
| [`examples/hello.c`](examples/hello.c) | Core API, no dependencies |
| [`examples/hello_sdl.c`](examples/hello_sdl.c) | `ATOM_LOG_SDL` + native `SDL_Log` (needs SDL3) |

```bash
rake example:atom_log   # builds all; skips *_sdl if SDL3 is missing
```

## Develop

```bash
rake test:atom_log
rake test:atom_log:sdl   # needs SDL3
rake example:atom_log
rake docs
```
