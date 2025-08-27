#!/bin/bash
#
# generate the output NetCDFs from  for a tile and a waterYearDate.
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
scriptId=daNetCDF
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(VariablesMatlab spiresdailytifsinu spiresdailymetadatajson)
outputDataLabels=(VariablesNetCDF outputnetcdf daacnetcdfv20220 daacnetcdfv202301)
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
  if (ismember('${regionName}', {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'}) && ismember(modisData.versionOf.VariablesMatlab, {'v2024.0', 'v2024.0d', 'v2024.1.0'})) || ismember(modisData.versionOf.VariablesMatlab, {'v2022.0', 'v2023.0d', 'v2023.0e', 'v2023.0f', 'v2023.0k', 'v2023.1'});
    inputDataLabel = 'VariablesMatlab';
    varName = '';
  else
    inputDataLabel = 'spiresdailytifsinu';
    varName = 'albedo_muZ_s';
  end;
  outputDataLabel = 'spiresdailynetcdf';
  if strcmp(modisData.versionOf.(inputDataLabel), 'v2022.0');
    outputDataLabel = 'daacnetcdfv20220';
    modisData.versionOf.(inputDataLabel) = 'v03';
    modisData.versionOf.(outputDataLabel) = 'v03';
    modisData.algorithm = 'stc';
  elseif ismember(modisData.versionOf.(inputDataLabel), {'v2023.0e', 'v2023.0.1'});
    outputDataLabel = 'daacnetcdfv202301';
    modisData.versionOf.(outputDataLabel) = 'v2023.0.1';
    modisData.algorithm = 'stc';
  elseif ismember(modisData.versionOf.(inputDataLabel), {'v2024.0d', 'v2024.1.0', 'v2025.0.1'})
    outputDataLabel = 'outputnetcdf';
    modisData.algorithm = 'spires';
  elseif ismember(modisData.versionOf.(inputDataLabel), {'v2023.0d', 'v2023.0f', 'v2023.0k', 'v2023.1', 'v2024.0'});
    outputDataLabel = 'VariablesNetCDF';
  end;
  ${waterYearDateInstantiation}
  ${espEnvInstantiation}
  espEnv.configParallelismPool(${parallelWorkersNb});
  region = Regions(${inputForRegion});
  theseDates = waterYearDate.getDailyDatetimeRange();
  parfor dateIdx = 1:length(theseDates);
    thisDate = theseDates(dateIdx);
    matFilePath = espEnv.getFilePathForDateAndVarName(region.name, ...
      inputDataLabel, thisDate, varName, '');
    netCDFFilePath = espEnv.getFilePathForDateAndVarName(region.name, ...
      outputDataLabel, thisDate, '', '');
    ESPNetCDF.generateNetCDFFromRegionAndMatFile( ...
      region, thisDate, matFilePath, netCDFFilePath);
  end;
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh
