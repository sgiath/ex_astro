#include "utils.h"
#include "nifs.h"

ERL_NIF_TERM
exa_nif_spkezr(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceChar target[NATIVE_STRING_BODY_MAX + 1];
  SpiceChar reference_frame[NATIVE_STRING_FRAME_MAX + 1];
  SpiceChar abcorr[NATIVE_STRING_ABCORR_MAX + 1];
  SpiceChar observer[NATIVE_STRING_BODY_MAX + 1];
  SpiceDouble et;

  if (!exa_load_string(env, argv[0], NATIVE_STRING_BODY, target, sizeof(target)) ||
      !enif_get_double(env, argv[1], &et) ||
      !exa_load_string(env, argv[2], NATIVE_STRING_FRAME, reference_frame, sizeof(reference_frame)) ||
      !exa_load_string(env, argv[3], NATIVE_STRING_ABCORR, abcorr, sizeof(abcorr)) ||
      !exa_load_string(env, argv[4], NATIVE_STRING_BODY, observer, sizeof(observer)))
    return enif_make_badarg(env);

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // retrieve state vector at the time
  spkezr_c(target, et, reference_frame, abcorr, observer, state, &lt);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result2(env, exa_make_list(env, state, 6), enif_make_double(env, lt));
}

ERL_NIF_TERM
exa_nif_spkez(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceDouble et;
  SpiceInt target, observer;
  SpiceChar reference_frame[NATIVE_STRING_FRAME_MAX + 1];
  SpiceChar abcorr[NATIVE_STRING_ABCORR_MAX + 1];

  if (!enif_get_int(env, argv[0], &target) ||
      !enif_get_double(env, argv[1], &et) ||
      !exa_load_string(env, argv[2], NATIVE_STRING_FRAME, reference_frame, sizeof(reference_frame)) ||
      !exa_load_string(env, argv[3], NATIVE_STRING_ABCORR, abcorr, sizeof(abcorr)) ||
      !enif_get_int(env, argv[4], &observer))
    return enif_make_badarg(env);

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // retrieve state vector at the time
  spkez_c(target, et, reference_frame, abcorr, observer, state, &lt);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result2(env, exa_make_list(env, state, 6), enif_make_double(env, lt));
}

ERL_NIF_TERM
exa_nif_spkgeo(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  // inputs
  SpiceDouble et;
  SpiceInt target, observer;
  SpiceChar reference_frame[NATIVE_STRING_FRAME_MAX + 1];

  if (!enif_get_int(env, argv[0], &target) ||
      !enif_get_double(env, argv[1], &et) ||
      !exa_load_string(env, argv[2], NATIVE_STRING_FRAME, reference_frame, sizeof(reference_frame)) ||
      !enif_get_int(env, argv[3], &observer))
    return enif_make_badarg(env);

  // output
  SpiceDouble state[6];
  SpiceDouble lt;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // retrieve state vector at the time
  spkgeo_c(target, et, reference_frame, observer, state, &lt);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result2(env, exa_make_list(env, state, 6), enif_make_double(env, lt));
}

ERL_NIF_TERM
exa_nif_oscelt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble state[6];
  SpiceDouble et;
  SpiceDouble mu;
  SpiceDouble elts[8];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_list(env, argv[0], 6, state) ||
      !enif_get_double(env, argv[1], &et) ||
      !enif_get_double(env, argv[2], &mu))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // retrieve state vector at the time
  oscelt_c(state, et, mu, elts);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, exa_make_list(env, elts, 8));
}

ERL_NIF_TERM
exa_nif_conics(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble elts[8];
  SpiceDouble et;
  SpiceDouble state[6];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_list(env, argv[0], 8, elts) ||
      !enif_get_double(env, argv[1], &et))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // retrieve state vector at the time
  conics_c(elts, et, state);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, exa_make_list(env, state, 6));
}

ERL_NIF_TERM
exa_nif_sxform(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar from[NATIVE_STRING_FRAME_MAX + 1];
  SpiceChar to[NATIVE_STRING_FRAME_MAX + 1];
  SpiceDouble et;
  SpiceDouble xform[6][6];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_FRAME, from, sizeof(from)) ||
      !exa_load_string(env, argv[1], NATIVE_STRING_FRAME, to, sizeof(to)) ||
      !enif_get_double(env, argv[2], &et))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // 6x6 state transformation matrix from `from` to `to` at `et`
  sxform_c(from, to, et, xform);

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, exa_make_list(env, &xform[0][0], 36));
}
