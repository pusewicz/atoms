/**
 * @file host_compat.h
 * @brief Minimal POSIX shims for unit tests (Windows vs Unix).
 */

#ifndef ATOM_LOG_TEST_HOST_COMPAT_H
#define ATOM_LOG_TEST_HOST_COMPAT_H

#include <stdio.h>
#include <stdlib.h>

#if defined(_WIN32)
#include <io.h>
#include <process.h>

#define ATOM_LOG_TEST_DUP(fd) _dup(fd)
#define ATOM_LOG_TEST_DUP2(a, b) _dup2((a), (b))
#define ATOM_LOG_TEST_CLOSE(fd) _close(fd)
#define ATOM_LOG_TEST_FILENO(f) _fileno(f)
#define ATOM_LOG_TEST_UNLINK(p) _unlink(p)
#define ATOM_LOG_TEST_GETPID() _getpid()
#ifndef STDERR_FILENO
#define STDERR_FILENO 2
#endif

static inline void atom_log_test_setenv(const char* key, const char* val) {
  /* _putenv_s requires non-null value; empty string clears for our tests. */
  (void)_putenv_s(key, val ? val : "");
}
#else
#include <unistd.h>

#define ATOM_LOG_TEST_DUP(fd) dup(fd)
#define ATOM_LOG_TEST_DUP2(a, b) dup2((a), (b))
#define ATOM_LOG_TEST_CLOSE(fd) close(fd)
#define ATOM_LOG_TEST_FILENO(f) fileno(f)
#define ATOM_LOG_TEST_UNLINK(p) unlink(p)
#define ATOM_LOG_TEST_GETPID() getpid()

static inline void atom_log_test_setenv(const char* key, const char* val) {
  setenv(key, val ? val : "", 1);
}
#endif

#endif /* ATOM_LOG_TEST_HOST_COMPAT_H */
