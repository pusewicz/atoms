# Changelog

All notable changes to **atom_log** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed

- Docs: include detailed description paragraphs and `@c` / `@p` markup from
  `public.h` (e.g. `ATOM_LOG_COUNTOF` typeof / `_Generic` note).

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
