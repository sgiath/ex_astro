#include "utils.h"
#include "nifs.h"
#include <erfam.h>

static bool
erfa_status_ok(int status)
{
  return status == 0;
}

static bool
erfa_status_ok_or_dubious_year(int status)
{
  return status == 0 || status == 1;
}

static ERL_NIF_TERM
make_julian_date(ErlNifEnv *env, double jd1, double jd2)
{
  return enif_make_tuple2(env, enif_make_double(env, jd1), enif_make_double(env, jd2));
}

ERL_NIF_TERM
exa_nif_dtf2d(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int iy, im, id, ihr, imn;
  int status;
  double sec, d1, d2;

  if (!enif_get_int(env, argv[0], &iy) ||
      !enif_get_int(env, argv[1], &im) ||
      !enif_get_int(env, argv[2], &id) ||
      !enif_get_int(env, argv[3], &ihr) ||
      !enif_get_int(env, argv[4], &imn) ||
      !enif_get_double(env, argv[5], &sec))
    return enif_make_badarg(env);

  status = eraDtf2d("UTC", iy, im, id, ihr, imn, sec, &d1, &d2);
  if (!erfa_status_ok_or_dubious_year(status))
    return enif_make_badarg(env);

  return make_julian_date(env, d1, d2);
}

ERL_NIF_TERM
exa_nif_utc2tai(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double utc1, utc2, tai1, tai2;
  if (!enif_get_double(env, argv[0], &utc1) ||
      !enif_get_double(env, argv[1], &utc2))
    return enif_make_badarg(env);

  status = eraUtctai(utc1, utc2, &tai1, &tai2);
  if (!erfa_status_ok_or_dubious_year(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tai1, tai2);
}

ERL_NIF_TERM
exa_nif_tai2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tai1, tai2, tt1, tt2;
  if (!enif_get_double(env, argv[0], &tai1) ||
      !enif_get_double(env, argv[1], &tai2))
    return enif_make_badarg(env);

  status = eraTaitt(tai1, tai2, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tt1, tt2);
}

ERL_NIF_TERM
exa_nif_tai2utc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tai1, tai2, utc1, utc2;
  if (!enif_get_double(env, argv[0], &tai1) ||
      !enif_get_double(env, argv[1], &tai2))
    return enif_make_badarg(env);

  status = eraTaiutc(tai1, tai2, &utc1, &utc2);
  if (!erfa_status_ok_or_dubious_year(status))
    return enif_make_badarg(env);

  return make_julian_date(env, utc1, utc2);
}

ERL_NIF_TERM
exa_nif_tt2tai(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tt1, tt2, tai1, tai2;
  if (!enif_get_double(env, argv[0], &tt1) ||
      !enif_get_double(env, argv[1], &tt2))
    return enif_make_badarg(env);

  status = eraTttai(tt1, tt2, &tai1, &tai2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tai1, tai2);
}

ERL_NIF_TERM
exa_nif_tt2tcg(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tt1, tt2, tcg1, tcg2;
  if (!enif_get_double(env, argv[0], &tt1) ||
      !enif_get_double(env, argv[1], &tt2))
    return enif_make_badarg(env);

  status = eraTttcg(tt1, tt2, &tcg1, &tcg2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tcg1, tcg2);
}

ERL_NIF_TERM
exa_nif_tt2tdb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tt1, tt2, ut, elong, u, v, dtr, tdb1, tdb2;
  if (!enif_get_double(env, argv[0], &tt1) ||
      !enif_get_double(env, argv[1], &tt2) ||
      !enif_get_double(env, argv[2], &ut) ||
      !enif_get_double(env, argv[3], &elong) ||
      !enif_get_double(env, argv[4], &u) ||
      !enif_get_double(env, argv[5], &v))
    return enif_make_badarg(env);

  /* The public API takes UT in seconds; eraDtdb wants a fraction of a day. */
  ut /= ERFA_DAYSEC;

  dtr = eraDtdb(tt1, tt2, ut, elong, u, v);

  status = eraTttdb(tt1, tt2, dtr, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  dtr = eraDtdb(tdb1, tdb2, ut, elong, u, v);

  status = eraTttdb(tt1, tt2, dtr, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tdb1, tdb2);
}

ERL_NIF_TERM
exa_nif_tcg2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tcg1, tcg2, tt1, tt2;
  if (!enif_get_double(env, argv[0], &tcg1) ||
      !enif_get_double(env, argv[1], &tcg2))
    return enif_make_badarg(env);

  status = eraTcgtt(tcg1, tcg2, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tt1, tt2);
}

ERL_NIF_TERM
exa_nif_tdb2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tdb1, tdb2, ut, elong, u, v, dtr, tt1, tt2;
  if (!enif_get_double(env, argv[0], &tdb1) ||
      !enif_get_double(env, argv[1], &tdb2) ||
      !enif_get_double(env, argv[2], &ut) ||
      !enif_get_double(env, argv[3], &elong) ||
      !enif_get_double(env, argv[4], &u) ||
      !enif_get_double(env, argv[5], &v))
    return enif_make_badarg(env);

  /* The public API takes UT in seconds; eraDtdb wants a fraction of a day. */
  ut /= ERFA_DAYSEC;

  dtr = eraDtdb(tdb1, tdb2, ut, elong, u, v);

  status = eraTdbtt(tdb1, tdb2, dtr, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  dtr = eraDtdb(tt1, tt2, ut, elong, u, v);

  status = eraTdbtt(tdb1, tdb2, dtr, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tt1, tt2);
}

ERL_NIF_TERM
exa_nif_tdb2tcb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tdb1, tdb2, tcb1, tcb2;
  if (!enif_get_double(env, argv[0], &tdb1) ||
      !enif_get_double(env, argv[1], &tdb2))
    return enif_make_badarg(env);

  status = eraTdbtcb(tdb1, tdb2, &tcb1, &tcb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tcb1, tcb2);
}

ERL_NIF_TERM
exa_nif_tcb2tdb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double tcb1, tcb2, tdb1, tdb2;
  if (!enif_get_double(env, argv[0], &tcb1) ||
      !enif_get_double(env, argv[1], &tcb2))
    return enif_make_badarg(env);

  status = eraTcbtdb(tcb1, tcb2, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tdb1, tdb2);
}

ERL_NIF_TERM
exa_nif_jd2dt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double jd1, jd2;
  int iy, im, id, ihmsf[4];

  if (!enif_get_double(env, argv[0], &jd1) ||
      !enif_get_double(env, argv[1], &jd2))
    return enif_make_badarg(env);

  /*
   * Inputs are UTC quasi-JDs from eraDtf2d/eraTaiutc. eraD2dtf scales the day
   * fraction by the real length of leap-second days and carries rounding
   * into the next day, so it is the exact inverse of eraDtf2d("UTC").
   */
  status = eraD2dtf("UTC", 6, jd1, jd2, &iy, &im, &id, ihmsf);
  if (!erfa_status_ok_or_dubious_year(status))
    return enif_make_badarg(env);

  return enif_make_tuple7(
      env,
      enif_make_int(env, iy),
      enif_make_int(env, im),
      enif_make_int(env, id),
      enif_make_int(env, ihmsf[0]),
      enif_make_int(env, ihmsf[1]),
      enif_make_int(env, ihmsf[2]),
      enif_make_int(env, ihmsf[3]));
}

ERL_NIF_TERM
exa_nif_str2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble et;
  SpiceChar *timstr = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_TIME, &timstr))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!exa_cspice_lock())
  {
    result = exa_cspice_sync_error(env);
    goto cleanup;
  }

  // convert to TDB (ET)
  str2et_c(timstr, &et);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    result = exa_error_result(env, error);
    goto cleanup;
  }

  exa_cspice_unlock();
  result = exa_ok_result(env, enif_make_double(env, et));

cleanup:
  free(timstr);

  return result;
}

ERL_NIF_TERM
exa_nif_utc2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double et;
  char *utcstr = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_UTC_TIME, &utcstr))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!exa_cspice_lock())
  {
    result = exa_cspice_sync_error(env);
    goto cleanup;
  }

  // convert to TDB (ET)
  utc2et_c(utcstr, &et);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    result = exa_error_result(env, error);
    goto cleanup;
  }

  exa_cspice_unlock();
  result = exa_ok_result(env, enif_make_double(env, et));

cleanup:
  free(utcstr);

  return result;
}

ERL_NIF_TERM
exa_nif_unitim(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble epoch;
  SpiceChar *insys = NULL, *outsys = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &epoch) ||
      !exa_load_string(env, argv[1], NATIVE_STRING_TIME_SYSTEM, &insys) ||
      !exa_load_string(env, argv[2], NATIVE_STRING_TIME_SYSTEM, &outsys))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!exa_cspice_lock())
  {
    result = exa_cspice_sync_error(env);
    goto cleanup;
  }

  SpiceDouble converted_epoch = unitim_c(epoch, insys, outsys);

  // check for any errors
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    result = exa_error_result(env, error);
    goto cleanup;
  }

  exa_cspice_unlock();
  result = exa_ok_result(env, enif_make_double(env, converted_epoch));

cleanup:
  free(insys);
  free(outsys);

  return result;
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
  return make_julian_date(env, j2000, j_sec / spd);
}

ERL_NIF_TERM
exa_nif_day2sec(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double jd1, jd2;
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
  return enif_make_double(env, ((jd1 - j2000) + jd2) * spd);
}
