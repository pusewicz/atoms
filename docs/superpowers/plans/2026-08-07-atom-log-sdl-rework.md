# atom_log SDL Rework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make atom_log a thin wrapper around SDL3 logging — no non-SDL path, no `ATOM_LOG_SDL` define — and switch all "colour" spellings to "color".

**Architecture:** Source merges from five impl fragments to three (`path.c`, `format.c`, `log.c`); every log line routes through `SDL_LogMessage` on `SDL_LOG_CATEGORY_CUSTOM`, and atom_log's column formatter is installed via `SDL_SetLogOutputFunction`. Level filtering delegates to SDL per-category priorities (no internal min-level state). Rake grows a per-lib "requires SDL" declaration used by test/example/asan/tidy tasks.

**Tech Stack:** C23 (strict `-Werror` flags from `rakelib/cflags.rb`), SDL3 (`SDL_log.h` only), pico_unit, Rake.

**Spec:** `docs/superpowers/specs/2026-08-07-atom-log-sdl-rework-design.md`

## Global Constraints

- SDL3 is a hard dependency of atom_log: tests/examples/tidy **abort** (never skip) when SDL3 is missing, with message `SDL3 not found (pkg-config sdl3, or set SDL3_DIR / VCPKG_ROOT)`.
- American spelling: no "colour" in filenames, code, comments, or docs (historical CHANGELOG entries for released versions stay untouched).
- Edit `src/` and `rakelib/` only — never hand-edit or commit `dist/` or `build/`.
- Every user-visible change adds a `## [Unreleased]` CHANGELOG bullet **in the same commit**.
- C23 style per AGENTS.md: `nullptr`, typed enums, `[[noreturn]]`/`[[gnu::format]]`; `static const` instead of `constexpr` for objects.
- Run `rake format` before each commit touching C files; commits are short imperative style (e.g. "Make SDL3 the sole atom_log backend").
- Public API names, output format (columns, tags, colors, RS location packing), and the `atom_log__` internal prefix do not change.
- Execution happens in an isolated worktree (superpowers:using-git-worktrees / native EnterWorktree) branched from `main`.

---

### Task 1: Rake — per-lib SDL requirement

Make the build system treat atom_log as SDL-dependent *before* the source requires it. Old source/tests still pass: they just gain SDL include/link flags they don't yet use. The `test:atom_log:sdl` task keeps working unchanged (removed in Task 3).

**Files:**
- Modify: `rakelib/atoms.rb`
- Modify: `rakelib/test.rake`
- Modify: `rakelib/format.rake` (tidy task)

**Interfaces:**
- Produces: `Atoms.requires_sdl?(name)` → bool; `sdl_build_flags!(name)` → `[cflags_array, ldflags_array]` (test.rake helper, aborts if SDL missing). Tasks 2–4 rely on `rake test:atom_log` / `rake example:atom_log` compiling with SDL3 include+link flags.

- [ ] **Step 1: Declare the SDL requirement in `rakelib/atoms.rb`**

Add inside `module Atoms`, after `GITHUB = ...` and before `module_function`:

```ruby
  # Atoms with a hard SDL3 dependency (tests, examples, and tidy link SDL3).
  SDL_REQUIRED = %w[atom_log].freeze
```

Add after the `lib_dir` method:

```ruby
  def requires_sdl?(name)
    SDL_REQUIRED.include?(name)
  end
```

- [ ] **Step 2: Wire test/asan/example tasks in `rakelib/test.rake`**

Add this helper after the existing `def sdl_available?` block:

```ruby
def sdl_build_flags!(name)
  return [[], []] unless Atoms.requires_sdl?(name)

  unless sdl_available?
    abort "SDL3 not found (pkg-config sdl3, or set SDL3_DIR / VCPKG_ROOT)"
  end

  cfg = Atoms::Sdl.config
  puts "SDL3 via #{cfg.source}"
  Atoms::Sdl.prepend_bin_to_path!
  [cfg.cflags, cfg.libs]
end
```

Replace the `test:#{name}` core task body (keep the `:sdl` task block untouched for now):

```ruby
    desc "Run tests for #{name}#{' (requires SDL3)' if Atoms.requires_sdl?(name)}"
    task name => "dist:#{name}" do
      extra_cflags, extra_ldflags = sdl_build_flags!(name)
      core_tests.each do |src|
        bin = Atoms::BUILD.join("#{src.basename('.c')}#{exe_suffix}")
        compile_and_link(src, bin, extra_cflags: extra_cflags,
                                   extra_ldflags: extra_ldflags)
        run_bin(bin)
      end
    end
```

