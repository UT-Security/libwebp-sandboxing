#!/usr/bin/python3
import numpy as np
import sys
import os
import matplotlib.pyplot as plt

input_dir = "inputs"
results_dir = "results"
testname = ""
test_types = ["native_unchanged", "nativesimd_unchanged", "native", "nativesimd", "wasm", "wasmsimd", "wasmsimd_emscripten"]
test_type_colors = {"native_unchanged": "c", "nativesimd_unchanged": "m", "native": "r", "nativesimd": "g", "wasm": "b", "wasmsimd": "y", "wasmsimd_emscripten": "purple"}
MIN = 0.0
MAX = 20.0
ITERATIONS = 100.0

def get_improvement(hi, lo, performance):
  """
  Get improvement from two execution speeds.
  Arguments:
    hi, lo: (double) execution speeds
    performance: (bool) True if calculating performance increase, False if calculating time reduction.
  Returns: (double) Calculated improvement
  """

  return 100 * (hi - lo) / (lo if performance else hi)

def generate_data():
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
      #print(f"Unable to find {results_file}")
      #print(f"Skipping {f}")
      del data[f]


  return data

def generate_txt(data):
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

def generate_plt(data):
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

def generate_bar(data):
  """
  Generate output bar chart .png file
  Arguments:
    data = {filename: (average execution time, [raw data])}
  """
  plt_file_name = os.path.join(results_dir, "unified_analysis_bar_chart.png")
  data_file_name = os.path.join(results_dir, "unified_analysis_data.txt")

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
  if testname != "":
    plt.title(f"{testname}: Comparison of Decoding Speeds (total time for 100 decodes)")
  else:
    plt.title("Comparison of Decoding Speeds (total time for 100 decodes)")
  plt.legend(handles, labels, loc="upper left")
  plt.savefig(plt_file_name)
  plt.close()
  data_file.close()
  print(f"Plot saved to {plt_file_name}")
  print(f"Data saved to {data_file_name}")
    
def main():
  global input_dir
  global results_dir
  global testname
  if len(sys.argv) > 2:
    input_dir = sys.argv[1]
    results_dir = sys.argv[2]
    print(f"Using input {input_dir} and results {results_dir}")
    if len(sys.argv) > 3:
      testname = sys.argv[3]
      print(f"Using testname {testname}")

  data = generate_data()
  generate_txt(data)
  generate_plt(data)
  plt.close()
  generate_bar(data)

if __name__ == "__main__":
  main()
