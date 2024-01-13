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
ml slurmtools

source scripts/toolsJobs.sh

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
get_water_year_date_string(){
    # Get the waterYearDate year, month and month window as parameters for snowTodayStep1
    # and 2 to update the cubes with a 3-month window.
    year=$(date +'%Y')
    month=$(date +'%-m')
	echo "${year} ${month} ${monthWindow}"
}
get_slurm_std_out_directory(){
    # Get the slurm std ouput file for the SLURM_JOB_ID.#
    # Parameters
    # ----------
    # $1: char/num. SLURM_JOB_ID.
    JOBID=$1
    MYSTDOUT=$(scontrol show job ${JOBID} | grep StdOut | tr -s ' ' | cut -d = -f 2)
    MYSTDOUT=$(dirname ${MYSTDOUT})
    echo "${MYSTDOUT}"
}
log_level_1(){
    # Log.
    # Parameters
    # ----------
    # $1: char. Status to log.
    # $2: char. Message
    # 
    # NB: Formatting could be improved.
    printf "\ndate; dura.; script; job; task; region; status; hostname; CPU%%; "
    printf "mem%%; totalMem; cores; message\n"
    printf ".....................................................................\n"
    printf "$(date '+%m%dT%H:%M'); $(TZ=UTC0 printf '%(%H:%M)T' "$SECONDS"); "
    printf "${scriptId}; ${SLURM_JOB_ID}; ${SLURM_ARRAY_TASK_ID}; ${regionName}; "
    printf "${1}; $(hostname); "
    
    # The following with seff doesn't systematically work on Blanca nodes, and RC team
    # doesn't know exactly why, and me neither, despite some research.
    # I replaced the code using seff by a more convoluted code using sacct directly.
    # 2024-01-11.
    #printf %q "$(seff ${SLURM_JOB_ID} | grep "CPU Efficiency" | awk '{print $3}' | sed s/.[0-9][0-9]//)";
    #printf "; "
    #printf %q "$(seff ${SLURM_JOB_ID} | grep "Memory Efficiency" | awk '{print $3}' | sed s/.[0-9][0-9]//)";
    #printf "; "
    #printf %q "$(seff ${SLURM_JOB_ID} | grep "Memory Efficiency" | awk '{print $5$6}')";
    #printf "; "
    #printf %q "$(seff ${SLURM_JOB_ID} | grep "Cores" | awk '{print $4}')"; printf "; "
    #printf "${3}"
    
    printf "; ; "
        # Place for CPU% and mem% used, to be filled by toolsJobAchieved.sh at the
        # end of the job.
    sacct1=($(sacct --format AllocCPUS,ReqMem -j ${SLURM_JOB_ID} | sed '3q;d' | sed 's/ \{1,\}/;/g' | tr ";" "\n"))
    # sacct --format JobName,User,Group,State,Cluster,AllocCPUS,REQMEM,TotalCPU,Elapsed,MaxRSS,ExitCode,NNodes,NTasks -j 3058775
    # gives three lines and sacct1 get variable values into arrays to be handled
    # below.
    memThatWasRequired=$(get_mem_in_Gb ${sacct1[1]})
    nbOfCoresRequired=${sacct1[0]}
    printf "%0.0f GB; " ${memThatWasRequired}
    printf "%0d; ${2}" ${nbOfCoresRequired}
    
    printf "\n\n"
}

error_exit() {
    # Use for fatal program error
    # Argument:
    #   $1: optional string containing descriptive error message
    #   if no error message, prints "Unknown Error"
    # Stop the stopwatch and report elapsed time
    log_level_1 "end:ERROR" "${1:-"Unknown Error"}" 
    exit 1
}

# Script core.
#---------------------------------------------------------------------------------------
printf "Github branch: $(git rev-parse --abbrev-ref HEAD)\n"

# Caller script arguments.
# NB: Not all scripts can be parametered with these arguments. Check the script codes
# for details.
dateOfToday=
filterConfId=0
# id of the filter configuration (in configuration_of_filters.csv). 0 indicates take
# the filter id of the region configuration, other value points to another specific
# filter configuration.
inputFromArchive=
# copy input files from archive to scratch.
LABEL="test"
# is inputLabel, that is the version label of the input files, and also outputLabel,
# if outputLabel not supplied.
noPipeline=
# if set to 1, the following script in the pipeline is not called.
outputToArchive=
# copy output files from scratch to archive.
outputLabel=
# version label of the output files.
scratchPath=${espScratchDir}
# scratch path, by default environment variable.
startyyyymmdd=
# start date for import.
testing=
# if set to 1, doesn't send emails to everybody.
VERSION_OF_ANCILLARY="v3.1"
while getopts "A:c:d:hiL:noO:s:tx:" opt
# NB: add a : in string above when option expects a value.
do
    case $opt in
    A) VERSION_OF_ANCILLARY="$OPTARG";;
    c) filterConfId="$OPTARG";;
    d) dateOfToday="$OPTARG";;
	h) usage
	   exit 1;;
    i) inputFromArchive=1;;
	L) LABEL="$OPTARG";;
    n) noPipeline=1;;
    o) outputToArchive=1;;
    O) outputLabel="$OPTARG";;
    s) startyyyymmdd="$OPTARG";;
    t) testing=1;;
    x) scratchPath="$OPTARG";;
	?) printf "Unknown option %s\n" $opt
	   usage
           exit 1;;
	esac
