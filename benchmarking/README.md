# Benchmarking Sandboxed Libwebp

## Setup
See [setup_test_environment.sh](./setup_test_environment.sh) with how to get the proper tools.

## Environment

We have two environments at the moment we're testing on:
1. Debian 6.1.38 with an AMD EPYC 7713P 64-Core Processor, 128 threads, 1TB of RAM
2. Ubuntu 22.04 Virtual Machine, Windows 11 Host, with an Intel i7-9850H 6-core Processor 12 threads, 4 GB RAM allocated.


## Tests

We are currently focusing on lossy webp with no alpha and no animation. 

Because our goal is to sandbox libwebp in Firefox, we are using the same incremental decoder API inside of [decode_webp.c](./decode_webp.c) and measuring its performance.

We have four build scripts: [build_native.sh](../build_native.sh), [build_nativesimd.sh](../build_nativesimd.sh), [build_wasm.sh](../build_wasm.sh), and [build_wasmsimd.sh](../build_wasmsimd.sh).

## Libwebp Process

Libwebp takes a compressed webp file and performs two key operations:
1. Bitstream parsing
2. Image reconstruction

The bitstream parsing decodes the prediction algorithm to use and the residual information from the compressed bitstream. The image reconstruction takes the prediction choice and residuals and produces the YUVA output.

## Sandboxing Process
At the moment we are just using the wasm-sandbox, but later we will rely on RLBox's guarantees as well.

We take the libwebp source code, and compile it to WASM. Then we take this WASM and compile back to C using WABT's wasm2c. This final C code is compiled to native code.

## Versions of libwebp we're Comparing

We are running 6 different versions of [decode_webp.c](./decode_webp.c).

1. Native Unchanged: This is the upstream version of libwebp, compiled once and not again. We disable the inclusion of SIMD instructions by passing `--disable-sse2` and `--disable-sse4.1`.
2. Native SIMD Unchanged: This is the upstream version of libwebp, compiled once and not again. This incorporates the runtime SIMD instructions by having `--enable-sse2` and `--enable-sse4`.
3. Native: This version does not have SIMD instructions, and is compiled with each code change to see what impact our change has to the library.
4. Native SIMD: This version has SIMD instructions, and is compiled with each code change to see what impact our change has to the library.
5. WASM: Compiled to WASM with wasi-clang. No SIMD instructions.
6. WAMSIMD: Compiled to WASM with wasi-clang with `-msimd128` and SIMD-everywhere intrinsics transformation.

## Positive Results

With our test environment correctly building libwebp, here we note the changes we've made and their associated positive performance impact.

We also denote in the title whether the change primarily affects Bitstream Parsing (BP) or Image Reconstruction (IR).

### Enabling SIMD-everywhere (IR)

With this [WABT pull request](https://github.com/WebAssembly/wabt/pull/2119), we can go from WASM to C by relying on SIMD-everywhere.

SIMD-everywhere is a library that translates SIMD intrinsics across architectures. We primarily use it in wasm2c to convert WASMSIMD instructions to the native architecture we're compiling the C code to. We also use it when compiling to WASM to reuse intrinsics that exist in the underlying library. For libwebp, we use SIMDe in both ways.

Our primary change to libwebp to enable SIMDe is to add a new `WEBP_USE_SIMDE` definition in the code and use it when compiling the WASMSIMD library. This definitions changes the intrinsic `#include` files to use SIMD-everywhere's include files, and adjusts the logic around SSE2 and SSE4.1 checking to enable these code paths for WASMSIMD. We also pass in `SIMDE_ENABLE_NATIVE_ALIASES` to not have to rewrite each intrinsic call. Passing in `-msimd128` to the compiler ensures that WASMSIMD opcodes are emitted. We also need to update the libwebp CPU check to return success on any runtime check to determine whether intrinsics can be used.

#### Alternatives
- We only rely on the SSE2 and SSE4.1 intrinsics, but libwebp also has intrinsics for MIPS and ARM. This requires some further testing.
- We could rely on only `-msimd128` when compiling, but the autovectorization isn't able to do as well as SSE provided intrinsics.


### Bitreader Bit Size (BP)
When bitstream parsing, libwebp will cache some number of bytes in the VP8BitReader field `value_`. This field is made to be the size of one register, which is architecture dependent. For architectures that it's not familiar with, it defaults to `uint32_t`. In our case, this is failing to capture the 64-bit size registers of WASM, leading to unnecessary memcpys to load into `value_`. 

Inside of `src/utils/bit_reader_utils.h` we add a new condition to ensure the BITS definition is set to use its 64-bit representation on WASM.

### USE_GENERIC_TREE (BP)
Inside of [src/dec/tree_dec.c](../src/dec/tree_dec.c) we have the following snippet at the top:
```c
#if !defined(USE_GENERIC_TREE)
#if !defined(__arm__) && !defined(_M_ARM) && !WEBP_AARCH64
// using a table is ~1-2% slower on ARM. Prefer the coded-tree approach then.
#define USE_GENERIC_TREE 1   // ALTERNATE_CODE
#else
#define USE_GENERIC_TREE 0
#endif
#endif  // USE_GENERIC_TREE
```

When `USE_GENERIC_TREE` is set to to 1, the intra prediction parsing will read a bit in a loop and use that to index into an array until a negative value (the prediction mode) is found in the array. When `USE_GENERIC_TREE` is set to 0, then the parsing will traverse a hard-coded tree to recover the prediction mode.

According to how `USE_GENERIC_TREE` is defined, it is slower on ARM platforms, but works well on all others. We found in our testing on the AMD server machine that hard-coded tree (aka `USE_GENERIC_TREE` set to 0) is faster on all platforms. At the moment, we just enable it for WASM.

### Removing indirect function calls in libwebp (IR)
Libwebp does runtime checks to determine whether SIMD functions will work on the machine it's running on. It then updates global function pointers that are called at image reconstruction time. While this is okay for native compilation, this pattern in WASM leads to using `CALL_INDIRECTs` which is an extra memory read to get the global function pointer then an extra bounds check to ensure the offset is within memory. This extra overhead has a significant impact during image reconstruction as each call to a SIMD-enhanced function eats this cost.

What we do is avoid the indirect call when compiling to WASM by not relying on the runtime checks and instead using the SIMD-enhanced functions directly. This has the benefit of helping both the WASM and WASMSIMD versions. When compiling from the wasm2c code back to Native, the SIMD-everywhere can handle the case of the host not adequately supporting a particular SIMD instruction set.



### VP8BitReader Aliasing (BP)

#### VP8ParseIntraModeRow

### WABT Changes 

#### Removing Forced Reads

#### GS/FS registers via Segue


## Negative Results

There are some changes we tried that hurt performance, which we log here.

### Aliasing

#### VP8ParseProba

#### VP8DecodeMB


