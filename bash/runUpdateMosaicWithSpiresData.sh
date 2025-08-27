#!/bin/bash
#
# script to run job array to update all daily regionName mosaic files
#
# Read bash/configurationForHelp.sh for all options and arguments.
#
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=moSpires
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(modisspiressmoothbycell spiresdailytifsinu)
outputDataLabels=(VariablesMatlab modspiresdaily vnpspiresdaily spiresdailytifsinu spiresdailymetadatajson)
# NB: Inconsistency here because spiresdailytifsinu will have the version of the outputLabel, not the inputLabel
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=0
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=12

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
  espEnv.configParallelismPool(${parallelWorkersNb}); feature('numcores');
  region = Regions(${inputForRegion});
  mosaic = Mosaic(region);
  if ismember(region.name, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'}) && ismember(modisData.versionOf.VariablesMatlab, {'v2024.0', 'v2024.0d'});
    mosaic.delete(waterYearDate);
    inputDataLabel = 'modisspiressmoothbycell';
    outputDataLabel = 'VariablesMatlab';
  elseif strcmp(modisData.inputProduct, 'mod09ga');
    inputDataLabel = 'modspirestimebycell';
    outputDataLabel = 'modspiresdaily';
  elseif strcmp(modisData.inputProduct, 'vnp09ga');
    inputDataLabel = 'vnpspirestimebycell';
    outputDataLabel = 'vnpspiresdaily';
  end;
  if ismember(modisData.versionOf.spiresdailytifsinu, {'v2024.0', 'v2024.0d', 'v2024.0f'});
    mosaic.writeSpiresData(waterYearDate, inputDataLabel, outputDataLabel);
  else;
    mosaic = [];
    mosaic = SpiresMosaicAlbedo(region);
    mosaic.mosaic(waterYearDate);
  end;
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh
