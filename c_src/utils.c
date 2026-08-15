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

bool
exa_load_string(ErlNifEnv *env, ERL_NIF_TERM arg, NativeStringKind kind, char **result)
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

void
exa_free_string(char *value)
{
  if (value != NULL)
    free(value);
}

bool
exa_load_list(ErlNifEnv *env, ERL_NIF_TERM arg, size_t length, double *result)
{
  unsigned int len;
  ERL_NIF_TERM head;
  ERL_NIF_TERM tail = arg;

  if (!enif_get_list_length(env, arg, &len) || len != length)
    return false;

  for (unsigned int i = 0; i < len; i++)
  {
    if (!enif_get_list_cell(env, tail, &head, &tail) ||
        !enif_get_double(env, head, &result[i]))
      return false;
  }

  return true;
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

  *result = enif_raise_exception(env, enif_make_atom(env, "ex_astro_alloc_failed"));
  return false;
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
  getmsg_c("LONG", CSPICE_ERROR_LENGTH - 1, error_msg);
  error_msg[CSPICE_ERROR_LENGTH - 1] = '\0';
  reset_c();
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
