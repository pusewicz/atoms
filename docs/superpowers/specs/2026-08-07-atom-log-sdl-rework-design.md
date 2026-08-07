# atom_log SDL rework — design

**Date:** 2026-08-07
**Status:** Approved

## Goal

Make atom_log a thin wrapper around SDL3 logging. Every game that uses this
logger incorporates SDL, so the non-SDL path is dead weight: remove the
`ATOM_LOG_SDL` feature define and the stderr fallback entirely. While at it,
switch all British spellings ("colour") to American ("color") in filenames,
code, comments, and docs.

## Decisions

- **Keep the formatter.** atom_log's column-aligned, colored, timestamped
  output is the library's value-add. It stays, installed as the SDL log
  output function. SDL's own categories (video, audio, …) keep getting
  formatted too.
- **Delegate level filtering to SDL.** No internal minimum-level state; SDL
  per-category priorities are the single source of truth.
- **Keep `atom_log_set_output`.** It receives fully formatted lines
  (downstream of the formatter) — not redundant with
  `SDL_SetLogOutputFunction`, which would replace the formatter.
- **Merge source around SDL.** Five impl fragments become three; the
  core/backend split no longer means anything.

## API & behavior (`public.h`)

Same API names, SDL-native semantics. SDL3 is a hard requirement.

- `atom_log_init()` — detect color (`NO_COLOR` + TTY), clear SDL priority
  prefixes, install the formatter via `SDL_SetLogOutputFunction`, set
  `SDL_LOG_CATEGORY_CUSTOM` to TRACE; in debug builds (`!NDEBUG`) set all
  categories to VERBOSE (unchanged behavior).
- `atom_log_set_level(min)` — calls
  `SDL_SetLogPriority(SDL_LOG_CATEGORY_CUSTOM, mapped)`. No internal filter.
- `atom_log_message(...)` — format into the 1024-byte buffer, pack the
  RS-marked location body, emit via
  `SDL_LogMessage(SDL_LOG_CATEGORY_CUSTOM, mapped)`. No level pre-check;
  SDL filters.
- `atom_log_fatal(...)` — **behavior fix:** previously bypassed SDL and wrote
  to stderr directly. Now routes through the same SDL path at
  `SDL_LOG_PRIORITY_CRITICAL`, then `abort()`. CRITICAL outranks every
  settable level, so it always prints.
- `atom_log_set_output`, `atom_log_debug_force_color` — kept, unchanged.
- Defines removed: `ATOM_LOG_SDL`.
  Defines kept: `ATOM_LOG_IMPLEMENTATION`, `ATOM_LOG_SHORT_NAMES`,
  `ATOM_LOG_NO_COLOR`, `ATOM_LOG_PATH_MARKER`, `ATOM_LOG_STATIC`.
- Logging before `atom_log_init()` works; lines appear in SDL's default
  format until the formatter is installed (as today).
- Call order: `atom_log_init()` resets the CUSTOM category to TRACE, so
  `atom_log_set_level` must be called after init (document in `public.h`).

## Source layout

```
src/atom_log/
  public.h    — API (same shape, updated docs)
  log.c       — init, set_level/set_output/force_color, message, fatal,
                SDL bridge: category labels, priority maps, RS location
                packing/unpacking, SDL output callback, install
  format.c    — AtomLogPrio, level tags, level colors, color detection
                (absorbed from colour.c), time column, write_line
  path.c      — src-relative locations (unchanged)
```

Deleted: `core.c`, `sdl.c`, `colour.c`.
`amalgamate.rb` `IMPL_ORDER`: `path.c format.c log.c`.
`<SDL3/SDL_log.h>` is included from the implementation section only; the
public API exposes no SDL types.

## Build, tests, examples

- `rakelib/atoms.rb` gains a per-lib "requires SDL" declaration
  (atom_log: yes). `test:atom_log`, `asan`, `example:atom_log`, and
  `compile_commands` use it to add SDL cflags/libs, and abort with the
  existing "SDL3 not found (pkg-config sdl3, or set SDL3_DIR / VCPKG_ROOT)"
  message when SDL3 is missing. Tests must not silently skip.
- `test:atom_log:sdl` task and the `_sdl` filename convention are removed.
- Tests merge into one `tests/test_atom_log.c` suite (SDL3 required):
  formatting/path/color cases plus SDL bridge cases (category labels,
  priority tags, RS splitting, trace-passes-after-init). The set_level test
  now exercises SDL priority filtering. `test_atom_log_sdl.c` deleted.
- Examples merge into one `examples/hello.c` (SDL3 required): atom_log
  macros plus a native `SDL_Log` line to show unified formatting.
  `hello_sdl.c` deleted.
- CI installs SDL3 on every matrix job already; no workflow changes
  expected.

## Docs, versioning, repo rules

- README and `banner.h.in`: SDL3 requirement stated up front, defines table
  updated, American spelling throughout.
- CHANGELOG `[Unreleased]` breaking-change bullets: SDL3 required,
  `ATOM_LOG_SDL` removed, set_level delegates to SDL, fatal routes through
  SDL.
- `VERSION`: 0.1.2 (unreleased) → **0.2.0**.
- `AGENTS.md`: reword "Zero hard deps in core" and "Core suites must not
  require SDL" — atoms may declare a hard dependency; atom_log's is SDL3.
  Command list drops `test:atom_log:sdl`.

## Out of scope

- Wiring consumer games (e.g. Space Delivery).
- New logging features (categories API, file sinks, etc.).
- Changing the output format itself.