Replace the `:asan` task body:

```ruby
desc "Run tests under ASan+UBSan"
task :asan do
  asan_cflags = Atoms::CFlags.asan
  asan_ldflags = Shellwords.split(ENV.fetch("LDFLAGS", "")) +
                 %w[-fsanitize=address,undefined]
  Atoms.libs.each do |name|
    Rake::Task["dist:#{name}"].invoke
    extra_cflags, extra_ldflags = sdl_build_flags!(name)
    Atoms.lib_dir(name).glob("tests/test_#{name}.c").each do |src|
      bin = Atoms::BUILD.join("asan_#{src.basename('.c')}#{exe_suffix}")
      compile_and_link(src, bin, cflags: asan_cflags,
                                 extra_cflags: extra_cflags,
                                 extra_ldflags: asan_ldflags + extra_ldflags)
      run_bin(bin)
    end
  end
end
```

Replace the `example:#{name}` task body (drops the `_sdl`-suffix special-casing; atom_log is the only lib, and its examples all get SDL flags now — `hello_sdl.c` self-defines `ATOM_LOG_SDL` so it still builds the SDL backend):

```ruby
    desc "Build and run examples for #{name}#{' (requires SDL3)' if Atoms.requires_sdl?(name)}"
    task name => "dist:#{name}" do
      extra_cflags, extra_ldflags = sdl_build_flags!(name)
      Atoms.lib_dir(name).glob("examples/*.c").sort.each do |src|
        bin = Atoms::BUILD.join("example_#{name}_#{src.basename('.c')}#{exe_suffix}")
        compile_and_link(src, bin, extra_cflags: extra_cflags,
                                   extra_ldflags: extra_ldflags)
        run_bin(bin)
      end
    end
```

- [ ] **Step 3: Wire clang-tidy in `rakelib/format.rake`**

Add `require_relative "sdl"` under `require_relative "atoms"`. Replace the tidy loop body:

```ruby
desc "clang-tidy first-party test TUs (after dist)"
task tidy: :dist do
  abort "clang-tidy not found" unless system("command -v clang-tidy",
                                             out: File::NULL, err: File::NULL)
  Atoms.libs.each do |name|
    extra = []
    if Atoms.requires_sdl?(name)
      unless Atoms::Sdl.available?
        abort "SDL3 not found (pkg-config sdl3, or set SDL3_DIR / VCPKG_ROOT)"
      end
      extra = Atoms::Sdl.config.cflags
    end
    Atoms.lib_dir(name).glob("tests/test_#{name}.c").each do |src|
      sh "clang-tidy", src.to_s, "--", *Atoms::CFlags.default, *extra
    end
  end
end
```

- [ ] **Step 4: Verify everything still passes**

Run: `rake test`
Expected: prints `SDL3 via …` before the core suite now; both `test:atom_log` and `test:atom_log:sdl` suites pass.

Run: `rake example:atom_log`
Expected: both `hello` and `hello_sdl` build (with SDL flags) and run.

- [ ] **Step 5: Commit**

```bash
git add rakelib/atoms.rb rakelib/test.rake rakelib/format.rake
git commit -m "Rake: declare per-lib SDL3 requirement (atom_log)"
```

---

### Task 2: Source rework — SDL-only backend, merged fragments

