#ifndef DECODE_WEBP_H_
#define DECODE_WEBP_H_

#include <stdlib.h>
#include <string.h>
#include <webp/decode.h>
#include <webp/types.h>

int DecodeWebpImage(const uint8_t* data, size_t data_size, int iterations, uint8_t** result, size_t* result_size);

#endif /* DECODE_WEBP_H_ */
