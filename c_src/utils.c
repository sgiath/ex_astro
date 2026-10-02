#include "utils.h"

static ErlNifMutex *cspice_mutex = NULL;

/*
 * CSPICE keeps process-global kernel and error state inside the linked toolkit
 * image. Every CSPICE call that may touch that state must hold this mutex
 * through failed_c/getmsg_c/reset_c so another scheduler cannot observe or
 * overwrite the error state from the call.
 */
bool
exa_cspice_lock(void)
{
  if (cspice_mutex == NULL)
  {
    fprintf(stderr, "CSPICE synchronization unavailable: mutex is not initialized\n");
    return false;
  }

  enif_mutex_lock(cspice_mutex);
  return true;
}

void
exa_cspice_unlock(void)
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

/*
 * Copy a validated binary into the caller's buffer and NUL-terminate it.
 * `buf_size` must cover the category limit plus the terminator; returning
 * false means the input (or a too-small buffer) is invalid, never OOM.
 */
bool
exa_load_string(ErlNifEnv *env, ERL_NIF_TERM arg, NativeStringKind kind, char *buf, size_t buf_size)
{
  ErlNifBinary bin;
  size_t limit = native_string_limit(kind);

  if (buf_size <= limit)
    return false;

  if (!enif_inspect_binary(env, arg, &bin))
    return false;

  if (bin.size == 0 || bin.size > limit)
    return false;

  if (memchr(bin.data, '\0', bin.size) != NULL)
    return false;

  memcpy(buf, bin.data, bin.size);
  buf[bin.size] = '\0';

  return true;
}

/*
 * Decode exactly `length` doubles and require the list to end there. This
 * never walks past `length` cells, so an oversized caller-supplied list cannot
 * keep a normal scheduler busy the way enif_get_list_length would.
 */
bool
exa_load_list(ErlNifEnv *env, ERL_NIF_TERM arg, size_t length, double *result)
{
  ERL_NIF_TERM head;
  ERL_NIF_TERM tail = arg;

  for (size_t i = 0; i < length; i++)
  {
    if (!enif_get_list_cell(env, tail, &head, &tail) ||
        !enif_get_double(env, head, &result[i]))
      return false;
  }

  return enif_is_empty_list(env, tail);
}

ERL_NIF_TERM
exa_make_list(ErlNifEnv *env, double *list, size_t length)
{
  ERL_NIF_TERM result = enif_make_list(env, 0);

  for (size_t i = length; i > 0; i--)
    result = enif_make_list_cell(env, enif_make_double(env, list[i - 1]), result);

  return result;
}

bool
exa_make_binary(ErlNifEnv *env, char *data, ERL_NIF_TERM *result)
{
  ErlNifBinary bin;
  size_t length = strlen(data);

  if (enif_alloc_binary(length, &bin))
  {
    memcpy(bin.data, data, length);
    *result = enif_make_binary(env, &bin);
    return true;
  }

  *result = exa_raise_alloc_failed(env);
  return false;
}

ERL_NIF_TERM
exa_raise_alloc_failed(ErlNifEnv *env)
{
  return enif_raise_exception(env, enif_make_atom(env, "ex_astro_alloc_failed"));
}

ERL_NIF_TERM
exa_error_result(ErlNifEnv *env, char *error_msg)
{
  ERL_NIF_TERM binary;

  if (!exa_make_binary(env, error_msg, &binary))
    return binary;

  return enif_make_tuple2(env, enif_make_atom(env, "error"), binary);
}

ERL_NIF_TERM
exa_cspice_sync_error(ErlNifEnv *env)
{
  return exa_error_result(env, "CSPICE synchronization unavailable");
}

static void
read_cspice_error(char *error_msg)
{
  SpiceChar short_msg[CSPICE_SHORT_ERROR_LENGTH];
  SpiceChar long_msg[CSPICE_LONG_ERROR_LENGTH];

  getmsg_c("SHORT", sizeof(short_msg), short_msg);
  getmsg_c("LONG", sizeof(long_msg), long_msg);
  reset_c();

  snprintf(error_msg, CSPICE_ERROR_LENGTH, "%s -- %s", short_msg, long_msg);
}

bool
exa_cspice_failed(char *error_msg)
{
  if (!failed_c())
    return false;

  read_cspice_error(error_msg);
  return true;
}

ERL_NIF_TERM
exa_ok_result(ErlNifEnv *env, ERL_NIF_TERM result)
{
  return enif_make_tuple2(env, enif_make_atom(env, "ok"), result);
}

ERL_NIF_TERM
exa_ok_result2(ErlNifEnv *env, ERL_NIF_TERM result1, ERL_NIF_TERM result2)
{
  return enif_make_tuple3(env, enif_make_atom(env, "ok"), result1, result2);
}

int
exa_cspice_init(void)
{
  SpiceChar error[CSPICE_ERROR_LENGTH];
  int load_status = 0;

  cspice_mutex = enif_mutex_create("ex_astro_cspice_mutex");
  if (cspice_mutex == NULL)
  {
    fprintf(stderr, "Failed to initialize CSPICE mutex during NIF load\n");
    return 1;
  }

  if (!exa_cspice_lock())
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

  exa_cspice_unlock();

  if (load_status != 0)
  {
    enif_mutex_destroy(cspice_mutex);
    cspice_mutex = NULL;
  }

  return load_status;
}

void
exa_cspice_teardown(void)
{
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (cspice_mutex == NULL)
    return;

  if (exa_cspice_lock())
  {
    kclear_c();

    if (failed_c())
    {
      read_cspice_error(error);
      fprintf(stderr, "Failed to clear CSPICE kernels during NIF unload: %s\n", error);
    }

    exa_cspice_unlock();
  }

  enif_mutex_destroy(cspice_mutex);
  cspice_mutex = NULL;
}