Merge `core.c` + `sdl.c` into a new `log.c`; absorb `colour.c` into `format.c`; delete the non-SDL path and all `ATOM_LOG_SDL` conditionals. Both existing test suites must still pass unmodified after this task (they compile with SDL flags since Task 1; `test_atom_log_sdl.c`'s self-`#define ATOM_LOG_SDL` becomes a harmless no-op).

**Files:**
- Create: `src/atom_log/log.c`
- Modify: `src/atom_log/format.c`
- Modify: `src/atom_log/public.h` (doc comments only)
- Modify: `rakelib/amalgamate.rb:11`
- Modify: `src/atom_log/CHANGELOG.md`
- Delete: `src/atom_log/core.c`, `src/atom_log/sdl.c`, `src/atom_log/colour.c`

**Interfaces:**
- Consumes: SDL build flags from Task 1.
- Produces: impl fragments `path.c format.c log.c` (amalgamation order). Internal contract used by Task 3's tests: `atom_log_init` installs `atom_log__sdl_output` via `SDL_SetLogOutputFunction`, pins `SDL_LOG_CATEGORY_CUSTOM` to `SDL_LOG_PRIORITY_TRACE`; `atom_log_set_level(min)` = `SDL_SetLogPriority(SDL_LOG_CATEGORY_CUSTOM, atom_log__sdl_from_level(min))`; messages are packed as `"\x1e<location>\x1e<message>"`.

- [ ] **Step 1: Create `src/atom_log/log.c`**

Full content (functions carried over from `core.c`/`sdl.c` keep their exact bodies; new/changed parts are `atom_log__emit` taking an `SDL_LogPriority`, `atom_log_init` absorbing the install logic, `atom_log_set_level` delegating to SDL, and `atom_log_fatal` emitting through SDL):

```c
/* log.c — public API entry points and the SDL3 log bridge.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

#include <SDL3/SDL_log.h>

static bool g_atom_log_color;
static AtomLogOutputFn g_atom_log_out_fn;
static void* g_atom_log_out_ud;

/* ASCII record separator. atom_log__emit packs "<RS>location<RS>message" into
 * the SDL message body so the call site survives SDL's log pipeline.
 * static const rather than constexpr: some compilers accept -std=c23 without
 * supporting C23 constexpr objects. */
static const char atom_log_loc_mark = '\x1e';

static const char* atom_log__category_label(int category) {
  switch (category) {
  case SDL_LOG_CATEGORY_APPLICATION:
    return "app";
  case SDL_LOG_CATEGORY_ERROR:
    return "error";
  case SDL_LOG_CATEGORY_ASSERT:
    return "assert";
  case SDL_LOG_CATEGORY_SYSTEM:
    return "system";
  case SDL_LOG_CATEGORY_AUDIO:
    return "audio";
  case SDL_LOG_CATEGORY_VIDEO:
    return "video";
  case SDL_LOG_CATEGORY_RENDER:
    return "render";
  case SDL_LOG_CATEGORY_INPUT:
    return "input";
  case SDL_LOG_CATEGORY_TEST:
    return "test";
  case SDL_LOG_CATEGORY_GPU:
    return "gpu";
  case SDL_LOG_CATEGORY_CUSTOM:
    return "game";
  default:
    return "sdl";
  }
}

static AtomLogPrio atom_log__prio_from_sdl(SDL_LogPriority priority) {
  switch (priority) {
  case SDL_LOG_PRIORITY_TRACE:
    return ATOM_LOG_PRIO_TRACE;
  case SDL_LOG_PRIORITY_VERBOSE:
    return ATOM_LOG_PRIO_VERBOSE;
  case SDL_LOG_PRIORITY_DEBUG:
    return ATOM_LOG_PRIO_DEBUG;
  case SDL_LOG_PRIORITY_INFO:
    return ATOM_LOG_PRIO_INFO;
  case SDL_LOG_PRIORITY_WARN:
    return ATOM_LOG_PRIO_WARN;
  case SDL_LOG_PRIORITY_ERROR:
    return ATOM_LOG_PRIO_ERROR;
  case SDL_LOG_PRIORITY_CRITICAL:
    return ATOM_LOG_PRIO_CRITICAL;
  default:
    return ATOM_LOG_PRIO_UNKNOWN;
  }
}

static SDL_LogPriority atom_log__sdl_from_level(AtomLogLevel level) {
  switch (level) {
  case ATOM_LOG_TRACE:
    return SDL_LOG_PRIORITY_TRACE;
  case ATOM_LOG_DEBUG:
    return SDL_LOG_PRIORITY_DEBUG;
  case ATOM_LOG_INFO:
    return SDL_LOG_PRIORITY_INFO;
  case ATOM_LOG_WARN:
    return SDL_LOG_PRIORITY_WARN;
  case ATOM_LOG_ERROR:
    return SDL_LOG_PRIORITY_ERROR;
  default:
    return SDL_LOG_PRIORITY_INFO;
  }
}

static bool atom_log__split_marked_body(const char* body, char* loc_out,
                                        size_t loc_n, const char** msg_out) {
  if (!body || body[0] != atom_log_loc_mark) {
    return false;
  }
  const char* loc_start = body + 1;
  const char* sep       = strchr(loc_start, atom_log_loc_mark);
  if (!sep) {
    return false;
  }
  const size_t loc_len = (size_t)(sep - loc_start);
  if (loc_len + 1 > loc_n) {
    return false;
  }
  memcpy(loc_out, loc_start, loc_len);
  loc_out[loc_len] = '\0';
  *msg_out         = sep + 1;
  return true;
}

static void atom_log__sdl_output(void* userdata, int category,
                                 SDL_LogPriority priority,
                                 const char* message) {
  (void)userdata;
  char loc_buf[128];
  const char* text = message ? message : "";

  if (!atom_log__split_marked_body(message, loc_buf, sizeof loc_buf, &text)) {
    snprintf(loc_buf, sizeof loc_buf, "%s", atom_log__category_label(category));
  }

  atom_log__write_line(g_atom_log_color, atom_log__prio_from_sdl(priority),
                       loc_buf, text, g_atom_log_out_fn, g_atom_log_out_ud);
}

static void atom_log__vformat(char* out, size_t out_n, const char* format,
                              va_list args) {
  if (format) {
    vsnprintf(out, out_n, format, args);
  } else {
    out[0] = '\0';
  }
}

/* Pack the call site into the SDL message body; the installed output
 * callback unpacks and renders it. */
static void atom_log__emit(SDL_LogPriority priority, const char* file,
                           int line, const char* user_message) {
  char loc[128];
  /* Sized so the location prefix and a full 1023-byte message both fit. */
  char body[1280];
  atom_log__format_location(loc, sizeof loc, file, line);
  const int written =
      snprintf(body, sizeof body, "%c%s%c%s", atom_log_loc_mark, loc,
               atom_log_loc_mark, user_message ? user_message : "");
  if (written < 0) {
    body[0] = '\0';
  }
  SDL_LogMessage(SDL_LOG_CATEGORY_CUSTOM, priority, "%s", body);
}

ATOM_LOG_API void atom_log_init(void) {
  g_atom_log_color = atom_log__detect_color();
  for (int p = SDL_LOG_PRIORITY_TRACE; p < SDL_LOG_PRIORITY_COUNT; ++p) {
    SDL_SetLogPriorityPrefix((SDL_LogPriority)p, "");
  }
  SDL_SetLogOutputFunction(atom_log__sdl_output, nullptr);
#if !defined(NDEBUG)
  SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);
#endif
  /* atom_log emits through the custom category; SDL's default priority for
   * it would drop lower levels. atom_log_set_level remains the filter. */
  SDL_SetLogPriority(SDL_LOG_CATEGORY_CUSTOM, SDL_LOG_PRIORITY_TRACE);
}

ATOM_LOG_API void atom_log_set_level(AtomLogLevel min) {
  SDL_SetLogPriority(SDL_LOG_CATEGORY_CUSTOM, atom_log__sdl_from_level(min));
}

ATOM_LOG_API void atom_log_set_output(AtomLogOutputFn fn, void* userdata) {
  g_atom_log_out_fn = fn;
  g_atom_log_out_ud = userdata;
}

ATOM_LOG_API void atom_log_debug_force_color(bool enabled) {
  g_atom_log_color = enabled;
}

ATOM_LOG_API void atom_log_message(AtomLogLevel level, const char* file,
                                   int line, const char* format, ...) {
  char message[1024];
  va_list args;
  va_start(args, format);
  atom_log__vformat(message, sizeof message, format, args);
  va_end(args);
  atom_log__emit(atom_log__sdl_from_level(level), file, line, message);
}

ATOM_LOG_API void atom_log_fatal(const char* file, int line,
                                 const char* format, ...) {
  char message[1024];
  va_list args;
  va_start(args, format);
  atom_log__vformat(message, sizeof message, format, args);
  va_end(args);
  atom_log__emit(SDL_LOG_PRIORITY_CRITICAL, file, line, message);
  abort();
}
```

Note the deliberate changes vs. the old code:
- No `g_atom_log_min_level`, no pre-filter in `atom_log_message` — SDL's per-category priority is the only filter.
- `atom_log_fatal` no longer calls `atom_log__write_line` directly; it emits through SDL at CRITICAL (which outranks every settable level, and passes SDL's default CUSTOM priority even without init) and then aborts.
- `atom_log__emit` takes `SDL_LogPriority` so message and fatal share one path.

- [ ] **Step 2: Absorb color detection into `src/atom_log/format.c`**

Change the header comment (line 1) to:

```c
/* format.c — time column, level tags, color detection, line writer.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */
```

Insert directly after the `#include <time.h>` line (this is `colour.c`'s content with American spelling in the comment):

```c
#ifdef _WIN32
#include <io.h>
#include <stdio.h>
#elifndef __EMSCRIPTEN__
#include <unistd.h>
#endif

/* TTY / NO_COLOR detection. */
static bool atom_log__detect_color(void) {
#ifdef ATOM_LOG_NO_COLOR
  return false;
#else
  const char* no_color = getenv("NO_COLOR");
  if (no_color && no_color[0] != '\0') {
    return false;
  }

#ifdef __EMSCRIPTEN__
  return false;
#elifdef _WIN32
  return _isatty(_fileno(stderr)) != 0;
#else
  return isatty(STDERR_FILENO) != 0;
#endif
#endif
}
```

Delete the entire `#ifndef ATOM_LOG_SDL … #endif` block containing `atom_log__prio_from_level` (format.c lines 97–114 in the current file) — the level→prio mapping now goes through SDL priorities only.

- [ ] **Step 3: Delete the merged-away fragments**

```bash
git rm src/atom_log/core.c src/atom_log/sdl.c src/atom_log/colour.c
```

- [ ] **Step 4: Update the amalgamation order in `rakelib/amalgamate.rb`**

Replace line 11:

```ruby
      "atom_log" => %w[path.c format.c log.c]
```

- [ ] **Step 5: Update doc comments in `src/atom_log/public.h`**

Replace the `atom_log_init` doc block with:

```c
/**
 * @brief Configure logging for the process.
 *
 * Detects color support (TTY and the NO_COLOR environment variable),
 * clears SDL's log prefixes, installs atom_log's line formatter via
 * SDL_SetLogOutputFunction, and resets the minimum level to
 * ATOM_LOG_TRACE. Call once at startup, before atom_log_set_level.
 */
```

Replace the `atom_log_set_level` doc block with:

```c
/**
 * @brief Set the minimum level that will be emitted (inclusive).
 *
 * Delegates to SDL_SetLogPriority for atom_log's SDL log category. Lines
 * below @p min are discarded. Call after atom_log_init, which resets the
 * minimum to ATOM_LOG_TRACE.
 *
 * @param min  Minimum severity to emit.
 */
```

In the `atom_log_debug_force_color` doc block, change "Force ANSI colour on or off." to "Force ANSI color on or off." and "true to emit colour escape sequences." to "true to emit color escape sequences."

- [ ] **Step 6: Add CHANGELOG bullets**

In `src/atom_log/CHANGELOG.md`, under `## [Unreleased]` add:

```markdown
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
```

- [ ] **Step 7: Format, build, and run both old suites**

Run: `rake format`
Run: `rake dist:atom_log`
Expected: `wrote dist/atom_log.h` — inspect that it contains `/* ---- log.c ---- */` and no `ATOM_LOG_SDL` conditionals.

Run: `rake test`
Expected: both `test_atom_log` and `test_atom_log_sdl` suites pass unmodified (the old core suite now runs through the SDL path; the SDL suite's `#define ATOM_LOG_SDL` is a no-op).

Run: `rake example:atom_log`
Expected: both examples build and run; output lines stay column-aligned.

- [ ] **Step 8: Commit**

```bash
git add -A src/atom_log rakelib/amalgamate.rb
git commit -m "Make SDL3 the sole atom_log backend"
```

---

### Task 3: Merge test suites and examples

One suite (`test_atom_log.c`, needs SDL3), one example (`hello.c`, needs SDL3). Remove the `test:atom_log:sdl` task.

**Files:**
- Modify: `src/atom_log/tests/test_atom_log.c`
- Modify: `src/atom_log/examples/hello.c`
- Modify: `rakelib/test.rake`
- Modify: `src/atom_log/CHANGELOG.md`
- Delete: `src/atom_log/tests/test_atom_log_sdl.c`, `src/atom_log/examples/hello_sdl.c`

**Interfaces:**
- Consumes: Task 2's contract (`atom_log__sdl_output` installed by init; RS packing `"\x1e<location>\x1e<message>"`; `atom_log_set_level` ↔ `SDL_SetLogPriority(SDL_LOG_CATEGORY_CUSTOM, …)`).
- Produces: single test binary `build/test_atom_log`; `rake test` no longer has an `:sdl` sub-task.

- [ ] **Step 1: Merge SDL cases into `tests/test_atom_log.c`**

Apply these edits to the existing file:

1. Change the `@brief` (line 3) to: `@brief atom_log test suite (requires SDL3).`
2. Add `#include <SDL3/SDL_log.h>` directly above `#include <stdio.h>`.
3. Replace `install_logger` with (order matters — `SDL_SetLogPriorities` opens all SDL categories for the category-label tests regardless of NDEBUG; `atom_log_set_level` then exercises the delegation):

```c
static void install_logger(void) {
  atom_log_init();
  SDL_SetLogPriorities(SDL_LOG_PRIORITY_TRACE);
  atom_log_set_level(ATOM_LOG_TRACE);
  atom_log_debug_force_color(false);
}
```

4. Append the following after `test_warn_has_no_sdl_style_prefix` (these are the migrated SDL-suite cases plus one new delegation test; the RS constant and callback helpers come with them):

```c
/* ---- SDL bridge ----------------------------------------------------------- */

static const char k_loc_mark = '\x1e';

static SDL_LogOutputFunction g_log_out;
static void* g_log_ud;
static int g_cb_category;
static SDL_LogPriority g_cb_priority;
static const char* g_cb_message;

static void grab_output_fn(void) {
  SDL_GetLogOutputFunction(&g_log_out, &g_log_ud);
}

static void emit_via_callback(void) {
  g_log_out(g_log_ud, g_cb_category, g_cb_priority, g_cb_message);
}

static void emit_via_sdl(void) {
  SDL_LogMessage(SDL_LOG_CATEGORY_APPLICATION, SDL_LOG_PRIORITY_INFO, "%s",
                 g_cb_message);
}

TEST_CASE(test_init_installs_output_callback) {
  grab_output_fn();
  REQUIRE(g_log_out != nullptr);
  return true;
}

TEST_CASE(test_set_level_delegates_to_sdl_priority) {
  atom_log_set_level(ATOM_LOG_WARN);
  REQUIRE(SDL_GetLogPriority(SDL_LOG_CATEGORY_CUSTOM) ==
          SDL_LOG_PRIORITY_WARN);
  atom_log_set_level(ATOM_LOG_TRACE);
  REQUIRE(SDL_GetLogPriority(SDL_LOG_CATEGORY_CUSTOM) ==
          SDL_LOG_PRIORITY_TRACE);
  return true;
}

static void emit_trace_via_api(void) {
  atom_log_message(ATOM_LOG_TRACE, "src/game/ui.c", 5, "trace-through");
}

/* init alone must let every atom_log level through; SDL's default priority
 * for the custom category would otherwise drop lines below ERROR. */
TEST_CASE(test_init_passes_trace_without_manual_sdl_priorities) {
  SDL_ResetLogPriorities();
  atom_log_init();
  atom_log_debug_force_color(false);

  char out[512];
  REQUIRE(capture_log(out, sizeof out, emit_trace_via_api));
  REQUIRE(line_contains(out, "TRCE"));
  REQUIRE(line_contains(out, "trace-through"));
  return true;
}

TEST_CASE(test_category_labels) {
  struct {
    int category;
    const char* label;
  } cases[] = {
      {SDL_LOG_CATEGORY_APPLICATION, "app"},
      {SDL_LOG_CATEGORY_ERROR, "error"},
      {SDL_LOG_CATEGORY_GPU, "gpu"},
      {SDL_LOG_CATEGORY_CUSTOM, "game"},
      {9999, "sdl"},
  };

  for (size_t i = 0; i < countof(cases); i++) {
    char out[512];
    StderrCapture cap;
    REQUIRE(capture_begin(&cap));
    SDL_LogMessage(cases[i].category, SDL_LOG_PRIORITY_INFO, "cat-msg");
    REQUIRE(capture_end(&cap, out, sizeof out));
    REQUIRE(line_contains(out, cases[i].label));
    REQUIRE(line_contains(out, "cat-msg"));
  }
  return true;
}

TEST_CASE(test_all_sdl_priority_tags) {
  grab_output_fn();
  REQUIRE(g_log_out != nullptr);

  struct {
    SDL_LogPriority priority;
    const char* tag;
  } cases[] = {
      {SDL_LOG_PRIORITY_TRACE, "TRCE"},    {SDL_LOG_PRIORITY_VERBOSE, "VERB"},
      {SDL_LOG_PRIORITY_DEBUG, "DEBG"},    {SDL_LOG_PRIORITY_INFO, "INFO"},
      {SDL_LOG_PRIORITY_WARN, "WARN"},     {SDL_LOG_PRIORITY_ERROR, "ERR "},
      {SDL_LOG_PRIORITY_CRITICAL, "CRIT"}, {(SDL_LogPriority)12345, "????"},
  };

  for (size_t i = 0; i < countof(cases); i++) {
    char out[512];
    g_cb_category = SDL_LOG_CATEGORY_APPLICATION;
    g_cb_priority = cases[i].priority;
    g_cb_message  = "prio";
    REQUIRE(capture_log(out, sizeof out, emit_via_callback));
    REQUIRE(line_contains(out, cases[i].tag));
    REQUIRE(line_contains(out, "prio"));
  }
  return true;
}

TEST_CASE(test_marked_body_splits_location) {
  grab_output_fn();
  char body[256];
  snprintf(body, sizeof body, "%csrc/game/ui.c:416%chello", k_loc_mark,
           k_loc_mark);

  char out[512];
  g_cb_category = SDL_LOG_CATEGORY_CUSTOM;
  g_cb_priority = SDL_LOG_PRIORITY_INFO;
  g_cb_message  = body;
  REQUIRE(capture_log(out, sizeof out, emit_via_callback));
  REQUIRE(line_contains(out, "src/game/ui.c:416"));
  REQUIRE(line_contains(out, "hello"));
  REQUIRE(!line_contains(out, "  game  "));
  return true;
}

TEST_CASE(test_marked_body_missing_second_mark_falls_back) {
  grab_output_fn();
  char body[128];
  snprintf(body, sizeof body, "%csrc/game/ui.c:1-no-second", k_loc_mark);

  char out[512];
  g_cb_category = SDL_LOG_CATEGORY_GPU;
  g_cb_priority = SDL_LOG_PRIORITY_INFO;
  g_cb_message  = body;
  REQUIRE(capture_log(out, sizeof out, emit_via_callback));
  REQUIRE(line_contains(out, "gpu"));
  REQUIRE(line_contains(out, "src/game/ui.c:1-no-second"));
  return true;
}

TEST_CASE(test_unmarked_body_uses_category) {
  char out[512];
  g_cb_message = "plain sdl line";
  REQUIRE(capture_log(out, sizeof out, emit_via_sdl));
  REQUIRE(line_contains(out, "app"));
  REQUIRE(line_contains(out, "plain sdl line"));
  return true;
}
```

5. Register the new cases at the end of `suite_atom_log`:

```c
  RUN_TEST_CASE(test_init_installs_output_callback);
  RUN_TEST_CASE(test_set_level_delegates_to_sdl_priority);
  RUN_TEST_CASE(test_init_passes_trace_without_manual_sdl_priorities);
  RUN_TEST_CASE(test_category_labels);
  RUN_TEST_CASE(test_all_sdl_priority_tags);
  RUN_TEST_CASE(test_marked_body_splits_location);
  RUN_TEST_CASE(test_marked_body_missing_second_mark_falls_back);
  RUN_TEST_CASE(test_unmarked_body_uses_category);
```

- [ ] **Step 2: Delete the old SDL suite and run the merged one**

```bash
git rm src/atom_log/tests/test_atom_log_sdl.c
```

Run: `rake test:atom_log`
Expected: single suite, all cases pass (17 old + 8 SDL/bridge cases).

- [ ] **Step 3: Merge examples into `examples/hello.c`**

Replace `src/atom_log/examples/hello.c` with:

```c
/**
 * @file hello.c
 * @brief atom_log and native SDL_Log sharing one column layout (needs SDL3).
 */

#define ATOM_LOG_IMPLEMENTATION
#include <SDL3/SDL_log.h>

#include "atom_log.h"

int main(void) {
  atom_log_init();

  atom_log_trace("trace line");
  atom_log_debug("debug line");
  atom_log_info("booted %d", 42);
  atom_log_warn("heads up");
  atom_log_error("something failed: %s", "demo");

  /* Unmarked SDL messages use the category label as the location column. */
  SDL_Log("plain SDL_Log (application category)");
  SDL_LogWarn(SDL_LOG_CATEGORY_VIDEO, "SDL video warn");
  return 0;
}
```

```bash
git rm src/atom_log/examples/hello_sdl.c
```

Run: `rake example:atom_log`
Expected: one example builds and runs; atom_log lines show `src/atom_log/examples/hello.c:NN` locations, SDL lines show `app` / `video` labels.

- [ ] **Step 4: Remove the `:sdl` test task from `rakelib/test.rake`**

Delete the `sdl_tests = …` line, the `next if sdl_tests.empty?` line, and the whole `task "#{name}:sdl"` block. Simplify the aggregate `:test` task to:

```ruby
desc "Build dist and run all available test suites"
task :test do
  puts "CC=#{CC}  clangish=#{Atoms::CFlags.clangish?}  host=#{RbConfig::CONFIG['host_os']}"
  if Atoms::Sdl.available?
    puts "SDL3: #{Atoms::Sdl.config.source}"
  else
    puts "SDL3: not found (required by: #{Atoms::SDL_REQUIRED.join(', ')})"
  end

  Atoms.libs.each do |name|
    Rake::Task["test:#{name}"].invoke
  end
end
```

Run: `rake test`
Expected: one atom_log suite, passes; no `:sdl` invocation.

- [ ] **Step 5: Add CHANGELOG bullet**

Under `## [Unreleased]` add a `### Removed` section:

```markdown
### Removed

- Non-SDL stderr backend, the `rake test:atom_log:sdl` split suite, and the
  separate SDL example (`hello_sdl.c` merged into `hello.c`).
```

- [ ] **Step 6: Format and commit**

```bash
rake format
git add -A src/atom_log rakelib/test.rake
git commit -m "Merge atom_log SDL and core test suites and examples"
```

---

### Task 4: Docs, version, repo rules

**Files:**
- Modify: `src/atom_log/README.md`
- Modify: `src/atom_log/banner.h.in`
- Modify: `src/atom_log/VERSION`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: final API/semantics from Tasks 2–3.
- Produces: release-ready 0.2.0 in-progress state.

- [ ] **Step 1: Rewrite `src/atom_log/README.md`**

Full new content:

```markdown
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

Install the amalgamated header from a [GitHub Release](https://github.com/pusewicz/atoms/releases) or build locally with `rake dist` → `dist/atom_log.h`.

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
```

- [ ] **Step 2: Update `src/atom_log/banner.h.in`**

- Line 2 tagline → `atom_log.h - v{{VERSION}} - Column-aligned leveled logging over SDL3 (C23)`
- In the USAGE block, add below the include lines: ` *   Requires SDL3: SDL3/SDL_log.h on the include path, link SDL3.`
- In OPTIONAL DEFINES, delete the `ATOM_LOG_SDL` line.

- [ ] **Step 3: Bump `src/atom_log/VERSION`**

Set the file content to `0.2.0` (breaking change on the 0.x line; 0.1.2 was never released).

- [ ] **Step 4: Update `AGENTS.md`**

- Commands section: change `- \`rake test\` / \`rake test:atom_log\` / \`rake test:atom_log:sdl\`` to `- \`rake test\` / \`rake test:atom_log\` (needs SDL3)`.
- Single-header conventions: replace `- Zero hard deps in core; optional backends behind feature defines.` with `- Keep dependencies minimal; an atom may declare a hard dependency when its domain demands it (atom_log requires SDL3). Optional extras stay behind feature defines.`
- Testing section: replace `- Core suites must not require SDL or network.` with `- Suites must not require network. atom_log's suite requires SDL3 (CI installs it on every job; declared via \`Atoms::SDL_REQUIRED\`).`

- [ ] **Step 5: Full verification sweep**

Run: `rake test`
Expected: pass.
Run: `rake example:atom_log`
Expected: pass.
Run: `rake docs:check`
Expected: `ok docs atom_log (… symbols, 1 examples)`.
Run: `rake format:check`
Expected: no diagnostics.
Run: `rake version:check`
Expected: passes with 0.2.0 (verify the task exists via `rake -T version` first; it validates VERSION/CHANGELOG consistency).

- [ ] **Step 6: Commit**

```bash
git add src/atom_log/README.md src/atom_log/banner.h.in src/atom_log/VERSION AGENTS.md
git commit -m "Document SDL3 requirement; bump atom_log to 0.2.0"
```

---

## Self-Review Notes

- **Spec coverage:** API/behavior → Task 2; layout/spelling → Task 2; build/tests/examples → Tasks 1 & 3; docs/version/AGENTS → Task 4; call-order constraint documented in public.h (Task 2 Step 5) and CHANGELOG (Task 2 Step 6). `compile_commands` needs no direct change — it drives `test`/`example` tasks, which Task 1 wires.
- **Green-commit sequencing:** Task 1 adds SDL flags while old code ignores them; Task 2 flips the source while both old suites still pass (verified reasoning: old core suite asserts backend-agnostic output through the now-SDL path; old SDL suite's `ATOM_LOG_SDL` define becomes a no-op); Task 3 merges files; Task 4 is docs-only.
- **Type consistency:** `atom_log__emit(SDL_LogPriority, const char*, int, const char*)` defined in Task 2 and only used there; test contract names (`atom_log__sdl_output` install, RS `'\x1e'` packing, `SDL_LOG_CATEGORY_CUSTOM` delegation) match between Task 2 code and Task 3 tests.
