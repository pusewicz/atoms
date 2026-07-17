/* core.c — init, message emit, fatal, hooks.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

static bool g_atom_log_color;
static AtomLogLevel g_atom_log_min_level = ATOM_LOG_TRACE;
static AtomLogOutputFn g_atom_log_out_fn;
static void* g_atom_log_out_ud;

/* Forward decls filled in by sdl.c (SDL install + emit). */
static void atom_log__sdl_install(void);
static void atom_log__emit(AtomLogLevel level, const char* file, int line,
                           const char* user_message);

ATOM_LOG_API void atom_log_init(void) {
  g_atom_log_color = atom_log__detect_color();
  atom_log__sdl_install();
}

ATOM_LOG_API void atom_log_set_level(AtomLogLevel min) {
  g_atom_log_min_level = min;
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
  if (format) {
    vsnprintf(message, sizeof message, format, args);
  } else {
    message[0] = '\0';
  }
  va_end(args);
  atom_log__emit(level, file, line, message);
}

ATOM_LOG_API void atom_log_fatal(const char* file, int line, const char* format,
                                 ...) {
  char message[1024];
  va_list args;
  va_start(args, format);
  if (format) {
    vsnprintf(message, sizeof message, format, args);
  } else {
    message[0] = '\0';
  }
  va_end(args);

  char loc[128];
  atom_log__format_location(loc, sizeof loc, file, line);
  atom_log__write_line(g_atom_log_color, ATOM_LOG_PRIO_CRITICAL, loc, message,
                       g_atom_log_out_fn, g_atom_log_out_ud);
  abort();
}
