# Changelog

All notable changes to **atom_log** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
