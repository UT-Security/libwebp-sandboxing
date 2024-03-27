
if [ "$WORK_DIR" == "" ]; then
	WORK_DIR=/home/wrv/research/wasmperf
fi

WASM_COMPILER_DEFINES="-DWEBP_WASM_GENERIC_TREE -DWEBP_WASM_BITSIZE -DWEBP_WASM_DIRECT_FUNCTION_CALL"

./build_wasm.sh
./build_wasmsimd.sh