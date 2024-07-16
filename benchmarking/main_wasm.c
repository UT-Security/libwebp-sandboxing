/**
 * Copyright Willy R. Vasquez.
 */

#ifdef ENABLE_SIMD
#include "decode_webp_wasmsimd.h"

#define   NAME          "wasmsimd"
#define   INST_TYPE     w2c_decode__webp__wasmsimd

// Functions
#define   winstantiate   wasm2c_decode__webp__wasmsimd_instantiate
#define   wmemory        w2c_decode__webp__wasmsimd_memory
#define   wmalloc        w2c_decode__webp__wasmsimd_malloc
#define   wdecodewebp    w2c_decode__webp__wasmsimd_DecodeWebpImage
#define   wfree          wasm2c_decode__webp__wasmsimd_free

#elif defined(SIMD_EMSCRIPTEN)

#include "decode_webp_wasmsimd_emscripten.h"

#define   NAME          "wasmsimd_emscripten"
#define   INST_TYPE     w2c_decode__webp__wasmsimd__emscripten

// Functions
#define   winstantiate   wasm2c_decode__webp__wasmsimd__emscripten_instantiate
#define   wmemory        w2c_decode__webp__wasmsimd__emscripten_memory
#define   wmalloc        w2c_decode__webp__wasmsimd__emscripten_malloc
#define   wdecodewebp    w2c_decode__webp__wasmsimd__emscripten_DecodeWebpImage
#define   wfree          wasm2c_decode__webp__wasmsimd__emscripten_free

#else  /* ENABLE_SIMD */

#include "decode_webp_wasm.h"
#define   NAME          "wasm"
#define   INST_TYPE     w2c_decode__webp__wasm

// Functions
#define   winstantiate   wasm2c_decode__webp__wasm_instantiate
#define   wmemory        w2c_decode__webp__wasm_memory
#define   wmalloc        w2c_decode__webp__wasm_malloc
#define   wdecodewebp    w2c_decode__webp__wasm_DecodeWebpImage
#define   wfree          wasm2c_decode__webp__wasm_free

#endif /* ENABLE_SIMD */

#include "helpers.h"

#define PAGE_SIZE 65536

//#define OUTPUT_IMAGE

#ifdef OUTPUT_IMAGE
#include "uvwasi.h"
#include "uvwasi-rt.h"
#define OUTPUT_MSG "(outputting image)"
#else
#define OUTPUT_MSG "(no output)"
#endif


int main(int argc, const char** argv) {
  const char* in_file = NULL;
  const char* out_time_file = NULL;
  const char* out_file_name = "wasm_out.pam";
  int iterations = 100;

  printf("%s Webp version 1.4.0 %s\n", NAME, OUTPUT_MSG);

  if (argc < 3) {
    print_usage();
    return 0;
  }

  in_file = argv[1];
  out_time_file = argv[2];

  if (argc > 3) {
    out_file_name = argv[3];
    if (argc > 4) {
      iterations = atoi(argv[4]);
    }
  }

  FILE *out_time = fopen(out_time_file, "a");
  if (!out_time) {
    printf("Unable to open %s\n", out_time_file);
    return -1;
  }

  const uint8_t* data = NULL;
  size_t data_size = 0;
  if (!open_file(in_file, &data, &data_size)) {
    return -1;
  }
  /* Initialize the Wasm runtime. */
  wasm_rt_init();

  /* Declare an instance of the `inst` module. */
  INST_TYPE inst = { 0 };

#ifdef OUTPUT_IMAGE
  // Create the uvwasi env for outputting
  uvwasi_t local_uvwasi_state = {0};

  struct w2c_wasi__snapshot__preview1 wasi_env = {
    .uvwasi = &local_uvwasi_state,
    .instance_memory = &inst.w2c_memory
  };

  uvwasi_options_t init_options;
  uvwasi_options_init(&init_options);

  //pass in standard descriptors
  init_options.in = 0;
  init_options.out = 1;
  init_options.err = 2;
  init_options.fd_table_size = 3;

  init_options.allocator = NULL;
  
  uvwasi_errno_t ret = uvwasi_init(&local_uvwasi_state, &init_options);

  if (ret != UVWASI_ESUCCESS) {
    printf("uvwasi_init failed with error %d\n", ret);
    exit(1);
  }

  /* Construct the module instance. */
  winstantiate(&inst, &wasi_env);

#else
  /* Construct the module instance. */
  winstantiate(&inst);
#endif /* OUTPUT_IMAGE */

  wasm_rt_memory_t* mem = wmemory(&inst);

  if (mem->size < data_size) {
    // Grow memory to handle file
    uint64_t delta = ((data_size - mem->size)/PAGE_SIZE)+1;
    uint64_t old_pages = wasm_rt_grow_memory(mem, delta);
    fprintf(stderr, "File too big (%zu) for WASM memory (%lu)\n", data_size, mem->size);
    fprintf(stderr, "Grew memory of size %lu by %lu pages\n", old_pages, delta);
  }
  // Allocate sandbox memory
  u32 webp_file = wmalloc(&inst, data_size);

  // Copy data to sandbox memory
  memcpy(&(mem->data[webp_file]), data, data_size);

  /////////////////////////////////////////////////////////////////////

  // Result is a pointer to a pointer
  u32 result = wmalloc(&inst, sizeof(u32));
  u32 result_size = wmalloc(&inst, sizeof(u32));

  Stopwatch stop_watch;

  /* Warm up phase */
  StopwatchReset(&stop_watch);
  wdecodewebp(&inst, webp_file, data_size, iterations, result, result_size);
  double dt = StopwatchReadAndReset(&stop_watch);

  /* Test phase */
  StopwatchReset(&stop_watch);
  wdecodewebp(&inst, webp_file, data_size, iterations, result, result_size);
  dt = StopwatchReadAndReset(&stop_watch);

  fprintf(stderr, "Time to decode %s %d times: %.10fs\n", in_file, iterations, dt);
  fprintf(out_time, "%f\n", dt);

  u32 size = *(u32*) (&mem->data[result_size]);

  if (size > 0) {
    u32 output_ptr = *(u32*) (&mem->data[result]);
    if (!save_file(out_file_name, &(mem->data[output_ptr]), size)){
      return -1;
    }
  }

  /////////////////////////////////////////////////////////////////////
EXIT:
  fclose(out_time);
  free((void*)data);
  /* Free the inst module. */
  wfree(&inst);

#ifdef OUTPUT_IMAGE
  uvwasi_destroy(&local_uvwasi_state);
#endif

  /* Free the Wasm runtime state. */
  wasm_rt_free();
  return 0;
}
