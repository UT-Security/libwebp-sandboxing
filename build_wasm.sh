if [ "$WORK_DIR" == "" ]; then
	WORK_DIR=/home/wrv/research/wasmperf
fi
if [ "$WASI_SDK_PATH" == "" ]; then
    WASI_SDK_PATH=${WORK_DIR}/wasi-sdk-21.0
fi

echo Before: "$WASM_COMPILER_DEFINES"

if [ "$WASM_COMPILER_DEFINES" == "" ]; then
	# Default to all existing optimizations
	WASM_COMPILER_DEFINES=""
	# Enable 64-bit registers in WASM
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=56"
	# Use the hardcoded tree approach
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
	# Avoid indirect function calls by renaming functions
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
	# Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
	# Use VP8L Fast Loads to load 32 bits at time
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
	# Enable direct calls in VP8L
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
fi

echo After: "$WASM_COMPILER_DEFINES"
echo "Building WASM version of libwebp"
curprefix=$(pwd)/libwebp_wasm

mkdir -p ${curprefix}

cd ${curprefix}

# If we're trying to recompile without changing the code, but changing
# only the feature flags, it won't work, so we clean it out :/
make clean

CFLAGS="-O2 ${WASM_COMPILER_DEFINES} -D_WASI_EMULATED_SIGNAL -msimd128" \
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
	--disable-sse4.1 \
	--disable-sse2

make
make install

cd ..