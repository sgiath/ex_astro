#include "utils.h"
#include "nifs.h"
#include "kernel_pool.h"

/*
 * Runtime management for the single process-wide CSPICE kernel pool.
 * exa_nif_kernel_furnsh snapshots the KEEPER list and, for text kernels, the
 * pool variables because furnsh_c can leave a partial load on failure,
 * especially for meta-kernels. See kernel_pool.c for the rollback.
 */
#define KERNEL_PATH_BUF 256
#define KERNEL_TYPE_BUF 33
#define KERNEL_TX_ERROR_LENGTH (CSPICE_ERROR_LENGTH * 2 + 80)

static bool
kernel_loaded_direct(const char *path, bool *direct, char *error)
{
  SpiceInt count = 0;
  SpiceInt which;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;

  *direct = false;

  ktotal_c("ALL", &count);
  if (exa_cspice_failed(error))
    return false;

  for (which = 0; which < count; which++)
  {
    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (exa_cspice_failed(error))
      return false;

    if (found && srcfil[0] == '\0' && strcmp(file, path) == 0)
    {
      *direct = true;
      break;
    }
  }

  return true;
}

ERL_NIF_TERM
exa_nif_kernel_furnsh(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char path[NATIVE_STRING_KERNEL_PATH_MAX + 1];
  ExaKernelSnapshot snapshot = {0};
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceChar restore_error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;
  bool direct = false;

  if (!exa_load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, path, sizeof(path)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  if (!kernel_loaded_direct(path, &direct, error))
  {
    result = exa_error_result(env, error);
    goto cleanup;
  }

  if (direct)
  {
    result = enif_make_atom(env, "ok");
    goto cleanup;
  }

  switch (exa_kernel_snapshot_take(&snapshot, path, error))
  {
  case EXA_SNAPSHOT_OK:
    break;
  case EXA_SNAPSHOT_SPICE_FAILED:
    result = exa_error_result(env, error);
    goto cleanup;
  case EXA_SNAPSHOT_ALLOC_FAILED:
    result = exa_raise_alloc_failed(env);
    goto cleanup;
  }

  furnsh_c(path);

  if (exa_cspice_failed(error))
  {
    if (!exa_kernel_snapshot_rollback(&snapshot, restore_error))
    {
      SpiceChar combined[KERNEL_TX_ERROR_LENGTH];

      snprintf(combined, sizeof(combined),
               "kernel load failed: %s; restore after failed load was incomplete: %s",
               error, restore_error);
      result = exa_error_result(env, combined);
      goto cleanup;
    }

    result = exa_error_result(env, error);
    goto cleanup;
  }

  result = enif_make_atom(env, "ok");

cleanup:
  exa_cspice_unlock();
  exa_kernel_snapshot_free(&snapshot);
  return result;
}

ERL_NIF_TERM
exa_nif_kernel_unload(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  char path[NATIVE_STRING_KERNEL_PATH_MAX + 1];
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, path, sizeof(path)))
    return enif_make_badarg(env);

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  unload_c(path);

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM
exa_nif_kernel_clear(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar error[CSPICE_ERROR_LENGTH];

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  kclear_c();

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  exa_cspice_unlock();
  return enif_make_atom(env, "ok");
}


ERL_NIF_TERM
exa_nif_kernel_list(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceInt count = 0;
  SpiceInt which;
  SpiceInt listed = 0;
  SpiceInt i;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM *files = NULL;
  ERL_NIF_TERM list;
  ERL_NIF_TERM binary;

  if (!exa_cspice_lock())
    return exa_cspice_sync_error(env);

  ktotal_c("ALL", &count);
  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    return exa_error_result(env, error);
  }

  if (count > 0)
  {
    files = malloc((size_t)count * sizeof(*files));
    if (files == NULL)
    {
      exa_cspice_unlock();
      return exa_raise_alloc_failed(env);
    }
  }

  for (which = 0; which < count; which++)
  {
    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (exa_cspice_failed(error))
    {
      free(files);
      exa_cspice_unlock();
      return exa_error_result(env, error);
    }

    if (!found)
      continue;

    if (!exa_make_binary(env, file, &binary))
    {
      free(files);
      exa_cspice_unlock();
      return binary;
    }

    files[listed] = binary;
    listed++;
  }

  exa_cspice_unlock();

  list = enif_make_list(env, 0);
  for (i = listed; i > 0; i--)
    list = enif_make_list_cell(env, files[i - 1], list);

  free(files);
  return exa_ok_result(env, list);
}
