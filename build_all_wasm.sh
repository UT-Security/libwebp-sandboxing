
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
	# Use VP8L Fast Loads to load 32 bits at time
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
	# Enable direct calls in VP8L
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_LOSSLESS_DIRECT_CALL"
fi

./build_wasm.sh
./build_wasmsimd.sh