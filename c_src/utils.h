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

static ERL_NIF_TERM EX_ASTRO_UNUSED
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

static bool EX_ASTRO_UNUSED
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
  int load_status = 0;

  /*
   * load_info is ignored. Kernel furnishing is a runtime NIF so a missing
   * path can be retried later instead of being baked into module load.
   */
  (void)env;
  (void)priv;
  (void)load_info;

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
  }

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

/*
 * Runtime kernel management for this shared object's CSPICE pool only.
 * Each NIF .so links its own toolkit image, so these helpers never
 * synchronize sibling pools. kernel_furnsh snapshots top-level paths
 * (kdata source empty), because furnsh_c can leave a partial load on
 * failure — especially meta-kernels.
 */
#define KERNEL_PATH_BUF 256
#define KERNEL_TYPE_BUF 33
#define KERNEL_TX_ERROR_LENGTH (CSPICE_ERROR_LENGTH * 2 + 80)

static void
free_kernel_paths(char **paths, SpiceInt count)
{
  SpiceInt i;

  if (paths == NULL)
    return;

  for (i = 0; i < count; i++)
    free_string(paths[i]);

  free(paths);
}

static bool
snapshot_top_level_kernels(char ***paths_out, SpiceInt *count_out, char *error)
{
  SpiceInt total = 0;
  SpiceInt which;
  SpiceInt top_count = 0;
  char **paths = NULL;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;

  *paths_out = NULL;
  *count_out = 0;

  ktotal_c("ALL", &total);
  if (cspice_failed(error))
    return false;

  if (total > 0)
  {
    paths = calloc((size_t)total, sizeof(*paths));
    if (paths == NULL)
    {
      snprintf(error, CSPICE_ERROR_LENGTH, "failed to allocate kernel snapshot");
      return false;
    }
  }

  for (which = 0; which < total; which++)
  {
    size_t path_len;
    char *copy;

    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (cspice_failed(error))
    {
      free_kernel_paths(paths, top_count);
      return false;
    }

    /* Non-empty source means this file was pulled in by a meta-kernel. */
    if (!found || srcfil[0] != '\0')
      continue;

    path_len = strlen(file);
    copy = malloc(path_len + 1);
    if (copy == NULL)
    {
      snprintf(error, CSPICE_ERROR_LENGTH, "failed to allocate kernel snapshot path");
      free_kernel_paths(paths, top_count);
      return false;
    }

    memcpy(copy, file, path_len + 1);
    paths[top_count] = copy;
    top_count++;
  }

  *paths_out = paths;
  *count_out = top_count;
  return true;
}

static bool
restore_top_level_kernels(char **paths, SpiceInt count, char *error)
{
  SpiceInt i;

  kclear_c();
  if (cspice_failed(error))
    return false;

  for (i = 0; i < count; i++)
  {
    furnsh_c(paths[i]);
    if (cspice_failed(error))
      return false;
  }

  return true;
}

static ERL_NIF_TERM
kernel_furnsh(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *path = NULL;
  char **snapshot = NULL;
  SpiceInt snapshot_count = 0;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceChar restore_error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;
  bool locked = false;

  if (!load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &path))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }
  locked = true;

  if (!snapshot_top_level_kernels(&snapshot, &snapshot_count, error))
  {
    result = error_result(env, error);
    goto cleanup;
  }

  furnsh_c(path);

  if (cspice_failed(error))
  {
    if (!restore_top_level_kernels(snapshot, snapshot_count, restore_error))
    {
      SpiceChar combined[KERNEL_TX_ERROR_LENGTH];

      snprintf(combined, sizeof(combined),
               "kernel load failed: %s; restore after failed load also failed: %s",
               error, restore_error);
      result = error_result(env, combined);
      goto cleanup;
    }

    result = error_result(env, error);
    goto cleanup;
  }

  result = enif_make_atom(env, "ok");

cleanup:
  if (locked)
    cspice_unlock();
  free_kernel_paths(snapshot, snapshot_count);
  free_string(path);
  return result;
}

static ERL_NIF_TERM
kernel_unload(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *path = NULL;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;

  if (!load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &path))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  unload_c(path);

  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = enif_make_atom(env, "ok");

cleanup:
  free_string(path);
  return result;
}

static ERL_NIF_TERM
kernel_clear(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!cspice_lock())
    return cspice_sync_error(env);

  kclear_c();

  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();
  return enif_make_atom(env, "ok");
}

static ERL_NIF_TERM
kernel_loaded_direct(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *path = NULL;
  SpiceInt count = 0;
  SpiceInt which;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;
  bool direct = false;

  if (!load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &path))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  ktotal_c("ALL", &count);
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  for (which = 0; which < count; which++)
  {
    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (cspice_failed(error))
    {
      cspice_unlock();
      result = error_result(env, error);
      goto cleanup;
    }

    if (found && srcfil[0] == '\0' && strcmp(file, path) == 0)
    {
      direct = true;
      break;
    }
  }

  cspice_unlock();
  result = enif_make_atom(env, direct ? "true" : "false");

cleanup:
  free_string(path);
  return result;
}

static ERL_NIF_TERM
kernel_list(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt count = 0;
  SpiceInt which;
  SpiceInt listed = 0;
  SpiceInt i;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM *files = NULL;
  ERL_NIF_TERM list;

  if (!cspice_lock())
    return cspice_sync_error(env);

  ktotal_c("ALL", &count);
  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  if (count > 0)
  {
    files = malloc((size_t)count * sizeof(*files));
    if (files == NULL)
    {
      cspice_unlock();
      return error_result(env, "failed to allocate kernel list");
    }
  }

  for (which = 0; which < count; which++)
  {
    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (cspice_failed(error))
    {
      free(files);
      cspice_unlock();
      return error_result(env, error);
    }

    if (!found)
      continue;

    files[listed] = make_binary(env, file);
    listed++;
  }

  cspice_unlock();

  list = enif_make_list(env, 0);
  for (i = listed; i > 0; i--)
    list = enif_make_list_cell(env, files[i - 1], list);

  free(files);
  return ok_result(env, list);
}

#define EX_ASTRO_KERNEL_NIF_FUNCS                                          \
  {"kernel_furnsh", 1, kernel_furnsh, ERL_NIF_DIRTY_JOB_IO_BOUND},         \
  {"kernel_unload", 1, kernel_unload, ERL_NIF_DIRTY_JOB_IO_BOUND},         \
  {"kernel_clear", 0, kernel_clear, ERL_NIF_DIRTY_JOB_IO_BOUND},           \
  {"kernel_loaded_direct", 1, kernel_loaded_direct, 0},                     \
  {"kernel_list", 0, kernel_list, 0}

#endif
