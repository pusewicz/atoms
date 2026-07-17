/* colour.c — TTY / NO_COLOR detection.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

#if defined(_WIN32)
#include <io.h>
#include <stdio.h>
#elif !defined(__EMSCRIPTEN__)
#include <unistd.h>
#endif

static bool atom_log__detect_color(void) {
#ifdef ATOM_LOG_NO_COLOR
  return false;
#else
  const char* no_color = getenv("NO_COLOR");
  if (no_color && no_color[0] != '\0') {
    return false;
  }

#if defined(__EMSCRIPTEN__)
  return false;
#elif defined(_WIN32)
  return _isatty(_fileno(stderr)) != 0;
#else
  return isatty(STDERR_FILENO) != 0;
#endif
#endif
}
