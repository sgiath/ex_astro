#include "kernel_pool.h"
#include "utils.h"

/*
 * furnsh_c does not clean up after a failure: KEEPER entries added before the
 * failure (including meta-kernel children) stay loaded, and a partially parsed
 * text kernel leaves its assignments in the pool. Rolling back by kclear_c and
 * re-furnishing every earlier file would re-read them from disk, picking up
 * edits or failing on deleted files. Instead the previous KEEPER list and pool
 * variables are kept in memory and restored from there.
 */

#define KEEPER_FILE_LENGTH 256
#define KEEPER_TYPE_LENGTH 33
#define FILE_ARCH_LENGTH 33
/* kernel.req: variable names are at most 32 characters, string values 80. */
#define POOL_NAME_LENGTH 33
#define POOL_STRING_LENGTH 81
#define POOL_NAME_BATCH 64
#define POOL_INITIAL_CAPACITY 256

struct ExaKeeperEntry
{
  SpiceChar file[KEEPER_FILE_LENGTH];
  SpiceChar type[KEEPER_TYPE_LENGTH];
  SpiceChar source[KEEPER_FILE_LENGTH];
};

struct ExaPoolVariable
{
  SpiceChar name[POOL_NAME_LENGTH];
  SpiceChar type;
  SpiceInt count;
  /* Index into `numbers` for 'N' variables, into `strings` for 'C' ones. */
  size_t offset;
};

typedef SpiceChar PoolString[POOL_STRING_LENGTH];

static bool
read_entry(SpiceInt which, struct ExaKeeperEntry *entry, char *error)
{
  SpiceInt handle;
  SpiceBoolean found;

  kdata_c(which, "ALL", KEEPER_FILE_LENGTH, KEEPER_TYPE_LENGTH, KEEPER_FILE_LENGTH,
          entry->file, entry->type, entry->source, &handle, &found);
  if (exa_cspice_failed(error))
    return false;

  if (!found)
  {
    snprintf(error, CSPICE_ERROR_LENGTH, "loaded kernel %ld could not be read", (long)which);
    return false;
  }

  return true;
}

static ExaSnapshotStatus
snapshot_entries(ExaKernelSnapshot *snapshot, char *error)
{
  SpiceInt total = 0;
  SpiceInt which;

  ktotal_c("ALL", &total);
  if (exa_cspice_failed(error))
    return EXA_SNAPSHOT_SPICE_FAILED;

  if (total == 0)
    return EXA_SNAPSHOT_OK;

  snapshot->entries = malloc((size_t)total * sizeof(*snapshot->entries));
  if (snapshot->entries == NULL)
    return EXA_SNAPSHOT_ALLOC_FAILED;

  for (which = 0; which < total; which++)
  {
    if (!read_entry(which, &snapshot->entries[which], error))
      return EXA_SNAPSHOT_SPICE_FAILED;
  }

  snapshot->entry_count = total;
  return EXA_SNAPSHOT_OK;
}

/* ZZLDKER sends every architecture except DAF and DAS to the text loader. */
static bool
loads_into_pool(const char *path, bool *pool, char *error)
{
  SpiceChar arch[FILE_ARCH_LENGTH];
  SpiceChar type[FILE_ARCH_LENGTH];

  getfat_c(path, FILE_ARCH_LENGTH, FILE_ARCH_LENGTH, arch, type);
  if (exa_cspice_failed(error))
    return false;

  *pool = strcmp(arch, "DAF") != 0 && strcmp(arch, "DAS") != 0;
  return true;
}

