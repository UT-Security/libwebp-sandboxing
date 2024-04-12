/* Automatically generated by wasm2c */
#ifndef DECODE_WEBP_WASM_H_GENERATED_
#define DECODE_WEBP_WASM_H_GENERATED_

#include "wasm-rt.h"

#include <stdint.h>

#ifndef WASM_RT_CORE_TYPES_DEFINED
#define WASM_RT_CORE_TYPES_DEFINED
typedef uint8_t u8;
typedef int8_t s8;
typedef uint16_t u16;
typedef int16_t s16;
typedef uint32_t u32;
typedef int32_t s32;
typedef uint64_t u64;
typedef int64_t s64;
typedef float f32;
typedef double f64;
#endif

#ifdef __cplusplus
extern "C" {
#endif

struct w2c_wasi__snapshot__preview1;

typedef struct w2c_decode__webp__wasm {
  struct w2c_wasi__snapshot__preview1* w2c_wasi__snapshot__preview1_instance;
  u32 w2c_0x5F_stack_pointer;
  u32 w2c_GOT0x2Edata0x2Einternal0x2E_0x5Fmemory_base;
  wasm_rt_memory_t w2c_memory;
  wasm_rt_funcref_table_t w2c_T0;
} w2c_decode__webp__wasm;

void wasm2c_decode__webp__wasm_instantiate(w2c_decode__webp__wasm*, struct w2c_wasi__snapshot__preview1*);
void wasm2c_decode__webp__wasm_free(w2c_decode__webp__wasm*);
wasm_rt_func_type_t wasm2c_decode__webp__wasm_get_func_type(uint32_t param_count, uint32_t result_count, ...);

/* import: 'wasi_snapshot_preview1' 'fd_close' */
u32 w2c_wasi__snapshot__preview1_fd_close(struct w2c_wasi__snapshot__preview1*, u32);

/* import: 'wasi_snapshot_preview1' 'fd_seek' */
u32 w2c_wasi__snapshot__preview1_fd_seek(struct w2c_wasi__snapshot__preview1*, u32, u64, u32, u32);

/* import: 'wasi_snapshot_preview1' 'fd_write' */
u32 w2c_wasi__snapshot__preview1_fd_write(struct w2c_wasi__snapshot__preview1*, u32, u32, u32, u32);

/* export: 'memory' */
wasm_rt_memory_t* w2c_decode__webp__wasm_memory(w2c_decode__webp__wasm* instance);

/* export: '_initialize' */
void w2c_decode__webp__wasm_0x5Finitialize(w2c_decode__webp__wasm*);

/* export: 'malloc' */
u32 w2c_decode__webp__wasm_malloc(w2c_decode__webp__wasm*, u32);

/* export: 'DecodeWebpImage' */
u32 w2c_decode__webp__wasm_DecodeWebpImage(w2c_decode__webp__wasm*, u32, u32, u32, u32, u32);

#ifdef __cplusplus
}
#endif

#endif  /* DECODE_WEBP_WASM_H_GENERATED_ */