# Copilot instructions — atoms

Collection of STB-style single-header **C23** libraries. Modular source lives
in `src/<lib>/`; day-to-day amalgamated headers are build products in
`build/amalgam/` (gitignored). `dist/<lib>.h` is the committed, released
header, written only by the release flow and also published via GitHub
Releases. Rake owns amalgamation, tests, docs, and release — no CMake.

## Hard rules (flag any violation)

- `build/` files must never appear in a diff; `dist/<lib>.h` may change only
  in a release commit (written by `rake release:<lib>`, never hand-edited).
  Edits belong in `src/<lib>/` only.
- Every user-visible change needs a bullet under `## [Unreleased]` in
  `src/<lib>/CHANGELOG.md` in the same PR (Keep a Changelog format).
- Public API changes must update the Doxygen comments in `src/<lib>/public.h`
  (docs are generated from it), plus examples and `src/<lib>/README.md` when
  relevant.
- Core code has no network dependency. An atom may declare a hard library
  dependency instead (e.g. atom_log requires SDL3, via `Atoms::SDL_REQUIRED`
  in `rakelib/atoms.rb`); its pico_unit suite may then require that library.
- Prefer fixing code over weakening test assertions.

## C23 — modern and strict

- Require `nullptr` (not `NULL`), `constexpr` for constants, typed enums
  (`enum Name : int`), `[[noreturn]]` and `[[gnu::format(printf, N, M)]]`
  where they apply; `_Generic` / `typeof` when they clarify types; standard
  types (`int`, `size_t`, `bool`).
- Everything must survive `-std=c23 -Wall -Wextra -Wpedantic -Werror` plus
  the curated flags in `rakelib/cflags.rb`.
- Portability targets: clang + gcc 15 (Linux), clang (macOS), LLVM clang
  (Windows). MSVC is out of scope; flag non-portable extensions beyond the
  attributes above.

## Single-header / amalgamation safety

- STB pattern: fragments in `src/<lib>/*.c` are concatenated inside one
  `ATOM_<NAME>_IMPLEMENTATION` block and never compiled standalone.
- Internal helpers must be `static` and named `atom_<lib>__…` (double
  underscore); file-scope state `static` named `g_atom_<lib>_…`; public
  symbols `atom_<lib>_…` declared in `public.h` via the `ATOM_<LIB>_API`
  macro. `ATOM_<LIB>_STATIC` must keep working for single-TU embeds.

## Review priorities

1. Correctness/UB: buffer bounds and truncation (`vsnprintf`), `va_list`
   pairing and reuse, format-string mismatches, signed/unsigned conversion,
   uninitialized reads, lifetime of pointers stashed in globals.
2. Amalgamation safety and naming-prefix discipline (above).
3. Portability across the compiler matrix.
4. Missing C23 idioms where a clearly better C23 equivalent exists.
5. Completeness: tests, changelog bullet, `public.h` docs, examples.

Keep feedback high-signal: concrete issues with file/line and a suggested
fix. Don't nitpick style that `clang-format` / `clang-tidy` already enforce.
