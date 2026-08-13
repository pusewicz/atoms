# Changelog

All notable changes to **atom_log** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Breaking:** SDL3 is now a required dependency; the logger is a thin
  wrapper over SDL's log system and the `ATOM_LOG_SDL` define is gone.
- **Breaking:** `atom_log_set_level` delegates to SDL
  (`SDL_SetLogPriority` on the custom log category). Call it after
  `atom_log_init`, which resets the minimum level to trace.
- `atom_log_fatal` now routes through SDL at CRITICAL priority instead of
  writing directly to stderr.
- American spelling throughout (`colour` → `color`); `colour.c` merged into
  `format.c`, `core.c` and `sdl.c` merged into `log.c`.
- Banner DISCOVERY URLs are tag-pinned instead of commit-SHA-pinned and gained
  a stable "Latest" raw URL; generated headers no longer embed a git SHA
  (starting with this release — earlier releases keep their SHA-pinned
  banners). The latest released header is now also committed at
  `dist/atom_log.h`.

### Removed

- Non-SDL stderr backend, the `rake test:atom_log:sdl` split suite, and the
  separate SDL example (`hello_sdl.c` merged into `hello.c`).
- **Breaking:** `ATOM_LOG_SHORT_NAMES` and the unprefixed aliases it defined
  (`log_trace`, `log_debug`, `log_info`, `log_warn`, `log_error`, `fatal`,
  `log_message`, `logger_init`). Use the `atom_log_*` / `atom_fatal` names
  directly.

## [0.1.1] - 2026-07-18
### Added

- SDL backend example (`examples/hello_sdl.c`); `rake example:atom_log` builds
  it when SDL3 is available.

### Removed

- `ATOM_LOG_COUNTOF` from the public API. The library itself never used it,
  and C2y standardises `countof`; the tests use that spelling (via
  `<stdcountof.h>` where available).

### Fixed

- Docs: include detailed description paragraphs and `@c` / `@p` markup from
  `public.h`.
- SDL backend: lines below SDL's default priority for the custom log category
  (INFO and lower in release builds, TRACE in debug) were silently dropped.
  `atom_log_init` now pins that category to trace, so `atom_log_set_level` is
  the only level filter.
- SDL backend: long messages no longer lose their tail to the internal
  location prefix.

## [0.1.0] - 2026-07-17
### Added

- Initial library: column-aligned leveled logging with optional SDL3 backend.
- Path rewriting for `src/` call sites, ANSI colour (TTY + `NO_COLOR`), fatal abort helper.
- Amalgamation via `rake dist`; core tests without SDL; optional SDL suite.
- `ATOM_LOG_COUNTOF` (`_Generic` + `typeof`) for fixed-array length.
- Tooling: pedantic/`-Werror` CFLAGS, `.editorconfig`, `.clang-format`, `.clang-tidy`.
- Docs: GitHub-Flavoured Markdown via commonmarker; Rouge (`github.light` /
  `github.dark`) for fenced code and API signatures.

### Changed

- C23 polish: typed enums, `constexpr`, `nullptr`, `[[noreturn]]` / `[[gnu::format]]`.
