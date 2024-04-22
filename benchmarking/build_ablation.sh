#!/bin/bash

cur_date=$(date +%s)
cur_dir=$(pwd)

gentitle() {
    local BITSIZE=$1
    local USE_GENERIC_TREE=$2
    local DIRECT_CALL=$3
    local ALIAS_VP8PARSEINTRAMODE=$4

    result="baseline"

    if [ "$BITSIZE" = "56" ]; then
        result="${result}_BITS56"
    fi

    if [ "$USE_GENERIC_TREE" = "1" ]; then
        result="${result}_USE_GENERIC_TREE"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        result="${result}_DIRECTCALL"
    fi

    if [ "$ALIAS_VP8PARSEINTRAMODE" = "true" ]; then
        result="${result}_ALIASVP8PARSEINTRAMODEROW"
    fi
}

buildlibrary() {
    local BITSIZE=$1
    local USE_GENERIC_TREE=$2
    local DIRECT_CALL=$3
    local ALIAS_VP8PARSEINTRAMODE=$4

    # Enable different features in both native and wasm versions
    export WASM_COMPILER_DEFINES=" " # We add a space to avoid empty string redefinition


    if [ "$BITSIZE" = "56" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=56"
    else
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DBITS=24"
    fi

    # This enables/disables hardcoded tree for native and WASM
    # Hardcoded Tree == TRUE means that Generic Tree is False
    if [ "$USE_GENERIC_TREE" = "1" ]; then
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=1"
    else
        WASM_COMPILER_DEFINES="${WASM_COMPILER_DEFINES} -DUSE_GENERIC_TREE=0"
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

    export WABT_VER=$2
    # Build the local binaries
    make all -B -C ${TGTDIR} > /dev/null
}

hostdir=tmp/${cur_date}_built_ablation
mkdir -p ${hostdir}

echo "Saving output to ${hostdir}"

# Enable 64-bit registers in WASM
for BITSIZE in '24' '56';
do
    # Use the hardcoded tree approach
    for USE_GENERIC_TREE in '0' '1';
    do
        # Avoid indirect function calls by renaming functions
        for DIRECT_CALL in 'false' 'true';
        do
            # Mimic WEBP_RESTRICT by aliasing VP8BitReader in VP8ParseIntraModeRow
            for ALIAS_VP8PARSEINTRAMODE in 'false' 'true';
            do
                # Produces $result
                gentitle ${BITSIZE} ${USE_GENERIC_TREE} ${DIRECT_CALL} ${ALIAS_VP8PARSEINTRAMODE}

                # Build the Library and Binary
                curdir=${hostdir}/$result
                mkdir -p ${curdir}

                buildlibrary ${BITSIZE} ${USE_GENERIC_TREE} ${DIRECT_CALL} ${ALIAS_VP8PARSEINTRAMODE}
                # Backup the built library
                cp -r ../libwebp_* ${curdir}/
                
                # Copy the source in a way where we can just call `make` inside the source
                mkdir -p ${curdir}/bench/
                cp *.c ${curdir}/bench/
                cp *.h ${curdir}/bench/
                cp Makefile ${curdir}/bench/

                for WABT_VERSION in 'upstream' 'combined' 'segue' 'no_force_read';
                do
                    buildbin ${curdir}/bench/ ${WABT_VERSION}

                    mkdir -p ${curdir}/bench/${WABT_VERSION}/
                    cp ${curdir}/bench/bin/* ${curdir}/bench/${WABT_VERSION}/
                    cp bin/decode_webp_native_unchanged ${curdir}/bench/${WABT_VERSION}/
                    cp bin/decode_webp_nativesimd_unchanged ${curdir}/bench/${WABT_VERSION}/
                done
            done
        done
    done
done


echo "Saved output to ${hostdir}"