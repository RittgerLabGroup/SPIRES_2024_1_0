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
    # $1: char/num. default value for SLURM_ARRAY_TASK_ID.
    if [ -z ${SLURM_ARRAY_TASK_ID+x} ]; then
        SLURM_ARRAY_TASK_ID=$defaultSlurmArrayTaskId
        printf "Default set SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}\n";
    fi
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
sbatch --dependency=afterany:$SLURM_JOB_ID ./scripts/toolsJobAchieved.sh \
    $SLURM_JOB_ID $SBATCH_OUTPUT
printf "Github branch: $(git rev-parse --abbrev-ref HEAD)\n"

set_slurm_array_task_id

# Caller script arguments.
LABEL="test"
VERSION_OF_ANCILLARY=prod
noPipeline=
testing=
while getopts "hL:A:" opt
do
    case $opt in
	h) usage
	   exit 1;;
	L) LABEL="$OPTARG";;
    A) VERSION_OF_ANCILLARY="$OPTARG";;
	?) printf "Unknown option %s\n" $opt
	   usage
           exit 1;;
	esac
done

shift $(($OPTIND - 1))
[[ "$#" -eq $expectedCountOfArguments ]] || \
    error_exit "Line ${LINENO}: Unexpected number of arguments."

modisdata_option=""
if [ $LABEL ]; then
    inputForModisData="label = '${LABEL}'"
fi
version_of_ancillary_option=""
# by default we set the version of ancillary data to the one of production.
# this implies that the ancillary data will NEVER be modified by the scripts called
# by this bash script (i.e. no call of scratchShuffleAncillary.sh to destination of 
# pl/archive).
inputForModisData="${inputForModisData}, versionOfAncillary = '${VERSION_OF_ANCILLARY}'"
printf "inputForModisData: ${inputForModisData}\n"
version_of_ancillary_option="-A $VERSION_OF_ANCILLARY"
