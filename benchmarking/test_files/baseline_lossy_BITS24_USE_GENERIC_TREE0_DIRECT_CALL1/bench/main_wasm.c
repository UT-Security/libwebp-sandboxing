#ifdef ENABLE_SIMD
#include "decode_webp_wasmsimd.h"
#else
#include "decode_webp_wasm.h"
#endif

#include "helpers.h"

#define PAGE_SIZE 65536

//#define OUTPUT_IMAGE

#ifdef OUTPUT_IMAGE
#include "uvwasi.h"
#include "uvwasi-rt.h"
#endif

int main(int argc, const char** argv) {
  const char* in_file = NULL;
  const char* out_time_file = NULL;
  const char* out_file_name = "wasm_out.pam";
  int iterations = 100;

#ifdef ENABLE_SIMD
  printf("WASMSIMD Webp version 1.4.0");
#else
  printf("WASM Webp version 1.4.0");
#endif

#ifdef OUTPUT_IMAGE
  printf(" (outputting image)\n");
#else
  printf(" (no output)\n");
#endif

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
#ifdef ENABLE_SIMD
  w2c_decode__webp__wasmsimd inst = { 0 };
#else
  w2c_decode__webp__wasm inst = { 0 };
#endif

#ifdef OUTPUT_IMAGE

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
#ifdef ENABLE_SIMD
  wasm2c_decode__webp__wasmsimd_instantiate(&inst, &wasi_env);
#else
  wasm2c_decode__webp__wasm_instantiate(&inst, &wasi_env);
#endif
#else
  /* Construct the module instance. */
#ifdef ENABLE_SIMD
  wasm2c_decode__webp__wasmsimd_instantiate(&inst);
#else
  wasm2c_decode__webp__wasm_instantiate(&inst);
#endif
#endif
#ifdef ENABLE_SIMD
  wasm_rt_memory_t* mem = w2c_decode__webp__wasmsimd_memory(&inst);
#else
  wasm_rt_memory_t* mem = w2c_decode__webp__wasm_memory(&inst);
#endif

  if (mem->size < data_size) {
    // Grow memory to handle file
    uint64_t delta = ((data_size - mem->size)/PAGE_SIZE)+1;
    uint64_t old_pages = wasm_rt_grow_memory(mem, delta);
    fprintf(stderr, "File too big (%zu) for WASM memory (%lu)\n", data_size, mem->size);
    fprintf(stderr, "Grew memory of size %lu by %lu pages\n", old_pages, delta);
  }
  // Allocate sandbox memory
#ifdef ENABLE_SIMD
  u32 webp_file = w2c_decode__webp__wasmsimd_malloc(&inst, data_size);
#else
  u32 webp_file = w2c_decode__webp__wasm_malloc(&inst, data_size);
#endif
  // Copy data to sandbox memory
  memcpy(&(mem->data[webp_file]), data, data_size);

  /////////////////////////////////////////////////////////////////////

  // Result is a pointer to a pointer
#ifdef ENABLE_SIMD
  u32 result = w2c_decode__webp__wasmsimd_malloc(&inst, sizeof(u32));
  u32 result_size = w2c_decode__webp__wasmsimd_malloc(&inst, sizeof(u32));
#else
  u32 result = w2c_decode__webp__wasm_malloc(&inst, sizeof(u32));
  u32 result_size = w2c_decode__webp__wasm_malloc(&inst, sizeof(u32));
#endif

  Stopwatch stop_watch;

  /* Warm up phase */
  StopwatchReset(&stop_watch);
#ifdef ENABLE_SIMD
  w2c_decode__webp__wasmsimd_DecodeWebpImage(&inst, webp_file, data_size, iterations, result, result_size);
#else
  w2c_decode__webp__wasm_DecodeWebpImage(&inst, webp_file, data_size, iterations, result, result_size);
#endif
  double dt = StopwatchReadAndReset(&stop_watch);

  /* Test phase */
  StopwatchReset(&stop_watch);
#ifdef ENABLE_SIMD
  w2c_decode__webp__wasmsimd_DecodeWebpImage(&inst, webp_file, data_size, iterations, result, result_size);
#else
  w2c_decode__webp__wasm_DecodeWebpImage(&inst, webp_file, data_size, iterations, result, result_size);
#endif
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
#ifdef ENABLE_SIMD
  wasm2c_decode__webp__wasmsimd_free(&inst);
#else
  wasm2c_decode__webp__wasm_free(&inst);
#endif

#ifdef OUTPUT_IMAGE
  uvwasi_destroy(&local_uvwasi_state);
#endif

  /* Free the Wasm runtime state. */
  wasm_rt_free();
  return 0;
}
