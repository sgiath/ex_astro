#include "utils.h"
#include "nifs.h"

/*
 * Every CSPICE entry runs on a dirty scheduler because any call may wait for
 * the shared mutex behind a longer dirty operation. Kernel mutation and SPK
 * file inspection use dirty IO schedulers; the remaining CSPICE work uses
 * dirty CPU schedulers. ERFA-only numeric conversions remain normal NIFs.
 */
static ErlNifFunc nif_funcs[] = {
    {"kernel_furnsh", 1, exa_nif_kernel_furnsh, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"kernel_unload", 1, exa_nif_kernel_unload, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"kernel_clear", 0, exa_nif_kernel_clear, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"kernel_list", 0, exa_nif_kernel_list, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"dtf2d", 6, exa_nif_dtf2d, 0},
    {"utc2tai", 2, exa_nif_utc2tai, 0},
    {"tai2tt", 2, exa_nif_tai2tt, 0},
    {"tai2utc", 2, exa_nif_tai2utc, 0},
    {"tt2tai", 2, exa_nif_tt2tai, 0},
    {"tt2tcg", 2, exa_nif_tt2tcg, 0},
    {"tt2tdb", 6, exa_nif_tt2tdb, 0},
    {"tcg2tt", 2, exa_nif_tcg2tt, 0},
    {"tdb2tt", 6, exa_nif_tdb2tt, 0},
    {"tdb2tcb", 2, exa_nif_tdb2tcb, 0},
    {"tcb2tdb", 2, exa_nif_tcb2tdb, 0},
    {"jd2dt", 2, exa_nif_jd2dt, 0},
    {"str2et", 1, exa_nif_str2et, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"utc2et", 1, exa_nif_utc2et, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"unitim", 3, exa_nif_unitim, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"sec2day", 1, exa_nif_sec2day, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"day2sec", 2, exa_nif_day2sec, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkezr", 5, exa_nif_spkezr, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkez", 5, exa_nif_spkez, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkgeo", 4, exa_nif_spkgeo, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"oscelt", 3, exa_nif_oscelt, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"conics", 2, exa_nif_conics, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"bodc2n", 1, exa_nif_bodc2n, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"bodn2c", 1, exa_nif_bodn2c, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"spkobj", 1, exa_nif_spkobj, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"bodvcd", 2, exa_nif_bodvcd, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"bodvrd", 2, exa_nif_bodvrd, ERL_NIF_DIRTY_JOB_CPU_BOUND},
    {"pmsafe", 8, exa_nif_pmsafe, 0},
    {"starpv", 6, exa_nif_starpv, 0},
    {"pvstar", 1, exa_nif_pvstar, 0},
};

static int
load(ErlNifEnv *env, void **priv, ERL_NIF_TERM load_info)
{
  (void)env;
  (void)priv;
  (void)load_info;

  return exa_cspice_init();
}

/*
 * CSPICE keeps kernel/error state in statics global to this shared object.
 * An upgraded module instance would share those statics with the old one, so
 * fresh-per-instance ownership is unsound. Hot upgrade stays unsupported
 * until there is a ref-counted takeover design.
 */
static int
upgrade(ErlNifEnv *env, void **priv, void **old_priv, ERL_NIF_TERM load_info)
{
  (void)env;
  (void)priv;
  (void)old_priv;
  (void)load_info;

  return 1;
}

static void
unload(ErlNifEnv *env, void *priv)
{
  (void)env;
  (void)priv;

  exa_cspice_teardown();
}

ERL_NIF_INIT(Elixir.Astro.NIF, nif_funcs, &load, NULL, &upgrade, &unload)
