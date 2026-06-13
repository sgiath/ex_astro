#ifndef EX_ASTRO_UTILS_H
#define EX_ASTRO_UTILS_H

/*
 * Shared NIF utility implementation.
 *
 * This header intentionally contains static helper definitions and static NIF
 * lifecycle state. Each first-party NIF C file includes it once, giving every
 * shared object its own CSPICE mutex/error/kernel ownership while keeping the
 * public NIF modules independent. Do not move these helpers to external
 * linkage without also redesigning that per-shared-object ownership model.
 */

#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <erl_nif.h>
#include <erfa.h>
#include "SpiceUsr.h"

#if defined(__GNUC__)
#define EX_ASTRO_UNUSED __attribute__((unused))
#else
#define EX_ASTRO_UNUSED
#endif

#define CSPICE_ERROR_LENGTH 1841

typedef enum
{
  NATIVE_STRING_BODY,
  NATIVE_STRING_FRAME,
  NATIVE_STRING_ABCORR,
  NATIVE_STRING_KERNEL_PATH,
  NATIVE_STRING_KERNEL_ITEM,
  NATIVE_STRING_TIME,
  NATIVE_STRING_UTC_TIME,
  NATIVE_STRING_TIME_SYSTEM
} NativeStringKind;

/*
 * Native string limits are byte counts excluding the trailing terminator.
 *
 * The NIF boundary rejects empty binaries, embedded NUL bytes, and binaries
 * longer than the category limit before CSPICE or ERFA-adjacent code sees a
 * NUL-terminated C string. Invalid native strings intentionally use the same
 * badarg/ArgumentError path as non-binary inputs.
 *
 * Limit rationale:
 * - Body names/ID strings: CSPICE body-name translation MAXL is 36.
 * - Frames: frames.req says user frame names must not exceed 26 characters.
 * - Aberration corrections: longest documented option is "XCN+S".
 * - Kernel paths: furnsh_c FILSIZ accepts non-blank file names up to 255.
 * - Kernel items: kernel.req caps kernel variable names at 32 characters.
 * - Time strings: str2et_c handles general calendar strings; 256 covers the
 *   documented examples without caller-controlled allocation.
 * - UTC strings: utc2et_c says input length should not exceed 80 characters.
 * - Time systems: longest unitim_c system name is "JDTDB"/"JDTDT".
 */
#define NATIVE_STRING_BODY_MAX 36
#define NATIVE_STRING_FRAME_MAX 26
#define NATIVE_STRING_ABCORR_MAX 5
#define NATIVE_STRING_KERNEL_PATH_MAX 255
#define NATIVE_STRING_KERNEL_ITEM_MAX 32
#define NATIVE_STRING_TIME_MAX 256
#define NATIVE_STRING_UTC_TIME_MAX 80
#define NATIVE_STRING_TIME_SYSTEM_MAX 5

static ErlNifMutex *cspice_mutex = NULL;

/*
 * CSPICE keeps process-global kernel/error state inside each linked toolkit
 * image. Every CSPICE call that may touch that state must hold this mutex
 * through failed_c/getmsg_c/reset_c so another BEAM scheduler cannot observe
 * or overwrite the error state from this call. The Makefile binds each NIF to
 * its own statically linked CSPICE copy, so this mutex is owned per NIF shared
 * object and is created/destroyed by the NIF load/unload callbacks below.
 */
static bool
cspice_lock(void)
{
  if (cspice_mutex == NULL)
  {
    fprintf(stderr, "CSPICE synchronization unavailable: mutex is not initialized\n");
    return false;
  }

  enif_mutex_lock(cspice_mutex);
  return true;
}

static void
cspice_unlock(void)
{
  enif_mutex_unlock(cspice_mutex);
}

static size_t
native_string_limit(NativeStringKind kind)
{
  switch (kind)
  {
  case NATIVE_STRING_BODY:
    return NATIVE_STRING_BODY_MAX;
  case NATIVE_STRING_FRAME:
    return NATIVE_STRING_FRAME_MAX;
  case NATIVE_STRING_ABCORR:
    return NATIVE_STRING_ABCORR_MAX;
  case NATIVE_STRING_KERNEL_PATH:
    return NATIVE_STRING_KERNEL_PATH_MAX;
  case NATIVE_STRING_KERNEL_ITEM:
    return NATIVE_STRING_KERNEL_ITEM_MAX;
  case NATIVE_STRING_TIME:
    return NATIVE_STRING_TIME_MAX;
  case NATIVE_STRING_UTC_TIME:
    return NATIVE_STRING_UTC_TIME_MAX;
  case NATIVE_STRING_TIME_SYSTEM:
    return NATIVE_STRING_TIME_SYSTEM_MAX;
  }

  return 0;
}

static bool
load_string(ErlNifEnv *env, ERL_NIF_TERM arg, NativeStringKind kind, char **result)
{
  ErlNifBinary bin;
  size_t limit = native_string_limit(kind);
  size_t allocation_size;
  char *value;

  if (!enif_inspect_binary(env, arg, &bin))
    return false;

  if (bin.size == 0 || bin.size > limit)
    return false;

  if (memchr(bin.data, '\0', bin.size) != NULL)
    return false;

  if (bin.size > SIZE_MAX - 1)
    return false;

  allocation_size = bin.size + 1;
  value = malloc(allocation_size);
  if (value == NULL)
    return false;

  memcpy(value, bin.data, bin.size);
  value[bin.size] = '\0';
  *result = value;

  return true;
}

