# Benchmarking Sandboxed Libwebp

## Setup
See [setup_test_environment.sh](./setup_test_environment.sh) with how to get the required tools.

## Testing Environment
We have two environments we are testing on:
1. Debian 6.1.38 with an AMD EPYC 7713P 64-Core Processor, 128 threads, 1TB of RAM
2. Ubuntu 22.04 Virtual Machine, Windows 11 Host, with an Intel i7-9850H 6-core Processor 12 threads, 4 GB RAM allocated.

## Tests
We are currently focusing on lossy webp with no alpha and no animation.

Because our goal is to sandbox libwebp in Firefox, we are using the same incremental decoder API inside of [decode_webp.c](./decode_webp.c) and measuring its performance.

### Building
We have four build scripts: [build_native.sh](../build_native.sh), [build_nativesimd.sh](../build_nativesimd.sh), [build_wasm.sh](../build_wasm.sh), and [build_wasmsimd.sh](../build_wasmsimd.sh). These are used to build libwebp.

We have a [Makefile](./Makefile) in this directory that builds the different versions of [decode_webp.c](./decode_webp.c) by linking to the respective libwebp library version.

### Test Images

We have [images](images/) that we use to compare performance. These images are meant to be representative of content web users may encounter.

Images (from [Google](https://developers.google.com/speed/webp/gallery1))
- [images/lossy/1.webp](images/lossy/1.webp): 550x368 px mountain picture, 30320 bytes.
- [images/lossy/2.webp](images/lossy/2.webp): 550x404 px kayaking picture, 60600 bytes.
- [images/lossy/3.webp](images/lossy/3.webp): 1280x720 px park run video frame, 203138 bytes.
- [images/lossy/4.webp](images/lossy/4.webp): 1024x772 px flowering cherry tree, 176972 bytes.
- [images/lossy/5.webp](images/lossy/5.webp): 1024x752 px fire spitter, 82698 bytes.

Images from around the web:
- [CVRT_1457_Starry_Night_HP_background.webp](images/lossy/6.webp): 3000x1996 px Starry Night, 473868 bytes. [ShutterStock details](https://www.shutterstock.com/image-photo/night-sky-filled-stars-including-big-2357121327)
- [test.webp](images/lossy/7.webp): 128x128 px Mountain image, 4928 bytes. From [libwebp-test-data repo](https://chromium.googlesource.com/webm/libwebp-test-data/+/refs/heads/main/test.webp).

## Libwebp Process

Libwebp takes a compressed webp file and performs two key operations:
1. Bitstream Parsing (BP)
2. Image Reconstruction (IR)

The bitstream parsing decodes the prediction algorithm to use and the residual information from the compressed bitstream. The image reconstruction takes the prediction choice and residuals and produces the YUVA output.

## Sandboxing Process
At the moment we are just using the wasm-sandbox, but later we will rely on RLBox's guarantees as well.

We take the libwebp source code, and compile it to WASM. Then we take this WASM and compile back to C using WABT's wasm2c. This final C code is compiled to native code.

## Versions of libwebp we Are Comparing

We are running 6 different versions of [decode_webp.c](./decode_webp.c).

1. Native Unchanged: This is the upstream version of libwebp, compiled once and not again. We disable the inclusion of SIMD instructions by passing `--disable-sse2` and `--disable-sse4.1`.
2. Native SIMD Unchanged: This is the upstream version of libwebp, compiled once and not again. This incorporates the runtime SIMD instructions by having `--enable-sse2` and `--enable-sse4`.
3. Native: This version does not have SIMD instructions, and is compiled with each code change to see what impact our change has to the library.
4. Native SIMD: This version has SIMD instructions, and is compiled with each code change to see what impact our change has to the library.
5. WASM: Compiled to WASM with wasi-clang. No SIMD instructions.
6. WAMSIMD: Compiled to WASM with wasi-clang with `-msimd128` and SIMD-everywhere intrinsics transformation.

## Positive Results

With our test environment correctly building libwebp, here we note the changes we have made and their associated positive performance impact. We denote in the title whether the change primarily affects Bitstream Parsing (BP) or Image Reconstruction (IR).

The title has the macro to pass in to enable this optimization.

### Enabling SIMD Everywhere (SIMDe) (IR): WEBP_USE_SIMDE
With this [WABT pull request](https://github.com/WebAssembly/wabt/pull/2119), we can go from WASM to C by relying on SIMD Everywhere (SIMDe).

SIMDe is a library that translates SIMD intrinsics across architectures. We primarily use it in wasm2c to convert WASMSIMD instructions to the native architecture we are compiling the C code to. We also use it when compiling to WASM to reuse intrinsics that exist in the underlying library. For libwebp, we use SIMDe in both ways.

Our primary change to libwebp to enable SIMDe is to add a new `WEBP_USE_SIMDE` definition in the code and use it when compiling the WASMSIMD library. This definitions changes the intrinsic `#include` files to use SIMDe's include files, and adjusts the logic around SSE2 and SSE4.1 checking to enable these code paths for WASMSIMD. We also pass in `SIMDE_ENABLE_NATIVE_ALIASES` to not have to rewrite each intrinsic call. Passing in `-msimd128` to the compiler ensures that WASMSIMD opcodes are emitted. We also need to update the libwebp CPU check to return success on any runtime check to determine whether intrinsics can be used.

#### Alternatives
- We only rely on the SSE2 and SSE4.1 intrinsics, but libwebp also has intrinsics for MIPS and ARM. This requires some further testing.
- We could rely on only `-msimd128` when compiling, but the autovectorization is not able to do as well as SSE provided intrinsics.

### Bitreader Bit Size (BP): WEBP_WASM_BITSIZE
When bitstream parsing, libwebp will cache some number of bytes in the VP8BitReader field `value_`. This field is made to be the size of one register, which is architecture dependent. For architectures that it is not familiar with, it defaults to `uint32_t`. In our case, this is failing to capture the 64-bit size registers of WASM, leading to unnecessary memcpys to load into `value_`.

Inside of `src/utils/bit_reader_utils.h` we add a new condition to ensure the BITS definition is set to use its 64-bit representation on WASM.

### USE_GENERIC_TREE (BP): WEBP_WASM_HARDCODED_TREE
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

### Removing indirect function calls in libwebp (IR): WEBP_WASM_DIRECT_FUNCTION_CALL
Libwebp does runtime checks to determine whether SIMD functions will work on the machine it is running on. It then updates global function pointers that are called at image reconstruction time. While this is okay for native compilation, this pattern in WASM leads to using `CALL_INDIRECT`s, which is an extra memory read to get the global function pointer then an extra bounds check to ensure the offset is within memory. This overhead has a significant impact during image reconstruction as each call to a SIMD-enhanced function eats this cost.

What we do is avoid the indirect call when compiling to WASM by not relying on the runtime checks and instead using the SIMD-enhanced functions directly. This has the benefit of helping both the WASM and WASMSIMD versions. When compiling from the wasm2c code back to Native, the SIMDe can handle the case of the host not adequately supporting a particular SIMD instruction set.

We perform three changes to enable direct function calling:
1. Inside of the file that does the indirect call, we use a macro to rename the indirect function name to the target function. For example, in [src/dec/frame_dec.c](../src/dec/frame_dec.c), we have `#define VP8Transform TransformTwo_C`.
2. To make the function we're directly calling accessible, we need to remove the `static` modifier in the file where the function exists. Using the same example, [src/dsp/dec.c](../src/dsp/dec.c) wraps the `static` in a `#if !defined(WEBP_WASM_DIRECT_FUNCTION_CALL)` wrapper.
3. Finally, we need to define the function in a location accessible to where we renamed the indirect call to the target call in number 1. For this, we include the function definition at the bottom of [src/dsp/dsp.h](../src/dsp/dsp.h). Behind the feature flag, we include, for example, `void TransformTwo_C(const int16_t* in, uint8_t* dst, int do_two);`. 

**This approach is something we'll also need to apply for Lossless and Alpha decoding.**

#### Other issues
Removing `static` from function definitions makes them visible outside the defined file. Some encoding functions have the same name as their decoding counterpart, and `src/dsp/dsp.h` is used in both decoding and encoding functions. Therefore we rename the encoding function with the same by prepending `enc_` to it.

### VP8BitReader Aliasing (BP): WEBP_WASM_ALIAS_BITREADER
Libwebp has some function calls with `WEBP_RESTRICT` modifiers on variable names. Inside of [src/dsp/dsp.h](../src/dsp/dsp.h) this is defined to use the `restrict` type qualifier if the compiler supports it (for GNUC use `__restrict__` and on MSC use `__restrict`). The `restrict` qualifier tells the compiler that the pointer is the only pointer referencing an object, so there is no concern about potential race conditions we do not need to load the pointer again. We primarily focus on the `WEBP_RESTRICT` modifier for pointers to VP8BitReader objects, and this is the key structure used when parsing the bitstream.

When compiling to WASM, the `WEBP_RESTRICT` qualifier is indeed used when producing the WASM output, but that information is lost when converted to C and subsequently to native. This means that we have an extra load in our final output each time we try to read from VP8BitReader. **A research question here is what would be the best way to communicate the `restrict` qualifier in our pipeline?**

What we do to manually mimic what `WEBP_RESTRICT` does is rewrite libwebp to not load the pointer on each function call by aliasing the VP8BitReader object's variables to local variables, and then updating the VP8BitReader object at the end with the local variables. This also required making new versions of VP8GetBit and friends to take in the aliased parameters. All this rewriting leads to changes in Native output as well, as we would like to avoid redundant code as much as possible.

The aliasing had mixed results, and in this section we talk about the wins. Later in the [Negative Results Section](#aliasing), we talk about where this did not work.

#### VP8ParseIntraModeRow: WEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW
VP8ParseIntraModeRow lives in [src/dec/tree_dec.c](../src/dec/tree_dec.c). This function is parsing the bitstream to recover the Intra mode to use for each macroblock. For each macroblock in a row, it calls ParseIntraMode which recovers the either 4x4 or 16x16 Luma Intra mode, and the 16x16 Chroma Intra mode used. It directly calls `VP8GetBit`, which during compilation is inlined in ParseIntraMode, which itself gets inlined inside VP8ParseIntraModeRow.

Aliasing this function consists of writing the following wrapper in VP8ParseIntraModeRow:
```c
int VP8ParseIntraModeRow(VP8BitReader* const br, VP8Decoder* const dec) {
  int mb_x;
  // Turn the values into local variables
  bit_t value_ = br->value_;
  range_t range_ = br->range_;
  int bits_ = br->bits_;
  const uint8_t* buf_ = br->buf_;
  const uint8_t* buf_end_ = br->buf_end_;
  const uint8_t* buf_max_ = br->buf_max_;
  int eof_ = br->eof_;
  //
  for (mb_x = 0; mb_x < dec->mb_w_; ++mb_x) {
    ParseIntraMode(br, dec, mb_x);
  }
  // Move the local variables back into the object
  br->value_ = value_;
  br->range_ = range_;
  br->bits_ = bits_;
  br->buf_ = buf_;
  br->buf_end_ = buf_end_;
  br->buf_max_ = buf_max_;
  br->eof_ = eof_;
  //
  return !dec->br_.eof_;
}
```

We also manually modify inline ParseIntraMode into VP8ParseIntraModeRow, and create a new VP8GetBit function that takes in aliased parameters rather than a VP8BitReader object. Because this new function is being inlined, it is not a concern whether we are stressing the ABI to push registers onto the stack because it all remains local.

This is the modified VP8GetBit function that does not take in a VP8BitReader object:
```c
static WEBP_INLINE int VP8GetBit_alias(bit_t *value, range_t *range, int *bits, const uint8_t** buf, const uint8_t** buf_end, const uint8_t** buf_max, int* eof,
                                 int prob) {
  // Don't move this declaration! It makes a big speed difference to store
  // 'range' *before* calling VP8LoadNewBytes(), even if this function doesn't
  // alter br->range_ value.
  range_t range_start = *range;
  if (*bits < 0) {
    assert(*buf != NULL);
    // Read 'BITS' bits at a time if possible.
    if (*buf < *buf_max) {
      // convert memory type to register type (with some zero'ing!)
      bit_t bits_start;
      lbit_t in_bits;
      memcpy(&in_bits, *buf, sizeof(in_bits));
      *buf += BITS >> 3;
      bits_start = __builtin_bswap64(in_bits);
      bits_start >>= 64 - BITS;
      *value = bits_start | (*value << BITS);
      *bits += BITS;
    } else {
      if (*buf < *buf_end) {
        *bits += 8;
        *value = (bit_t)(*(*buf)++) | (*value << 8);
      } else if (!*eof) {
        *value <<= 8;
        *bits += 8;
        *eof = 1;
      } else {
        *bits = 0;  // This is to avoid undefined behavior with shifts.
      }
    }
  }
  {
    const int pos = *bits;
    const range_t split = (range_start * prob) >> 8;
    const range_t value_start = (range_t)(*value >> pos);
    const int bit = (value_start > split);
    if (bit) {
      range_start -= split;
      *value -= (bit_t)(split + 1) << pos;
    } else {
      range_start = split + 1;
    }
    {
      const int shift = 24 ^ __builtin_clz(range_start);
      range_start <<= shift;
      *bits -= shift;
    }
    *range = range_start - 1;
    return bit;
  }
}
```
It also incorporates the dependent functions VP8LoadNewBytes and VP8LoadFinalBytes and chooses some defaults around `BIT_SIZE`.


### WABT Changes
Here we describe some not-yet-upstream features in WABT that we used to improve performance. These are not changes to libwebp, but changes to WABT itself that improves our stance.

#### Removing Forced Reads
WABT Pull Request [2357](https://github.com/WebAssembly/wabt/pull/2357).

At the moment, all reads in WASM are required to execute. Wasm2c enforces this by inserting inline asm that forces the result of the load to be live, even if it is never used. This pull request removes the forced read so that if a read value is never used, then it can be optimized out.

The discussion around the PR centers around whether it makes sense to include this WASM spec-non-compliance within the output. This PR is currently on hold, pending a review from the WASM spec designers.

The optimization here comes from the fact that an extra load is removed for each access.

#### GS/FS registers via Segue
WABT PULL Request [2395](https://github.com/WebAssembly/wabt/pull/2395).

This pull requests "uses the x86 segment register to perform memory accesses to WASM's linear heap." Instead of doing a load for each time we need to access the linear memory, the pointer will live in the gs/fs register throughout the lifetime of the function.

At the moment, this only works on Linux x86 machines, which is limiting the adoption of the PR into WABT.

## Negative Results

There are some changes we tried that had a negative impact on performance, which we log here.

### Aliasing

We describe aliasing [above](#vp8bitreader-aliasing-bp). We found that in some cases, aliasing was not sufficient to recover performance, and led to a degradation of performance across all versions.

#### VP8ParseProba
##### VP8ParseProba Background
VP8ParseProba is in [src/dec/tree_dec.c](../src/dec/tree_dec.c). This function is called to initialize the probability table used in VP8's entropy encoding. If a bit in the bitstream is 0, then it will parse the byte-sized probability from the bitstream, but if it is 1 then it will use one of the presets.

The challenge with this function is that it relies on more than just VP8GetBit to parse the bitstream; we also have VP8Get and VP8GetValue.

VP8GetValue is a wrapper around VP8GetBit that is defined in [src/utils/bit_reader_utils.c](../src/utils/bit_reader_utils.c) that takes in `bits` parameter which is the length to read from the bitstream. It calls VP8GetBit `bits` times with equal (0x80) probability.

VP8Get is a wrapper around VP8GetValue with `bits` set to 1, defined in [src/utils/bit_reader_utils.h](../src/utils/bit_reader_utils.h). **It's unclear why this is called instead of VP8GetBit**.

The entire bitstream reader has a debugging feature where you can pass in a Label to emit to see where the bitstream is getting parsed. You can enable this in [bit_reader_utils.h](../src/utils/bit_reader_utils.h) by setting `BITTRACE` to 1 or 2.
- VP8Get, VP8GetValue, and VP8GetSignedValue are only ever called with the label "global-header"
- VP8GetBit is called with the labels: segments, skip, block-size, pred-modes, pred-modes-uv, global-header, and coeffs
- VP8GetBitAlt and VP8GetSigned are only called with the label "coeffs"

##### VP8ParseProba Aliasing
We tried to alias this function by only calling the modified version of VP8GetBit we made for VP8ParseIntraMode, and removing the wrapper functions VP8Get and VP8GetValue with a direct call to VP8GetBit with the appropriate parameters.

Unfortunately, our approach led to a performance degradation across all versions.

#### VP8DecodeMB
VP8DecodeMB is in [src/dec/vp8_dec.c](../src/dec/vp8_dec.c). This is a hot function that decodes the residual information inside of macroblocks. It inlines the function ParseResiduals, which calls the indirect function GetCoeffs.

We aliased the parameters to GetCoeffs from ParseResiduals, and I think the came from the fact that we were aliasing in the wrong place. It's worth revisiting this aliasing because it is an important function to the bitstream decoding.

## Ablation Study

The ablation study measures the performance on a machine with all the positive results above.

First, run the special shell that will fix the CPU frequency and taskset our evaluation to that CPU, then run the ablation script. The results will be stored in `test_files/combined_results.csv`.

## Lossless Changes

### VP8L_USE_FAST_LOAD

When libwebp is built for ARM or x86 (but not MIPS, the other major supported target), this is enabled for use in the function `src/utils/bit_reader_utils.c:VP8LDoFillBitWindow`.

```c
#if defined(__arm__) || defined(_M_ARM) || WEBP_AARCH64 || \
    defined(__i386__) || defined(_M_IX86) || \
    defined(__x86_64__) || defined(_M_X64)
#define VP8L_USE_FAST_LOAD
#endif

#define VP8L_LOG8_WBITS 4  // Number of bytes needed to store VP8L_WBITS bits.


#define VP8L_LBITS 64  // Number of bits prefetched (= bit-size of vp8l_val_t).
#define VP8L_WBITS 32  // Minimum number of bytes ready after VP8LFillBitWindow.


typedef uint64_t vp8l_val_t;  // right now, this bit-reader can only use 64bit.


typedef struct {
  vp8l_val_t     val_;        // pre-fetched bits
  const uint8_t* buf_;        // input byte buffer
  size_t         len_;        // buffer length
  size_t         pos_;        // byte position in buf_
  int            bit_pos_;    // current bit-reading position in val_
  int            eos_;        // true if a bit was read past the end of buffer
} VP8LBitReader;


#if defined(WORDS_BIGENDIAN)
#define HToLE32 BSwap32
#define HToLE16 BSwap16
#else
#define HToLE32(x) (x)
#define HToLE16(x) (x)
#endif

// memcpy() is the safe way of moving potentially unaligned 32b memory.
static WEBP_INLINE uint32_t WebPMemToUint32(const uint8_t* const ptr) {
  uint32_t A;
  memcpy(&A, ptr, sizeof(A));
  return A;
}

static void ShiftBytes(VP8LBitReader* const br) {
  while (br->bit_pos_ >= 8 && br->pos_ < br->len_) {
    br->val_ >>= 8;
    br->val_ |= ((vp8l_val_t)br->buf_[br->pos_]) << (VP8L_LBITS - 8);
    ++br->pos_;
    br->bit_pos_ -= 8;
  }
  if (VP8LIsEndOfStream(br)) {
    VP8LSetEndOfStream(br);
  }
}

void VP8LDoFillBitWindow(VP8LBitReader* const br) {
  assert(br->bit_pos_ >= VP8L_WBITS);
#if defined(VP8L_USE_FAST_LOAD)
  if (br->pos_ + sizeof(br->val_) < br->len_) {
    br->val_ >>= VP8L_WBITS;
    br->bit_pos_ -= VP8L_WBITS;
    br->val_ |= (vp8l_val_t)HToLE32(WebPMemToUint32(br->buf_ + br->pos_)) <<
                (VP8L_LBITS - VP8L_WBITS);
    br->pos_ += VP8L_LOG8_WBITS;
    return;
  }
#endif
  ShiftBytes(br);       // Slow path.
}

// Advances the read buffer by 4 bytes to make room for reading next 32 bits.
// Speed critical, but infrequent part of the code can be non-inlined.
extern void VP8LDoFillBitWindow(VP8LBitReader* const br);
static WEBP_INLINE void VP8LFillBitWindow(VP8LBitReader* const br) {
  if (br->bit_pos_ >= VP8L_WBITS) VP8LDoFillBitWindow(br);
}

```

According to the above code snippet, each call to `VP8LFillBitWindow` should be 4x faster because we do a single memcpy to get the pointer data as opposed to looping over at least 4 times to copy over values.

The function `VP8LFillBitWindow` is called in 6 different places all in `src/dec/vp8l_dec.c`:
1. Once in ReadHuffmanCodeLengths in a loop
2. Twice in DecodeAlphaData, also in a loop.
3. Three times in DecodeImageData, all three in a loop.

We can enable it by passing in `-DVP8L_USE_FAST_LOAD` when compiling