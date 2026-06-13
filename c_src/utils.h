#include <stdlib.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>
#include <erl_nif.h>
#include <erfa.h>
#include "SpiceUsr.h"

#define CSPICE_ERROR_LENGTH 1841

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

static bool
load_string(ErlNifEnv *env, ERL_NIF_TERM arg, char **result)
{
  ErlNifBinary bin;

  if (!enif_inspect_binary(env, arg, &bin))
    return false;

  *result = malloc(sizeof(char) * (bin.size + 1));
  if (*result == NULL)
    return false;

  memcpy(*result, bin.data, bin.size);
  (*result)[bin.size] = '\0';

  return true;
}

static void
free_string(char *value)
{
  if (value != NULL)
    free(value);
}

static bool
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

static ERL_NIF_TERM
make_list(ErlNifEnv *env, double *list, size_t len)
{
  ERL_NIF_TERM result[len];

  for (int i = 0; i < len; i++)
  {
    result[i] = enif_make_double(env, list[i]);
  }

  return enif_make_list_from_array(env, result, len);
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

static ERL_NIF_TERM
ok_result(ErlNifEnv *env, ERL_NIF_TERM r)
{
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), r);
}

static ERL_NIF_TERM
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
    if (!load_string(env, head, &path))
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
