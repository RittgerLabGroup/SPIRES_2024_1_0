#!/bin/bash
#
# Initialize variables for other scripts launched in slurm and calling matlab.
# Also define the exit function.
# NB: Not very clean, but allow to mutualize code for easier maintenance. SIER_322.

# User should have set scriptId, which appears in logs.
if [ -z ${scriptId+x} ]; then
    scriptId="noName"
    printf "Warning: No script name set for logs.\n"
fi

# Functions.
#---------------------------------------------------------------------------------------
set_slurm_array_task_id(){
    # Default SLURM_ARRAY_TASK_ID to make it possible to run the script outside of
    # sbatch.
    # Parameters
    # ----------
    # $1: char/num. Default value for SLURM_ARRAY_TASK_ID.
    if [ -z ${SLURM_ARRAY_TASK_ID+x} ]; then
        SLURM_ARRAY_TASK_ID=$defaultSlurmArrayTaskId
        printf "Default set SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}\n";
    fi
}
get_start_stop_date_string(){
    # Get the string of start and stop dates to give as parameters for snowTodayStep1
    # and 2 to update the cubes with a 3-month window.
    # NB: Should be replaced by the use of the WaterYearDate class.                @todo
    yearStop=$(date +'%Y')
    monthStop=$(date +'%-m')
    dayStop=$(date +'%d')
    monthStart=$(( $monthStop - 2 ))
    if (( "$monthStart" < "1" )); then
        monthStart=$(( $monthStart + 12 ))
        yearStart=$(( $yearStop - 1 ))
    else
        yearStart=$yearStop
    fi
	echo "${yearStart} ${monthStart} ${yearStop} ${monthStop} ${dayStop}"
}
get_slurm_std_out_directory(){
    # Get the slurm std ouput file for the SLURM_JOB_ID.#
    # Parameters
    # ----------
    # $1: char/num. SLURM_JOB_ID.
    JOBID=$1
    MYSTDOUT=`scontrol show job ${JOBID} | grep StdOut | tr -s ' ' | cut -d = -f 2`
    MYSTDOUT=($MYSTDOUT)
    MYSTDOUT=$(dirname `${MYSTDOUT[0]}`)
    echo "${MYSTDOUT}"
}
log_level_1(){
    # Log.
    # Parameters
    # ----------
    # $1: char. Status to log.
    # $2: char. Message
    # NB: Formatting could be improved.
    printf "\ndate; dura.; script; job; task; region; status; hostname; CPU%%; "
    printf "mem%%; totalMem; cores; message\n"
    printf ".....................................................................\n"
    printf "$(date '+%m%dT%H:%M'); $(TZ=UTC0 printf '%(%H:%M)T' "$SECONDS"); "
    printf "${scriptId}; ${SLURM_JOB_ID}; $SLURM_ARRAY_TASK_ID; $regionName; "
    printf "${1}; $(hostname); "
    printf %q "$(seff ${SLURM_JOB_ID} | grep "CPU Efficiency" | awk '{print $3}' | sed s/.[0-9][0-9]//)";
    printf "; "
    printf %q "$(seff ${SLURM_JOB_ID} | grep "Memory Efficiency" | awk '{print $3}' | sed s/.[0-9][0-9]//)";
    printf "; "
    printf %q "$(seff ${SLURM_JOB_ID} | grep "Memory Efficiency" | awk '{print $5$6}')";
    printf "; "
    printf %q "$(seff ${SLURM_JOB_ID} | grep "Cores" | awk '{print $4}')"; printf "; "
    printf "${2}"
    printf "\n\n"
}

error_exit() {
    # Use for fatal program error
    # Argument:
    #   optional string containing descriptive error message
    #   if no error message, prints "Unknown Error"
    # Stop the stopwatch and report elapsed time
    log_level_1 "end:ERROR" "${1:-"Unknown Error"}"
    exit 1
}

# Script core.
#---------------------------------------------------------------------------------------
# Submit sbatch script updating the efficiency statistics at the end of the log file.
# NB: dependency should be afterany and not any, otherwise it would generate a killing
# lock.
printf "Github branch: $(git rev-parse --abbrev-ref HEAD)\n"
if [ -z isBatch ]; then
    echo "${PROGNAME}: SLURM_SCRATCH=$SLURM_SCRATCH"
    echo "${PROGNAME}: SLURM_JOB_ID=$SLURM_JOB_ID"
    sbatch --dependency=afterany:$SLURM_JOB_ID ./scripts/toolsJobAchieved.sh \
        $SLURM_JOB_ID $SBATCH_OUTPUT

    stdoutDir=$(get_slurm_std_out_directory ${SLURM_JOB_ID})
fi
set_slurm_array_task_id

# Caller script arguments.
LABEL="test"
VERSION_OF_ANCILLARY="v3.1"
noPipeline=
startyyyymmdd=
testing=
while getopts "A:hL:ns:t" opt
do
    case $opt in
    A) VERSION_OF_ANCILLARY="$OPTARG";;
	h) usage
	   exit 1;;
	L) LABEL="$OPTARG";;
    n) noPipeline=1;;
    s) startyyyymmdd="$OPTARG";;
    t) testing=1;;
	?) printf "Unknown option %s\n" $opt
	   usage
           exit 1;;
	esac
done

shift $(($OPTIND - 1))
[[ "$#" -eq $expectedCountOfArguments ]] || \
    error_exit "Line ${LINENO}: Unexpected number of arguments."

optionsForStep1="-L ${LABEL}"

version_of_ancillary_option=""
# by default we set the version of ancillary data to the one of production.
# this implies that the ancillary data will NEVER be modified by the scripts called
# by this bash script (i.e. no call of scratchShuffleAncillary.sh to destination of
# pl/archive).
inputForModisData="label = '${LABEL}', versionOfAncillary = '${VERSION_OF_ANCILLARY}'"
printf "inputForModisData: ${inputForModisData}\n"

shuffleAncillaryOptions="-A ${VERSION_OF_ANCILLARY}"
nextStepOptions="${shuffleAncillaryOptions} -L ${LABEL}"

# Do scratch shuffle for required ancillary data
${thisScriptDir}/scratchShuffleAncillary.sh ${shuffleAncillaryOptions} || \
    error_exit "Line $LINENO: scratchShuffleAncillary error"

echo "${PROGNAME}: Done with shuffle TO scratch."

if [ $testing ]; then
    echo "${PROGNAME}: TEST mode"
    nextStepOptions="${step1Options} -t"
else
    echo "${PROGNAME}: OPS mode"
fi
