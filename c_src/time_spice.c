#include "utils.h"
#include "nifs.h"
#include <math.h>

/* CSPICE time routines; ERFA time-scale conversions live in time.c. */

ERL_NIF_TERM
exa_nif_str2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble et;
  SpiceChar timstr[NATIVE_STRING_TIME_MAX + 1];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_TIME, timstr, sizeof(timstr)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // convert to TDB (ET)
  str2et_c(timstr, &et);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, enif_make_double(env, et));
}

ERL_NIF_TERM
exa_nif_utc2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double et;
  char utcstr[NATIVE_STRING_UTC_TIME_MAX + 1];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_UTC_TIME, utcstr, sizeof(utcstr)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  // convert to TDB (ET)
  utc2et_c(utcstr, &et);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, enif_make_double(env, et));
}

ERL_NIF_TERM
exa_nif_unitim(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble epoch;
  SpiceDouble converted_epoch;
  SpiceChar insys[NATIVE_STRING_TIME_SYSTEM_MAX + 1];
  SpiceChar outsys[NATIVE_STRING_TIME_SYSTEM_MAX + 1];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &epoch) ||
      !exa_load_string(env, argv[1], NATIVE_STRING_TIME_SYSTEM, insys, sizeof(insys)) ||
      !exa_load_string(env, argv[2], NATIVE_STRING_TIME_SYSTEM, outsys, sizeof(outsys)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  converted_epoch = unitim_c(epoch, insys, outsys);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return exa_ok_result(env, enif_make_double(env, converted_epoch));
}

ERL_NIF_TERM
exa_nif_sec2day(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double j_sec;
  double j2000;
  double spd;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &j_sec))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  j2000 = j2000_c();
  spd = spd_c();

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return enif_make_tuple2(env, enif_make_double(env, j2000), enif_make_double(env, j_sec / spd));
}

ERL_NIF_TERM
exa_nif_day2sec(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double jd1, jd2, big, small;
  double j2000;
  double spd;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &jd1) ||
      !enif_get_double(env, argv[1], &jd2))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  j2000 = j2000_c();
  spd = spd_c();

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();

  /* Subtract J2000 from the larger part so the smaller one keeps its precision. */
  if (fabs(jd1) >= fabs(jd2))
  {
    big = jd1;
    small = jd2;
  }
  else
  {
    big = jd2;
    small = jd1;
  }

  return enif_make_double(env, ((big - j2000) + small) * spd);
}
