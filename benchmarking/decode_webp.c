#include "decode_webp.h"

// Uncommenting this out saves the image to out.pam
//#define OUTPUT_IMAGE

// Use the incremental decoder
// Firefox uses the incremental decoder: https://searchfox.org/mozilla-central/source/image/decoders/nsWebPDecoder.cpp 
//#define INCREMENTAL 


#ifdef OUTPUT_IMAGE
#include <stdio.h>
#endif

extern void* VP8GetCPUInfo;   // opaque forward declaration.

#ifdef OUTPUT_IMAGE
int WebPWritePPMPAM(WebPDecoderConfig *config, uint8_t** result, size_t* result_size, int alpha) {
  const WebPDecBuffer* const buffer = &(config->output);
  const uint32_t width = buffer->width;
  const uint32_t height = buffer->height;
  const uint8_t* row = buffer->u.RGBA.rgba;
  const int stride = buffer->u.RGBA.stride;
  const size_t bytes_per_px = alpha ? 4 : 3;
  uint32_t y;

  char* header = malloc(128);
  if (header == NULL) return 0;
  memset(header, 0, 128);
  if (alpha) {
    snprintf(header, 128, "P7\nWIDTH %u\nHEIGHT %u\nDEPTH 4\nMAXVAL 255\n"
                    "TUPLTYPE RGB_ALPHA\nENDHDR\n", width, height);
  } else {
    snprintf(header, 30, "P6\n%u %u\n255\n", width, height);
  }
  size_t header_size = strlen(header);

  // Allocate the size of the result
  *result_size = height*width*bytes_per_px + header_size;
  *result = malloc(*result_size);

  if (row == NULL) return 0;
  if (*result == NULL) return 0;

  memcpy(*result, header, header_size);
  for (y = 0; y < height; ++y) {
    memcpy(&(*result)[header_size + y*stride], row, stride);
    row += stride;
  }
  free(header);
  return 1;
}
#endif



int DecodeWebpImage(const uint8_t* data, size_t data_size, int iterations, uint8_t** result, size_t* result_size) {
  int ok = 0;
  VP8StatusCode status;
  WebPDecoderConfig config;
  WebPDecBuffer* const output_buffer = &config.output;
  WebPBitstreamFeatures* const bitstream = &config.input;
  if (!WebPInitDecoderConfig(&config)){
    return -1;
  }
  // Used for writing PAM
  // Firefox has the following snippet of code:
  // https://searchfox.org/mozilla-central/rev/1e743db12971e365d1f8fc04c0c52ed55c01494b/image/decoders/nsWebPDecoder.cpp#230-243
  //   case SurfaceFormat::B8G8R8A8:
  //     mBuffer.colorspace = MODE_BGRA;
  //     break;
  //   case SurfaceFormat::A8R8G8B8:
  //     mBuffer.colorspace = MODE_ARGB;
  //     break;
  //   case SurfaceFormat::R8G8B8A8:
  //     mBuffer.colorspace = MODE_RGBA;
  //     break;
  //   default:
  output_buffer->colorspace = MODE_RGBA; // Default to RGBA for now

#ifdef INCREMENTAL
  for(int i = 0; i < iterations; i++){
    // This line parses the header to get features about our WebP
    WebPIDecoder* const idec = WebPIDecode(data, data_size, &config);
    if (idec == NULL) {
      return -1;
    } else {
      // This decodes the actual WebP
      status = WebPIUpdate(idec, data, data_size);
      // Clean up the decoder
      WebPIDelete(idec);
    }
  }
#else
  for(int i = 0; i < iterations; i++) {
    status = WebPDecode(data, data_size, &config);
  }
#endif

  if (status == VP8_STATUS_OK) ok = 1;

#ifdef OUTPUT_IMAGE
  // Firefox calls WebPIDecGetRGB to get the values to write out, but this is a RGBA output
  ok = WebPWritePPMPAM(&config, result, result_size, 1);
#endif

  WebPFreeDecBuffer(output_buffer);

  return ok ? 0 : -1;
}
