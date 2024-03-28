
if [ "$WORK_DIR" == "" ]; then
	WORK_DIR=/home/wrv/research/wasmperf
fi


echo "$$WASM_COMPILER_DEFINES"

if [ "$WASM_COMPILER_DEFINES" == "" ]; then
	# Enable different features
	export WASM_COMPILER_DEFINES=""
	# Enable 64-bit registers in WASM
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_BITSIZE"
	# Use the hardcoded tree approach
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_HARDCODED_TREE"
	# Avoid indirect function calls by renaming functions
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
	# Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
	WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
fi

./build_wasm.sh
./build_wasmsimd.sh