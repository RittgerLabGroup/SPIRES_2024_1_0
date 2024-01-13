#!/bin/bash
#
# Update log with CPU and memory efficiency, once the slurm job is achieved
# (the ones we get when running are unreliable) SIER_322.
#
# Parameters
# ----------
# $1: int. Slurm job id.
# $2: char. Log filepath.

#SBATCH --job-name toolsJobA
#SBATCH --time 00:00:15
#SBATCH --ntasks-per-node 1
#SBATCH --nodes=1
# Set the system up to notify upon completion
# Do not set --mail-user, let it default to the caller
# It can also be over-written at the command line
#SBATCH --mail-type FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT

source scripts/toolsJobs.sh

printf "Environment variables before export:\n--------------------------------------\n\n"
env
export SLURM_EXPORT_ENV=ALL
printf "\n--------------------------------------\n\nEnvironment variables after export:\n--------------------------------------\n\n"
env
printf "\n--------------------------------------\n\n"

thatJobId=$1
thatLog=$2
ml slurmtools
printf "Update ${thatLog} for job ${thatJobId}\n"

# The following with seff doesn't systematically work on Blanca nodes, and RC team
# doesn't know exactly why, and me neither, despite some research.
# I replaced the code using seff by a more convoluted code using sacct directly.

# Former code:
#text=$(printf %q "$(seff ${thatJobId} | grep "CPU Efficiency" | \
#    awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf "; ")
#text=${text}$(printf %q "$(seff ${thatJobId} | grep "Memory Efficiency" \
#    | awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf ";")

# New code:
sacct1=($(sacct --format AllocCPUS,ReqMem,TotalCPU,Elapsed -j ${thatJobId} | sed '3q;d' | sed 's/ \{1,\}/;/g' | tr ";" "\n"))
sacct2=($(sacct --format MaxRSS,Ntasks -j ${thatJobId} | sed '4q;d' | sed 's/ \{1,\}/;/g' | tr ";" "\n"))
# NB: We could also retrieve State and ExitCode (in a future dev).                 @todo
# sacct --format JobName,User,Group,State,Cluster,AllocCPUS,REQMEM,TotalCPU,Elapsed,MaxRSS,ExitCode,NNodes,NTasks -j 3058775
# gives three lines and sacct1 and sacct2 get variable values into arrays to be handled
# below.

# CPU efficiency.
cpuEfficiency=$(get_time_in_seconds ${sacct1[2]})
cpuElapsed=$(get_time_in_seconds ${sacct1[3]})
cpuEfficiency=$(echo "scale=10; ${cpuEfficiency} / ${cpuElapsed} / ${sacct1[0]} * 100 " | bc)
text="$(printf "%0.0f%%; " ${cpuEfficiency})"

# Memory efficiency.
memEfficiency=$(get_mem_in_Gb ${sacct2[0]})
memEfficiency=$(echo "scale=10; ${memEfficiency} * ${sacct2[1]} " | bc)
memThatWasRequired=$(get_mem_in_Gb ${sacct1[1]})
memEfficiency=$(echo "scale=10; ${memEfficiency} / ${memThatWasRequired} * 100 " | bc)
text="$text$(printf "%0.0f%%;" ${memEfficiency})"

sed -ri "s/(; end:[^;]*;[^;]*; )[^;]*;[^;]*;/\1${text}/" ${thatLog}
printf "end:DONE ${thatLog}\n"
