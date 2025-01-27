#!/bin/bash
#
# Start logging and launch matlab configuration.
# NB: Not very clean, but allow to mutualize code for easier maintenance. SIER_322.

# Script core.
########################################################################################

# Start the stopwatch
SECONDS=0
set_slurm_array_task_id $defaultSlurmArrayTaskId
log_level_1 "start"

printf "$(pStart): Environment \$PATH: ${PATH}.\n"
printf "$(pStart): Loading matlab/R2021b...\n"
module purge
ml matlab/R2021b
printf "$(pStart): Environment \$PATH: ${PATH}.\n"

if [ -z $(echo ${PATH} | grep "/curc/sw/matlab/R2021b/bin") ]; then
  printf "$(pStart): Failed to load matlab/R2021b.\n"
  error_exit "Exit=1, matlab=no, Failed to load matlab/R2021b."
fi

#Make a unique temporary directory for matlab job storage
#Set TMPDIR/TMP to this location so job array uses it for tmp location
#tmpDir=${scratchPath}.matlabTmp/alpine-$SLURM_JOB_ID
tmpDir=${scratchPath}.matlabTmp/alpine-$(date +%s)
if [ ! -v ${slurmFullJobId} ]; then
  tmpDir=${scratchPath}.matlabTmp/alpine-${slurmFullJobId}
fi
mkdir -p $tmpDir
export TMPDIR=$tmpDir
export TMP=$tmpDir
matlabLaunched=1
printf "$(pStart): Matlab launched (?) with tmpDir=${tmpDir}\n"
