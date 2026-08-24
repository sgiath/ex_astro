#ifndef EX_ASTRO_UTILS_H
#define EX_ASTRO_UTILS_H

/* Shared declarations for ex_astro's single native library. */

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <erl_nif.h>
#include <erfa.h>
#include "SpiceUsr.h"

#define CSPICE_ERROR_LENGTH 1841

typedef enum
{
  NATIVE_STRING_BODY,
  NATIVE_STRING_FRAME,
  NATIVE_STRING_ABCORR,
  NATIVE_STRING_KERNEL_PATH,
  NATIVE_STRING_KERNEL_ITEM,
  NATIVE_STRING_TIME,
  NATIVE_STRING_UTC_TIME,
  NATIVE_STRING_TIME_SYSTEM
} NativeStringKind;

/*
 * Native string limits are byte counts excluding the trailing terminator.
 *
 * The NIF boundary rejects empty binaries, embedded NUL bytes, and binaries
 * longer than the category limit before CSPICE or ERFA-adjacent code sees a
 * NUL-terminated C string. Invalid native strings intentionally use the same
 * badarg/ArgumentError path as non-binary inputs.
 *
 * Limit rationale:
 * - Body names/ID strings: CSPICE body-name translation MAXL is 36.
 * - Frames: frames.req says user frame names must not exceed 26 characters.
 * - Aberration corrections: longest documented option is "XCN+S".
 * - Kernel paths: furnsh_c FILSIZ accepts non-blank file names up to 255.
 * - Kernel items: kernel.req caps kernel variable names at 32 characters.
 * - Time strings: str2et_c handles general calendar strings; 256 covers the
 *   documented examples without caller-controlled allocation.
 * - UTC strings: utc2et_c says input length should not exceed 80 characters.
 * - Time systems: longest unitim_c system name is "JDTDB"/"JDTDT".
 */
#define NATIVE_STRING_BODY_MAX 36
#define NATIVE_STRING_FRAME_MAX 26
#define NATIVE_STRING_ABCORR_MAX 5
#define NATIVE_STRING_KERNEL_PATH_MAX 255
#define NATIVE_STRING_KERNEL_ITEM_MAX 32
#define NATIVE_STRING_TIME_MAX 256
#define NATIVE_STRING_UTC_TIME_MAX 80
#define NATIVE_STRING_TIME_SYSTEM_MAX 5

bool exa_cspice_lock(void);
void exa_cspice_unlock(void);
bool exa_load_string(ErlNifEnv *env, ERL_NIF_TERM arg, NativeStringKind kind, char **result);
bool exa_load_list(ErlNifEnv *env, ERL_NIF_TERM arg, size_t length, double *result);
ERL_NIF_TERM exa_make_list(ErlNifEnv *env, double *list, size_t length);
bool exa_make_binary(ErlNifEnv *env, char *data, ERL_NIF_TERM *result);
ERL_NIF_TERM exa_error_result(ErlNifEnv *env, char *error_msg);
ERL_NIF_TERM exa_cspice_sync_error(ErlNifEnv *env);
bool exa_cspice_failed(char *error_msg);
ERL_NIF_TERM exa_ok_result(ErlNifEnv *env, ERL_NIF_TERM result);
ERL_NIF_TERM exa_ok_result2(ErlNifEnv *env, ERL_NIF_TERM result1, ERL_NIF_TERM result2);
int exa_cspice_init(void);
void exa_cspice_teardown(void);

#endif
