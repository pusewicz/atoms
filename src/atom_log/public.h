/**
 * @file public.h
 * @brief Public API for atom_log — column-aligned leveled logging.
 */

#ifndef ATOM_LOG_PUBLIC_H
#define ATOM_LOG_PUBLIC_H

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef ATOM_LOG_API
#ifdef ATOM_LOG_STATIC
#define ATOM_LOG_API static
#else
#define ATOM_LOG_API
#endif
#endif

/**
 * @brief Severity levels for log lines.
 */
typedef enum AtomLogLevel : int {
  ATOM_LOG_TRACE = 0,
  ATOM_LOG_DEBUG = 1,
  ATOM_LOG_INFO  = 2,
  ATOM_LOG_WARN  = 3,
  ATOM_LOG_ERROR = 4,
} AtomLogLevel;

/**
 * @brief Optional custom line writer.
 *
 * When set, replaces the default stderr writer. The callback receives a
 * complete formatted line including the trailing newline.
 *
 * @param userdata  Pointer passed to atom_log_set_output.
 * @param line      NUL-terminated line including trailing newline.
 */
typedef void (*AtomLogOutputFn)(void* userdata, const char* line);

/**
 * @brief Configure logging for the process.
 *
 * Detects color support (TTY and the NO_COLOR environment variable),
 * clears SDL's log prefixes, installs atom_log's line formatter via
 * SDL_SetLogOutputFunction, and resets the minimum level to
 * ATOM_LOG_TRACE. Call once at startup, before atom_log_set_level.
 *
 * atom_log_init must be called before any other atom_log function. Until it
 * runs, lines go through SDL's default log output: anything below
 * ATOM_LOG_ERROR is dropped by SDL's default priority for the log category,
 * lines that do print carry atom_log's internal location markers as raw
 * control bytes, and atom_log_set_output is bypassed.
 */
ATOM_LOG_API void atom_log_init(void);

/**
 * @brief Set the minimum level that will be emitted (inclusive).
 *
 * Delegates to SDL_SetLogPriority for atom_log's SDL log category. Lines
 * below @p min are discarded. Call after atom_log_init, which resets the
 * minimum to ATOM_LOG_TRACE.
 *
 * @param min  Minimum severity to emit.
 */
ATOM_LOG_API void atom_log_set_level(AtomLogLevel min);

/**
 * @brief Send formatted lines to a custom writer instead of stderr.
 *
 * @param fn        Callback, or nullptr to restore the stderr default.
 * @param userdata  Passed through to @p fn.
 */
ATOM_LOG_API void atom_log_set_output(AtomLogOutputFn fn, void* userdata);

/**
 * @brief Force ANSI color on or off.
 *
 * Overrides the detection done by atom_log_init. Intended for tests.
 *
 * @param enabled  true to emit color escape sequences.
 */
ATOM_LOG_API void atom_log_debug_force_color(bool enabled);

/**
 * @brief Emit a printf-formatted log line with source location.
 *
 * Prefer the atom_log_trace/debug/info/warn/error macros. Message text is
 * truncated to an internal 1024-byte buffer.
 *
 * @param level   Severity.
 * @param file    Source file (usually __FILE__).
 * @param line    Source line (usually __LINE__).
 * @param format  printf-style format string.
 * @param ...     Format arguments.
 */
[[gnu::format(printf, 4, 5)]] ATOM_LOG_API void
atom_log_message(AtomLogLevel level, const char* file, int line,
                 const char* format, ...);

/**
 * @brief Log an unrecoverable error and abort.
 *
 * Prefer the atom_fatal() macro.
 *
 * @param file    Source file.
 * @param line    Source line.
 * @param format  printf-style format string.
 * @param ...     Format arguments.
 */
[[noreturn, gnu::format(printf, 3, 4)]] ATOM_LOG_API void
atom_log_fatal(const char* file, int line, const char* format, ...);

/** @brief Log at trace severity. */
#define atom_log_trace(...)                                                    \
  atom_log_message(ATOM_LOG_TRACE, __FILE__, __LINE__, __VA_ARGS__)
/** @brief Log at debug severity. */
#define atom_log_debug(...)                                                    \
  atom_log_message(ATOM_LOG_DEBUG, __FILE__, __LINE__, __VA_ARGS__)
/** @brief Log at info severity. */
#define atom_log_info(...)                                                     \
  atom_log_message(ATOM_LOG_INFO, __FILE__, __LINE__, __VA_ARGS__)
/** @brief Log at warn severity. */
#define atom_log_warn(...)                                                     \
  atom_log_message(ATOM_LOG_WARN, __FILE__, __LINE__, __VA_ARGS__)
/** @brief Log at error severity. */
#define atom_log_error(...)                                                    \
  atom_log_message(ATOM_LOG_ERROR, __FILE__, __LINE__, __VA_ARGS__)
/** @brief Abort with a formatted error at the call site. */
#define atom_fatal(...) atom_log_fatal(__FILE__, __LINE__, __VA_ARGS__)

#ifdef __cplusplus
}
#endif

#endif /* ATOM_LOG_PUBLIC_H */
