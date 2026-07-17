# AGENTS.md

## Project

Collection of STB-style single-header C23 libraries ("atoms"). Modular source
lives under `src/<lib>/`. Amalgamated headers are build products in `dist/`
(gitignored) and published as GitHub Release assets — never commit `dist/`.

## Commands

- `rake dist` / `rake dist:atom_log` — amalgamate headers into `dist/`
- `rake test` / `rake test:atom_log` / `rake test:atom_log:sdl`
- `rake example:atom_log` — build and run examples
- `rake docs` / `rake docs:check` / `rake docs:serve`
- `rake version` / `rake version:check` / `rake version:atom_log:bump[patch]`
- `rake release:atom_log` — promote changelog (VERSION unchanged)
- `rake release:atom_log:bump_next` — VERSION += patch after tagging
- `rake asan` — sanitizer build + tests
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
- C23; prefer standard types (`int`, `size_t`, `bool`).
- License: root `LICENSE` only; SPDX + SHA-pinned URL in banner (no footer dump).

## Documentation

- API docs generated from `public.h` comments → `rake docs`.
- Examples in `src/<lib>/examples/`; docs list and link all of them.
- Generated docs link back to repo resources at the build commit SHA.
- `rake docs:check`: public symbols documented; ≥1 example per lib.

## Testing

- Framework: pico_unit (`third_party/pico_unit.h`).
- Always test the amalgamated header (`rake test` ⇒ `dist` first).
- Core suites must not require SDL or network.
- Prefer fixing code over weakening assertions.

## Boundaries

- No CMake unless explicitly requested; Rake owns dist, tests, docs, release.
- Do not wire consumer games (e.g. Space Delivery) unless asked.
- Prefer small, reviewable diffs; match neighbouring atoms' style.
