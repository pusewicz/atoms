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
