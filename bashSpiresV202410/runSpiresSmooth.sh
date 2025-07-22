#!/bin/bash
#
# script to run job array to generate spires gap-filled cubes for a given tile
# and water year.
#
# Read bash/configurationForHelp.sh for all options and arguments.
#
#SBATCH --constraint=spsc
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=spiSmooC
defaultSlurmArrayTaskId=292001
expectedCountOfArguments=
inputDataLabels=(modisspiresfill)
outputDataLabels=(modisspiressmoothbycell)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=0
thisSequence=001-036
thisSequenceMultiplierToIndices=1
thisMonthWindow=12

# Matlab package paths added.
matlabPackages=(parBal spiresCore spiresGeneral spiresModisHdf spiresTimeSpace)

source bash/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

source bash/toolsMatlab.sh

# Matlab.
########################################################################################
read -r -d '' matlabString << EOM

clear;
try;
  ${packagePathInstantiation}
  ${modisDataInstantiation}
  ${waterYearDateInstantiation}
  ${espEnvInstantiation}
  rng(${SLURM_ARRAY_TASK_ID});
  pauseTime = mtimes(rand(1), 120);
  fprintf('\nParallel pool launched in %.0f secs...\n', pauseTime);
  pause(pauseTime);
  espEnv.configParallelismPool(${parallelWorkersNb});
  region = Regions(${inputForRegion});
  smoothSPIREScube20240204(region, ${cellIdx}, waterYearDate, 0, ${thisMode});
${catchExceptionAndExit}

EOM

# pause(mtimes(rand(1), 60)); Allows to prevent all smooth jobs starting parallel pools
# in the
# same time in blanca, that creates strain on /home/ and /projects/, which can make the
# pool not start.
# NB: didn't figure out how to escape * character.

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh
