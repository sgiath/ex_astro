#include "utils.h"

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

static bool
advance_calendar_day(int *iy, int *im, int *id)
{
  int status;
  double djm0, djm, fd;

  status = eraCal2jd(*iy, *im, *id, &djm0, &djm);
  if (!erfa_status_ok(status))
    return false;

  status = eraJd2cal(djm0, djm + 1.0, iy, im, id, &fd);
  return erfa_status_ok(status);
}

static double
topocentric_tdb_minus_tt(double jd1, double jd2, double ut, double elong, double u, double v)
{
  return eraDtdb(jd1, jd2, ut, elong, u, v);
}

static ERL_NIF_TERM
dtf2d(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
utc2tai(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tai2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tai2utc(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tt2tai(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tt2tcg(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tt2tdb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

  dtr = topocentric_tdb_minus_tt(tt1, tt2, ut, elong, u, v);

  status = eraTttdb(tt1, tt2, dtr, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  dtr = topocentric_tdb_minus_tt(tdb1, tdb2, ut, elong, u, v);

  status = eraTttdb(tt1, tt2, dtr, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tdb1, tdb2);
}

static ERL_NIF_TERM
tcg2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tdb2tt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

  dtr = topocentric_tdb_minus_tt(tdb1, tdb2, ut, elong, u, v);

  status = eraTdbtt(tdb1, tdb2, dtr, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  dtr = topocentric_tdb_minus_tt(tt1, tt2, ut, elong, u, v);

  status = eraTdbtt(tdb1, tdb2, dtr, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  return make_julian_date(env, tt1, tt2);
}

static ERL_NIF_TERM
tdb2tcb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
tcb2tdb(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
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

static ERL_NIF_TERM
jd2dt(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  int status;
  double jd1, jd2, fd;
  int iy, im, id, ihmsf[4];
  char sign = '+';

  if (!enif_get_double(env, argv[0], &jd1) ||
      !enif_get_double(env, argv[1], &jd2))
    return enif_make_badarg(env);

  status = eraJd2cal(jd1, jd2, &iy, &im, &id, &fd);
  if (!erfa_status_ok(status))
    return enif_make_badarg(env);

  eraD2tf(6, fd, &sign, ihmsf);

  /*
   * eraD2tf rounds independently from the calendar date. Near midnight that
   * can produce hour 24, which Elixir datetime types cannot represent.
   */
  if (ihmsf[0] >= 24) {
    if (!advance_calendar_day(&iy, &im, &id))
      return enif_make_badarg(env);

    ihmsf[0] = 0;
    ihmsf[1] = 0;
    ihmsf[2] = 0;
    ihmsf[3] = 0;
  }

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

static ERL_NIF_TERM
str2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble et;
  SpiceChar *timstr = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_string(env, argv[0], NATIVE_STRING_TIME, &timstr))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  // convert to TDB (ET)
  str2et_c(timstr, &et);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = enif_make_double(env, et);

cleanup:
  free_string(timstr);

  return result;
}

static ERL_NIF_TERM
utc2et(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double et;
  char *utcstr = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!load_string(env, argv[0], NATIVE_STRING_UTC_TIME, &utcstr))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  // convert to TDB (ET)
  utc2et_c(utcstr, &et);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = enif_make_double(env, et);

cleanup:
  free_string(utcstr);

  return result;
}

static ERL_NIF_TERM
unitim(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceDouble epoch;
  SpiceChar *insys = NULL, *outsys = NULL;
  ERL_NIF_TERM result;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &epoch) ||
      !load_string(env, argv[1], NATIVE_STRING_TIME_SYSTEM, &insys) ||
      !load_string(env, argv[2], NATIVE_STRING_TIME_SYSTEM, &outsys))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!cspice_lock())
  {
    result = cspice_sync_error(env);
    goto cleanup;
  }

  SpiceDouble converted_epoch = unitim_c(epoch, insys, outsys);

  // check for any errors
  if (cspice_failed(error))
  {
    cspice_unlock();
    result = error_result(env, error);
    goto cleanup;
  }

  cspice_unlock();
  result = enif_make_double(env, converted_epoch);

cleanup:
  free_string(insys);
  free_string(outsys);

  return result;
}

static ERL_NIF_TERM
sec2day(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double j_sec;
  double j2000;
  double spd;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &j_sec))
    return enif_make_badarg(env);

  if (!cspice_lock())
    return cspice_sync_error(env);

  j2000 = j2000_c();
  spd = spd_c();

  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();
  return make_julian_date(env, j2000, j_sec / spd);
}

static ERL_NIF_TERM
day2sec(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double jd1, jd2;
  double j2000;
  double spd;
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!enif_get_double(env, argv[0], &jd1) ||
      !enif_get_double(env, argv[1], &jd2))
    return enif_make_badarg(env);

  if (!cspice_lock())
    return cspice_sync_error(env);

  j2000 = j2000_c();
  spd = spd_c();

  if (cspice_failed(error))
  {
    cspice_unlock();
    return error_result(env, error);
  }

  cspice_unlock();
  return enif_make_double(env, ((jd1 - j2000) + jd2) * spd);
}

/*
 * Scheduler policy:
 * - str2et/utc2et use CSPICE time parsers that can do non-trivial string
 *   parsing and consult loaded time-kernel state, so they run as dirty CPU
 *   jobs.
 * - ERFA-only split-Julian-Date conversions are bounded numeric work and
 *   remain normal scheduler NIFs.
 * - unitim/sec2day/day2sec are short CSPICE scalar/constant conversions and
 *   remain normal scheduler NIFs.
 * - Shared kernel-management entries (furnsh/unload/kclear) from utils.h
 *   are dirty IO jobs; kernel_list stays on a normal scheduler.
 *
 * All CSPICE calls, dirty or normal, keep using the mutex/error-reset contract
 * in utils.h. NIF load/unload callbacks can still perform kernel I/O outside
 * ErlNifFunc dirty scheduling.
 */
static ErlNifFunc nif_funcs[] = {
    EX_ASTRO_KERNEL_NIF_FUNCS,
    {"dtf2d", 6, dtf2d, 0},
    {"utc2tai", 2, utc2tai, 0},
    {"tai2tt", 2, tai2tt, 0},
    {"tai2utc", 2, tai2utc, 0},
    {"tt2tai", 2, tt2tai, 0},
    {"tt2tcg", 2, tt2tcg, 0},
    {"tt2tdb", 6, tt2tdb, 0},
    {"tcg2tt", 2, tcg2tt, 0},
    {"tdb2tt", 6, tdb2tt, 0},
    {"tdb2tcb", 2, tdb2tcb, 0},
    {"tcb2tdb", 2, tcb2tdb, 0},
    {"jd2dt", 2, jd2dt, 0},
    {"str2et", 1, str2et, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"utc2et", 1, utc2et, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"unitim", 3, unitim, 0},
    {"sec2day", 1, sec2day, 0},
    {"day2sec", 2, day2sec, 0},
};

ERL_NIF_INIT(Elixir.Astro.Time.NIF, nif_funcs, &load, NULL, &upgrade, &unload)
