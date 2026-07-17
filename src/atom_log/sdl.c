/* sdl.c — optional SDL3 log backend + RS location packing.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

#ifdef ATOM_LOG_SDL

#include <SDL3/SDL_log.h>

/* RS (record separator): pack call-site across module boundaries via SDL body.
 * static const for compilers that lack C23 constexpr objects. */
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

static void atom_log__sdl_install(void) {
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_TRACE, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_VERBOSE, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_DEBUG, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_INFO, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_WARN, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_ERROR, "");
  SDL_SetLogPriorityPrefix(SDL_LOG_PRIORITY_CRITICAL, "");
  SDL_SetLogOutputFunction(atom_log__sdl_output, nullptr);
#if !defined(NDEBUG)
  SDL_SetLogPriorities(SDL_LOG_PRIORITY_VERBOSE);
#endif
}

static void atom_log__emit(AtomLogLevel level, const char* file, int line,
                           const char* user_message) {
  if ((int)level < (int)g_atom_log_min_level) {
    return;
  }
  char loc[128];
  char body[1024];
  atom_log__format_location(loc, sizeof loc, file, line);
  const int written =
      snprintf(body, sizeof body, "%c%s%c%s", atom_log_loc_mark, loc,
               atom_log_loc_mark, user_message ? user_message : "");
  if (written < 0) {
    body[0] = '\0';
  }
  SDL_LogMessage(SDL_LOG_CATEGORY_CUSTOM, atom_log__sdl_from_level(level), "%s",
                 body);
}

#else /* !ATOM_LOG_SDL */

static void atom_log__sdl_install(void) {}

static void atom_log__emit(AtomLogLevel level, const char* file, int line,
                           const char* user_message) {
  if ((int)level < (int)g_atom_log_min_level) {
    return;
  }
  const AtomLogPrio prio = atom_log__prio_from_level(level);
  char loc[128];
  atom_log__format_location(loc, sizeof loc, file, line);
  atom_log__write_line(g_atom_log_color, prio, loc, user_message,
                       g_atom_log_out_fn, g_atom_log_out_ud);
}

#endif /* ATOM_LOG_SDL */