done
if [ ! outputLabel ]; then
    outputLabel=LABEL
fi

sbatchOptionString="--account ucb-general --export=NONE --partition amilan --qos normal "\
"-o /rc_scratch/%u/slurm_out/%x-%j.out"
# Determine the sbatch options string.
if [[ ${scratchPath:0:12} == "/rc_scratch/" ]]; then
    sbatchOptionString="--account blanca-rittger --export=NONE --qos preemptable -o /rc_scratch/%u/slurm_out/%x-%j.out"
fi

echo "ancillary: ${VERSION_OF_ANCILLARY}, "\
"dateOfToday: ${dateOfToday}, " \
"filterConfId for ${filterConfLabel}: ${filterConfId}, "\
"inputFromArchive: ${inputFromArchive}, inputLabel: ${LABEL}, "\
"noPipeline: ${noPipeline}, outputLabel: ${outputLabel}, "\
"outputToArchive: ${outputToArchive}, testing: ${testing}, "\
"scratchPath: ${scratchPath}, "\
"sbatchOptionString: ${sbatchOptionString}."\

# Output file. This variable is not transferred from sbatch to bash, so we define it.
# NB: to split a string, don't put indent otherwise there will be two variables.
THISSBATCH_OUTPUT="${scratchPath}slurm_out/${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_"\
"${SLURM_ARRAY_TASK_ID}.out"
# Submit sbatch script updating the efficiency statistics at the end of the log file.
# NB: dependency should be afterany and not any, otherwise it would generate a killing
# lock.
if [ ! -z ${isBatch} ]; then
    echo "${PROGNAME}: SLURM_SCRATCH=$SLURM_SCRATCH"
    echo "${PROGNAME}: SLURM_JOB_ID=$SLURM_JOB_ID"
    sbatch ${sbatchOptionString} --dependency=afterany:$SLURM_JOB_ID ./scripts/toolsJobAchieved.sh \
        $SLURM_JOB_ID $THISSBATCH_OUTPUT

    stdoutDir=$(get_slurm_std_out_directory ${SLURM_JOB_ID})
    echo "stdoutDir: " ${stdoutDir}
fi
set_slurm_array_task_id


shift $(($OPTIND - 1))

if [[ "$#" -ne $expectedCountOfArguments ]]; then
    printf "ERROR: received %0d arguments, %0d expected.\n" $# $expectedCountOfArguments
fi

[[ "$#" -eq $expectedCountOfArguments ]] || \
    error_exit "Line ${LINENO}: Unexpected number of arguments."

version_of_ancillary_option=""
# by default we set the version of ancillary data to the one of production.
# this implies that the ancillary data will NEVER be modified by the scripts called
# by this bash script (i.e. no call of scratchShuffleAncillary.sh to destination of
# pl/archive).
inputForModisData="label = '${LABEL}', versionOfAncillary = '${VERSION_OF_ANCILLARY}'"
printf "inputForModisData: ${inputForModisData}\n"
modisDataInstantiation="modisData = MODISData(${inputForModisData}); "
if [[ ${LABEL} != ${outputLabel} ]] & [ outputDataLabels ]; then
    for thisLabel in ${outputDataLabels[*]};
        do modisDataInstantiation=${modisDataInstantiation}""\
"modisData.versionOf.${thisLabel}='${outputLabel}'; ";
    done
    printf "modisDataInstantiation: ${modisDataInstantiation}.\n"
fi

inputForESPEnv="modisData = modisData, scratchPath = '${scratchPath}'"
espEnvInstantiation="espEnv = ESPEnv(${inputForESPEnv}); "
if [[ ${filterConfId} -ne 0 ]]; then
    espEnvInstantiation=${espEnvInstantiation}" "\
"espEnv.myConf.region.${filterConfLabel}ConfId(:)=${filterConfId}; ";
    printf "espEnvInstantiation: ${espEnvInstantiation}.\n"
fi
waterYearDateSetToday=""
if [ ! -z ${dateOfToday} ]; then
    waterYearDateSetToday="waterYearDate.dateOfToday = datetime(${dateOfToday:0:4}, "\
"${dateOfToday:4:2}, ${dateOfToday:6:2}); ";
    printf "waterYearDateSetToday: ${waterYearDateSetToday}.\n"
fi
# NB: month and day can be input as 09 and 01 apparently with Matlab 2021b.

shuffleAncillaryOptions="-A ${VERSION_OF_ANCILLARY} -x ${scratchPath}"
nextStepOptions="${shuffleAncillaryOptions} -L ${LABEL}"
if [ inputFromArchive ]; then
    nextStepOptions="${nextStepOptions} -i"
fi
if [ outputToArchive ]; then
    nextStepOptions="${nextStepOptions} -o"
fi
if [ testing ]; then
    nextStepOptions="${nextStepOptions} -t"
fi

# Do scratch shuffle for required ancillary data
${thisScriptDir}/scratchShuffleAncillary.sh ${shuffleAncillaryOptions} || \
    error_exit "Line $LINENO: scratchShuffleAncillary error"

echo "${PROGNAME}: Done with shuffle TO scratch."

if [ $testing ]; then
    echo "${PROGNAME}: TEST mode"
else
    echo "${PROGNAME}: OPS mode"
fi
