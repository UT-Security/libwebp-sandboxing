#!/bin/bash

cur_date=$(date +%s)
cur_dir=$(pwd)

gentitle() {
    local BITSIZE=$1
    local USE_GENERIC_TREE=$2
    local DIRECT_CALL=$3

    result="baseline_lossy"

    if [ "$BITSIZE" = "56" ]; then
        result="${result}_BITS56"
    else
        result="${result}_BITS24"
    fi

    if [ "$USE_GENERIC_TREE" = "0" ]; then
        result="${result}_USE_GENERIC_TREE0"
    else
        result="${result}_USE_GENERIC_TREE1"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        result="${result}_DIRECT_CALL1"
    else
        result="${result}_DIRECT_CALL0"
    fi

}

buildlibrary() {
    local BITSIZE=$1
    local USE_GENERIC_TREE=$2
    local DIRECT_CALL=$3

    # Enable different features in both native and wasm versions
    export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition

    if [ "$BITSIZE" = "56" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=56"
    else
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=24"
    fi

    # This enables/disables hardcoded tree for native and WASM
    if [ "$USE_GENERIC_TREE" = "1" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    else
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
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
for BITSIZE in '56' '24';
do
    # Use the hardcoded tree approach
    for USE_GENERIC_TREE in '0' '1';
    do
        # Avoid indirect function calls by renaming functions
        for DIRECT_CALL in 'true' 'false';
        do
            # Produces $result
            gentitle ${BITSIZE} ${USE_GENERIC_TREE} ${DIRECT_CALL}

            # Build the Library and Binary
            curdir=${hostdir}/$result
            mkdir -p ${curdir}

            buildlibrary ${BITSIZE} ${USE_GENERIC_TREE} ${DIRECT_CALL}
            # Backup the built library
            cp -r ../libwebp_wasm ${curdir}/
            
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
done


echo "Saved output to ${hostdir}"