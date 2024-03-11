# Benchmarking Sandboxed Libwebp

## Setup
See [setup_test_environment.sh](./setup_test_environment.sh) with how to get the proper tools.


## Tests

We are currently focusing on lossy webp with no alpha and no animation. 

Because our goal is to sandbox libwebp in Firefox, we are using the same incremental decoder API inside of [decode_webp.c](./decode_webp.c) and measuring its performance.

## Libwebp Process

Libwebp takes a compressed webp file and performs two key operations:

1. Bitstream parsing
2. Image reconstruction

The bitstream parsing recovers the prediction algorithm to use and the residual information from the compressed bitstream. The image reconstruction takes the prediction choice and residuals and produces the YUVA output. 



## Positive Results

With our test environment correctly building libwebp, here we note the changes we've made and the performance impact it's had.


### Enabling SIMD-everywhere

### Removing indirect function calls in libwebp

### USE_GENERIC_TREE

### VP8BitReader Aliasing

#### VP8ParseIntraModeRow

### WABT Changes

#### Removing Forced Reads

#### GS/FS registers via Segue


## Negative Results

There are some changes we tried that hurt performance, which we log here.

### Aliasing

#### VP8ParseProba

#### VP8DecodeMB


