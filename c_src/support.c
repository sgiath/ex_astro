#include "utils.h"

#define SPKOBJ_INITIAL_CAPACITY 1024
#define SPKOBJ_MAX_CAPACITY 65536
#define BODY_VALUE_NAME_LENGTH 64
#define BODY_VALUE_ERROR_LENGTH 160

static bool
init_spice_int_cell(SpiceCell *cell, SpiceInt capacity, SpiceInt **storage)
{
  size_t count;
  SpiceInt *data;

  if (capacity <= 0 || (size_t)capacity > (SIZE_MAX / sizeof(SpiceInt)) - SPICE_CELL_CTRLSZ)
    return false;

  count = SPICE_CELL_CTRLSZ + (size_t)capacity;
  data = malloc(count * sizeof(SpiceInt));
  if (data == NULL)
    return false;

  *cell = (SpiceCell){
      SPICE_INT,
      0,
      capacity,
      0,
      SPICETRUE,
      SPICEFALSE,
      SPICEFALSE,
      (void *)data,
      (void *)(data + SPICE_CELL_CTRLSZ)};
  *storage = data;

  return true;
}

static bool
spkobj_capacity_error(char *error)
{
  return strstr(error, "SPICE(SETEXCESS)") != NULL;
}

static ERL_NIF_TERM
spkobj_capacity_result(ErlNifEnv *env)
{
  return error_result(env, "SPK object result exceeds supported capacity of 65536 IDs");
}

static ERL_NIF_TERM
make_spice_int_list(ErlNifEnv *env, SpiceCell *cell, SpiceInt len)
{
  ERL_NIF_TERM result = enif_make_list(env, 0);

  for (SpiceInt i = len; i > 0; i--)
  {
    result = enif_make_list_cell(env, enif_make_int(env, SPICE_CELL_ELEM_I(cell, i - 1)), result);
  }

  return result;
}

static ERL_NIF_TERM
make_spice_double_list(ErlNifEnv *env, SpiceDouble *values, SpiceInt len)
{
  ERL_NIF_TERM result = enif_make_list(env, 0);

  for (SpiceInt i = len; i > 0; i--)
  {
    result = enif_make_list_cell(env, enif_make_double(env, values[i - 1]), result);
  }

  return result;
}

static bool
body_value_name(SpiceInt code, SpiceChar *item, SpiceChar *name, size_t name_size)
{
  int written = snprintf(name, name_size, "BODY%d_%s", (int)code, item);

  return written > 0 && (size_t)written < name_size;
}

static ERL_NIF_TERM
body_value_error(ErlNifEnv *env, char *prefix, SpiceChar *name)
{
  SpiceChar message[BODY_VALUE_ERROR_LENGTH];

  snprintf(message, sizeof(message), "%s: %s", prefix, name);

  return error_result(env, message);
}

static ERL_NIF_TERM
body_values(ErlNifEnv *env, SpiceInt code, SpiceChar *item)
{
  SpiceChar name[BODY_VALUE_NAME_LENGTH];
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceChar type[1];
  SpiceBoolean found;
  SpiceInt dim;
  SpiceInt count;
  SpiceDouble *values = NULL;
  ERL_NIF_TERM result;

  if (!body_value_name(code, item, name, sizeof(name)))
    return error_result(env, "kernel variable name exceeds supported native buffer");

  if (!cspice_lock())
    return cspice_sync_error(env);

  dtpool_c(name, &found, &dim, type);

  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  if (!found)
  {
    cspice_unlock();
    return body_value_error(env, "kernel variable not found", name);
  }

  if (type[0] != 'N')
  {
    cspice_unlock();
    return body_value_error(env, "kernel variable is not numeric", name);
  }

  if (dim < 0 || (size_t)dim > SIZE_MAX / sizeof(SpiceDouble))
  {
    cspice_unlock();
    return body_value_error(env, "kernel variable value count exceeds supported allocation size", name);
  }

  if (dim == 0)
  {
    cspice_unlock();
    return ok_result(env, enif_make_list(env, 0));
  }

  if (dim > 0)
  {
    values = malloc((size_t)dim * sizeof(SpiceDouble));
    if (values == NULL)
    {
      cspice_unlock();
      return body_value_error(env, "failed to allocate kernel variable values", name);
    }
  }

  gdpool_c(name, 0, dim, &count, values, &found);

  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();

  if (!found)
  {
    result = body_value_error(env, "kernel variable not found", name);
    goto cleanup;
  }

  if (count != dim)
  {
    result = body_value_error(env, "kernel variable value count changed while reading", name);
    goto cleanup;
  }

  result = ok_result(env, make_spice_double_list(env, values, dim));

cleanup:
  free(values);

  return result;
}

