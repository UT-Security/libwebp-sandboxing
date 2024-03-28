
if ! test -f ./configure; then
    ./autogen.sh
fi

export WORK_DIR=/home/wrv/research/wasmperf

export WASI_SDK_PATH=${WORK_DIR}/wasi-sdk-21.0
export SIMDE_PATH=${WORK_DIR}/simde-0.7.6

./build_native.sh
./build_nativesimd.sh
./build_all_wasm.sh