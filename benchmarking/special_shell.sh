# Install dependencies
sudo apt install cpuset cpufrequtils zip

freq=2600MHz

# disable hyperthreads
sudo bash -c "echo off > /sys/devices/system/cpu/smt/control"
# set cpu freq on CPU 2
sudo cpufreq-set -c 2 -g performance
sudo cpufreq-set -c 2 --min ${freq} --max ${freq}
# set cpu shield on CPU 2
sudo cset shield -c 2 -k on
sudo cset shield -e sudo -- -u "$USER" env "PATH=$PATH" ./benchmark_ablation.sh

# You are in a subshell now, run your benchmark here

# Ctrl+D to close the current subshell
# Enable hyperthreading
sudo bash -c "echo on > /sys/devices/system/cpu/smt/control"
# Reset cpu frequency on CPU 2 by copying policy from cpu 0
POLICYINFO=($(cpufreq-info -c 0 -p)) && \
sudo cpufreq-set -c 2 -g ${POLICYINFO[2]} && \
sudo cpufreq-set -c 2 --min ${POLICYINFO[0]}MHz --max ${POLICYINFO[1]}MHz

echo "Done :)"