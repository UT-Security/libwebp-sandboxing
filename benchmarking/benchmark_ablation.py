#!/usr/bin/python3
import os
import sys
import argparse
import logging
import numpy as np
import matplotlib.pyplot as plt
import random
from subprocess import run, PIPE
from itertools import chain, combinations

################# CONSTANTS ###########################
# Build flags that enable the features we are ablating
ABLATION_PARAMS = {
    "BITS56": ["-DBITS=24", "-DBITS=56"], 
    "USE_GENERIC_TREE": ["-DUSE_GENERIC_TREE=0", "-DUSE_GENERIC_TREE=1"], 
    "DIRECTCALL": ["", "-DWEBP_WASM_DIRECT_FUNCTION_CALL"], 
    "ALIASVP8PARSEINTRAMODEROW": ["", "-DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"]
}

# Different flavors of WABT we're testing
WABT_TYPES = ['combined', 'upstream', 'segue', 'no_force_read']

# Binaries to run
BINARIES = ['native_unchanged', 'nativesimd_unchanged', 'native', 'nativesimd', 'wasm', 'wasmsimd']

# The temp directory to store outputs unless stated otherwise
TMP_DIR = "tmp/"

################# LOGGING AND ARGS ###########################

logger = logging.getLogger(__name__)
parser = argparse.ArgumentParser(
                    prog='Libwebp Ablation Study')
parser.add_argument('mode', help="The current task to perform with this script", choices=["build", "test", "analyze"], default="test")
parser.add_argument('-d', '--directory', help="The directory that contains the test files. If none is provided, then one will be generated.")
parser.add_argument('-t', '--title', help="The title of this experiment")
parser.add_argument('-l', '--build-library', action='store_true', help="Builds the library and the relevant binaries")
parser.add_argument('-b', '--build-only-binary', action='store_true', help="Only builds the relevant binaries. Useful for WABT modifications")
parser.add_argument('-i', '--iterations', help="Number of iterations for an individual experiment")
parser.add_argument('-n', '--number-of-decodes', help="Number of times to decode an individual image")
parser.add_argument('-m', '--image-directory', help="Directory where the input images are located")

################# UTILITIES ###########################

# From https://docs.python.org/3/library/itertools.html#itertools-recipes
def powerset(iterable):
    "powerset([1,2,3]) → () (1,) (2,) (3,) (1,2) (1,3) (2,3) (1,2,3)"
    s = list(iterable)
    return chain.from_iterable(combinations(s, r) for r in range(len(s)+1))

def make_directory(name):
    logger.info(f"Making directory: {name}")
    try:
        os.makedirs(name, exist_ok=True)
    except:
        logger.error(f"Failed to make directory {name}")

########################## ANALYSIS FUNCTIONS ########################################

def singe_analysis(raw_data, stats_file, plot_title, fig_file):
    data = np.genfromtxt(raw_data,delimiter=',')
    
    with open(stats_file, 'w') as f:
        if data.size > 1:
            f.write("n: " + str(len(data)) + "\n")
            f.write("mean: " + str(np.mean(data)) + "\n")
            f.write("standard deviation: " + str(np.std(data)) + "\n")
            f.write("variance: " + str(np.var(data)) + "\n")
            f.write("max: " + str(max(data)) + "\n")
            f.write("min: " + str(min(data)) + "\n")
            _ = plt.hist(data, bins=25)
        else:
            f.write("n: 1\n")
            f.write("mean: " + str(data) + "\n")
            f.write("standard deviation: 0\n")
            f.write("variance: 0\n")
            f.write("max: " + str(data) + "\n")
            f.write("min: " + str(data) + "\n")
            _ = plt.hist([data], bins=25)

    plt.xlabel("Time [s]")
    plt.ylabel("Frequency")
    plt.title(plot_title)
    plt.savefig(fig_file)

def get_improvement(hi, lo, performance):
    """
    Get improvement from two execution speeds.
    Arguments:
        hi, lo: (double) execution speeds
        performance: (bool) True if calculating performance increase, False if calculating time reduction.
    Returns: (double) Calculated improvement
    """

    return 100 * (hi - lo) / (lo if performance else hi)

def generate_data(input_dir, test_types, results_dir):
    data = {}
    input_filenames = sorted(os.listdir(input_dir))
    for f in input_filenames:
        try:
            data[f] = {}
            for t in test_types:
                #data[f][t] = (-1, [-1]) # Default throwaway values
                results_file = os.path.join(results_dir, f + "_" + t + ".csv")
                
                raw_data = np.genfromtxt(results_file,delimiter='\n')
                data[f][t] = (np.mean(raw_data), raw_data)
        except FileNotFoundError:
            print(f"Unable to find {results_file}")
            print(f"Skipping {f}")
            del data[f]
    return data

