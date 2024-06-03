#!/bin/bash


gentitle() {
    local FAST_LOAD=$1
    local DIRECT_CALL=$2

    result="baseline_lossless"

    if [ "$FAST_LOAD" = "1" ]; then
        result="${result}_FAST_LOAD"
    fi

    if [ "$DIRECT_CALL" = "true" ]; then
        result="${result}_DIRECTCALL"
    fi
}


cur_date=$(date +%s)
cur_dir=$(pwd)

# Number of times to run the individual experiment
N=20
# Number of times to decode the image
decode_count=100

indir=images/lossless

# Expecting the binaries to be in test_files
hostdir=test_files
resultsdir=test_results

mkdir -p ${resultsdir}
combined_log=${resultsdir}/combined_lossless_results.csv

echo "IMAGE, WABT_TYPE, FAST_LOAD, DIRECT_CALL, native_unchanged,nativesimd_unchanged,native,nativesimd,wasm,wasmsimd,native_unchanged_errorbar,nativesimd_unchanged_errorbar,native_errorbar,nativesimd_errorbar,wasm_errorbar,wasmsimd_errorbar" > $combined_log

for WABT_TYPE in 'combined' 'no_force_read' 'segue' 'upstream';
do
    # Enable 64-bit registers in WASM
    for FAST_LOAD in '0' '1';
    do
        # Avoid indirect function calls by renaming functions
        for DIRECT_CALL in 'false' 'true';
        do
            gentitle ${FAST_LOAD} ${DIRECT_CALL}

            echo "Starting experiment: ${result} (${WABT_TYPE})"
            workdir=${hostdir}/${result}/bench/${WABT_TYPE}
            outdir=${resultsdir}/${WABT_TYPE}/${result}

            mkdir -p ${outdir}
            for IMAGE in ${indir}/*.webp;
            do
                imagename=${IMAGE##*/}
                echo "Decoding ${imagename}"
                for t in 'native_unchanged' 'nativesimd_unchanged' 'native' 'nativesimd' 'wasm' 'wasmsimd';
                do
                    logname=${outdir}/benchmark_log_${t}.txt

                    for i in $(seq 1 $N)
                    do
                        ${workdir}/decode_webp_${t} ${indir}/${imagename} ${outdir}/${imagename}_${t}.csv ${outdir}/${imagename}_${t}.pam ${decode_count} > ${logname} 2>&1
                    done
                    virtualenv/bin/python3 stat_analysis.py "${outdir}/${imagename}_${t}.csv" "${outdir}/${imagename}_${t}_stats.txt" "${imagename} with ${t}" "${outdir}/${imagename}_${t}_stats.png"
                    #sleep 1
                done

                sha256sum ${outdir}/*.pam
                virtualenv/bin/python3 comp_analysis.py ${indir} ${outdir} "${result}"
                echo "${imagename}, ${WABT_TYPE}, ${FAST_LOAD}, ${DIRECT_CALL}, $(tail -1 ${outdir}/unified_analysis_data.txt)" >> $combined_log
            done
        done
    done
done

cat /proc/cpuinfo > ${resultsdir}/device_info.txt
uname -a >> ${resultsdir}/device_info.txt

zip -r results_lossless.zip ${resultsdir}

echo "Please send me results_lossless.zip :)"