static void
free_string(char *value)
{
  if (value != NULL)
    free(value);
}

static bool EX_ASTRO_UNUSED
load_list(ErlNifEnv *env, ERL_NIF_TERM arg, size_t l, double *result)
{
  unsigned int len;
  if (!enif_get_list_length(env, arg, &len) || len != l)
    return false;

  ERL_NIF_TERM head, tail = arg;

  for (unsigned int i = 0; i < len; i++)
  {
    if (!enif_get_list_cell(env, tail, &head, &tail) ||
        !enif_get_double(env, head, &result[i]))
      return false;
  }

  return true;
}

static ERL_NIF_TERM EX_ASTRO_UNUSED
make_list(ErlNifEnv *env, double *list, size_t len)
{
  ERL_NIF_TERM result = enif_make_list(env, 0);

  /*
   * Build from the tail to avoid variable-length stack arrays. Existing
   * callers pass fixed SPICE/ERFA output sizes, and this stays bounded by
   * caller-visible list length instead of stack capacity.
   */
  for (size_t i = len; i > 0; i--)
  {
    result = enif_make_list_cell(env, enif_make_double(env, list[i - 1]), result);
  }

  return result;
}

static ERL_NIF_TERM
make_binary(ErlNifEnv *env, char *data)
{
  ErlNifBinary bin;

  // Assuming 'data' is a null-terminated char*
  size_t length = strlen(data);

  // Create a binary term from the data
  if (enif_alloc_binary(length, &bin))
  {
    memcpy(bin.data, data, length);
    return enif_make_binary(env, &bin);
  }
  else
  {
    // Return an error term if allocation fails
    return enif_make_badarg(env);
  }
}

static ERL_NIF_TERM
error_result(ErlNifEnv *env, char *error_msg)
{
  return enif_make_tuple2(env, enif_make_atom(env, "error"), make_binary(env, error_msg));
}

static ERL_NIF_TERM
cspice_sync_error(ErlNifEnv *env)
{
  return error_result(env, "CSPICE synchronization unavailable");
}

static void
read_cspice_error(char *error_msg)
{
  getmsg_c("LONG", CSPICE_ERROR_LENGTH - 1, error_msg);
  error_msg[CSPICE_ERROR_LENGTH - 1] = '\0';

  reset_c();
}

static bool
cspice_failed(char *error_msg)
{
  if (!failed_c())
    return false;

  read_cspice_error(error_msg);
  return true;
}

static ERL_NIF_TERM EX_ASTRO_UNUSED
ok_result(ErlNifEnv *env, ERL_NIF_TERM r)
{
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), r);
}

static ERL_NIF_TERM EX_ASTRO_UNUSED
ok_result2(ErlNifEnv *env, ERL_NIF_TERM r1, ERL_NIF_TERM r2)
{
  return enif_make_tuple3(env, enif_make_atom(env, "ok"), r1, r2);
}

static int
load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info)
{
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceChar *path = NULL;
  ERL_NIF_TERM head, tail = load_info;
  int load_status = 0;

  cspice_mutex = enif_mutex_create("ex_astro_cspice_mutex");
  if (cspice_mutex == NULL)
  {
    fprintf(stderr, "Failed to initialize CSPICE mutex during NIF load\n");
    return 1;
  }

  if (!cspice_lock())
  {
    enif_mutex_destroy(cspice_mutex);
    cspice_mutex = NULL;
    return 1;
  }

  erract_c("SET", 0, "RETURN");
  errdev_c("SET", 0, "NULL");
  errprt_c("SET", 0, "ALL");

  if (failed_c())
  {
    read_cspice_error(error);
    fprintf(stderr, "Failed to configure CSPICE error handling during NIF load: %s\n", error);
    load_status = 1;
    goto cleanup;
  }

  while (enif_get_list_cell(env, tail, &head, &tail))
  {
    if (!load_string(env, head, NATIVE_STRING_KERNEL_PATH, &path))
    {
      fprintf(stderr, "Failed to decode SPICE kernel path during NIF load\n");
      load_status = 1;
      goto cleanup;
    }

    furnsh_c(path);

    if (failed_c())
    {
      read_cspice_error(error);
      fprintf(stderr, "Failed to load SPICE kernel '%s': %s\n", path, error);
      load_status = 1;
      goto cleanup;
    }

    free_string(path);
    path = NULL;
  }

cleanup:
  free_string(path);
  cspice_unlock();

  if (load_status != 0)
  {
    enif_mutex_destroy(cspice_mutex);
    cspice_mutex = NULL;
  }

  return load_status;
}

static int
upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM load_info)
{
  return 1;
}

static void
unload(ErlNifEnv *env, void *priv)
{
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (cspice_mutex == NULL)
    return;

  if (cspice_lock())
  {
    kclear_c();

    if (failed_c())
    {
      read_cspice_error(error);
      fprintf(stderr, "Failed to clear CSPICE kernels during NIF unload: %s\n", error);
    }

    cspice_unlock();
  }

  enif_mutex_destroy(cspice_mutex);
  cspice_mutex = NULL;
}

#endif