def generate_txt(data, results_dir):
    """
    Generate output .txt file
    Arguments:
        data = {filename: (average execution time, [raw data])}
    """
    for f in data.keys():
        native_comp_p = get_improvement(data[f]["native"][0], data[f]["nativesimd"][0], True)
        wasm2c_comp_p = get_improvement(data[f]["wasm"][0], data[f]["wasmsimd"][0], True)

        simd2c_comp_p = get_improvement(data[f]["wasmsimd"][0], data[f]["nativesimd"][0], True)
        no_simd2c_comp_p = get_improvement(data[f]["wasm"][0], data[f]["native"][0], True)

        native_comp_t = get_improvement(data[f]["native"][0], data[f]["nativesimd"][0], False)
        wasm2c_comp_t = get_improvement(data[f]["wasm"][0], data[f]["wasmsimd"][0], False)

        simd2c_comp_t = get_improvement(data[f]["wasmsimd"][0], data[f]["nativesimd"][0], False)
        no_simd2c_comp_t = get_improvement(data[f]["wasm"][0], data[f]["native"][0], False)

        results_for_f = os.path.join(results_dir, f + "_analysis_comparative_results.txt")
        with open(results_for_f, 'w') as compout:
            compout.write("averages: \n")
            compout.write("  native without sse2    : " + str(data[f]["native"][0]) + "\n")
            compout.write("  native with sse2       : " + str(data[f]["nativesimd"][0]) + "\n")
            compout.write("  wasm2c without simd128 : " + str(data[f]["wasm"][0]) + "\n")
            compout.write("  wasm2c with simd128    : " + str(data[f]["wasmsimd"][0]) + "\n")
            compout.write("\n")
            compout.write("performance increase percentage [100 * (hi - lo) / lo]: \n")
            compout.write("  native without sse2 -> native with sse2       : " + str(native_comp_p) + "\n")
            compout.write("  wasm2c without simd128 -> wasm2c with simd128 : " + str(wasm2c_comp_p) + "\n")
            compout.write("  wasm2c with simd128 -> native with sse2       : " + str(simd2c_comp_p) + "\n")
            compout.write("  wasm2c without simd128 -> native without sse2 : " + str(no_simd2c_comp_p) + "\n")
            compout.write("\n")
            compout.write("time reduction percentage [100 * (hi - lo) / hi]: \n")
            compout.write("  native without sse2 -> native with sse2       : " + str(native_comp_t) + "\n")
            compout.write("  wasm2c without simd128 -> wasm with simd128   : " + str(wasm2c_comp_t) + "\n")
            compout.write("  wasm2c with simd128 -> native with sse2       : " + str(simd2c_comp_t) + "\n")
            compout.write("  wasm2c without simd128 -> native without sse2 : " + str(no_simd2c_comp_t) + "\n")

def generate_plt(data, results_dir):
    """
    Generate output histogram .png file
    Arguments:
        data = {filename: (average execution time, [raw data])}
    """
    for f in data.keys():
        if data[f]["native"][1].size > 1:
            plt.hist(data[f]["native"][1], "auto", alpha=0.5, label="Native", edgecolor="black")
        if data[f]["nativesimd"][1].size > 1:
            plt.hist(data[f]["nativesimd"][1], "auto", alpha=0.5, label="Native SIMD", edgecolor="black")
        if data[f]["wasm"][1].size > 1:
            plt.hist(data[f]["wasm"][1], "auto", alpha=0.5, label="WASM", edgecolor="black")
        if data[f]["wasmsimd"][1].size > 1:
            plt.hist(data[f]["wasmsimd"][1], "auto", alpha=0.5, label="WASMSIMD", edgecolor="black")
        
        plt.xlabel("Time [s]")
        plt.ylabel("Frequency")
        plt.legend(loc='upper left', fontsize='small')
        plt.title(f"Comparison of Decoding Speeds for {f}")
        plt_file_name = os.path.join(results_dir, f + "_analysis_comparison_new.png")
        plt.savefig(plt_file_name)
        plt.close()

