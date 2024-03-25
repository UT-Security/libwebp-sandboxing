if [ "$WORK_DIR" == "" ]; then
	WORK_DIR=/home/wrv/research/wasmperf
fi
if [ "$WASI_SDK_PATH" == "" ]; then
    WASI_SDK_PATH=${WORK_DIR}/wasi-sdk-21.0
fi
if [ "$SIMDE_PATH" == "" ]; then
    SIMDE_PATH=${WORK_DIR}/simde-0.7.6
fi
if [ "$WASM_COMPILER_DEFINES" == "" ]; then
    WASM_COMPILER_DEFINES="-DWEBP_WASM_GENERIC_TREE -DWEBP_WASM_BITSIZE"
fi

make clean > /dev/null
echo "Building WASMSIMD version of libwebp"
curprefix=$(pwd)/libwebp_wasmsimd

mkdir -p ${curprefix}


CFLAGS="-O2 ${WASM_COMPILER_DEFINES} -D_WASI_EMULATED_SIGNAL -msimd128 -DWEBP_USE_SIMDE -DSIMDE_ENABLE_NATIVE_ALIASES -I${SIMDE_PATH}" \
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
	./configure \
	--with-sysroot=${WASI_SDK_PATH}/share/wasi-sysroot \
	--host=wasm32 \
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

# We copy the config to verify each library is compiled with the same defs
cp src/webp/config.h ${curprefix}/config.h
