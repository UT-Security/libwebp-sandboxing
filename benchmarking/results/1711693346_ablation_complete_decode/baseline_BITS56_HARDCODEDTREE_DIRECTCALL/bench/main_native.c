#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/time.h>

#include "decode_webp.h"
#include "helpers.h"


int main(int argc, const char* argv[]) {
  const char* in_file = NULL;
  const char* out_time_file = NULL;
  const char* out_file_name = "native_out.ppm";
  int iterations = 100;

  printf("Webp version 1.3.2");

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

  uint8_t* result = NULL;
  size_t result_size = 0;


  Stopwatch stop_watch;
  StopwatchReset(&stop_watch);
  int status = DecodeWebpImage(data, data_size, iterations, &result, &result_size);
  const double dt = StopwatchReadAndReset(&stop_watch);
  if (status != 0) {
    fprintf(stderr, "Failed to decode :(\n");
    return -1;
  }
  fprintf(stderr, "Time to decode %s %d times: %.10fs\n", in_file, iterations, dt);

  if (result_size > 0 && result != NULL) {
    if (!save_file(out_file_name, result, result_size)){
      return -1;
    }
  }
  fprintf(out_time, "%f\n", dt);
  fclose(out_time);
  free((void*)data);
  free(result);
  return 0;
}

