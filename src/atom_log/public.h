/**
 * @file public.h
 * @brief Public API for atom_log — column-aligned leveled logging.
 */

#ifndef ATOM_LOG_PUBLIC_H
#define ATOM_LOG_PUBLIC_H

#include <stdbool.h>
#include <stddef.h>

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
 * @brief Compile-time length of a fixed array (rejects decayed pointers).
 *
 * Uses C23 @c typeof and @c _Generic so passing a pointer is a type error.
 */
#define ATOM_LOG_COUNTOF(arr)                                                  \
  (_Generic(&(arr), typeof((arr)[0])(*)[]: (sizeof(arr) / sizeof((arr)[0]))))

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
 * Detects colour (TTY + NO_COLOR), installs the default stderr writer, and
 * when ATOM_LOG_SDL is defined installs the SDL log output backend. Call once
 * at startup.
 */
ATOM_LOG_API void atom_log_init(void);

/**
 * @brief Set the minimum level that will be emitted (inclusive).
 *
 * Lines below @p min are discarded. Default is ATOM_LOG_TRACE.
 *
 * @param min  Minimum severity to emit.
 */
ATOM_LOG_API void atom_log_set_level(AtomLogLevel min);

/**
 * @brief Replace the default stderr writer.
 *
 * @param fn        Callback, or nullptr to restore stderr.
 * @param userdata  Passed to @p fn.
 */
ATOM_LOG_API void atom_log_set_output(AtomLogOutputFn fn, void* userdata);

/**
 * @brief Force ANSI colour on or off (test / override hook).
 *
 * @param enabled  true to enable colour escape sequences.
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

#ifdef ATOM_LOG_SHORT_NAMES
#ifndef log_trace
#define log_trace(...) atom_log_trace(__VA_ARGS__)
#define log_debug(...) atom_log_debug(__VA_ARGS__)
#define log_info(...) atom_log_info(__VA_ARGS__)
#define log_warn(...) atom_log_warn(__VA_ARGS__)
#define log_error(...) atom_log_error(__VA_ARGS__)
#define fatal(...) atom_fatal(__VA_ARGS__)
#define log_message atom_log_message
#define logger_init atom_log_init
#endif
#endif

#ifdef __cplusplus
}
#endif

#endif /* ATOM_LOG_PUBLIC_H */
