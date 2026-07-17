/**
 * @file hello.c
 * @brief Minimal atom_log example — init and a few levels.
 */

#define ATOM_LOG_IMPLEMENTATION
#include "atom_log.h"

int main(void) {
  atom_log_init();
  atom_log_trace("trace line");
  atom_log_debug("debug line");
  atom_log_info("booted %d", 42);
  atom_log_warn("heads up");
  atom_log_error("something failed: %s", "demo");
  return 0;
}
