echo "Building Native version of libwebp"
curprefix=$(pwd)/libwebp_native

echo Using NATIVE_COMPILER_DEFINES: "$NATIVE_COMPILER_DEFINES"

mkdir -p ${curprefix}

cd ${curprefix}

# If we're trying to recompile without changing the code, but changing
# only the feature flags, it won't work, so we clean it out :/
make clean

CFLAGS="-O2 ${NATIVE_COMPILER_DEFINES}"\
	../configure \
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

sed -i 's|#define HAVE_DLFCN_H 1|/\* #undef HAVE_DLFCN_H\*/|' src/webp/config.h

make
make install

cd ..