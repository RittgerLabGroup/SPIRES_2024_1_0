#!/bin/bash
#
# script to run job array to generate spires gap files for a given tile
# and period.
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
scriptId=spiFillC
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(mod09ga)
outputDataLabels=(modisspiresfill)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=0
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=2

# Matlab package paths added.
matlabPackages=(inpaintNans spiresCore spiresGeneral spiresMappping spiresMccm \
spiresModisHdf spiresRasterReprojection)

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
  espEnv.configParallelismPool(${parallelWorkersNb});
  region = Regions(${inputForRegion});
  theseDates = waterYearDate.getDailyDatetimeRange();
  matdates = arrayfun(@(x) datenum(x), theseDates);
  fill_and_run_modis20240204(region, matdates);
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh

# "if ${nbDays} ~= 0; theseDates = theseDates((end - ${nbDays}):end); end; "

