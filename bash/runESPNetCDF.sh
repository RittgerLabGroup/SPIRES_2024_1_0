#!/bin/bash
#
# generate the NetCDF from the mosaic tile .mat files for a tile and a waterYearDate.
#
# For 1 tile 1 year, runs in 2-6 mins on 2 cores - 8G
#
# Arguments:
#
#SBATCH --job-name netcd
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --time 00:15:00
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=2023
#   List of years of the waterYeardates until which we want the generation done.
#   E.g. if we want generation for oct to dec 2019, should be 2019.
#       if we want generation for oct to sept 2020, should be 2020.

# Functions.
#---------------------------------------------------------------------------------------
usage() {
    echo "" 1>&2
    echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY] [-h] [-L LABEL] " 1>&2
    echo "  [-O outputLabel] [-x scratchPath] REGIONNAME MONTH DAY MONTHWINDOW" 1>&2
    echo "  Job array to update REGIONNAME daily variable files for a set of water years" 1>&2
    echo "Options: "  1>&2
    echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
    echo "     e.g. for operational processing, use -A v3.1 for westernUS " 1>&2
    echo "     or -A v3.2 for USAlaska" 1>&2
    echo "  -h: display help message and exit" 1>&2
    echo "  -L LABEL: string with version label for directories" 1>&2
    echo "     e.g. for operational processing, use -L v2023.x" 1>&2
    echo "  -O outputLabel: string with version label for output files" 1>&2
    echo "     If -O not precised, LABEL is used for both input and output files" 1>&2
    echo "  -x scratchPath: string indicating where is the scratch, where are " 1>&2
    echo "     temporarily input and ouput files, and permanently the logs. " 1>&2
    echo "Arguments: " 1>&2
    echo "  REGIONNAME : regionName " 1>&2
    echo "  MONTH : Month of waterYearDate (stop date month). E.g. 9" 1>&2
    echo "  DAY : Day of waterYearDate (stop date day). E.g. 30" 1>&2
    echo "  MONTHWINDOW : Period of calculation in months. E.g 12" 1>&2
    echo "Output: " 1>&2
    echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
    echo "Notes: " 1>&2
    echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
    echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
    echo "  is assumed to exist" 1>&2
    echo "  When calling with sbatch, set --job-name=upMos" 1>&2
    echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
    echo "  Run this script on the tiles before" 1>&2
    echo "    running it on big Regions (such as westernUS)." 1>&2
}

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
