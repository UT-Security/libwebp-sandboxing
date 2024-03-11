# Get dependencies

git clone https://github.com/WebAssembly/wabt wabt_src
cd wabt_src/

## Update submodules and build WABT 
git submodule update --init

### TODO: Apply PRs 2395 (Segue) and 2357 (No force read)
#git fetch origin pull/2395/head:segue
#git switch segue
#git rebase main # This currently has some issues preventing automated rebasing

#git fetch origin pull/2357/head:no_force_read
#git rebase no_force_read # This currently has some issues prevening rebasing

### We're now in the segue branch with both changes applied.

mkdir build && cd build/
cmake ..
cmake --build .

cd ../../

## Get WASI
wget https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-21/wasi-sdk-21.0-linux.tar.gz
tar xvzf wasi-sdk-21.0-linux.tar.gz
### Should now live in wasi-sdk-21.0/


## Get SIMDe
wget https://github.com/simd-everywhere/simde/archive/refs/tags/v0.7.6.zip
unzip v0.7.6.zip

### Should now live in simde-0.7.6/


## Get uvwasi (this is for a system interface)
wget https://github.com/nodejs/uvwasi/archive/refs/tags/v0.0.20.zip
unzip v0.0.20.zip

### Should now live in uvwasi-0.0.20/
cd uvwasi-0.0.20/
mkdir -p out/cmake ; cd out/cmake
CFLAGS="-fPIC" cmake ../.. -DBUILD_TESTING=ON
cmake --build .
ctest -C Debug --output-on-failure

cd ../../../
# Back in cwd


# Get Library

git clone https://github.com/webmproject/libwebp libwebp
cd libwebp/

# Make the Benchmarking folder
mkdir -p benchmarking/inputs_one

# Download the test image
cd benchmarking/inputs_one/
wget https://www.gstatic.com/webp/gallery/1.webp

cd ../../../

