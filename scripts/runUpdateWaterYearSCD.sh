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
#SBATCH --time=01:00:00
# Trial and error: memory requirements are large,
# this might need to change max number of tiles that
# can be processed this way
# Data for 5 westernUS tiles for WY=2001-2021 took
# up to 28 GB memory per tile/year
# matlab job uses parfor with nTiles workers
#SBATCH --ntasks-per-node=32
#SBATCH --nodes=1
#SBATCH --partition=amilan
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --mail-user brodzik@colorado.edu
#SBATCH --array=2001-2021

# Grab the full path to this script
# depends on whether it's running as sbatch job
isBatch=
if [[ ${BASH_SOURCE} == *"slurm_script"* ]]; then
    # Running as slurm
    echo "Running as sbatch job..."
    PROGNAME=(`scontrol show job ${SLURM_JOB_ID} | grep Command | tr -s ' ' | cut -d = -f 2`)
    isBatch=1
else
    echo "Not running as sbatch..."
    PROGNAME=${BASH_SOURCE[0]}
fi
thisScriptDir="$( cd "$( dirname "${PROGNAME}" )" && pwd )"

usage() {
    echo "" 1>&2
    echo "Usage: ${PROGNAME} [-h] [-L LABEL] REGIONNAME" 1>&2
    echo "  Job array to update REGIONNAMES Interp STC cubes " 1>&2
    echo "  with SCD for complete water years" 1>&2
    echo "Options: "  1>&2
    echo "  -h: display help message and exit" 1>&2
    echo "  -L LABEL: string with version label for directories" 1>&2
    echo "     e.g. for operational processing, use -L v2023.x" 1>&2
    echo "Arguments: " 1>&2
    echo "  REGIONNAME : regionName to update" 1>&2
    echo "Output: " 1>&2
    echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
    echo "Notes: " 1>&2
    echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
    echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
    echo "  is assumed to exist" 1>&2
    echo "  When calling with sbatch, set --job-name=SCD-regionName" 1>&2
    echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
}

error_exit() {
    # Use for fatal program error
    # Argument:
    #   optional string containing descriptive error message
    #   if no error message, prints "Unknown Error"

    echo "${PROGNAME}: ERROR: ${1:-"Unknown Error"}" 1>&2
    exit 1
}

LABEL=

while getopts "hL:" opt
do
    case $opt in
	h) usage
	   exit 1;;
	L) LABEL="$OPTARG";;
	?) printf "Unknown option %s\n" $opt
	   usage
           exit 1;;
	esac
done

shift $(($OPTIND - 1))

[[ "$#" -eq 1 ]] || error_exit "Line $LINENO: Unexpected number of arguments."

REGIONNAME=$1

options=""
if [ $LABEL ]; then
    options="'label', '$LABEL'"
fi

module purge
ml matlab/R2021b
date

#Go to parent of this script, so that correct pathdef.m file is used
cd "${thisScriptDir}/../"

# Start the stopwatch
SECONDS=0

#Make a unique temporary directory for matlab job storage
myTmpDir=/scratch/alpine/${USER}/slurmTmp/$SLURM_ARRAY_JOB_ID-$SLURM_ARRAY_TASK_ID
mkdir -p $myTmpDir
export TMPDIR=$myTmpDir
export TMP=$myTmpDir

matlab -nodesktop -nodisplay -r "clear; "\
"try; "\
"espEnv = ESPEnv(); "\
"mData = MODISData($options); "\
"region = Regions('"${REGIONNAME}"', '"${REGIONNAME}"_mask', espEnv, mData); "\
"updateWaterYearSCDFor(region, "$SLURM_ARRAY_TASK_ID"); "\
"catch e; "\
"fprintf('%s: %s\n', e.identifier, e.message); "\
"exit(-1); "\
"end; "\
"exit(0);" || error_exit "Line $LINENO: matlab error."

#Clean up temporary directory for matlab job storage
echo "${PROGNAME}: Removing TMPDIR=$TMPDIR..."
rm -rf $TMPDIR

# Stop the stopwatch and report elapsed time
elapsedSeconds=$SECONDS
duration=$(TZ=UTC0 printf 'Duration: %(%H:%M:%S)T\n' "$elapsedSeconds")

thisDate=$(date)
echo "${PROGNAME}: Done on hostname=$thisHost on $thisDate [${duration}]"

