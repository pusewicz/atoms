/* path.c — source path rewrite for the location column.
 * Amalgamated inside ATOM_LOG_IMPLEMENTATION. Do not compile standalone.
 */

#ifndef ATOM_LOG_PATH_MARKER
#define ATOM_LOG_PATH_MARKER "src"
#endif

/// Prefer a project-relative marker path (default "src/…"); else basename.
static const char* atom_log__src_relative_path(const char* file) {
  if (!file || !file[0]) {
    return "-";
  }

  const char* marker = ATOM_LOG_PATH_MARKER;
  const size_t mlen = strlen(marker);

  for (const char* p = file; *p; ++p) {
    size_t i = 0;
    for (; i < mlen; ++i) {
      char a = p[i];
      char b = marker[i];
      if (a >= 'A' && a <= 'Z') {
        a = (char)(a - 'A' + 'a');
      }
      if (b >= 'A' && b <= 'Z') {
        b = (char)(b - 'A' + 'a');
      }
      if (a != b) {
        break;
      }
    }
    if (i == mlen && (p[mlen] == '/' || p[mlen] == '\\')) {
      if (p == file || p[-1] == '/' || p[-1] == '\\') {
        return p;
      }
    }
  }

  const char* base = file;
  for (const char* p = file; *p; ++p) {
    if (*p == '/' || *p == '\\') {
      base = p + 1;
    }
  }
  return base;
}

static void atom_log__format_location(char* out, size_t out_n, const char* file,
                                      int line) {
  const char* rel = atom_log__src_relative_path(file);
  char path[256];
  size_t i = 0;
  for (; rel[i] && i + 1 < sizeof path; ++i) {
    path[i] = (rel[i] == '\\') ? '/' : rel[i];
  }
  path[i] = '\0';
  snprintf(out, out_n, "%s:%d", path, line);
}
