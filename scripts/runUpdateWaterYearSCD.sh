#!/bin/bash
#
# script to run job array to update the snow cover days (SCD) variables in the
# STC Interp month cubes for a given region and water year
# caller can use sbatch argument '--job-name NEWNAME' to include regionName in
# output file
#
# Set up the SBATCH nodes/ntasks-per-node for 1 matlab job per water year
# that only needs 1 task
#
# Arguments:
#
#SBATCH --export=NONE
#SBATCH --qos normal
# Caller can override this with regionName
#SBATCH --job-name SCD-regionName
#SBATCH --time=00:30:00
# Trial and error: memory requirements are large,
# this might need to change max number of tiles that
# can be processed this way
# Data for 5 westernUS tiles for WY=2001-2021 took
# up to 28 GB memory per tile/year
# matlab job uses parfor with nTiles workers
#SBATCH --ntasks-per-node=5
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=292
  # regionId.

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY] [-h] [-L LABEL] " 1>&2
  echo " [-O outputLabel] [-x scratchPath]" 1>&2
  echo "  Job array to update REGIONNAMES Interp STC cubes " 1>&2
  echo "  with SCD for complete water years" 1>&2
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
  echo "  None." 1>&2
  echo "Output: " 1>&2
  echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
  echo "Notes: " 1>&2
  echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
  echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
  echo "  is assumed to exist" 1>&2
  echo "  When calling with sbatch, set --job-name=SCD-regionName" 1>&2
  echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
}

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=scdInCub
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(VariablesMatlab)
outputDataLabels=(VariablesMatlab)
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
  ${modisDataInstantiation}
  ${espEnvInstantiation}
  region = Regions(${inputForRegion});
  waterYearDate = WaterYearDate(${inputForWaterYearDate});
  variables = Variables(region);
  variables.calcSnowCoverDays(waterYearDate);
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source scripts/toolsStop.sh