static ERL_NIF_TERM
bodc2n(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_int(env, argv[0], &code))
    return enif_make_badarg(env);

  SpiceChar name[36];
  SpiceBoolean found;

  if (!cspice_lock())
    return cspice_sync_error(env);

  bodc2n_c(code, 36, name, &found);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();

  // return error if body was not found
  if (!found)
    return error_result(env, "body not found");

  return ok_result(env, make_binary(env, name));
}

static ERL_NIF_TERM
bodn2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *name = NULL;
  ERL_NIF_TERM result;

  if (!load_string(env, argv[0], NATIVE_STRING_BODY, &name))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  SpiceInt code;
  SpiceBoolean found;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  bodn2c_c(name, &code, &found);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();

  // return error if body was not found
  if (!found)
  {
    result = error_result(env, "body not found");
    goto cleanup;
  }

  // return OK tuple
  result = ok_result(env, enif_make_int(env, code));

cleanup:
  free_string(name);

  return result;
}

static ERL_NIF_TERM
spkobj(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *file = NULL;
  SpiceCell ids;
  SpiceInt *ids_storage = NULL;
  SpiceInt capacity = SPKOBJ_INITIAL_CAPACITY;
  ERL_NIF_TERM result;
  SpiceInt length;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &file))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  while (true)
  {
    if (!init_spice_int_cell(&ids, capacity, &ids_storage))
    {
      result = error_result(env, "failed to allocate SPK object result buffer");
      goto cleanup;
    }

    if (!cspice_lock())
    {
      result = cspice_sync_error(env);
      goto cleanup;
    }

    spkobj_c(file, &ids);

    if (cspice_failed(error))
    {
      cspice_unlock();
      free(ids_storage);
      ids_storage = NULL;

      if (spkobj_capacity_error(error) && capacity < SPKOBJ_MAX_CAPACITY)
      {
        capacity *= 2;
        if (capacity > SPKOBJ_MAX_CAPACITY)
          capacity = SPKOBJ_MAX_CAPACITY;

        continue;
      }

      result = spkobj_capacity_error(error) ? spkobj_capacity_result(env) : error_result(env, error);
      goto cleanup;
    }

    length = card_c(&ids);

    if (cspice_failed(error))
    {
      cspice_unlock();
      result = error_result(env, error);
      goto cleanup;
    }

    cspice_unlock();

    result = ok_result(env, make_spice_int_list(env, &ids, length));
    goto cleanup;
  }

cleanup:
  free(ids_storage);
  free_string(file);

  return result;
}

static ERL_NIF_TERM
bodvcd(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;
  SpiceChar *item = NULL;
  ERL_NIF_TERM result;

  if (!enif_get_int(env, argv[0], &code) ||
      !load_string(env, argv[1], NATIVE_STRING_KERNEL_ITEM, &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  result = body_values(env, code, item);

cleanup:
  free_string(item);

  return result;
}

static ERL_NIF_TERM
bodvrd(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *name = NULL, *item = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceInt code;
  SpiceBoolean found;

  if (!load_string(env, argv[0], NATIVE_STRING_BODY, &name) ||
      !load_string(env, argv[1], NATIVE_STRING_KERNEL_ITEM, &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  bods2c_c(name, &code, &found);

  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();

  if (!found)
  {
    result = error_result(env, "body not found");
    goto cleanup;
  }

  result = body_values(env, code, item);

cleanup:
  free_string(name);
  free_string(item);

  return result;
}
/*
 * Scheduler policy:
 * - spkobj opens and inspects the SPK file path supplied by the caller, so it
 *   runs as a dirty IO job.
 * - body-name/ID and kernel-pool value lookups are short CSPICE table/pool
 *   lookups and remain normal scheduler NIFs.
 *
 * All CSPICE calls, dirty or normal, keep using the mutex/error-reset contract
 * in utils.h. NIF load/unload callbacks can still perform kernel I/O outside
 * ErlNifFunc dirty scheduling.
 */
static ErlNifFunc nif_funcs[] = {
    {"bodc2n", 1, bodc2n, 0},
    {"bodn2c", 1, bodn2c, 0},
    {"spkobj", 1, spkobj, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"bodvcd", 2, bodvcd, 0},
    {"bodvrd", 2, bodvrd, 0},
};

ERL_NIF_INIT(Elixir.Astro.Support, nif_funcs, &load, NULL, &upgrade, &unload)
