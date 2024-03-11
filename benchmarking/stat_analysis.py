#!/usr/bin/python3
import numpy as np
import sys
import matplotlib.pyplot as plt

def main(rawdata, statsfile, plottitle, figfile):
  data = np.genfromtxt(rawdata,delimiter=',')
  
  with open(statsfile, 'w') as f:
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
  plt.title(plottitle)

  plt.savefig(figfile)

if __name__ == "__main__":
  main(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
