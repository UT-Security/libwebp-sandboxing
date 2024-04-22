#!/bin/bash


gentitle() {
    local BITSIZE=$1
    local HARDCODED_TREE=$2
    local DIRECT_CALL=$3
    local ALIAS_VP8PARSEINTRAMODE=$4

    title="baseline"

    if [ "$BITSIZE" = "true" ]; then
        title="${title}_BITS56"
    fi

    if [ "$HARDCODED_TREE" = "true" ]; then
        title="${title}_HARDCODEDTREE"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        title="${title}_DIRECTCALL"
    fi

    if [ "$ALIAS_VP8PARSEINTRAMODE" = "true" ]; then
        title="${title}_ALIASVP8PARSEINTRAMODEROW"
    fi
}


cur_date=$(date +%s)
cur_dir=$(pwd)

## Title for graph
title="complete_decode"

# Number of times to run the individual experiment
N=20
# Number of times to decode the image
decode_count=100

indir=inputs_one/
infile=inputs_one/1.webp

# Expecting the binaries to be in test_files
hostdir=test_files/
resultsdir=test_results/

mkdir -p ${resultsdir}
combined_log=${resultsdir}/combined_results.csv

echo "WABT_TYPE, BITSIZE, HARDCODED_TREE, DIRECT_CALL, ALIAS_VP8PARSEINTRAMODE, native_unchanged,nativesimd_unchanged,native,nativesimd,wasm,wasmsimd,native_unchanged_errorbar,nativesimd_unchanged_errorbar,native_errorbar,nativesimd_errorbar,wasm_errorbar,wasmsimd_errorbar" > $combined_log

for WABT_TYPE in 'combined' 'no_force_read' 'segue' 'upstream';
do
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

                    echo "Starting experiment: ${title}"
                    workdir=${hostdir}/${title}/bench/${WABT_TYPE}
                    outdir=${resultsdir}/${WABT_TYPE}/${title}

                    mkdir -p ${outdir}

                    for t in 'native_unchanged' 'nativesimd_unchanged' 'native' 'nativesimd' 'wasm' 'wasmsimd';
                    do
                        logname=${outdir}/benchmark_log_${t}.txt
                        imagename=${infile##*/}

                        for i in $(seq 1 $N)
                        do
                            ${workdir}/decode_webp_${t} ${indir}/${imagename} ${outdir}/${imagename}_${t}.csv ${outdir}/${imagename}_${t}.ppm ${decode_count} > ${logname} 2>&1
                        done
                        virtualenv/bin/python3 stat_analysis.py "${outdir}/${imagename}_${t}.csv" "${outdir}/${imagename}_${t}_stats.txt" "${imagename} with ${t}" "${outdir}/${imagename}_${t}_stats.png"
                        sleep 1
                    done

                    sha256sum ${outdir}/*.ppm
                    virtualenv/bin/python3 comp_analysis.py ${indir} ${outdir} "${title}"
                    echo "${WABT_TYPE}, ${BITSIZE}, ${HARDCODED_TREE}, ${DIRECT_CALL}, ${ALIAS_VP8PARSEINTRAMODE}, $(tail -1 ${outdir}/unified_analysis_data.txt)" >> $combined_log
                done
            done
        done
    done
done

cat /proc/cpuinfo > ${resultsdir}/device_info.txt
uname -a >> ${resultsdir}/device_info.txt

zip -r results.zip ${resultsdir}

echo "Please send me results.zip :)"