static ExaSnapshotStatus
snapshot_variable_names(ExaKernelSnapshot *snapshot, size_t *number_count, size_t *string_count,
                        char *error)
{
  SpiceChar names[POOL_NAME_BATCH][POOL_NAME_LENGTH];
  SpiceInt start = 0;
  SpiceInt returned;
  SpiceInt i;
  SpiceBoolean found;
  size_t capacity = 0;

  for (;;)
  {
    gnpool_c("*", start, POOL_NAME_BATCH, POOL_NAME_LENGTH, &returned, names, &found);
    if (exa_cspice_failed(error))
      return EXA_SNAPSHOT_SPICE_FAILED;

    if (!found || returned == 0)
      return EXA_SNAPSHOT_OK;

    if (snapshot->variable_count + (size_t)returned > capacity)
    {
      size_t grown_capacity = capacity == 0 ? POOL_INITIAL_CAPACITY : capacity * 2;
      struct ExaPoolVariable *grown =
          realloc(snapshot->variables, grown_capacity * sizeof(*grown));

      if (grown == NULL)
        return EXA_SNAPSHOT_ALLOC_FAILED;

      snapshot->variables = grown;
      capacity = grown_capacity;
    }

    for (i = 0; i < returned; i++)
    {
      struct ExaPoolVariable *variable = &snapshot->variables[snapshot->variable_count];
      SpiceBoolean defined;

      memcpy(variable->name, names[i], POOL_NAME_LENGTH);
      dtpool_c(variable->name, &defined, &variable->count, &variable->type);
      if (exa_cspice_failed(error))
        return EXA_SNAPSHOT_SPICE_FAILED;

      if (!defined)
      {
        snprintf(error, CSPICE_ERROR_LENGTH,
                 "kernel pool variable %s disappeared during snapshot", variable->name);
        return EXA_SNAPSHOT_SPICE_FAILED;
      }

      if (variable->type == 'N')
      {
        variable->offset = *number_count;
        *number_count += (size_t)variable->count;
      }
      else
      {
        variable->offset = *string_count;
        *string_count += (size_t)variable->count;
      }

      snapshot->variable_count++;
    }

    if (returned < POOL_NAME_BATCH)
      return EXA_SNAPSHOT_OK;

    start += returned;
  }
}

static ExaSnapshotStatus
snapshot_pool(ExaKernelSnapshot *snapshot, char *error)
{
  PoolString *strings;
  size_t number_count = 0;
  size_t string_count = 0;
  size_t i;
  ExaSnapshotStatus status;

  status = snapshot_variable_names(snapshot, &number_count, &string_count, error);
  if (status != EXA_SNAPSHOT_OK)
    return status;

  if (number_count > 0)
  {
    snapshot->numbers = malloc(number_count * sizeof(*snapshot->numbers));
    if (snapshot->numbers == NULL)
      return EXA_SNAPSHOT_ALLOC_FAILED;
  }

  if (string_count > 0)
  {
    snapshot->strings = malloc(string_count * sizeof(PoolString));
    if (snapshot->strings == NULL)
      return EXA_SNAPSHOT_ALLOC_FAILED;
  }

  strings = snapshot->strings;

  for (i = 0; i < snapshot->variable_count; i++)
  {
    const struct ExaPoolVariable *variable = &snapshot->variables[i];
    SpiceInt returned = 0;
    SpiceBoolean defined;

    if (variable->type == 'N')
      gdpool_c(variable->name, 0, variable->count, &returned,
               snapshot->numbers + variable->offset, &defined);
    else
      gcpool_c(variable->name, 0, variable->count, POOL_STRING_LENGTH, &returned,
               strings[variable->offset], &defined);

    if (exa_cspice_failed(error))
      return EXA_SNAPSHOT_SPICE_FAILED;

    if (!defined || returned != variable->count)
    {
      snprintf(error, CSPICE_ERROR_LENGTH,
               "kernel pool variable %s changed during snapshot", variable->name);
      return EXA_SNAPSHOT_SPICE_FAILED;
    }
  }

  snapshot->has_pool = true;
  return EXA_SNAPSHOT_OK;
}

ExaSnapshotStatus
exa_kernel_snapshot_take(ExaKernelSnapshot *snapshot, const char *path, char *error)
{
  ExaSnapshotStatus status;
  bool pool;

  if (!loads_into_pool(path, &pool, error))
    return EXA_SNAPSHOT_SPICE_FAILED;

  status = snapshot_entries(snapshot, error);
  if (status != EXA_SNAPSHOT_OK || !pool)
    return status;

  return snapshot_pool(snapshot, error);
}

