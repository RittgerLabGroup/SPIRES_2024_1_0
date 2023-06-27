#!/bin/bash
#
# script to generate all historical geotiffs for westernUS in a certain projection or in
# the geographic coordinate system. SIER_163.
#

#SBATCH --qos normal
#SBATCH --partition amilan
#SBATCH --job-name histGeot
#SBATCH --account=ucb-general
#SBATCH --time=00:45:00
#SBATCH --ntasks-per-node=9
#SBATCH --nodes=1
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
# Do not set --mail-user, let it default to the caller
# It can also be over-written at the command line
#SBATCH --mail-type FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=2023

# Example runs:
# - Dailey EPSG 3857: for year in {2023..2023}; do for month in 5; do sbatch --job-name HistGeon-${year}-${month} --time=00:05:00 --ntasks-per-node=10 --array=${year} ./scripts/runHistoricGeotiffs.sh -L v2023.1 westernUS 3857 ${month} 16 0; done; done;
# - Historic EPSG 4326: for year in {2020..2022}; do for month in 3 6 9 12; do sbatch --job-name HistGeom-${year}-${month} --time=00:40:00 --ntasks-per-node=9 --array=${year} ./scripts/runHistoricGeotiffs.sh -L v2023.1 westernUS 4326 ${month} 31 3; done; done
# - Historic EPSG 5070: for year in {2000..2007}; do for month in 3 6 9 12; do sbatch --job-name HistGeom-${year}-${month} --time=00:40:00 --ntasks-per-node=16 --array=${year} ./scripts/runHistoricGeotiffs.sh -L v2023.1 westernUS 5070 ${month} 31 3; done; done

# Functions.
#--------------------------------------------------------------------------
usage() {
    echo "" 1>&2
    echo "Usage: ${PROGNAME} [-h] [-L LABEL] [-A LABEL_ANCILLARY] REGIONNAME EPSG MONTH DAY WINDOW" 1>&2
    echo "  Generates Geotiffs of REGIONNAME for this WATERYR in SLURM_ARRAY_TASK_ID" 1>&2
    echo "  WaterYear Starts Oct, 1st of SLURM_ARRAY_TASK_ID -1 and ends" 1>&2
    echo "      Sept, 31 of SLURM_ARRAY_TASK_ID." 1>&2
    echo "Options: "  1>&2
    echo "  -h: display help message and exit" 1>&2
    echo "  -L LABEL: string with version label for directories" 1>&2
    echo "     e.g. for operational processing, use -L v2023.x" 1>&2
    echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
    echo "     e.g. for operational processing, use -A v3" 1>&2
    echo "Arguments: " 1>&2
    echo "  REGIONNAME: Name of the region or tile. E.g. westernUS." 1>&2
    echo "      Mosaics must have been generated for this region/tile." 1>&2
    echo "  EPSG: Projection or geographic system EPSG Code. E.g. 4326." 1>&2
    echo "      NB: Some codes don't work depending on Matlab version." 1>&2
    echo "      NB: For geographic system only accepts 4326. Otherwise" 1>&2
    echo "      will produce an error/wrong data at some point." 1>&2
    echo "  MONTH: Month of the last day we want geotiffs. E.g. 9." 1>&2
    echo "  DAY: Last day in the month we want geotiffs. E.g. 30." 1>&2
    echo "  WINDOW: Number of months before the last day, for which" 1>&2
    echo "      we want geotiffs. E.g. 12 if we want the full wateryear." 1>&2
    echo "      NB: Geotiff generation is long due to reprojection. It may" 1>&2
    echo "      be worth to split a wateryear in several sets of months" 1>&2
    echo "      to be certain that generation takes < 24 h." 1>&2
    echo "      In that case, WINDOW could be 6 e.g." 1>&2
    echo "Output: " 1>&2
    echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
    echo "Notes: " 1>&2
    echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
    echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
    echo "  is assumed to exist" 1>&2
}

# Core script.
#--------------------------------------------------------------------------
# Initialize variables, option setting.
# Grab the full path to this script and pwd to its directory.
# depends on whether it's running as sbatch job.
scriptId=histGeot
defaultSlurmArrayTaskId=$(date +%Y)
expectedCountOfArguments=5
# Output file. This variable is not transferred from sbatch to bash, so we define it.
# NB: to split a string, don't put indent otherwise there will be two variables.
SBATCH_OUTPUT="/scratch/alpine/${USER}/slurm_out/${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_"\
"${SLURM_ARRAY_TASK_ID}.out"


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
tileId=$1
regionName=$tileId
geotiffEPSG=$2
month=$3
day=$4
window=$5

inputForESPEnv="modisData = modisData"
inputForRegion="'"${regionName}"', '"${regionName}"_mask', espEnv, modisData"

source scripts/toolsMatlab.sh

matlab -nodesktop -nodisplay -r "clear; "\
"try; "\
"modisData = MODISData(${inputForModisData}); "\
"espEnv = ESPEnv(${inputForESPEnv}); "\
"region = Regions(${inputForRegion}); "\
"waterYearDate = WaterYearDate(datetime(${SLURM_ARRAY_TASK_ID}, "\
"       ${month}, min(eomday(${SLURM_ARRAY_TASK_ID}, ${month}), ${day})), ${window}); "\
"region.writeGeotiffs(NaN, waterYearDate, ${geotiffEPSG}); "\
"catch e; "\
"fprintf('%s: %s\n', e.identifier, e.message); "\
"exit(-1); "\
"end; "\
"exit(0);" || error_exit "Line $LINENO: matlab error."

source scripts/toolsStop.sh
