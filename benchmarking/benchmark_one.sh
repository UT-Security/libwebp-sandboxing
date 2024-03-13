title="complete_decode_simde"
cur_date=$(date +%s)

# Number of times to run the individual experiment
N=20
# Number of times to run the overall experiment
runs=3
# Number of times to decode the image
decode_count=100

indir=inputs_one/
infile=inputs_one/1.webp
outputdirname=tmp/${cur_date}_${title}

# Build the library
if [ "$1" = "build" ]; then
    echo "Building!"
    cd ..
    ./build.sh
    cd benchmarking_code
    # Build the local binaries
    make all -B
fi

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
            #echo bin/decode_webp_${testname} ${indir}/${imagename} ${outdir}/${imagename}_${testname}.csv ${outdir}/${imagename}_${testname}.ppm ${decode_count}
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
