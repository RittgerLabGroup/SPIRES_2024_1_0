#!/bin/bash
#
# generate the NetCDF from the mosaic tile .mat files for a tile and a waterYearDate.
#
# Set up the SBATCH nodes/ntasks-per-node for 1 matlab job, trial-and-error
# with top monitoring shows job currently
# only uses 1 task but needs up to 35GB memory and I can't seem to
# request only 1 task with this much memory
#
# Arguments:
#
#SBATCH --qos normal
# Caller can override this job-name with specifics
#SBATCH --job-name netcd
#SBATCH --time=01:15:00
#SBATCH --ntasks-per-node=32
#   Rather use 5-10 when submitting for modis tiles.
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
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
#---------------------------------------------------------------------------------------
# Initialize variables, option setting.
# Grab the full path to this script
# depends on whether it's running as sbatch job
scriptId=daNetCDF
defaultSlurmArrayTaskId=2022
expectedCountOfArguments=4
inputDataLabels=(VariablesMatlab)
outputDataLabels=(VariablesNetCDF)

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
year=${SLURM_ARRAY_TASK_ID}
month=$2
day=$3
monthWindow=$4
countOfWorkers=10
# countOfWorkers should be an argument.                                            @todo

inputForRegion="'"${regionName}"', '"${regionName}"_mask', espEnv, modisData"
inputForWaterYearDate="datetime(${year}, ${month}, ${day}), "\
"region.getFirstMonthOfWaterYear(), ${monthWindow}"
echo "${PROGNAME}: waterYearDate: ${inputForWaterYearDate}"

source scripts/toolsMatlab.sh

# Matlab.
#---------------------------------------------------------------------------------------
matlabString=$(cat << EOF
    clear;
    try;
        ${modisDataInstantiation}
        ${espEnvInstantiation}
        region = Regions(${inputForRegion});
        waterYearDate = WaterYearDate(${inputForWaterYearDate});
        theseDates = waterYearDate.getDailyDatetimeRange();
        espEnv.configParallelismPool(${countOfWorkers});
        parfor dateIdx = 1:length(theseDates);
            thisDate = theseDates(dateIdx);
            matFilePath = 
                espEnv.getFilePathForDateAndVarName('${regionName}', 'VariablesMatlab', 
                thisDate, '', '');
            netCDFFilePath = espEnv.getFilePathForDateAndVarName('${regionName}', 
                'VariablesNetCDF', thisDate, '', '');
            ESPNetCDF.generateNetCDFFromRegionAndMatFile( 
                region, thisDate, matFilePath, netCDFFilePath);
        end;
    catch e;
        fprintf('%s: %s\n', e.identifier, e.message);
        exit(-1);
    end;
    exit(0);
EOF
)
#---------------------------------------------------------------------------------------
matlabString=$(echo $matlabString | tr -d '\n')

echo "\n"$matlabString
matlab -nodesktop -nodisplay -r "${matlabString}" || error_exit "Line $LINENO: matlab error."

source scripts/toolsStop.sh
