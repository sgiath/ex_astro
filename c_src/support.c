#include "utils.h"
#include "nifs.h"

#define SPKOBJ_INITIAL_CAPACITY 1024
#define SPKOBJ_MAX_CAPACITY 65536
#define BODY_VALUE_NAME_LENGTH 64
#define BODY_VALUE_ERROR_LENGTH 160

/*
 * Allocate an integer cell of `capacity` (bounded by SPKOBJ_MAX_CAPACITY).
 * Returns the storage the caller must free, or NULL when allocation fails.
 */
static SpiceInt *
init_spice_int_cell(SpiceCell *cell, SpiceInt capacity)
{
  SpiceInt *data = malloc((SPICE_CELL_CTRLSZ + (size_t)capacity) * sizeof(SpiceInt));

  if (data == NULL)
    return NULL;

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

  return data;
}

static bool
spkobj_capacity_error(char *error)
{
  return strstr(error, "SPICE(SETEXCESS)") != NULL;
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

static bool
body_value_name(SpiceInt code, SpiceChar *item, SpiceChar *name, size_t name_size)
{
  int written = snprintf(name, name_size, "BODY%d_%s", (int)code, item);

  return written > 0 && (size_t)written < name_size;
}

static ERL_NIF_TERM
prefixed_error(ErlNifEnv *env, char *prefix, SpiceChar *name)
{
  SpiceChar message[BODY_VALUE_ERROR_LENGTH];

  snprintf(message, sizeof(message), "%s: %s", prefix, name);

  return exa_error_result(env, message);
}

/* Caller must hold the CSPICE lock; it is still held on return. */
static ERL_NIF_TERM
read_body_values(ErlNifEnv *env, SpiceInt code, SpiceChar *item)
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
    return exa_error_result(env, "kernel variable name exceeds supported native buffer");

  dtpool_c(name, &found, &dim, type);

  if (exa_cspice_failed(error))
    return exa_error_result(env, error);

  if (!found)
    return prefixed_error(env, "kernel variable not found", name);

  if (type[0] != 'N')
    return prefixed_error(env, "kernel variable is not numeric", name);

  if (dim < 0 || (size_t)dim > SIZE_MAX / sizeof(SpiceDouble))
    return prefixed_error(env, "kernel variable value count exceeds supported allocation size", name);

  if (dim == 0)
    return exa_ok_result(env, enif_make_list(env, 0));

  values = malloc((size_t)dim * sizeof(SpiceDouble));
  if (values == NULL)
    return exa_raise_alloc_failed(env);

  gdpool_c(name, 0, dim, &count, values, &found);

  if (exa_cspice_failed(error))
    result = exa_error_result(env, error);
  else if (!found)
    result = prefixed_error(env, "kernel variable not found", name);
  else if (count != dim)
    result = prefixed_error(env, "kernel variable value count changed while reading", name);
  else
    result = exa_ok_result(env, exa_make_list(env, values, dim));

  free(values);

  return result;
}

ERL_NIF_TERM
exa_nif_bodc2n(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  /* bodc2n_c's length includes the terminator, so a 36-character name needs 37. */
  SpiceChar name[NATIVE_STRING_BODY_MAX + 1];
  SpiceBoolean found;
  ERL_NIF_TERM name_term;

  if (!enif_get_int(env, argv[0], &code))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  bodc2n_c(code, sizeof(name), name, &found);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();

  // return error if body was not found
  if (!found)
  {
    snprintf(error, sizeof(error), "body not found: %d", (int)code);
    return exa_error_result(env, error);
  }

  if (!exa_make_binary(env, name, &name_term))
    return name_term;

  return exa_ok_result(env, name_term);
}

ERL_NIF_TERM
exa_nif_bodn2c(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar name[NATIVE_STRING_BODY_MAX + 1];
  SpiceInt code;
  SpiceBoolean found;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_BODY, name, sizeof(name)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  bodn2c_c(name, &code, &found);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();

  // return error if body was not found
  if (!found)
    return prefixed_error(env, "body not found", name);

  return exa_ok_result(env, enif_make_int(env, code));
}

ERL_NIF_TERM
exa_nif_spkobj(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar file[NATIVE_STRING_KERNEL_PATH_MAX + 1];
  SpiceCell ids;
  SpiceInt *ids_storage;
  SpiceInt capacity = SPKOBJ_INITIAL_CAPACITY;
  ERL_NIF_TERM result;
  SpiceInt length;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, file, sizeof(file)))
    return enif_make_badarg(env);

  while (true)
  {
    ids_storage = init_spice_int_cell(&ids, capacity);
    if (ids_storage == NULL)
      return exa_raise_alloc_failed(env);

    if (!exa_cspice_lock())
    {
      free(ids_storage);
      return exa_cspice_sync_error(env);
    }

    spkobj_c(file, &ids);

    if (exa_cspice_failed(error))
    {
      exa_cspice_unlock();
      free(ids_storage);

      if (spkobj_capacity_error(error) && capacity < SPKOBJ_MAX_CAPACITY)
      {
        capacity *= 2;
        if (capacity > SPKOBJ_MAX_CAPACITY)
          capacity = SPKOBJ_MAX_CAPACITY;

        continue;
      }

      return spkobj_capacity_error(error) ? exa_error_result(env, "SPK object result exceeds supported capacity of 65536 IDs") : exa_error_result(env, error);
    }

    length = card_c(&ids);

    if (exa_cspice_failed(error))
    {
      exa_cspice_unlock();
      free(ids_storage);
      return exa_error_result(env, error);
    }

    exa_cspice_unlock();

    result = exa_ok_result(env, make_spice_int_list(env, &ids, length));
    free(ids_storage);

    return result;
  }
}

ERL_NIF_TERM
exa_nif_bodvcd(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;
  SpiceChar item[NATIVE_STRING_KERNEL_ITEM_MAX + 1];
  ERL_NIF_TERM result;

  if (!enif_get_int(env, argv[0], &code) ||
      !exa_load_string(env, argv[1], NATIVE_STRING_KERNEL_ITEM, item, sizeof(item)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  result = read_body_values(env, code, item);
  exa_cspice_unlock();

  return result;
}

ERL_NIF_TERM
exa_nif_bodvrd(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar name[NATIVE_STRING_BODY_MAX + 1];
  SpiceChar item[NATIVE_STRING_KERNEL_ITEM_MAX + 1];
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceInt code;
  SpiceBoolean found;

  if (!exa_load_string(env, argv[0], NATIVE_STRING_BODY, name, sizeof(name)) ||
      !exa_load_string(env, argv[1], NATIVE_STRING_KERNEL_ITEM, item, sizeof(item)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  /* Resolve the name and read its values under one lock so a concurrent
   * kernel mutation cannot pair a code with values from another pool state. */
  bods2c_c(name, &code, &found);

  if (exa_cspice_failed(error))
    result = exa_error_result(env, error);
  else if (!found)
    result = prefixed_error(env, "body not found", name);
  else
    result = read_body_values(env, code, item);

  exa_cspice_unlock();

  return result;
}
