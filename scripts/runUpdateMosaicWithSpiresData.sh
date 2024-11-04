#!/bin/bash
#
# script to run job array to update all daily regionName mosaic files
#
# Set up the SBATCH nodes/ntasks-per-node for 1 matlab job, trial-and-error
# with top monitoring shows job currently
# only uses 1 task but needs up to 35GB memory and I can't seem to
# request only 1 task with this much memory
#
# Arguments:
#
#SBATCH --export=NONE
#SBATCH --qos normal
# Caller can override this job-name with specifics
#SBATCH --job-name mosSpi
#SBATCH --time=01:15:00
#SBATCH --ntasks-per-node=32
#   Rather use 5-10 when submitting for modis tiles.
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=2001-2023
#   List of years of the waterYeardates until which we want the generation done.
#   E.g. if we want generation for oct to dec 2019, should be 2019.
#       if we want generation for oct to sept 2020, should be 2020.

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY] [-h] [-L LABEL] " 1>&2
  echo "  [-O outputLabel] [-x scratchPath]" 1>&2
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
  echo "  None. " 1>&2
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
scriptId=moSpires
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(modisspiressmoothbycell)
outputDataLabels=(VariablesMatlab modspiresdaily vnpspiresdaily)
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

source scripts/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

source scripts/toolsMatlab.sh

# Matlab.
########################################################################################
read -r -d '' matlabString << EOM

clear;
try;
  ${packagePathInstantiation}
  ${modisDataInstantiation}
  ${espEnvInstantiation}
  espEnv.configParallelismPool(${parallelWorkersNb}); feature('numcores');
  region = Regions(${inputForRegion});
  waterYearDate = WaterYearDate(${inputForWaterYearDate});
  mosaic = Mosaic(region);
  inputDataLabel = 'modisspiressmoothbycell';
  if ismember(region.name, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'}) && ismember(modisData.versionOf.VariablesMatlab, {'v2024.0', 'v2024.0d')};
    mosaic.delete(waterYearDate);
    outputDataLabel = 'VariablesMatlab';
  else;
    outputDataLabel = 'modspiresdaily';
  end;
  mosaic.writeSpiresData(waterYearDate, inputDataLabel, outputDataLabel);
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source scripts/toolsStop.sh
