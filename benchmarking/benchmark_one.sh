## Optimizations to enable and test
# Enable 64-bit registers in WASM
BITSIZE=56 # 24
# Use the hardcoded tree approach
USE_GENERIC_TREE=0
# Avoid indirect function calls by renaming functions
DIRECT_CALL=true
# Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
ALIAS_VP8PARSEINTRAMODE=false
# Use VP8L Fast Load to enable copying 4 bytes at a time
FAST_LOAD=1

## Title for graph
title="complete_decode_simde_all_predictor11sse2"

# Enable different features in both native and wasm versions
export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition
export WASMSIMD_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition
export NATIVE_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition
export NATIVESIMD_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition


if [ "$BITSIZE" = "56" ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=56"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DBITS=56"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DBITS=56"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DBITS=56"
    title="${title}_BITS56"
else
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=24"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DBITS=24"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DBITS=24"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DBITS=24"
    title="${title}_BITS24"
fi

# This enables/disables hardcoded tree for native and WASM
if [ "$USE_GENERIC_TREE" = "1" ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    title="${title}_USE_GENERIC_TREE1"
else
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
    title="${title}_USE_GENERIC_TREE0"
fi

# Now Applies to both Lossy and Lossless
if [ "$DIRECT_CALL" = "true" ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL -DWEBP_WASMSIMD_DIRECT_FUNCTION_CALL"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL -DWEBP_WASMSIMD_DIRECT_FUNCTION_CALL"
    title="${title}_DIRECTCALL1"
else
    title="${title}_DIRECTCALL0"
fi

if [ "$ALIAS_VP8PARSEINTRAMODE" = "true" ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    title="${title}_ALIASVP8PARSEINTRAMODEROW1"
else
    title="${title}_ALIASVP8PARSEINTRAMODEROW0"
fi

# This enables the fast load path in FillBitWindow
if [ "$FAST_LOAD" = "1" ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
    WASMSIMD_COMPILER_DEFINES="${WASMSIMD_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
    NATIVE_COMPILER_DEFINES="${NATIVE_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
    NATIVESIMD_COMPILER_DEFINES="${NATIVESIMD_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
    title="${title}_FAST_LOAD1"
else
    title="${title}_FAST_LOAD0"
fi


cur_date=$(date +%s)
cur_dir=$(pwd)
# Number of times to run the individual experiment
N=20
# Number of times to run the overall experiment
runs=1
# Number of times to decode the image
decode_count=100

indir=images/lossy/
infile=${indir}/1.webp
outputdirname=tmp/${cur_date}_${title}

# Build the library
if [ "$1" = "build" ]; then
    echo "Building!"
    echo "WASM_COMPILER_DEFINES: ${WASM_COMPILER_DEFINES}"
    echo "WASMSIMD_COMPILER_DEFINES: ${WASMSIMD_COMPILER_DEFINES}"
    echo "NATIVE_COMPILER_DEFINES: ${NATIVE_COMPILER_DEFINES}"
    echo "NATIVESIMD_COMPILER_DEFINES: ${NATIVESIMD_COMPILER_DEFINES}"
    cd ..
    ./build.sh
    cd ${cur_dir}
    # Build the local binaries
    make all -B
fi

echo "Starting experiment!"

# Experiment runs
for r in $(seq 1 $runs)
do
    outdir=${outputdirname}_${r}
    mkdir -p ${outdir}

    for testname in 'native_unchanged' 'nativesimd_unchanged' 'native' 'nativesimd' 'wasm' 'wasmsimd' 'wasmsimd_emscripten';
    do
        echo "Running ${testname}"
        logname=${outdir}/benchmark_log_${testname}.txt
        imagename=${infile##*/}
        rm ${outdir}/${imagename}_${testname}.csv > /dev/null 2>&1
        for i in $(seq 1 $N)
        do
            #echo bin/decode_webp_${testname} ${infile} ${outdir}/${imagename}_${testname}.csv ${outdir}/${imagename}_${testname}.pam ${decode_count}
            bin/decode_webp_${testname} ${infile} ${outdir}/${imagename}_${testname}.csv ${outdir}/${imagename}_${testname}.pam ${decode_count} > ${logname} 2>&1
        done
        python3 stat_analysis.py "${outdir}/${imagename}_${testname}.csv" "${outdir}/${imagename}_${testname}_stats.txt" "${imagename} with ${testname}" "${outdir}/${imagename}_${testname}_stats.png"
        objdump -d bin/decode_webp_${testname} > ${outdir}/decode_webp_${testname}.objdump
        # Copy test files
        cp bin/decode_webp_${testname}* ${outdir}/
        if [[ ${testname} != *"unchanged" ]]; then
            cp -r ../libwebp_${testname} ${outdir}/
        fi
    done

    cp decode_webp_wasm* ${outdir}/
    sha256sum ${outdir}/*.pam

    python3 comp_analysis.py ${indir} ${outdir} "${title}"
done
