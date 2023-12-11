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

thatJobId=$1
thatLog=$2
ml slurmtools
printf "Update ${thatLog} for job ${thatJobId}\n"
text=$(printf %q "$(seff ${thatJobId} | grep "CPU Efficiency" | \
    awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf "; ")
text=${text}$(printf %q "$(seff ${thatJobId} | grep "Memory Efficiency" \
    | awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf ";")
sed -ri "s/(; end:[^;]*;[^;]*; )[^;]*;[^;]*;/\1${text}/" ${thatLog}
printf "end:DONE ${thatLog}\n"