def generate_bar(data, results_dir, test_types, title):
    """
    Generate output bar chart .png file
    Arguments:
        data = {filename: (average execution time, [raw data])}
    """
    plt_file_name = os.path.join(results_dir, "unified_analysis_bar_chart.png")
    data_file_name = os.path.join(results_dir, "unified_analysis_data.txt")

    test_type_colors = {"native_unchanged": "c", "nativesimd_unchanged": "m", "native": "r", "nativesimd": "g", "wasm": "b", "wasmsimd": "y"}

    data_file = open(data_file_name, 'w')

    fig = plt.figure(figsize=(30,12))
    gs = fig.add_gridspec(1, len(data.keys()), hspace=0, wspace=0)
    subplots = gs.subplots(sharex='col', sharey='row')
    subplot_idx = 0
    for f in data.keys():
        print(f)
        x_axis = test_types[:len(data[f])] # Cut out data tests that may not exist
        y_axis = np.zeros(len(data[f]))
        err_val = np.zeros(len(data[f]))
        yaxis_str = ""
        err_str = ""
        for i in range(len(data[f].values())):
            y_axis[i] = round(data[f][x_axis[i]][0],4)
            err_val[i] = np.std(data[f][x_axis[i]][1], ddof=1) / np.sqrt(np.size(data[f][x_axis[i]][1]))
            yaxis_str += str(y_axis[i]) + ","
            err_str += str(err_val[i]) + ","
        # Trim trailing comma
        yaxis_str = yaxis_str[:-1]
        err_str = err_str[:-1]

        xax = ",".join(x_axis) + "," + "_errorbar,".join(x_axis) + "_errorbar"
        print(xax)
        print(yaxis_str)
        print(err_str)

        data_file.write(xax+ "\n")
        data_file.write(yaxis_str + ",")
        data_file.write(err_str + "\n")

        if len(data.keys()) > 1:
            subplots[subplot_idx].bar(x_axis, y_axis, yerr=err_val, align='center', alpha=0.5, ecolor='black', capsize=10, color=test_type_colors.values())
            for i in range(len(x_axis)):
                subplots[subplot_idx].text(i, y_axis[i], y_axis[i], rotation=60, rotation_mode='anchor')
            subplots[subplot_idx].set(xlabel=f)
            subplots[subplot_idx].axes.get_xaxis().set_ticks([])
            subplot_idx += 1
        else:
            # If only 1 file, then there are no subplots - it's just 1
            if np.logical_or.reduce(np.isnan(err_val)):
                subplots.bar(x_axis, y_axis, align='center', alpha=0.5, ecolor='black', capsize=10, color=test_type_colors.values())
            else:
                subplots.bar(x_axis, y_axis, yerr=err_val, align='center', alpha=0.5, ecolor='black', capsize=10, color=test_type_colors.values())
            
            for i in range(len(x_axis)):
                subplots.text(i, y_axis[i], y_axis[i], rotation=60, rotation_mode='anchor')
            subplots.set(xlabel=f)
            subplots.axes.get_xaxis().set_ticks([])
    
    for ax in fig.get_axes():
        ax.label_outer()
    if len(data.keys()) > 1:
        subplots[0].set(ylabel="Time [s]")
    else:
        subplots.set(ylabel="Time [s]")
    labels = list(test_type_colors.keys())
    handles = [plt.Rectangle((0,0),1,1, color=test_type_colors[label], alpha=0.5) for label in labels]
    if title != "":
        plt.title(f"{title}: Comparison of Decoding Speeds (total time for 100 decodes)")
    else:
        plt.title("Comparison of Decoding Speeds (total time for 100 decodes)")
    plt.legend(handles, labels, loc="upper left")
    plt.savefig(plt_file_name)
    plt.close()
    data_file.close()
    print(f"Plot saved to {plt_file_name}")
    print(f"Data saved to {data_file_name}")

######################## BUILD FUNCTIONS ######################################

def build_library(flags):
    logger.info("Building Library")

    env = os.environ.copy()
    env["WASM_COMPILER_DEFINES"] = flags

    logger.info(f"Using WASM_COMPILER_DEFINES: {flags}")

    p = run(["./build.sh"], cwd="../", env=env, stdout=PIPE, stderr=PIPE)

    if p.returncode != 0:
        logger.error("Failed to build library")
        logger.error(p.stdout)
        logger.error(p.stderr)
        return 1
    
    return 0

def build_bin():
    logger.info("Building Binary")

def run_decode_webp(work_dir, ver, image_path, iter_amount, decode_count, title):
    # Returns the time

    prog = f"{work_dir}/decode_webp_{ver}"
    out_csv = f"{work_dir}/{image_path}_{ver}.csv"
    out_ppm = f"{work_dir}/{image_path}_{ver}.ppm"

    for _ in range(iter_amount):
        p = run([prog, image_path, out_csv, out_ppm, decode_count], stdout=PIPE, stderr=PIPE)

    out_stats = f"{work_dir}/{image_path}_{ver}_stats.txt"
    out_fig   = f"{work_dir}/{image_path}_{ver}_stats.png"

    singe_analysis(out_csv, out_stats, title, out_fig)

    return 5.0

def gen_title(config):
    result = "baseline"
    for k in ABLATION_PARAMS.keys():
        if config[k] == 1:
            result += f"_{k}"
    return result

def mode_build(args):
    configs = list(powerset(len(ABLATION_PARAMS.keys())))
    for c in configs:
        flags = ""
        for k in ABLATION_PARAMS.keys():
            if k in c:
                flags += ""




def mode_analyze(args):
    pass

def mode_test(args):
    # Get flags
    
    logging.basicConfig(filename='ablation.log', level=logging.ERROR)

    configs = list(powerset(len(ABLATION_PARAMS.keys())))
    random.shuffle(configs)

    logging.info(f"Running the following combinations: {str(configs)}")

    # Want something like 
    # {"bitsize": 0, "directcall": 1, "generictree": 0", "alias": 1}
    # and all the different permutations of it for each 

    for c in configs:
        flags = " ".join(c)
        
        title = gen_title(flags)

        logging.info(f"Running configuration: {flags}")

        bin_versions = BINARIES[::]
        random.shuffle(bin_versions)

        for ver in bin_versions:
            #t = run_decode_webp(work_dir, ver, image_path, iter_amount, decode_count, title)
            print(ver, title, flags)


def main():
    args = parser.parse_args()
    
    if args.mode == "build":
        mode_build(args)
    elif args.mode == "analyze":
        mode_analyze(args)
    else:
        mode_test(args)

if __name__ == "__main__":
    main()


