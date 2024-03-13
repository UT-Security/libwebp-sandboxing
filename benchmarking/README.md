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

The bitstream parsing decodes the prediction algorithm to use and the residual information from the compressed bitstream. The image reconstruction takes the prediction choice and residuals and produces the YUVA output.

## Sandboxing Process
At the moment we are using the wasm-sandbox, but later we will rely on RLBox's guarantees as well.

We take the libwebp source code, and compile it to WASM. Then we take this WASM and compile back to C using WABT's wasm2c. This final C code is compiled to native code.

## Positive Results

With our test environment correctly building libwebp, here we note the changes we've made and their associated positive performance impact.


### Enabling SIMD-everywhere

With this [WABT pull request](https://github.com/WebAssembly/wabt/pull/2119), we can go from WASM to C by relying on SIMD-everywhere.

We perform a few changes in libwebp to enable this.

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


