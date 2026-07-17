/**
 * @file test_atom_log.c
 * @brief Core unit tests for atom_log (zero-dep, no SDL).
 */

#define PICO_UNIT_IMPLEMENTATION
#include <pico_unit.h>

#define ATOM_LOG_IMPLEMENTATION
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "atom_log.h"
#include "host_compat.h"

/* ---- stderr capture ------------------------------------------------------ */

typedef struct StderrCapture {
  char path[96];
  int saved_fd;
  int tmp_fd;
} StderrCapture;

static void capture_drop(StderrCapture* c) {
  if (c->tmp_fd >= 0) {
    ATOM_LOG_TEST_CLOSE(c->tmp_fd);
    c->tmp_fd = -1;
  }
  if (c->path[0] != '\0') {
    ATOM_LOG_TEST_UNLINK(c->path);
    c->path[0] = '\0';
  }
}

static bool capture_begin(StderrCapture* c) {
  c->path[0]  = '\0';
  c->tmp_fd   = -1;
  c->saved_fd = -1;
  fflush(stderr);

  snprintf(c->path, sizeof c->path, "build/test_atom_log_%d.tmp",
           (int)ATOM_LOG_TEST_GETPID());
  FILE* f = fopen(c->path, "w+b");
  if (!f) {
    c->path[0] = '\0';
    return false;
  }
  c->tmp_fd = ATOM_LOG_TEST_DUP(ATOM_LOG_TEST_FILENO(f));
  fclose(f);
  if (c->tmp_fd < 0) {
    capture_drop(c);
    return false;
  }

  c->saved_fd = ATOM_LOG_TEST_DUP(STDERR_FILENO);
  if (c->saved_fd < 0) {
    capture_drop(c);
    return false;
  }
  if (ATOM_LOG_TEST_DUP2(c->tmp_fd, STDERR_FILENO) < 0) {
    ATOM_LOG_TEST_CLOSE(c->saved_fd);
    c->saved_fd = -1;
    capture_drop(c);
    return false;
  }
  return true;
}

static bool capture_end(StderrCapture* c, char* out, size_t out_n) {
  fflush(stderr);
  if (ATOM_LOG_TEST_DUP2(c->saved_fd, STDERR_FILENO) < 0) {
    ATOM_LOG_TEST_CLOSE(c->saved_fd);
    c->saved_fd = -1;
    capture_drop(c);
    return false;
  }
  ATOM_LOG_TEST_CLOSE(c->saved_fd);
  c->saved_fd = -1;
  ATOM_LOG_TEST_CLOSE(c->tmp_fd);
  c->tmp_fd = -1;

  FILE* f = fopen(c->path, "rb");
  ATOM_LOG_TEST_UNLINK(c->path);
  c->path[0] = '\0';
  if (!f || out_n == 0) {
    if (f) {
      fclose(f);
    }
    return false;
  }
  size_t n = fread(out, 1, out_n - 1, f);
  fclose(f);
  out[n] = '\0';
  return true;
}

static bool capture_log(char* out, size_t out_n, void (*fn)(void)) {
  StderrCapture cap;
  if (!capture_begin(&cap)) {
    return false;
  }
  fn();
  return capture_end(&cap, out, out_n);
}

/* ---- helpers ------------------------------------------------------------- */

static void install_logger(void) {
  atom_log_init();
  atom_log_set_level(ATOM_LOG_TRACE);
  atom_log_debug_force_color(false);
}

static void fixture_setup(void) {
  atom_log_test_setenv("NO_COLOR", "");
  install_logger();
}

static void fixture_teardown(void) {}

static bool has_ansi(const char* s) {
  return strstr(s, "\x1b[") != nullptr;
}

static bool time_column_ok(const char* line) {
  if (strlen(line) < 14) {
    return false;
  }
  for (int i = 0; i < 12; i++) {
    const char ch = line[i];
    if (i == 2 || i == 5) {
      if (ch != ':') {
        return false;
      }
    } else if (i == 8) {
      if (ch != '.') {
        return false;
      }
    } else if (ch < '0' || ch > '9') {
      return false;
    }
  }
  return line[12] == ' ' && line[13] == ' ';
}

static bool line_contains(const char* line, const char* needle) {
  return strstr(line, needle) != nullptr;
}

static AtomLogLevel g_emit_level;
static const char* g_emit_file;
static int g_emit_line;
static const char* g_emit_fmt;
static const char* g_emit_arg;

