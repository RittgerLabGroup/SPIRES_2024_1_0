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
#SBATCH --partition=amilan
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=2001-2021

# Functions.
#---------------------------------------------------------------------------------------
usage() {
    echo "" 1>&2
    echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY] [-h] [-L LABEL] " 1>&2
    echo " [-O outputLabel] [-x scratchPath] REGIONNAME" 1>&2
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
    echo "  REGIONNAME : regionName (tile id, e.g. h08v04) to update" 1>&2
    echo "Output: " 1>&2
    echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
    echo "Notes: " 1>&2
    echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
    echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
    echo "  is assumed to exist" 1>&2
    echo "  When calling with sbatch, set --job-name=SCD-regionName" 1>&2
    echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
}

 Core script.
#---------------------------------------------------------------------------------------
# Initialize variables, option setting.
# Grab the full path to this script
# depends on whether it's running as sbatch job
scriptId=scdInCub
defaultSlurmArrayTaskId=2022
expectedCountOfArguments=1

isBatch=
if [[ ${BASH_SOURCE} == *"slurm_script"* ]]; then
    # Running as slurm
    printf "Running as sbatch job...\n"
    PROGNAME=(`scontrol show job ${SLURM_JOB_ID} | grep Command | tr -s ' ' | cut -d = -f 2`)
    isBatch=1
else
    printf "Not running as sbatch...\n"
    PROGNAME=${BASH_SOURCE[0]}
fi
cd "$(dirname "${PROGNAME}")"
thisScriptDir=$(pwd)
printf "Script directory: ${thisScriptDir}\n"
#Go to parent of this script, so that correct pathdef.m file is used
cd ..
source scripts/toolsStart.sh

# Argument setting
regionName=$1
waterYear=${SLURM_ARRAY_TASK_ID}

inputForESPEnv="modisData = modisData"
inputForRegion="'"${regionName}"', '"${regionName}"_mask', espEnv, modisData"
inputForWaterYearDate="${waterYear}, modisData.getFirstMonthOfWaterYear('"${regionName}"'), "\
"WaterYearDate.yearMonthWindow"
echo "${PROGNAME}: input for waterYearDate: ${inputForWaterYearDate}"

source scripts/toolsMatlab.sh

# Matlab.
#---------------------------------------------------------------------------------------
matlabString="clear; "\
"try; "\
"${modisDataInstantiation}"\
"${espEnvInstantiation}"\
"region = Regions(${inputForRegion}); "\
"waterYearDate = WaterYearDate.getLastWYDateForWaterYear(${inputForWaterYearDate}); "\
"variables = Variables(region); "\
"variables.calcSnowCoverDays(waterYearDate); "\
"catch e; "\
"fprintf('%s: %s\n', e.identifier, e.message); "\
"exit(-1); "\
"end; "\
"exit(0);"

echo "\n"$matlabString
matlab -nodesktop -nodisplay -r "${matlabString}" || error_exit "Line $LINENO: matlab error."

source scripts/toolsStop.sh
