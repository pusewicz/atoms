# AGENTS.md

## Project

Collection of STB-style single-header C23 libraries ("atoms"). Modular source
lives under `src/<lib>/`. Amalgamated headers are build products in `dist/`
(gitignored) and published as GitHub Release assets — never commit `dist/`.

## Commands

- `rake dist` / `rake dist:atom_log` — amalgamate headers into `dist/`
- `rake test` / `rake test:atom_log` / `rake test:atom_log:sdl`
- `rake example:atom_log` — build and run examples
- `rake docs` / `rake docs:serve` — local static site only (not run on PR CI)
- `rake docs:check` — validate symbols/examples without building HTML
- GitHub Pages is built and deployed **only on library release tags**
  (`release.yml` after `atom_log-v*`)
- `rake version` / `rake version:check` / `rake version:atom_log:bump[patch]`
- `rake release:atom_log` — promote changelog (VERSION unchanged)
- `rake release:atom_log:bump_next` — VERSION += patch after tagging
- `rake asan` — sanitizer build + tests
- `rake format` / `rake format:check` — clang-format
- `rake tidy` — clang-tidy over core test TUs
- `rake clean` / `rake clobber`

## Source vs dist

- Edit `src/<lib>/` only. Never hand-edit `dist/`.
- After source changes, tests run `dist` first automatically.
- Never commit `dist/` or `build/`.

## Layout

- `src/<lib>/public.h` — public API (docs parse target)
- `src/<lib>/*.c` — implementation fragments (amalgamated)
- `src/<lib>/VERSION` — single-line semver (in-progress version)
- `src/<lib>/CHANGELOG.md` — Keep a Changelog; `## [Unreleased]` first
- `src/<lib>/examples/` — runnable samples (docs must link all of them)
- `src/<lib>/tests/` — pico_unit suites
- `site/` — docs HTML/CSS chrome only
- `rakelib/` — all Rake logic

## Versioning

- `VERSION` is the version currently in progress (stamped into dist).
- Every user-visible change adds an `[Unreleased]` bullet in the same change.
- Release: `rake release:atom_log` → commit → tag `atom_log-v<VERSION>` → push
  tag (CI publishes asset + docs) → `rake release:atom_log:bump_next`.

## Single-header conventions

- STB pattern: `#define ATOM_<NAME>_IMPLEMENTATION` in exactly one TU.
- Public symbols prefixed `atom_<name>_…`; optional short-name defines.
- Banner: version, copyright, SPDX, tiny usage, DISCOVERY URLs (SHA-pinned),
  scannable optional defines — no long essays.
- API docs: brief Doxygen on declarations in `public.h`.
- Zero hard deps in core; optional backends behind feature defines.
- **C23, modern and strict:** `nullptr`, `constexpr`, typed enums (`enum E : int`),
  `[[noreturn]]` / `[[gnu::format]]`, `_Generic` / `typeof` when they clarify
  types (e.g. `ATOM_LOG_COUNTOF`). Prefer standard types (`int`, `size_t`, `bool`).
- **Warnings:** tests/examples compile with `-std=c23 -Wall -Wextra -Wpedantic
  -Werror` plus the curated set in `rakelib/cflags.rb`. `third_party/` is
  `-isystem`. Run `rake format` / `rake format:check` / `rake tidy`.
- Style: `.clang-format`, `.clang-tidy`, `.editorconfig` at repo root.
- License: root `LICENSE` only; SPDX + SHA-pinned URL in banner (no footer dump).

## Documentation

- API docs generated from `public.h` comments → `rake docs` (local / release only).
- Markdown via **commonmarker** (cmark-gfm) and **Rouge** (`Gemfile`).
- Examples in `src/<lib>/examples/`; docs must list and link all of them.
- Generated docs link back to repo resources at the build commit SHA.
- **Do not** build or deploy docs from PR/`main` CI — only `release.yml` on tags.

## Testing

- Framework: pico_unit (`third_party/pico_unit.h`).
- Always test the amalgamated header (`rake test` ⇒ `dist` first).
- Core suites must not require SDL or network.
- Prefer fixing code over weakening assertions.
- CI matrix: Ubuntu (clang + gcc), macOS (clang), Windows (LLVM clang, core
  only — no SDL). Set `CC=gcc` / `CC=clang` locally. Windows needs a C23-capable
  clang (not MSVC).

## Boundaries

- No CMake unless explicitly requested; Rake owns dist, tests, docs, release.
- Do not wire consumer games (e.g. Space Delivery) unless asked.
- Prefer small, reviewable diffs; match neighbouring atoms' style.
