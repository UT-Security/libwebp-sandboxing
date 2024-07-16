// Must be in the very end as it uses other SSE2 intrinsics
static __inline__ __m128i __attribute__((__always_inline__, __nodebug__))
_mm_sad_epu8(__m128i __a, __m128i __b)
{
  v128_t __diff = wasm_v128_or(wasm_u8x16_sub_saturate((v128_t)__a, (v128_t)__b),
                                         wasm_u8x16_sub_saturate((v128_t)__a, (v128_t)__b));
  __diff = wasm_i16x8_add(wasm_u16x8_shr(__diff, 8),
                         wasm_v128_and(__diff, wasm_i16x8_splat(0x00FF)));
  __diff = wasm_i16x8_add(__diff, wasm_i32x4_shl(__diff, 16));
  __diff = wasm_i16x8_add(__diff, wasm_i64x2_shl(__diff, 32));
  return (__m128i) wasm_u64x2_shr(__diff, 48);
}