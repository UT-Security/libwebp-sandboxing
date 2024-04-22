echo "Building Native version of libwebp"
curprefix=$(pwd)/libwebp_native

mkdir -p ${curprefix}

cd ${curprefix}

CFLAGS="-O2"\
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