
if ! test -f ./configure; then
    ./autogen.sh
fi

WORK_DIR=/home/wrv/research/wasmperf

WASI_SDK_PATH=${WORK_DIR}/wasi-sdk-21.0
SIMDE_PATH=${WORK_DIR}/simde-0.7.6

./build_native.sh
./build_nativesimd.sh
./build_wasm.sh
./build_wasmsimd.sh
