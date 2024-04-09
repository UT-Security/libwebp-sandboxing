#!/bin/bash

# Install dependencies
sudo apt install cpuset
sudo apt install cpufrequtils

setupenv() {
    # disable hyperthreads
    sudo bash -c "echo off > /sys/devices/system/cpu/smt/control"
    # set cpu freq on CPU 2
    sudo cpufreq-set -c 2 -g performance
    sudo cpufreq-set -c 2 --min 2200MHz --max 2200MHz
    # set cpu shield on CPU 2
    sudo cset shield -c 2 -k on
    #sudo cset shield -e sudo -- -u "$USER" env "PATH=$PATH" bash
}


teardownenv() {
    # You are in a subshell now, run your benchmark here

    # Ctrl+D to close the current subshell
    # Enable hyperthreading
    sudo bash -c "echo on > /sys/devices/system/cpu/smt/control"
    # Reset cpu frequency on CPU 2 by copying policy from cpu 0
    POLICYINFO=($(cpufreq-info -c 0 -p)) && \
    sudo cpufreq-set -c 2 -g ${POLICYINFO[2]} && \
    sudo cpufreq-set -c 2 --min ${POLICYINFO[0]}MHz --max ${POLICYINFO[1]}MHz
}

cur_date=$(date +%s)
cur_dir=$(pwd)


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
N=20
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

setupenv

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
                    virtualenv/bin/python3 stat_analysis.py "${outdir}/${imagename}_${t}.csv" "${outdir}/${imagename}_${t}_stats.txt" "${imagename} with ${t}" "${outdir}/${imagename}_${t}_stats.png"
                    sleep 1
                done

                sha256sum ${outdir}/*.ppm
                virtualenv/bin/python3 comp_analysis.py ${indir} ${outdir} "${title}"
            done
        done
    done
done


teardownenv