static void emit_log_message(void) {
  if (g_emit_arg) {
    atom_log_message(g_emit_level, g_emit_file, g_emit_line, g_emit_fmt,
                     g_emit_arg);
  } else {
    atom_log_message(g_emit_level, g_emit_file, g_emit_line, "%s", g_emit_fmt);
  }
}

/* ---- cases --------------------------------------------------------------- */

TEST_CASE(test_log_level_tags) {
  struct {
    AtomLogLevel level;
    const char* tag;
  } cases[] = {
      {ATOM_LOG_TRACE, "TRCE"}, {ATOM_LOG_DEBUG, "DEBG"},
      {ATOM_LOG_INFO, "INFO"},  {ATOM_LOG_WARN, "WARN"},
      {ATOM_LOG_ERROR, "ERR "},
  };

  for (size_t i = 0; i < ATOM_LOG_COUNTOF(cases); i++) {
    char out[512];
    g_emit_level = cases[i].level;
    g_emit_file  = "src/engine/logger.c";
    g_emit_line  = 1;
    g_emit_fmt   = "lvl";
    g_emit_arg   = nullptr;
    REQUIRE(capture_log(out, sizeof out, emit_log_message));
    REQUIRE(time_column_ok(out));
    REQUIRE(line_contains(out, cases[i].tag));
    REQUIRE(line_contains(out, "lvl"));
  }
  return true;
}

TEST_CASE(test_log_level_invalid_falls_back_to_info) {
  char out[512];
  g_emit_level = (AtomLogLevel)99;
  g_emit_file  = "src/engine/logger.c";
  g_emit_line  = 1;
  g_emit_fmt   = "fallback";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "INFO"));
  REQUIRE(line_contains(out, "fallback"));
  return true;
}

TEST_CASE(test_log_macros_forward_to_message) {
  char out[512];
  StderrCapture cap;
  REQUIRE(capture_begin(&cap));
  atom_log_info("macro-smoke %d", 42);
  REQUIRE(capture_end(&cap, out, sizeof out));
  REQUIRE(line_contains(out, "INFO"));
  REQUIRE(line_contains(out, "macro-smoke 42"));
  REQUIRE(line_contains(out, "test_atom_log.c:"));
  return true;
}

TEST_CASE(test_src_relative_path_from_absolute) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "/Users/dev/space-delivery/src/game/ui.c";
  g_emit_line  = 416;
  g_emit_fmt   = "path";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "src/game/ui.c:416"));
  REQUIRE(!line_contains(out, "/Users/dev"));
  return true;
}

TEST_CASE(test_src_relative_path_capital_s) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "/proj/Src/engine/logger.c";
  g_emit_line  = 7;
  g_emit_fmt   = "cap";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "Src/engine/logger.c:7") ||
          line_contains(out, "src/engine/logger.c:7"));
  return true;
}

TEST_CASE(test_src_relative_path_backslash) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "C:\\build\\src\\game\\ship.c";
  g_emit_line  = 3;
  g_emit_fmt   = "win";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "src/game/ship.c:3"));
  REQUIRE(!line_contains(out, "\\"));
  return true;
}

TEST_CASE(test_basename_fallback_when_no_src) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "/usr/local/include/foo.h";
  g_emit_line  = 9;
  g_emit_fmt   = "base";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "foo.h:9"));
  REQUIRE(!line_contains(out, "/usr/local"));
  return true;
}

TEST_CASE(test_empty_and_null_file_become_dash) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "";
  g_emit_line  = 1;
  g_emit_fmt   = "empty";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "-:1"));

  g_emit_file = nullptr;
  g_emit_fmt  = "nullf";
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "-:1"));
  REQUIRE(line_contains(out, "nullf"));
  return true;
}

TEST_CASE(test_src_must_be_path_component) {
  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "/tmp/foosrc/bar.c";
  g_emit_line  = 2;
  g_emit_fmt   = "bound";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "bar.c:2"));
  REQUIRE(!line_contains(out, "foosrc"));
  return true;
}

TEST_CASE(test_wide_location_not_truncated) {
  char out[1024];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "src/game/very/deep/nested/path/that/exceeds/width/module.c";
  g_emit_line  = 99;
  g_emit_fmt   = "wide-msg";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(
      out, "src/game/very/deep/nested/path/that/exceeds/width/module.c:99"));
  REQUIRE(line_contains(out, "wide-msg"));
  return true;
}

