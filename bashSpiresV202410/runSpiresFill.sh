#!/bin/bash
#
# script to run job array to generate spires cubes for a given tile
# and year.
#
# caller can use sbatch argument '--job-name NEWNAME' to include tileID in
# output file
#
# Set up the SBATCH nodes/ntasks-per-node for 1 matlab job that
# may need up to all the tasks on this node.
#
# Sizing: tests on march 2021 data for western US tiles indicate
# max RAM used was 77 GB. Last working versions on Summit asked for
# 20 nodes * 4.84GB RAM/node = 96.8 GB RAM and then STC parpool only
# requested 12 workers.
# (Trying to set matlab to 20 workers on alpine)
#
# So for Alpine, 3.74GB/node, let's try:
# 100 GB / 3.74 GB/node = 26.8 cores--30 tasks here
# 30 was good for 4/5 westernUS tiles, March 2021.
# For h09v05, it errored out with MaxRSS=97GB,
# so I reset to 32 tasks, ran again and then MaxRSS was only 51GB.
# Go figure.
#
# Some preliminary runs indicate that the HMA tiles only needed 2 hours for
# this processing, but the westernUS scripts were set to 6 hours.
# Leaving 6 hours here to avoid aggravation, but probably worth checking.
#
# Arguments:
#
#SBATCH --export=NONE
#SBATCH --qos normal
# Caller can override this with tileID
#SBATCH --job-name Spires
#SBATCH --time=23:00:00
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=292
#       id of the regionName (see toolsRegions.sh)

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY] [-c filterConfId]  " 1>&2
  echo "  [-d dateOfToday] [-h] [-L LABEL] " 1>&2
  echo "  [-O outputLabel] [-x scratchPath] [-w parallelWorkersNb]" 1>&2
  echo "  Job array to update REGIONNAME (tile) Gap and STC month cubes for a set of years" 1>&2
  echo "Options: "  1>&2
  echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
  echo "     e.g. for operational processing, use -A v3.1 for westernUS " 1>&2
  echo "     or -A v3.2 for USAlaska" 1>&2
  echo "  -c filterConfId: int id of the region configuration to use to carry out " 1>&2
  echo "     calculations. If not precised, use the configuration indicated " 1>&2
  echo "     in configuration_of_regions.csv" 1>&2
  echo "  -d dateOfToday: char, e.g. 20230930, force the date of today be " 1>&2
  echo "      distinct from today, help handling waterYearDate cap to today " 1>&2
  echo "      behavior when there's a stop of the input data flux. " 1>&2
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
  echo "  When calling with sbatch, set --job-name=runUpdateSTCMonthCubes-tileID" 1>&2
  echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
}

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
source scripts/toolsStop.sh

# "if ${nbDays} ~= 0; theseDates = theseDates((end - ${nbDays}):end); end; "

