make clean > /dev/null
echo "Building NativeSIMD version of libwebp"
curprefix=$(pwd)/libwebp_nativesimd

mkdir -p ${curprefix}

# Difference from Native is that we enable the SSE optimizations

CFLAGS="-O2"\
	./configure \
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

# We copy the config to verify each library is compiled with the same defs
cp src/webp/config.h ${curprefix}/config.h
