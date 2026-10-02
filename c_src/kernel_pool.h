#ifndef EX_ASTRO_KERNEL_POOL_H
#define EX_ASTRO_KERNEL_POOL_H

/*
 * In-memory snapshot of CSPICE kernel state used to roll back a failed
 * furnsh_c without re-reading previously loaded files from disk.
 *
 * Every function must be called with the CSPICE mutex held, and the mutex must
 * stay held from exa_kernel_snapshot_take through the furnsh_c attempt and any
 * rollback so no other caller observes or changes the intermediate state.
 */

#include <stdbool.h>
#include <stddef.h>

#include "SpiceUsr.h"

struct ExaKeeperEntry;
struct ExaPoolVariable;

/*
 * Zero-initialize before use (`ExaKernelSnapshot snapshot = {0};`) so
 * exa_kernel_snapshot_free is safe on every path. Fields are private to
 * kernel_pool.c.
 */
typedef struct
{
  struct ExaKeeperEntry *entries;
  SpiceInt entry_count;
  bool has_pool;
  struct ExaPoolVariable *variables;
  size_t variable_count;
  SpiceDouble *numbers;
  void *strings;
} ExaKernelSnapshot;

typedef enum
{
  EXA_SNAPSHOT_OK,
  EXA_SNAPSHOT_SPICE_FAILED,
  EXA_SNAPSHOT_ALLOC_FAILED
} ExaSnapshotStatus;

/*
 * Record the KEEPER entry list before furnishing `path`. Kernel pool variables
 * are recorded too unless `path` is a binary DAF/DAS file, because only
 * text-loader kernels (text kernels and meta-kernels) touch the pool.
 * On EXA_SNAPSHOT_SPICE_FAILED, `error` (CSPICE_ERROR_LENGTH bytes) holds the
 * reason and the CSPICE error state has been reset.
 */
ExaSnapshotStatus exa_kernel_snapshot_take(ExaKernelSnapshot *snapshot, const char *path, char *error);

/*
 * Undo a failed furnsh_c: unload the KEEPER entries it added, replace the pool
 * with the recorded variables, and check the KEEPER list matches the snapshot.
 * Returns false with the first reason in `error` (CSPICE_ERROR_LENGTH bytes)
 * when the restore is incomplete. Never allocates.
 */
bool exa_kernel_snapshot_rollback(const ExaKernelSnapshot *snapshot, char *error);

void exa_kernel_snapshot_free(ExaKernelSnapshot *snapshot);

#endif
