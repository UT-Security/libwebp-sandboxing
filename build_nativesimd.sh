echo "Building NativeSIMD version of libwebp"
curprefix=$(pwd)/libwebp_nativesimd

echo Using NATIVESIMD_COMPILER_DEFINES: "$NATIVESIMD_COMPILER_DEFINES"

mkdir -p ${curprefix}

cd ${curprefix}

# If we're trying to recompile without changing the code, but changing
# only the feature flags, it won't work, so we clean it out :/
make clean

# Difference from Native is that we enable the SSE optimizations

CFLAGS="-O2 ${NATIVESIMD_COMPILER_DEFINES}"\
	../configure \
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

sed -i 's|#define HAVE_DLFCN_H 1|/\* #undef HAVE_DLFCN_H\*/|' src/webp/config.h

make
make install

cd ..