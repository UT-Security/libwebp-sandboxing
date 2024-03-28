## Optimizations to enable and test
# Enable 64-bit registers in WASM
BITSIZE=false
# Use the hardcoded tree approach
HARDCODED_TREE=false
# Avoid indirect function calls by renaming functions
DIRECT_CALL=false
# Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
ALIAS_VP8PARSEINTRAMODE=false

## Title for graph
title="complete_decode_simde"

# Enable different features
export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition

if [ "$BITSIZE" = true ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_BITSIZE"
    title="${title}_BITS56"
fi

if [ "$HARDCODED_TREE" = true ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_HARDCODED_TREE"
    title="${title}_HARDCODEDTREE"
fi

if [ "$DIRECT_CALL" = true ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
    title="${title}_DIRECTCALL"
fi

if [ "$ALIAS_VP8PARSEINTRAMODE" = true ]; then
    WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    title="${title}_ALIASVP8PARSEINTRAMODEROW"
fi


cur_date=$(date +%s)
cur_dir=$(pwd)
# Number of times to run the individual experiment
N=100
# Number of times to run the overall experiment
runs=1
# Number of times to decode the image
decode_count=100

indir=inputs_one/
infile=inputs_one/1.webp
outputdirname=tmp/${cur_date}_${title}

# Build the library
if [ "$1" = "build" ]; then
    echo "Building!"
    echo "WASM_COMPILER_DEFINES: ${WASM_COMPILER_DEFINES}"
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

    for testname in 'native_unchanged' 'nativesimd_unchanged' 'native' 'nativesimd' 'wasm' 'wasmsimd';
    do
        logname=${outdir}/benchmark_log_${testname}.txt
        imagename=${infile##*/}
        rm ${outdir}/${imagename}_${testname}.csv > /dev/null 2>&1
        for i in $(seq 1 $N)
        do
            bin/decode_webp_${testname} ${indir}/${imagename} ${outdir}/${imagename}_${testname}.csv ${outdir}/${imagename}_${testname}.ppm ${decode_count} > ${logname} 2>&1
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
    sha256sum ${outdir}/*.ppm

    python3 comp_analysis.py ${indir} ${outdir} "${title}"
done
