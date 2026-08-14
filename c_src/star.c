#include "utils.h"

static ERL_NIF_TERM
pmsafe(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double ra1, dec1, pmr1, pmd1, px1, rv1;
  double ep1a, ep1b, ep2a, ep2b;
  int ep1_arity, ep2_arity;
  const ERL_NIF_TERM *ep1, *ep2;
  double ra2 = 0.0, dec2 = 0.0, pmr2 = 0.0, pmd2 = 0.0, px2 = 0.0, rv2 = 0.0;
  int status;
  ERL_NIF_TERM value;

  if (!enif_get_double(env, argv[0], &ra1) ||
      !enif_get_double(env, argv[1], &dec1) ||
      !enif_get_double(env, argv[2], &pmr1) ||
      !enif_get_double(env, argv[3], &pmd1) ||
      !enif_get_double(env, argv[4], &px1) ||
      !enif_get_double(env, argv[5], &rv1) ||
      !enif_get_tuple(env, argv[6], &ep1_arity, &ep1) ||
      ep1_arity != 2 ||
      !enif_get_double(env, ep1[0], &ep1a) ||
      !enif_get_double(env, ep1[1], &ep1b) ||
      !enif_get_tuple(env, argv[7], &ep2_arity, &ep2) ||
      ep2_arity != 2 ||
      !enif_get_double(env, ep2[0], &ep2a) ||
      !enif_get_double(env, ep2[1], &ep2b))
    return enif_make_badarg(env);

  status = eraPmsafe(ra1, dec1, pmr1, pmd1, px1, rv1,
                     ep1a, ep1b, ep2a, ep2b,
                     &ra2, &dec2, &pmr2, &pmd2, &px2, &rv2);

  value = enif_make_tuple6(env,
                           enif_make_double(env, ra2),
                           enif_make_double(env, dec2),
                           enif_make_double(env, pmr2),
                           enif_make_double(env, pmd2),
                           enif_make_double(env, px2),
                           enif_make_double(env, rv2));

  return ok_result2(env, value, enif_make_int(env, status));
}

static ERL_NIF_TERM
starpv(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double ra, dec, pmr, pmd, px, rv;
  double pv[2][3] = {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}};
  int status;

  if (!enif_get_double(env, argv[0], &ra) ||
      !enif_get_double(env, argv[1], &dec) ||
      !enif_get_double(env, argv[2], &pmr) ||
      !enif_get_double(env, argv[3], &pmd) ||
      !enif_get_double(env, argv[4], &px) ||
      !enif_get_double(env, argv[5], &rv))
    return enif_make_badarg(env);

  status = eraStarpv(ra, dec, pmr, pmd, px, rv, pv);

  return ok_result2(env,
                    make_list(env, &pv[0][0], 6),
                    enif_make_int(env, status));
}

static ERL_NIF_TERM
pvstar(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  double pv[2][3];
  double ra = 0.0, dec = 0.0, pmr = 0.0, pmd = 0.0, px = 0.0, rv = 0.0;
  int status;
  ERL_NIF_TERM value;

  if (!load_list(env, argv[0], 6, &pv[0][0]))
    return enif_make_badarg(env);

  status = eraPvstar(pv, &ra, &dec, &pmr, &pmd, &px, &rv);

  value = enif_make_tuple6(env,
                           enif_make_double(env, ra),
                           enif_make_double(env, dec),
                           enif_make_double(env, pmr),
                           enif_make_double(env, pmd),
                           enif_make_double(env, px),
                           enif_make_double(env, rv));

  return ok_result2(env, value, enif_make_int(env, status));
}

/*
 * Scheduler policy:
 * - Shared kernel-management entries (furnsh/unload/kclear) from utils.h
 *   are dirty IO jobs; kernel_list stays on a normal scheduler.
 * - ERFA-only star conversions are bounded numeric work and remain normal
 *   scheduler NIFs.
 */
static ErlNifFunc nif_funcs[] = {
    EX_ASTRO_KERNEL_NIF_FUNCS,
    {"pmsafe_nif", 8, pmsafe, 0},
    {"starpv_nif", 6, starpv, 0},
    {"pvstar_nif", 1, pvstar, 0},
};

ERL_NIF_INIT(Elixir.Astro.Star, nif_funcs, &load, NULL, &upgrade, &unload)
