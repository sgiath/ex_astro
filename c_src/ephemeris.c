#include "utils.h"

static ERL_NIF_TERM
spkezr(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceChar *target = NULL, *reference_frame = NULL, *abcorr = NULL, *observer = NULL;
  SpiceDouble et;
  ERL_NIF_TERM result;

  if (!load_string(env, argv[0], NATIVE_STRING_BODY, &target) ||
      !enif_get_double(env, argv[1], &et) ||
      !load_string(env, argv[2], NATIVE_STRING_FRAME, &reference_frame) ||
      !load_string(env, argv[3], NATIVE_STRING_ABCORR, &abcorr) ||
      !load_string(env, argv[4], NATIVE_STRING_BODY, &observer))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  // retrieve state vector at the time
  spkezr_c(target, et, reference_frame, abcorr, observer, state, &lt);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = ok_result2(env, make_list(env, state, 6), enif_make_double(env, lt));

cleanup:
  free_string(target);
  free_string(reference_frame);
  free_string(abcorr);
  free_string(observer);

  return result;
}

static ERL_NIF_TERM
spkez(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceDouble et;
  SpiceInt target, observer;
  SpiceChar *reference_frame = NULL, *abcorr = NULL;
  ERL_NIF_TERM result;

  if (!enif_get_int(env, argv[0], &target) ||
      !enif_get_double(env, argv[1], &et) ||
      !load_string(env, argv[2], NATIVE_STRING_FRAME, &reference_frame) ||
      !load_string(env, argv[3], NATIVE_STRING_ABCORR, &abcorr) ||
      !enif_get_int(env, argv[4], &observer))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  // retrieve state vector at the time
  spkez_c(target, et, reference_frame, abcorr, observer, state, &lt);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = ok_result2(env, make_list(env, state, 6), enif_make_double(env, lt));

cleanup:
  free_string(reference_frame);
  free_string(abcorr);

  return result;
}

static ERL_NIF_TERM
spkgeo(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceDouble et;
  SpiceInt target, observer;
  SpiceChar *reference_frame = NULL;
  ERL_NIF_TERM result;

  if (!enif_get_int(env, argv[0], &target) ||
      !enif_get_double(env, argv[1], &et) ||
      !load_string(env, argv[2], NATIVE_STRING_FRAME, &reference_frame) ||
      !enif_get_int(env, argv[3], &observer))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  // retrieve state vector at the time
  spkgeo_c(target, et, reference_frame, observer, state, &lt);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = ok_result2(env, make_list(env, state, 6), enif_make_double(env, lt));

cleanup:
  free_string(reference_frame);

  return result;
}

static ERL_NIF_TERM
oscelt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble state[6];
  SpiceDouble et;
  SpiceDouble mu;
  SpiceDouble elts[8];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_list(env, argv[0], 6, state) ||
      !enif_get_double(env, argv[1], &et) ||
      !enif_get_double(env, argv[2], &mu))
    return enif_make_badarg(env);

  if (!cspice_lock())
    return cspice_sync_error(env);

  // retrieve state vector at the time
  oscelt_c(state, et, mu, elts);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();
  return ok_result(env, make_list(env, elts, 8));
}

static ERL_NIF_TERM
conics(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble elts[8];
  SpiceDouble et;
  SpiceDouble state[6];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_list(env, argv[0], 8, elts) ||
      !enif_get_double(env, argv[1], &et))
    return enif_make_badarg(env);

  if (!cspice_lock())
    return cspice_sync_error(env);

  // retrieve state vector at the time
  conics_c(elts, et, state);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();
  return ok_result(env, make_list(env, state, 6));
}

/*
 * Scheduler policy:
 * - spkezr/spkez/spkgeo can run longer than a normal scheduler budget while
 *   resolving states from loaded, file-backed SPICE ephemeris kernels, so they
 *   run as dirty CPU jobs.
 * - oscelt/conics are bounded numeric conversions over caller-provided arrays
 *   and remain normal scheduler NIFs.
 *
 * All CSPICE calls, dirty or normal, keep using the mutex/error-reset contract
 * in utils.h. NIF load/unload callbacks can still perform kernel I/O outside
 * ErlNifFunc dirty scheduling.
 */
static ErlNifFunc nif_funcs[] = {
    {"spkezr", 5, spkezr, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkez", 5, spkez, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkgeo", 4, spkgeo, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"oscelt", 3, oscelt, 0},
    {"conics", 2, conics, 0},
};

ERL_NIF_INIT(Elixir.Astro.Ephemeris, nif_funcs, &load, NULL, &upgrade, &unload)
