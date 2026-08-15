#include "utils.h"
#include "nifs.h"

/*
 * Runtime management for the single process-wide CSPICE kernel pool.
 * exa_nif_kernel_furnsh snapshots top-level paths because furnsh_c can leave
 * a partial load on failure, especially for meta-kernels.
 */
#define KERNEL_PATH_BUF 256
#define KERNEL_TYPE_BUF 33
#define KERNEL_TX_ERROR_LENGTH (CSPICE_ERROR_LENGTH * 2 + 80)

static void
free_kernel_paths(char **paths, SpiceInt count)
{
  SpiceInt i;

  if (paths == NULL)
    return;

  for (i = 0; i < count; i++)
    exa_free_string(paths[i]);

  free(paths);
}

static bool
snapshot_top_level_kernels(char ***paths_out, SpiceInt *count_out, char *error)
{
  SpiceInt total = 0;
  SpiceInt which;
  SpiceInt top_count = 0;
  char **paths = NULL;
  SpiceChar file[KERNEL_PATH_BUF];
  SpiceChar filtyp[KERNEL_TYPE_BUF];
  SpiceChar srcfil[KERNEL_PATH_BUF];
  SpiceInt handle;
  SpiceBoolean found;

  *paths_out = NULL;
  *count_out = 0;

  ktotal_c("ALL", &total);
  if (exa_cspice_failed(error))
    return false;

  if (total > 0)
  {
    paths = calloc((size_t)total, sizeof(*paths));
    if (paths == NULL)
    {
      snprintf(error, CSPICE_ERROR_LENGTH, "failed to allocate kernel snapshot");
      return false;
    }
  }

  for (which = 0; which < total; which++)
  {
    size_t path_len;
    char *copy;

    kdata_c(which, "ALL", KERNEL_PATH_BUF, KERNEL_TYPE_BUF, KERNEL_PATH_BUF,
            file, filtyp, srcfil, &handle, &found);
    if (exa_cspice_failed(error))
    {
      free_kernel_paths(paths, top_count);
      return false;
    }

    if (!found || srcfil[0] != '\0')
      continue;

    path_len = strlen(file);
    copy = malloc(path_len + 1);
    if (copy == NULL)
    {
      snprintf(error, CSPICE_ERROR_LENGTH, "failed to allocate kernel snapshot path");
      free_kernel_paths(paths, top_count);
      return false;
    }

    memcpy(copy, file, path_len + 1);
    paths[top_count] = copy;
    top_count++;
  }

  *paths_out = paths;
  *count_out = top_count;
  return true;
}

static bool
restore_top_level_kernels(char **paths, SpiceInt count, char *error)
{
  SpiceInt i;

  kclear_c();
  if (exa_cspice_failed(error))
    return false;

  for (i = 0; i < count; i++)
  {
    furnsh_c(paths[i]);
    if (exa_cspice_failed(error))
      return false;
  }

  return true;
}

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
  SpiceChar *path = NULL;
  char **snapshot = NULL;
  SpiceInt snapshot_count = 0;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  SpiceChar restore_error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;
  bool locked = false;
  bool direct = false;

  if (!exa_load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &path))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!exa_cspice_lock())
  {
    result = exa_cspice_sync_error(env);
    goto cleanup;
  }
  locked = true;

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

  if (!snapshot_top_level_kernels(&snapshot, &snapshot_count, error))
  {
    result = exa_error_result(env, error);
    goto cleanup;
  }

  furnsh_c(path);

  if (exa_cspice_failed(error))
  {
    if (!restore_top_level_kernels(snapshot, snapshot_count, restore_error))
    {
      SpiceChar combined[KERNEL_TX_ERROR_LENGTH];

      snprintf(combined, sizeof(combined),
               "kernel load failed: %s; restore after failed load also failed: %s",
               error, restore_error);
      result = exa_error_result(env, combined);
      goto cleanup;
    }

    result = exa_error_result(env, error);
    goto cleanup;
  }

  result = enif_make_atom(env, "ok");

cleanup:
  if (locked)
    exa_cspice_unlock();
  free_kernel_paths(snapshot, snapshot_count);
  exa_free_string(path);
  return result;
}

ERL_NIF_TERM
exa_nif_kernel_unload(ErlNifEnv *env, int argc, const ERL_NIF_TERM argv[])
{
  SpiceChar *path = NULL;
  SpiceChar error[CSPICE_ERROR_LENGTH];
  ERL_NIF_TERM result;

  if (!exa_load_string(env, argv[0], NATIVE_STRING_KERNEL_PATH, &path))
  {
    result = enif_make_badarg(env);
    goto cleanup;
  }

  if (!exa_cspice_lock())
  {
    result = exa_cspice_sync_error(env);
    goto cleanup;
  }

  unload_c(path);

  if (exa_cspice_failed(error))
  {
    exa_cspice_unlock();
    result = exa_error_result(env, error);
    goto cleanup;
  }

  exa_cspice_unlock();
  result = enif_make_atom(env, "ok");

cleanup:
  exa_free_string(path);
  return result;
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
      return exa_error_result(env, "failed to allocate kernel list");
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
