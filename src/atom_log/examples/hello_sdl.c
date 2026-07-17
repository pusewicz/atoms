/**
 * @file hello_sdl.c
 * @brief Optional SDL3 backend — atom_log and SDL_Log share one column layout.
 *
 * Requires SDL3. Locally: rake example:atom_log (skips if SDL3 is missing).
 * Define ATOM_LOG_SDL before the header and link SDL3.
 */

#ifndef ATOM_LOG_SDL
#define ATOM_LOG_SDL
#endif
#define ATOM_LOG_IMPLEMENTATION
#include <SDL3/SDL_log.h>

#include "atom_log.h"

int main(void) {
  /* Installs SDL_SetLogOutputFunction and clears SDL priority prefixes. */
  atom_log_init();
  atom_log_set_level(ATOM_LOG_TRACE);

  atom_log_info("atom_log via SDL backend");
  atom_log_warn("call-site path is packed through SDL_LogMessage");

  /* Unmarked SDL messages use the category label as the location column. */
  SDL_Log("plain SDL_Log (application category)");
  SDL_LogInfo(SDL_LOG_CATEGORY_APPLICATION, "SDL app info %d", 7);
  SDL_LogWarn(SDL_LOG_CATEGORY_VIDEO, "SDL video warn");
  SDL_LogError(SDL_LOG_CATEGORY_ERROR, "SDL error channel");

  return 0;
}
