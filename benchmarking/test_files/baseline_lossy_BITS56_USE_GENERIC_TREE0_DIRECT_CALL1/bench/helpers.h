#ifndef HELPERS_H_
#define HELPERS_H_

#include <stdio.h>
#include <stdlib.h>
#include <sys/time.h>
#include <stdint.h>

typedef struct timeval Stopwatch;

static inline void StopwatchReset(Stopwatch* watch) {
  gettimeofday(watch, NULL);
}

static inline double StopwatchReadAndReset(Stopwatch* watch) {
  struct timeval old_value;
  double delta_sec, delta_usec;
  memcpy(&old_value, watch, sizeof(old_value));
  gettimeofday(watch, NULL);
  delta_sec = (double)watch->tv_sec - old_value.tv_sec;
  delta_usec = (double)watch->tv_usec - old_value.tv_usec;
  return delta_sec + delta_usec / 1000000.0;
}

static void print_usage(){
  printf("Usage: dwebp [input_file] [output_time] [output_filename] [iterations]\n\n"
    "Decodes the WebP image file to YUV format [Default].\n"
    "Note: Animated WebP files are not supported.\n\n"
    "input_file:      webp file to decode\n"
    "output_time:     file to save the decode time\n"
    "output_filename: (Optional) File to save the output.\n"
    "iterations:      (Optional) number of times to decode the image.\n"
  );
}

static int open_file(const char* const in_file,
            const uint8_t** data, size_t* data_size) {
  int ok;
  uint8_t* file_data;
  size_t file_size;
  FILE* in;

  *data = NULL;
  *data_size = 0;

  in = fopen(in_file, "rb");
  if (in == NULL) {
    fprintf(stderr, "cannot open input file '%s'\n", (const char*)in_file);
    return 0;
  }
  fseek(in, 0, SEEK_END);
  file_size = ftell(in);
  fseek(in, 0, SEEK_SET);
  // we allocate one extra byte for the \0 terminator
  file_data = (uint8_t*) malloc(file_size + 1);
  if (file_data == NULL) {
    fclose(in);
    fprintf(stderr, "memory allocation failure when reading file %s\n",
             (const char*)in_file);
    return 0;
  }
  ok = (fread(file_data, file_size, 1, in) == 1);
  fclose(in);

  if (!ok) {
    fprintf(stderr, "Could not read %d bytes of data from file %s\n",
             (int)file_size, (const char*)in_file);
    free(file_data);
    return 0;
  }
  file_data[file_size] = '\0';  // convenient 0-terminator
  *data = file_data;
  *data_size = file_size;

  return 1;
}

static int save_file(const char* const out_file_name, const uint8_t* result, size_t result_size) {
  fprintf(stderr, "Saving %zu bytes to %s\n", result_size, out_file_name);
  FILE *outfile = fopen(out_file_name, "wb");
  if (!outfile) {
    fprintf(stderr, "Unable to open %s\n", out_file_name);
    return 0;
  }

  fwrite(result, sizeof(uint8_t), result_size, outfile);
  fclose(outfile);
  return 1;
}

#endif /* HELPERS_H_ */
