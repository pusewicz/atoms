/* format.c — time column, level tags, line writer.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

#include <time.h>

enum {
  ATOM_LOG_PRIO_TRACE = 0,
  ATOM_LOG_PRIO_VERBOSE,
  ATOM_LOG_PRIO_DEBUG,
  ATOM_LOG_PRIO_INFO,
  ATOM_LOG_PRIO_WARN,
  ATOM_LOG_PRIO_ERROR,
  ATOM_LOG_PRIO_CRITICAL,
  ATOM_LOG_PRIO_UNKNOWN
};

enum { ATOM_LOG_LOC_WIDTH = 32 };

static const char* atom_log__level_tag(int prio) {
  switch (prio) {
  case ATOM_LOG_PRIO_TRACE:
    return "TRCE";
  case ATOM_LOG_PRIO_VERBOSE:
    return "VERB";
  case ATOM_LOG_PRIO_DEBUG:
    return "DEBG";
  case ATOM_LOG_PRIO_INFO:
    return "INFO";
  case ATOM_LOG_PRIO_WARN:
    return "WARN";
  case ATOM_LOG_PRIO_ERROR:
    return "ERR ";
  case ATOM_LOG_PRIO_CRITICAL:
    return "CRIT";
  default:
    return "????";
  }
}

#ifndef ATOM_LOG_NO_COLOR
static const char* atom_log__level_color(int prio) {
  switch (prio) {
  case ATOM_LOG_PRIO_TRACE:
  case ATOM_LOG_PRIO_VERBOSE:
    return "\x1b[2m";
  case ATOM_LOG_PRIO_DEBUG:
    return "\x1b[36m";
  case ATOM_LOG_PRIO_INFO:
    return "\x1b[32m";
  case ATOM_LOG_PRIO_WARN:
    return "\x1b[33m";
  case ATOM_LOG_PRIO_ERROR:
    return "\x1b[31m";
  case ATOM_LOG_PRIO_CRITICAL:
    return "\x1b[1;31m";
  default:
    return "";
  }
}
#endif

static void atom_log__format_time(char* out, size_t out_n) {
#if defined(CLOCK_REALTIME)
  struct timespec ts;
  if (clock_gettime(CLOCK_REALTIME, &ts) == 0) {
    struct tm tm;
#if defined(_WIN32)
    if (localtime_s(&tm, &ts.tv_sec) == 0) {
#else
    if (localtime_r(&ts.tv_sec, &tm) != NULL) {
#endif
      const int ms = (int)(ts.tv_nsec / 1000000L);
      snprintf(out, out_n, "%02d:%02d:%02d.%03d", tm.tm_hour, tm.tm_min,
               tm.tm_sec, ms);
      return;
    }
  }
#else
  time_t now = time(NULL);
  if (now != (time_t)-1) {
    struct tm* tm = localtime(&now);
    if (tm) {
      snprintf(out, out_n, "%02d:%02d:%02d.000", tm->tm_hour, tm->tm_min,
               tm->tm_sec);
      return;
    }
  }
#endif
  snprintf(out, out_n, "%s", "??:??:??.???");
}

static int atom_log__prio_from_level(AtomLogLevel level) {
  switch (level) {
  case ATOM_LOG_TRACE:
    return ATOM_LOG_PRIO_TRACE;
  case ATOM_LOG_DEBUG:
    return ATOM_LOG_PRIO_DEBUG;
  case ATOM_LOG_INFO:
    return ATOM_LOG_PRIO_INFO;
  case ATOM_LOG_WARN:
    return ATOM_LOG_PRIO_WARN;
  case ATOM_LOG_ERROR:
    return ATOM_LOG_PRIO_ERROR;
  default:
    return ATOM_LOG_PRIO_INFO;
  }
}

/// Write one column-aligned line to the active output.
static void atom_log__write_line(bool color, int prio, const char* loc,
                                 const char* text, AtomLogOutputFn out_fn,
                                 void* out_ud) {
  char time_buf[16];
  char line[1280];

  atom_log__format_time(time_buf, sizeof time_buf);

  const char* tag = atom_log__level_tag(prio);
  const char* msg = text ? text : "";
  const char* location = loc ? loc : "-";

#ifndef ATOM_LOG_NO_COLOR
  const char* cseq = color ? atom_log__level_color(prio) : "";
  const char* dim = color ? "\x1b[2m" : "";
  const char* reset = color ? "\x1b[0m" : "";
#else
  (void)color;
  const char* cseq = "";
  const char* dim = "";
  const char* reset = "";
#endif

  const int loc_pad = (int)strlen(location);
  const int loc_field =
      loc_pad < ATOM_LOG_LOC_WIDTH ? ATOM_LOG_LOC_WIDTH : loc_pad;

  snprintf(line, sizeof line, "%s%s%s  %s%s%s  %s%-*s%s  %s\n", dim, time_buf,
           reset, cseq, tag, reset, dim, loc_field, location, reset, msg);

  if (out_fn) {
    out_fn(out_ud, line);
  } else {
    fputs(line, stderr);
  }
}
