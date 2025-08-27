#!/bin/bash
#
# script to run job array to update all daily regionName mosaic files
#
# Read bash/configurationForHelp.sh for all options and arguments.
#
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

export SLURM_EXPORT_ENV=ALL

########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=daMosBig
defaultSlurmArrayTaskId=5
expectedCountOfArguments=
inputDataLabels=(VariablesMatlab modspiresdaily vnpspiresdaily)
outputDataLabels=(VariablesMatlab modspiresdaily vnpspiresdaily)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=1
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=12

source bash/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting
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
  region = Regions(${inputForRegion});
  mosaic = Mosaic(region);
  dataLabel = 'modspiresdaily';
  if ismember(region.name, {'westernUS'});
    dataLabel = 'VariablesMatlab';
  end;
  mosaic.buildTileSet(waterYearDate, dataLabel);
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh

# SIER_201 remove the tile h07v03 for USAlaska tileset because lack JPL data from
# 2005 to 2018.
