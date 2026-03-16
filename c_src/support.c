#include "utils.h"

static ERL_NIF_TERM
bodc2n(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt code;

  if (!enif_get_int(env, argv[0], &code))
    return enif_make_badarg(env);

  SpiceChar name[36];
  SpiceBoolean found;

  bodc2n_c(code, 36, name, &found);

  // check for any errors
  if (failed_c())
    return handle_error(env);

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

  bodn2c_c(name, &code, &found);

  // check for any errors
  if (failed_c())
  {
    result = handle_error(env);
    goto cleanup;
  }

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

  if (!load_string(env, argv[0], &file))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  spkobj_c(file, &ids);

  // check for any errors
  if (failed_c())
  {
    result = handle_error(env);
    goto cleanup;
  }

  SpiceInt length = card_c(&ids);

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

  if (!enif_get_int(env, argv[0], &code) ||
      !load_string(env, argv[1], &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  SpiceInt dim;
  SpiceDouble values[16];

  bodvcd_c(code, item, 16, &dim, values);

  // check for any errors
  if (failed_c())
  {
    result = handle_error(env);
    goto cleanup;
  }

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

  if (!load_string(env, argv[0], &name) ||
      !load_string(env, argv[1], &item))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  SpiceInt dim;
  SpiceDouble values[16];

  bodvrd_c(name, item, 16, &dim, values);

  // check for any errors
  if (failed_c())
  {
    result = handle_error(env);
    goto cleanup;
  }

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