/*
 * Unload the entries the failed furnsh_c added, newest first. unload_c removes
 * the last KEEPER entry with the given name, which is always the entry read
 * here. Unloading a text entry clears the pool and re-reads the remaining text
 * kernels from disk; that re-read may fail on an edited or deleted file, which
 * is harmless when the pool snapshot replaces the pool afterwards.
 */
static bool
unload_added_entries(const ExaKernelSnapshot *snapshot, char *error)
{
  struct ExaKeeperEntry entry;
  SpiceInt total = 0;
  SpiceInt remaining = 0;

  ktotal_c("ALL", &total);
  if (exa_cspice_failed(error))
    return false;

  while (total > snapshot->entry_count)
  {
    if (!read_entry(total - 1, &entry, error))
      return false;

    unload_c(entry.file);
    if (snapshot->has_pool)
    {
      if (failed_c())
        reset_c();
    }
    else if (exa_cspice_failed(error))
    {
      return false;
    }

    ktotal_c("ALL", &remaining);
    if (exa_cspice_failed(error))
      return false;

    if (remaining >= total)
    {
      snprintf(error, CSPICE_ERROR_LENGTH, "could not unload %s", entry.file);
      return false;
    }

    total = remaining;
  }

  return true;
}

/* pdpool_c/pcpool_c and clpool_c notify watchers, so dependent caches refresh. */
static bool
restore_pool(const ExaKernelSnapshot *snapshot, char *error)
{
  const PoolString *strings = snapshot->strings;
  size_t i;

  clpool_c();
  if (exa_cspice_failed(error))
    return false;

  for (i = 0; i < snapshot->variable_count; i++)
  {
    const struct ExaPoolVariable *variable = &snapshot->variables[i];

    if (variable->type == 'N')
      pdpool_c(variable->name, variable->count, snapshot->numbers + variable->offset);
    else
      pcpool_c(variable->name, variable->count, POOL_STRING_LENGTH, strings[variable->offset]);

    if (exa_cspice_failed(error))
      return false;
  }

  return true;
}

static bool
entries_match(const ExaKernelSnapshot *snapshot, char *error)
{
  struct ExaKeeperEntry entry;
  SpiceInt total = 0;
  SpiceInt which;

  ktotal_c("ALL", &total);
  if (exa_cspice_failed(error))
    return false;

  if (total != snapshot->entry_count)
  {
    snprintf(error, CSPICE_ERROR_LENGTH,
             "%ld kernels are loaded instead of the previous %ld",
             (long)total, (long)snapshot->entry_count);
    return false;
  }

  for (which = 0; which < total; which++)
  {
    const struct ExaKeeperEntry *expected = &snapshot->entries[which];

    if (!read_entry(which, &entry, error))
      return false;

    if (strcmp(entry.file, expected->file) != 0 || strcmp(entry.type, expected->type) != 0 ||
        strcmp(entry.source, expected->source) != 0)
    {
      snprintf(error, CSPICE_ERROR_LENGTH,
               "loaded kernel %ld is %s instead of the previous %s",
               (long)which, entry.file, expected->file);
      return false;
    }
  }

  return true;
}

static void
keep_first_failure(char *error, bool *complete, const char *reason)
{
  if (!*complete)
    return;

  snprintf(error, CSPICE_ERROR_LENGTH, "%s", reason);
  *complete = false;
}

bool
exa_kernel_snapshot_rollback(const ExaKernelSnapshot *snapshot, char *error)
{
  char reason[CSPICE_ERROR_LENGTH];
  bool complete = true;

  if (!unload_added_entries(snapshot, reason))
    keep_first_failure(error, &complete, reason);

  if (snapshot->has_pool && !restore_pool(snapshot, reason))
    keep_first_failure(error, &complete, reason);

  if (!entries_match(snapshot, reason))
    keep_first_failure(error, &complete, reason);

  return complete;
}

void
exa_kernel_snapshot_free(ExaKernelSnapshot *snapshot)
{
  free(snapshot->entries);
  free(snapshot->variables);
  free(snapshot->numbers);
  free(snapshot->strings);
}
