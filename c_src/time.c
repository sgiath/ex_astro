#include "utils.h"
#include "nifs.h"
#include <erfam.h>
#include <stdarg.h>

/* ERFA time-scale conversions; CSPICE time routines live in time_spice.c. */

#define ERFA_ERROR_LENGTH 160

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

/* Raises %ArgumentError{message: ...} so Elixir callers see why ERFA refused. */
static ERL_NIF_TERM __attribute__((format(printf, 2, 3)))
raise_argument_error(ErlNifEnv *env, const char *format, ...)
{
  char message[ERFA_ERROR_LENGTH];
  ERL_NIF_TERM keys[3], values[3], exception;
  va_list args;

  va_start(args, format);
  vsnprintf(message, sizeof(message), format, args);
  va_end(args);

  if (!exa_make_binary(env, message, &values[2]))
    return values[2];

  keys[0] = enif_make_atom(env, "__struct__");
  values[0] = enif_make_atom(env, "Elixir.ArgumentError");
  keys[1] = enif_make_atom(env, "__exception__");
  values[1] = enif_make_atom(env, "true");
  keys[2] = enif_make_atom(env, "message");

  if (!enif_make_map_from_arrays(env, keys, values, 3, &exception))
    return enif_make_badarg(env);

  return enif_raise_exception(env, exception);
}

static ERL_NIF_TERM
raise_unexpected_status(ErlNifEnv *env, const char *routine, int status)
{
  return raise_argument_error(env, "ERFA %s returned unexpected status %d", routine, status);
}

/* eraDtf2d statuses: -1..-6 name the rejected field; +2 (+3 with a dubious year) means past end of day. */
static ERL_NIF_TERM
raise_dtf2d_error(ErlNifEnv *env, int status, int iy, int im, int id, int ihr, int imn, double sec)
{
  switch (status)
  {
  case -1:
    return raise_argument_error(env, "invalid UTC date: year %d is before -4799", iy);
  case -2:
    return raise_argument_error(env, "invalid UTC date: month %d is not in 1..12", im);
  case -3:
    return raise_argument_error(env, "invalid UTC date: day %d does not exist in %d-%02d", id, iy, im);
  case -4:
    return raise_argument_error(env, "invalid UTC time: hour %d is not in 0..23", ihr);
  case -5:
    return raise_argument_error(env, "invalid UTC time: minute %d is not in 0..59", imn);
  case -6:
    return raise_argument_error(env, "invalid UTC time: second %.15g is negative", sec);
  case 2:
  case 3:
    return raise_argument_error(env,
                                "invalid UTC time: second %.15g is past the end of %d-%02d-%02d",
                                sec, iy, im, id);
  default:
    return raise_unexpected_status(env, "eraDtf2d", status);
  }
}

/* eraUtctai, eraTaiutc, and eraD2dtf return -1 when the date is outside eraJd2cal's range. */
static ERL_NIF_TERM
raise_jd_error(ErlNifEnv *env, const char *routine, int status, double jd1, double jd2)
{
  if (status == -1)
    return raise_argument_error(env,
                                "Julian Date {%.15g, %.15g} is outside the range ERFA can convert to a calendar date",
                                jd1, jd2);

  return raise_unexpected_status(env, routine, status);
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
    return raise_dtf2d_error(env, status, iy, im, id, ihr, imn, sec);

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
    return raise_jd_error(env, "eraUtctai", status, utc1, utc2);

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
    return raise_unexpected_status(env, "eraTaitt", status);

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
    return raise_jd_error(env, "eraTaiutc", status, tai1, tai2);

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
    return raise_unexpected_status(env, "eraTttai", status);

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
    return raise_unexpected_status(env, "eraTttcg", status);

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
    return raise_unexpected_status(env, "eraTttdb", status);

  dtr = eraDtdb(tdb1, tdb2, ut, elong, u, v);

  status = eraTttdb(tt1, tt2, dtr, &tdb1, &tdb2);
  if (!erfa_status_ok(status))
    return raise_unexpected_status(env, "eraTttdb", status);

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
    return raise_unexpected_status(env, "eraTcgtt", status);

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
    return raise_unexpected_status(env, "eraTdbtt", status);

  dtr = eraDtdb(tt1, tt2, ut, elong, u, v);

  status = eraTdbtt(tdb1, tdb2, dtr, &tt1, &tt2);
  if (!erfa_status_ok(status))
    return raise_unexpected_status(env, "eraTdbtt", status);

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
    return raise_unexpected_status(env, "eraTdbtcb", status);

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
    return raise_unexpected_status(env, "eraTcbtdb", status);

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
    return raise_jd_error(env, "eraD2dtf", status, jd1, jd2);

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
