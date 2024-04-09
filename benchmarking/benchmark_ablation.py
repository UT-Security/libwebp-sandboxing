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
logger = logging.getLogger(__name__)

parser = argparse.ArgumentParser(
                    prog='Libwebp Ablation Study')
parser.add_argument('-d', '--directory', help="The directory that contains the test files. If none is provided, then one will be generated.")
parser.add_argument('-t', '--title', help="The title of this experiment")
parser.add_argument('-l', '--build-library', action='store_true', help="Builds the library and the relevant binaries")
parser.add_argument('-b', '--build-only-binary', action='store_true', help="Only builds the relevant binaries. Useful for WABT modifications")
parser.add_argument('-i', '--iterations', help="Number of iterations for an individual experiment")
parser.add_argument('-n', '--number-of-decodes', help="Number of times to decode an individual image")
parser.add_argument('-m', '--image-directory', help="Directory where the input images are located")


# Build flags that enable the features we are ablating
ABLATION_PARAMS = ["-DWEBP_WASM_BITSIZE", "-DWEBP_WASM_HARDCODED_TREE", "-DWEBP_WASM_DIRECT_FUNCTION_CALL", "-DWEBP_WASM_ALIAS_VP8PARSEINTRAMODEROW"]

# Binaries to run
BINARIES = ['native_unchanged', 'nativesimd_unchanged', 'native', 'nativesimd', 'wasm', 'wasmsimd']

# From https://docs.python.org/3/library/itertools.html#itertools-recipes
def powerset(iterable):
    "powerset([1,2,3]) → () (1,) (2,) (3,) (1,2) (1,3) (2,3) (1,2,3)"
    s = list(iterable)
    return chain.from_iterable(combinations(s, r) for r in range(len(s)+1))


def build_library(flags):
    logger.info("Building Library")

    env = os.environ.copy()
    env["WASM_COMPILER_DEFINES"] = flags

    p = run(["./build.sh"], cwd="../", env=env, stdout=PIPE, stderr=PIPE)

    if p.returncode != 0:
        logger.error("Failed to build library")
        logger.error(p.stdout)
        logger.error(p.stderr)
        return 1
    
    return 0

def build_bin():
    logger.info("Building Binary")

def run_program(ver):
    # Returns the time
    return 5.0

def gen_title(title):
    pass

def main():
    args = parser.parse_args()

    # Get flags
    build_lib = args.build_library
    build_bin = args.build_only_binary or build_lib
    title = args.title
    dir = args.directory


    logging.basicConfig(filename='ablation.log', level=logging.ERROR)

    title = gen_title(title)

    configs = list(powerset(ABLATION_PARAMS))
    random.shuffle(configs)



    logging.info(f"Running the following combinations: {str(configs)}")

    # Print initial CSV line
    results = {}

    for c in configs:
        flags = " ".join(c)
        if build_lib:
            build_library(flags)
        
        if build_bin:
            build_bin()

        logging.info(f"Running configuration: {flags}")

        bins = BINARIES[::]
        random.shuffle(bins)

        for b in bins:
            t = run_program(b)




if __name__ == "__main__":
    main()


