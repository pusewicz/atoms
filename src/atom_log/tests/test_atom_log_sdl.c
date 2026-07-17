/**
 * @file test_atom_log_sdl.c
 * @brief SDL backend tests for atom_log (requires ATOM_LOG_SDL + SDL3).
 */

#define PICO_UNIT_IMPLEMENTATION
#include <pico_unit.h>

#ifndef ATOM_LOG_SDL
#define ATOM_LOG_SDL
#endif
#define ATOM_LOG_IMPLEMENTATION
#include "atom_log.h"

#include <SDL3/SDL_log.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

static const char k_loc_mark = '\x1e';

typedef struct StderrCapture {
  char path[96];
  int saved_fd;
  int tmp_fd;
} StderrCapture;

static void capture_drop(StderrCapture* c) {
  if (c->tmp_fd >= 0) {
    close(c->tmp_fd);
    c->tmp_fd = -1;
  }
  if (c->path[0] != '\0') {
    unlink(c->path);
    c->path[0] = '\0';
  }
}

static bool capture_begin(StderrCapture* c) {
  c->path[0] = '\0';
  c->tmp_fd = -1;
  c->saved_fd = -1;
  fflush(stderr);
  snprintf(c->path, sizeof c->path, "build/test_atom_log_sdl_%d.tmp",
           (int)getpid());
  FILE* f = fopen(c->path, "w+b");
  if (!f) {
    return false;
  }
  c->tmp_fd = dup(fileno(f));
  fclose(f);
  if (c->tmp_fd < 0) {
    capture_drop(c);
    return false;
  }
  c->saved_fd = dup(STDERR_FILENO);
  if (c->saved_fd < 0 || dup2(c->tmp_fd, STDERR_FILENO) < 0) {
    capture_drop(c);
    return false;
  }
  return true;
}

static bool capture_end(StderrCapture* c, char* out, size_t out_n) {
  fflush(stderr);
  dup2(c->saved_fd, STDERR_FILENO);
  close(c->saved_fd);
  c->saved_fd = -1;
  close(c->tmp_fd);
  c->tmp_fd = -1;
  FILE* f = fopen(c->path, "rb");
  unlink(c->path);
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

static bool line_contains(const char* line, const char* needle) {
  return strstr(line, needle) != NULL;
}

static void install_logger(void) {
  atom_log_init();
  atom_log_set_level(ATOM_LOG_TRACE);
  atom_log_debug_force_color(false);
  SDL_SetLogPriorities(SDL_LOG_PRIORITY_TRACE);
}

static void fixture_setup(void) {
  setenv("NO_COLOR", "", 1);
  install_logger();
}

static void fixture_teardown(void) {}

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
  REQUIRE(g_log_out != NULL);
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

  for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
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
  REQUIRE(g_log_out != NULL);

  struct {
    SDL_LogPriority priority;
    const char* tag;
  } cases[] = {
      {SDL_LOG_PRIORITY_TRACE, "TRCE"},
      {SDL_LOG_PRIORITY_VERBOSE, "VERB"},
      {SDL_LOG_PRIORITY_DEBUG, "DEBG"},
      {SDL_LOG_PRIORITY_INFO, "INFO"},
      {SDL_LOG_PRIORITY_WARN, "WARN"},
      {SDL_LOG_PRIORITY_ERROR, "ERR "},
      {SDL_LOG_PRIORITY_CRITICAL, "CRIT"},
      {(SDL_LogPriority)12345, "????"},
  };

  for (size_t i = 0; i < sizeof cases / sizeof cases[0]; i++) {
    char out[512];
    g_cb_category = SDL_LOG_CATEGORY_APPLICATION;
    g_cb_priority = cases[i].priority;
    g_cb_message = "prio";
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
  g_cb_message = body;
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
  g_cb_message = body;
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

TEST_CASE(test_atom_log_message_uses_location) {
  char out[512];
  StderrCapture cap;
  REQUIRE(capture_begin(&cap));
  atom_log_message(ATOM_LOG_INFO, "src/game/ui.c", 416, "via-api");
  REQUIRE(capture_end(&cap, out, sizeof out));
  REQUIRE(line_contains(out, "src/game/ui.c:416"));
  REQUIRE(line_contains(out, "via-api"));
  REQUIRE(line_contains(out, "INFO"));
  return true;
}

static TEST_SUITE(suite_atom_log_sdl) {
  RUN_TEST_CASE(test_init_installs_output_callback);
  RUN_TEST_CASE(test_category_labels);
  RUN_TEST_CASE(test_all_sdl_priority_tags);
  RUN_TEST_CASE(test_marked_body_splits_location);
  RUN_TEST_CASE(test_marked_body_missing_second_mark_falls_back);
  RUN_TEST_CASE(test_unmarked_body_uses_category);
  RUN_TEST_CASE(test_atom_log_message_uses_location);
}

int main(void) {
  pu_setup(fixture_setup, fixture_teardown);
  RUN_TEST_SUITE(suite_atom_log_sdl);
  pu_print_stats();
  return pu_test_failed() ? 1 : 0;
}
