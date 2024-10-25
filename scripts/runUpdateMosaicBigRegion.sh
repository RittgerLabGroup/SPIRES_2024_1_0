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
#SBATCH --job-name upMos
#SBATCH --time=01:15:00
#SBATCH --ntasks-per-node=32
#   Rather use 5-10 when submitting for modis tiles.
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=5
  # regionId. Should have only 1 id right now.

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY]" 1>&2
  echo "  [-h] [-L LABEL] " 1>&2
  echo "  [-O outputLabel] [-x scratchPath]" 1>&2
  echo "  Job array to update REGIONNAME daily variable files for a set of water years" 1>&2
  echo "Options: "  1>&2
  echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
  echo "     e.g. for operational processing, use -A v3.1 for westernUS " 1>&2
  echo "     or -A v3.2 for USAlaska" 1>&2
  echo "  -c filterConfId: int id of the region configuration to use to carry out " 1>&2
  echo "     calculations. If not precised, use the configuration indicated " 1>&2
  echo "     in configuration_of_regions.csv" 1>&2
  echo "  -h: display help message and exit" 1>&2
  echo "  -L LABEL: string with version label for directories" 1>&2
  echo "     e.g. for operational processing, use -L v2023.x" 1>&2
  echo "  -O outputLabel: string with version label for output files" 1>&2
  echo "     If -O not precised, LABEL is used for both input and output files" 1>&2
  echo "  -x scratchPath: string indicating where is the scratch, where are " 1>&2
  echo "     temporarily input and ouput files, and permanently the logs. " 1>&2
  echo "Arguments: " 1>&2
  echo "  None." 1>&2
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

source scripts/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting
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
  region = Regions(${inputForRegion});
  waterYearDate = WaterYearDate(${inputForWaterYearDate});
  mosaic = Mosaic(region);
  dataLabel = 'modspiresdaily';
  if ismember(region.name, {'westernUS'});
    dataLabel = 'VariablesMatlab';
  end;
  mosaic.buildTileSet(waterYearDate, dataLabel);
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source scripts/toolsStop.sh

# SIER_201 remove the tile h07v03 for USAlaska tileset because lack JPL data from
# 2005 to 2018.
