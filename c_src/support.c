#include "utils.h"

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

  if (!load_string(env, argv[0], &name))
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
  SPICEINT_CELL(ids, 1000);
  ERL_NIF_TERM result;
  ERL_NIF_TERM erl_ids[1000];
  SpiceInt length;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_string(env, argv[0], &file))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  spkobj_c(file, &ids);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
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

  for (int i = 0; i < length; i++)
  {
    erl_ids[i] = enif_make_int(env, SPICE_CELL_ELEM_I(&ids, i));
  }

  result = ok_result(env, enif_make_list_from_array(env, erl_ids, length));

cleanup:
  free_string(file);

  return result;
}

static ERL_NIF_TERM
bodvcd(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;
  SpiceChar *item = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_int(env, argv[0], &code) ||
      !load_string(env, argv[1], &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  SpiceInt dim;
  SpiceDouble values[16];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  bodvcd_c(code, item, 16, &dim, values);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = ok_result(env, make_list(env, values, dim));

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

  if (!load_string(env, argv[0], &name) ||
      !load_string(env, argv[1], &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  SpiceInt dim;
  SpiceDouble values[16];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  bodvrd_c(name, item, 16, &dim, values);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = ok_result(env, make_list(env, values, dim));

cleanup:
  free_string(name);
  free_string(item);

  return result;
}
static ErlNifFunc nif_funcs[] = {
    {"bodc2n", 1, bodc2n},
    {"bodn2c", 1, bodn2c},
    {"spkobj", 1, spkobj},
    {"bodvcd", 2, bodvcd},
    {"bodvrd", 2, bodvrd},
};

ERL_NIF_INIT(Elixir.Astro.Support, nif_funcs, &load, NULL, &upgrade, &unload)
