# AGENTS.md

## Project

Collection of STB-style single-header C23 libraries ("atoms"). Modular source
lives under `src/<lib>/`. Day-to-day amalgamated headers are build products in
`build/amalgam/` (gitignored). `dist/<lib>.h` is the **committed, released**
header (latest release; stable raw URL), written only by the release flow and
also published as a GitHub Release asset.

## Commands

- `rake amalgamate` / `rake amalgamate:atom_log` — amalgamate headers into `build/amalgam/`
- `rake test` / `rake test:atom_log` (needs SDL3)
- `rake example:atom_log` — build and run examples
- `rake docs` / `rake docs:serve` — local static site only (not run on PR CI)
- `rake docs:check` — validate symbols/examples without building HTML
- GitHub Pages: `docs.yml` (manual **Actions → Docs → Run workflow**, or
  called from `release.yml` on `*-v*` tags). Not on PR/`main` CI.
- `rake version` / `rake version:check` / `rake version:atom_log:bump[patch]`
- `rake release:atom_log` — promote changelog + write released `dist/atom_log.h` (VERSION unchanged)
- `rake release:atom_log:bump_next` — VERSION += patch after tagging
- `rake asan` — sanitizer build + tests
- `rake compile_commands` — clang compile database at repo root (builds tests + examples)
- `rake format` / `rake format:check` — clang-format
- `rake tidy` — clang-tidy over core test TUs
- `rake clean` / `rake clobber`

## Source vs dist

- Edit `src/<lib>/` only. Never hand-edit `dist/` or `build/`.
- After source changes, tests run `amalgamate` first automatically.
- `dist/<lib>.h` is committed, but **only** as part of a release commit
  (`rake release:<lib>`). Any other diff touching `dist/` is a bug.
- Never commit `build/`.

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

- `VERSION` is the version currently in progress (stamped into amalgams).
- Every user-visible change adds an `[Unreleased]` bullet in the same change.
- Release: agent skill **`/release-atom`** (see `.claude/skills/release-atom/`)
  or manual: `rake release:atom_log` → commit changelog + VERSION +
  `dist/atom_log.h` → tag `atom_log-v<VERSION>` → push tag (CI verifies the
  committed header, publishes asset + docs) → `rake release:atom_log:bump_next`.

## Single-header conventions

- STB pattern: `#define ATOM_<NAME>_IMPLEMENTATION` in exactly one TU.
- Public symbols prefixed `atom_<name>_…`; optional short-name defines.
- Banner: version, copyright, SPDX, tiny usage, DISCOVERY URLs (tag-pinned),
  scannable optional defines — no long essays.
- API docs: brief Doxygen on declarations in `public.h`.
- Keep dependencies minimal; an atom may declare a hard dependency when its domain demands it (atom_log requires SDL3). Optional extras stay behind feature defines.
- **C23, modern and strict:** `nullptr`, `constexpr`, typed enums (`enum E : int`),
  `[[noreturn]]` / `[[gnu::format]]`, `_Generic` / `typeof` when they clarify
  types. Prefer standard types (`int`, `size_t`, `bool`).
- **Warnings:** tests/examples compile with `-std=c23 -Wall -Wextra -Wpedantic
  -Werror` plus the curated set in `rakelib/cflags.rb`. `third_party/` is
  `-isystem`. Run `rake format` / `rake format:check` / `rake tidy`.
- Style: `.clang-format`, `.clang-tidy`, `.editorconfig` at repo root.
- License: root `LICENSE` only; SPDX + tag-pinned URL in banner (no footer dump).

## Documentation

- API docs generated from `public.h` comments → `rake docs` (local or Actions).
- Markdown via **commonmarker** (cmark-gfm) and **Rouge** (`Gemfile`).
- Examples in `src/<lib>/examples/`; docs must list and link all of them.
- Generated docs link back to repo resources at the build commit SHA.
- **Do not** build or deploy docs from PR/`main` CI — use `docs.yml`
  (workflow_dispatch) or a library release tag.

## Testing

- Framework: pico_unit (`third_party/pico_unit.h`).
- Always test the amalgamated header (`rake test` ⇒ `amalgamate` first).
- Suites must not require network. atom_log's suite requires SDL3 (CI installs it on every job; declared via `Atoms::SDL_REQUIRED`).
- Prefer fixing code over weakening assertions.
- CI matrix: **ubuntu-26.04** (clang + gcc 15), macOS (clang), Windows (LLVM
  clang). SDL3 via [libsdl-org/setup-sdl](https://github.com/libsdl-org/setup-sdl)
  (`SDL3_DIR` = action `prefix`). Locally: pkg-config, or set `SDL3_DIR` /
  `VCPKG_ROOT`. `CC=gcc` / `CC=clang`. Windows needs a C23-capable clang (not MSVC).

## Boundaries

- No CMake unless explicitly requested; Rake owns amalgamation, tests, docs, release.
- Do not wire consumer games (e.g. Space Delivery) unless asked.
- Prefer small, reviewable diffs; match neighbouring atoms' style.
