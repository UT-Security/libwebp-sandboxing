#!/bin/bash

cur_date=$(date +%s)
cur_dir=$(pwd)

buildlibrary() {
    local BITSIZE=$1
    local HARDCODED_TREE=$2
    local DIRECT_CALL=$3
    local ALIAS_VP8PARSEINTRAMODE=$4

    # Enable different features
    export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition

    if [ "$BITSIZE" = "true" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_BITSIZE"
    fi

    if [ "$HARDCODED_TREE" = "true" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_HARDCODED_TREE"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
    fi

    if [ "$ALIAS_VP8PARSEINTRAMODE" = "true" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"
    fi
    echo "Building Library!"
    echo "WASM_COMPILER_DEFINES: ${WASM_COMPILER_DEFINES}"
    cd ..
    ./build.sh > /dev/null
    cd ${cur_dir}
}

buildbin() {
    local TGTDIR=$1

    echo "Building Binary!"

    # Build the local binaries
    make all -B -C ${TGTDIR} > /dev/null
}

gentitle() {
    local BITSIZE=$1
    local HARDCODED_TREE=$2
    local DIRECT_CALL=$3
    local ALIAS_VP8PARSEINTRAMODE=$4

    result="baseline"

    if [ "$BITSIZE" = "true" ]; then
        result="${result}_BITS56"
    fi

    if [ "$HARDCODED_TREE" = "true" ]; then
        result="${result}_HARDCODEDTREE"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        result="${result}_DIRECTCALL"
    fi

    if [ "$ALIAS_VP8PARSEINTRAMODE" = "true" ]; then
        result="${result}_ALIASVP8PARSEINTRAMODEROW"
    fi
}


## Title for graph
title="complete_decode"

# Number of times to run the individual experiment
N=100
# Number of times to decode the image
decode_count=100

indir=inputs_one/
infile=inputs_one/1.webp

hostdir=tmp/${cur_date}_ablation_${title}

# Check to see if the hostdir is build or 
if [ "$1" = "" ]; then
    echo 'Usage: ./benchmark_ablation.sh ["build" | dir] ["lib" if "build" is passed]'
    echo 'dir is a previously generated directory'
    exit 1
elif [ "$1" != "build" ]; then
    hostdir=$1
fi

# Enable 64-bit registers in WASM
for BITSIZE in 'false' 'true';
do
    # Use the hardcoded tree approach
    for HARDCODED_TREE in 'false' 'true';
    do
        # Avoid indirect function calls by renaming functions
        for DIRECT_CALL in 'false' 'true';
        do
            # Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
            for ALIAS_VP8PARSEINTRAMODE in 'false' 'true';
            do
                gentitle ${BITSIZE} ${HARDCODED_TREE} ${DIRECT_CALL} ${ALIAS_VP8PARSEINTRAMODE}

                # Build the Library and Binary
                if [ "$1" = "build" ] || [ "$2" = "build" ]; then
                    mkdir -p ${hostdir}
                    curdir=${hostdir}/$result
                    mkdir -p ${curdir}

                    # Only build the library when needed. Build defaults to 
                    if [ "$2" = "lib" ] || [ "$3" = "lib" ]; then
                        buildlibrary ${BITSIZE} ${HARDCODED_TREE} ${DIRECT_CALL} ${ALIAS_VP8PARSEINTRAMODE}
                        # Backup the built library
                        cp -r ../libwebp_* ${curdir}/
                    fi
                    
                    # Copy the source in a way where we can just call `make` inside the source
                    mkdir -p ${curdir}/bench/
                    cp *.c ${curdir}/bench/
                    cp *.h ${curdir}/bench/
                    cp Makefile ${curdir}/bench/

                    buildbin ${curdir}/bench/

                    cp bin/decode_webp_native_unchanged ${curdir}/bench/bin/
                    cp bin/decode_webp_nativesimd_unchanged ${curdir}/bench/bin/

                    objdump -d ${curdir}/bench/bin/decode_webp_native       > ${curdir}/bench/bin/decode_webp_native.objdump
                    objdump -d ${curdir}/bench/bin/decode_webp_nativesimd   > ${curdir}/bench/bin/decode_webp_nativesimd.objdump
                    objdump -d ${curdir}/bench/bin/decode_webp_wasm         > ${curdir}/bench/bin/decode_webp_wasm.objdump
                    objdump -d ${curdir}/bench/bin/decode_webp_wasmsimd     > ${curdir}/bench/bin/decode_webp_wasmsimd.objdump
                fi

                title="complete_decode_$result"

                echo "Starting experiment: ${title}"
                outdir=${hostdir}/${result}/bench

                for t in 'native_unchanged' 'nativesimd_unchanged' 'native' 'nativesimd' 'wasm' 'wasmsimd';
                do                    
                    logname=${outdir}/benchmark_log_${t}.txt
                    imagename=${infile##*/}
                    rm ${outdir}/${imagename}_${t}.csv > /dev/null 2>&1

                    for i in $(seq 1 $N)
                    do
                        #echo ${outdir}/bin/decode_webp_${t} ${indir}/${imagename} ${outdir}/${imagename}_${t}.csv ${outdir}/${imagename}_${t}.ppm ${decode_count}
                        ${outdir}/bin/decode_webp_${t} ${indir}/${imagename} ${outdir}/${imagename}_${t}.csv ${outdir}/${imagename}_${t}.ppm ${decode_count} > ${logname} 2>&1
                    done
                    python3 stat_analysis.py "${outdir}/${imagename}_${t}.csv" "${outdir}/${imagename}_${t}_stats.txt" "${imagename} with ${t}" "${outdir}/${imagename}_${t}_stats.png"
                done

                sha256sum ${outdir}/*.ppm
                python3 comp_analysis.py ${indir} ${outdir} "${title}"
            done
        done
    done
done
