if [ "$WORK_DIR" == "" ]; then
	WORK_DIR=/home/wrv/research/wasmperf
fi
if [ "$WASI_SDK_PATH" == "" ]; then
    WASI_SDK_PATH=${WORK_DIR}/wasi-sdk-21.0
fi

echo Before: "$WASMSIMD_COMPILER_DEFINES"

if [ "$WASMSIMD_COMPILER_DEFINES" == "" ]; then
	# Default to all existing optimizations
	WASMSIMD_COMPILER_DEFINES=""
	# Enable 64-bit registers in WASM
	WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DBITS=56"
	# Use the hardcoded tree approach
	WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
	# Avoid indirect function calls by renaming functions
	WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL -DWEBP_WASMSIMD_DIRECT_FUNCTION_CALL"
	# Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
	#WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
	# Use VP8L Fast Loads to load 32 bits at time
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
fi

echo After: "$WASMSIMD_COMPILER_DEFINES"
echo "Building WASMSIMD version of libwebp"
curprefix=$(pwd)/libwebp_wasmsimd_emscripten
emscriptensimd=$(pwd)/benchmarking

echo "Using $emscriptensimd directory"

mkdir -p ${curprefix}

cd ${curprefix}



# If we're trying to recompile without changing the code, but changing
# only the feature flags, it won't work, so we clean it out :/
make clean

CFLAGS="-O2 ${WASMSIMD_COMPILER_DEFINES} -D_WASI_EMULATED_SIGNAL \
	-msimd128 -D__SSE2__ -D__SSE4_1__ -D__SSE__ -D__SSSE3__ -D__SSE3__ -DWEBP_USE_EMSCRIPTEN_SIMD -I${emscriptensimd}" \
	LDFLAGS="-L${WASI_SDK_PATH}/share/wasi-sysroot/lib \
		-Wl,--no-entry \
		-Wl,--export-all \
		-Wl,--growable-table $*" \
	LD=${WASI_SDK_PATH}/bin/wasm-ld \
	CC=${WASI_SDK_PATH}/bin/clang \
	AR=${WASI_SDK_PATH}/bin/ar \
	LIBS=-lwasi-emulated-signal \
	STRIP=${WASI_SDK_PATH}/bin/strip \
	RANLIB=${WASI_SDK_PATH}/bin/ranlib \
	../configure \
	--with-sysroot=${WASI_SDK_PATH}/share/wasi-sysroot \
	--host=wasm64 \
	--prefix=${curprefix} \
	--disable-libwebpdemux \
	--disable-libwebpmux \
	--disable-libwebpdecoder \
	--disable-png \
	--disable-tiff \
	--disable-jpeg \
	--disable-threading \
	--enable-sse4.1 \
	--enable-sse2

# Apply patch to enable SSE4.1 and SSE2
sed -i 's|/\* #undef WEBP_HAVE_SSE41 \*/|#define WEBP_HAVE_SSE41 1|' src/webp/config.h
sed -i 's|/\* #undef WEBP_HAVE_SSE2 \*/|#define WEBP_HAVE_SSE2 1|' src/webp/config.h


make
make install

cd ..