TEST_CASE(test_printf_formatting) {
  char out[512];
  StderrCapture cap;
  REQUIRE(capture_begin(&cap));
  atom_log_message(ATOM_LOG_INFO, "src/game/ui.c", 1, "credits=%d ok=%s", 12,
                   "yes");
  REQUIRE(capture_end(&cap, out, sizeof out));
  REQUIRE(line_contains(out, "credits=12 ok=yes"));
  return true;
}

TEST_CASE(test_long_message_does_not_overflow) {
  char big[2048];
  for (size_t i = 0; i < sizeof big - 1; i++) {
    big[i] = 'A';
  }
  big[sizeof big - 1] = '\0';

  char out[4096];
  StderrCapture cap;
  REQUIRE(capture_begin(&cap));
  atom_log_message(ATOM_LOG_INFO, "src/game/ui.c", 1, "%s", big);
  REQUIRE(capture_end(&cap, out, sizeof out));
  REQUIRE(time_column_ok(out));
  REQUIRE(line_contains(out, "INFO"));
  REQUIRE(line_contains(out, "AAA"));
  return true;
}

TEST_CASE(test_no_color_env_disables_ansi) {
  atom_log_test_setenv("NO_COLOR", "1");
  install_logger();
  char out[512];
  g_emit_level = ATOM_LOG_ERROR;
  g_emit_file  = "src/game/ui.c";
  g_emit_line  = 1;
  g_emit_fmt   = "nocolor";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(!has_ansi(out));
  REQUIRE(line_contains(out, "ERR "));
  REQUIRE(line_contains(out, "nocolor"));

  atom_log_test_setenv("NO_COLOR", "");
  install_logger();
  return true;
}

TEST_CASE(test_color_enabled_emits_ansi_and_reset) {
  atom_log_test_setenv("NO_COLOR", "");
  install_logger();
  atom_log_debug_force_color(true);

  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "src/game/ui.c";
  g_emit_line  = 1;
  g_emit_fmt   = "colored";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(has_ansi(out));
  REQUIRE(line_contains(out, "\x1b[32m"));
  REQUIRE(line_contains(out, "\x1b[0m"));
  REQUIRE(line_contains(out, "colored"));

  atom_log_debug_force_color(false);
  return true;
}

TEST_CASE(test_empty_no_color_allows_color_flag) {
  atom_log_test_setenv("NO_COLOR", "");
  install_logger();
  atom_log_debug_force_color(true);

  char out[512];
  g_emit_level = ATOM_LOG_INFO;
  g_emit_file  = "src/game/ui.c";
  g_emit_line  = 1;
  g_emit_fmt   = "empty-env";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(has_ansi(out));

  atom_log_debug_force_color(false);
  return true;
}

TEST_CASE(test_warn_has_no_sdl_style_prefix) {
  char out[512];
  g_emit_level = ATOM_LOG_WARN;
  g_emit_file  = "src/game/ui.c";
  g_emit_line  = 10;
  g_emit_fmt   = "heads up";
  g_emit_arg   = nullptr;
  REQUIRE(capture_log(out, sizeof out, emit_log_message));
  REQUIRE(line_contains(out, "WARN"));
  REQUIRE(!line_contains(out, "WARN: "));
  REQUIRE(!line_contains(out, "WARNING"));
  return true;
}

static TEST_SUITE(suite_atom_log) {
  RUN_TEST_CASE(test_log_level_tags);
  RUN_TEST_CASE(test_log_level_invalid_falls_back_to_info);
  RUN_TEST_CASE(test_log_macros_forward_to_message);
  RUN_TEST_CASE(test_src_relative_path_from_absolute);
  RUN_TEST_CASE(test_src_relative_path_capital_s);
  RUN_TEST_CASE(test_src_relative_path_backslash);
  RUN_TEST_CASE(test_basename_fallback_when_no_src);
  RUN_TEST_CASE(test_empty_and_null_file_become_dash);
  RUN_TEST_CASE(test_src_must_be_path_component);
  RUN_TEST_CASE(test_wide_location_not_truncated);
  RUN_TEST_CASE(test_printf_formatting);
  RUN_TEST_CASE(test_long_message_does_not_overflow);
  RUN_TEST_CASE(test_no_color_env_disables_ansi);
  RUN_TEST_CASE(test_color_enabled_emits_ansi_and_reset);
  RUN_TEST_CASE(test_empty_no_color_allows_color_flag);
  RUN_TEST_CASE(test_warn_has_no_sdl_style_prefix);
}

int main(void) {
  pu_setup(fixture_setup, fixture_teardown);
  RUN_TEST_SUITE(suite_atom_log);
  pu_print_stats();
  return pu_test_failed() ? 1 : 0;
}
