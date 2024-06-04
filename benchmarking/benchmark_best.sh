#!/bin/bash


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


cur_date=$(date +%s)
cur_dir=$(pwd)

# Number of times to run the individual experiment
N=10
# Number of times to decode the image
decode_count=20

indir=images/test

# Expecting the binaries to be in test_files
hostdir=test_files/
resultsdir=test_results/

mkdir -p ${resultsdir}
combined_log=${resultsdir}/combined_benchmark_results.csv

echo "IMAGE, WABT_TYPE, BITSIZE, USE_GENERIC_TREE, DIRECT_CALL, native_unchanged,nativesimd_unchanged,native,nativesimd,wasm,wasmsimd,native_unchanged_errorbar,nativesimd_unchanged_errorbar,native_errorbar,nativesimd_errorbar,wasm_errorbar,wasmsimd_errorbar" > $combined_log

BITSIZE='56' # '24' '56'
WABT_TYPE='upstream' # 'combined' 'no_force_read' 'segue' 'upstream'
USE_GENERIC_TREE='0' # '0' '1'
DIRECT_CALL='true' # 'false' 'true'

gentitle ${BITSIZE} ${USE_GENERIC_TREE} ${DIRECT_CALL}

echo "Starting experiment: ${result}"
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
    done

    sha256sum ${outdir}/*.pam
    virtualenv/bin/python3 comp_analysis.py ${indir} ${outdir} "${result}"
    echo "${imagename}, ${WABT_TYPE}, ${BITSIZE}, ${USE_GENERIC_TREE}, ${DIRECT_CALL}, $(tail -1 ${outdir}/unified_analysis_data.txt)" >> $combined_log
done


cat /proc/cpuinfo > ${resultsdir}/device_info.txt
uname -a >> ${resultsdir}/device_info.txt

zip -r results_lossy.zip ${resultsdir}

echo "Please send me results_lossy.zip :)"
