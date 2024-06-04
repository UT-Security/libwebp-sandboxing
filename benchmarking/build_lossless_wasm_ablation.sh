#!/bin/bash

cur_date=$(date +%s)
cur_dir=$(pwd)

gentitle() {
    local FAST_LOAD=$1
    local DIRECT_CALL=$2

    result="baseline_lossless"

    if [ "$FAST_LOAD" = "1" ]; then
        result="${result}_FAST_LOAD1"
    else
        result="${result}_FAST_LOAD0"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        result="${result}_DIRECTCALL1"
    else
        result="${result}_DIRECTCALL0"
    fi
}

buildlibrary() {
    local FAST_LOAD=$1
    local DIRECT_CALL=$2

    # Enable different features in both native and wasm versions
    export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition

    # This enables the fast load path in FillBitWindow
    if [ "$FAST_LOAD" = "1" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DVP8L_USE_FAST_LOAD"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DWEBP_WASM_DIRECT_FUNCTION_CALL"
    fi

    echo "Building Library!"
    echo "WASM_COMPILER_DEFINES: ${WASM_COMPILER_DEFINES}"
    cd ..
    ./build_wasm.sh > /dev/null
    cd ${cur_dir}
}

buildbin() {
    local TGTDIR=$1

    echo "Building Binary!"

    export WABT_VER=$2
    # Build the local binaries
    make bin/decode_webp_wasm -B -C ${TGTDIR} > /dev/null
}

hostdir=test_files/
mkdir -p ${hostdir}

echo "Saving output to ${hostdir}"

# Enable 64-bit registers in WASM
for FAST_LOAD in '0' '1';
do
    # Avoid indirect function calls by renaming functions
    for DIRECT_CALL in 'false' 'true';
    do
        # Produces $result
        gentitle ${FAST_LOAD} ${DIRECT_CALL}

        # Build the Library and Binary
        curdir=${hostdir}/$result
        mkdir -p ${curdir}

        buildlibrary ${FAST_LOAD} ${DIRECT_CALL}
        # Backup the built library
        cp -r ../libwebp_* ${curdir}/
        
        # Copy the source in a way where we can just call `make` inside the source
        mkdir -p ${curdir}/bench/
        cp decode_webp.c ${curdir}/bench/
        cp main_wasm.c ${curdir}/bench/
        cp uvwasi-rt.c ${curdir}/bench/
        cp decode_webp.h ${curdir}/bench/
        cp helpers.h ${curdir}/bench/
        cp uvwasi-rt.h ${curdir}/bench/
        cp Makefile ${curdir}/bench/

        for WABT_VERSION in 'upstream' 'combined' 'segue' 'no_force_read';
        do
            buildbin ${curdir}/bench/ ${WABT_VERSION}

            mkdir -p ${curdir}/bench/${WABT_VERSION}/
            cp ${curdir}/bench/bin/decode_webp_wasm ${curdir}/bench/${WABT_VERSION}/
        done
    done
done



echo "Saved output to ${hostdir}"