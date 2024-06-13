#!/bin/bash
#
# Initialize variables for other scripts launched in slurm and calling matlab.
# Also define the exit function.
# NB: Not very clean, but allow to mutualize code for easier maintenance. SIER_322.
########################################################################################
# 0. Initialize and include general configuration.sh and calculation functions
########################################################################################
fileSeparator='/'

sleep 5
# Might help to make work sacct (sacct not fully informed at the beginning of a job).

# User should have set scriptId, which appears in logs.
# NB: not sure it works
if [ ! -v scriptId ]; then
    # ${scriptId} defined in main .sh script.
  scriptId="noName"
  printf "Warning: No script name set for logs.\n"
fi
if [ ! -v expectedCountOfArguments ]; then expectedCountOfArguments=0; fi
if [ ! -v defaultSlurmArrayTaskId ]; then defaultSlurmArrayTaskId=292; fi

source scripts/configuration.sh
source scripts/toolsJobs.sh
# We also source scripts/toolsRegions.sh below.

########################################################################################
# Functions.
########################################################################################
set_slurm_array_task_id(){
  # Default SLURM_ARRAY_TASK_ID to make it possible to run the script outside of
  # sbatch.
  # Parameters
  # ----------
  # $1: char/num. Default value for SLURM_ARRAY_TASK_ID.
  #                                                                            obsolete
  if [ ! -v SLURM_ARRAY_TASK_ID ]; then
    SLURM_ARRAY_TASK_ID=$defaultSlurmArrayTaskId
    # $defaultSlurmArrayTaskId defined in main .sh script.
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
  # NB: Beware if you modify this formatting because, toolsJobAchieved.sh and
  # runSubmitter.sh extract info
  # from this, so don't forget to check/change that script too !!               @warning
  thisPad=$(printf "%50s")
  formatSlurmJobId="${SLURM_JOB_ID}${thisPad:$(( ${#thisPad} - 8 + ${#SLURM_JOB_ID} ))}"
  formatObjectId="${thisPad:$(( ${#thisPad} - 4 + ${#objectId} ))}${objectId}"
  formatCell=" "
  if [ -v thisSequence ] && [ "$thisSequence" != "0" ]; then
    formatCell="${cellIdx}"
  fi
  formatCell="${thisPad:$(( ${#thisPad} - 4 + ${#formatCell} ))}${formatCell}"
  formatDate="${waterYearDateString}${thisPad:$(( ${#thisPad} - 13 + ${#waterYearDateString} ))}"
  formatStatus="${1}${thisPad:$(( ${#thisPad} - 9 + ${#1} ))}"
  formatHostName="${HOSTNAME}${thisPad:$(( ${#thisPad} - 15 + ${#slurmBatchHost} ))}"
  formatMessage="${2}"
  formatMessage=${formatMessage//[$'\t\r\n']}
    # Remove newline and tab characters.
  printf "\ndate%6s; dura.; script  ; job%5s; obj.; cel.; date%9s; status%3s; "
  printf "hostname%7s; CPU%%; mem%%; cores; totalMem; message\n"
  printf ".....................................................................\n"
  printf "$(date '+%m%dT%H:%M'); $(TZ=UTC0 printf '%(%H:%M)T' "$SECONDS"); "
  printf "${scriptId}; ${formatSlurmJobId}; ${formatObjectId}; ${formatCell}; "
  printf "${formatDate}; ${formatStatus}; ${formatHostName}; "

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
: '
  # Former method to get cpu and mem.
  sacct1=($(sacct --format AllocCPUS,ReqMem -j ${slurmFullJobId} | sed ''3q;d'' | sed ''s/ \{1,\}/;/g'' | tr ";" "\n"))
  # sacct --format JobName,User,Group,State,Cluster,AllocCPUS,REQMEM,TotalCPU,Elapsed,MaxRSS,ExitCode,NNodes,NTasks -j 3058775
  # gives three lines and sacct1 get variable values into arrays to be handled
  # below.
  memRequired=$(sacct --format ReqMem -j ${slurmFullJobId} | tr -d '' '' | tr ''\n'' @ | cut -d @ -f 3)
  memRequired=$(get_mem_in_Gb ${memRequired})
  nbOfCoresRequired=$(sacct --format AllocCPUS -j 16531438_292 | tr -d '' '' | tr ''\n'' ; | cut -d ; -f 4)
' memRequired=
  if [ -v slurmMem ]; then
    memRequired=$(get_mem_in_Gb ${slurmMem})
  fi
  printf "%0d; " ${slurmNTasksPerNode}
  printf "%0.0f GB; ${2}" ${memRequired}
  if [ ${1} != "end:DONE" ] && [ ${1} != "end:ERROR" ]; then
    printf "\n\n"
  else
    printf "\n"
  fi
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

########################################################################################
# Script core.
########################################################################################
printf "Github branch: $(git rev-parse --abbrev-ref HEAD)\n"
printf "$(bash --version | grep version | head -1)\n"
printf "#############################################################################\n\n"

# 1. Check that the slurm node has logged in and has the slurm environment
########################################################################################
if [ -v SLURM_JOB_ID ] && [ ! -v USER ]; then
  printf " Error no USER exported.\n"
  printf "#############################################################################\n"
  printf "Environment variables:\n"
  printf "#############################################################################\n"
  export

  printf "\n\n\n\n"
  printf "#############################################################################\n"
  printf "Scontrol show job variables:\n"
  printf "#############################################################################\n"
  scontrol show job ${SLURM_JOB_ID}

  printf "\n\n\n\n"
  printf "#############################################################################\n"
  printf "Sacct job info:\n"
  printf "#############################################################################\n"
  sacct -j ${SLURM_JOB_ID} -l --json
  
  # Quick get of objectId/cellId (also done above when node logged in).
  if [ -v SLURM_ARRAY_TASK_ID ]; then
    objectId=${SLURM_ARRAY_TASK_ID}
    cellIdx=1
  
    # If sequence, SLURM_ARRAY_TASK_ID includes objectId in the left and cellIdx in the
    # right.
    # Here, $thisSequence can be defined either in main script constants or in pipeline
    # configuration.
    if [ -v thisSequence ] && [ "$thisSequence" != "0" ]; then
      cellIdx=$((10#${objectId: -3}))
      objectId=${objectId::-3}
    fi
  fi

  printf "\n\n\n\n"
  error_exit "Exit=1, matlab=no, Defective node, impossible to login."
fi

########################################################################################
# 2. Get the slurm variables.
########################################################################################
sbatchCommand=
isBatch=
if [ -v SLURM_JOB_ID ]; then
  isBatch=1
  slurmFullJobId=${SLURM_JOB_ID}
  if [ -v SLURM_ARRAY_TASK_ID ]; then
    slurmFullJobId=${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}
  fi
  # NB: scontrol only works for ongoing jobs.
  thisSControl=$(scontrol show job ${slurmFullJobId} | tr -s ' ' | tr ' ' '\n' | tr -s '\n')
  slurmAccount=$(echo "$thisSControl" | grep Account | cut -d = -f 2)
  # ${SLURM_JOB_ACCOUNT} is not set when interactive.
  slurmBatchHost=$(echo "$thisSControl" | grep BatchHost | cut -d = -f 2)
  slurmCommand=$(echo "$thisSControl" | grep Command | cut -d = -f 2)
  # the "" are there to keep displaying the \n using echo command.
  slurmMailType=$(echo "$thisSControl" | grep MailType | cut -d = -f 2)
  slurmMailUser=$(echo "$thisSControl" | grep MailUser | cut -d = -f 2)
  slurmNodeList=$(echo "$thisSControl" | grep NodeList | grep -v Req | grep -v Exc | cut -d = -f 2)
  slurmPartition=$(echo "$thisSControl" | grep Partition | cut -d = -f 2)
  slurmQos=$(echo "$thisSControl" | grep QOS | cut -d = -f 2)
  slurmStdOut=$(echo "$thisSControl" | grep StdOut | cut -d = -f 2)
  # slurmStdErr=slurmStdOut.
  # Should be constructed as "${slurmLogDir}${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out"
  slurmLogDir=$(dirname "${slurmStdOut}")${fileSeparator}
  slurmTime=$(echo "$thisSControl" | grep TimeLimit | cut -d = -f 2)
  #slurmStartTime=$(echo "$thisSControl" | grep StartTime | cut -d = -f 2)
  #slurmEndTime=$(echo "$thisSControl" | grep EndTime | cut -d = -f 2)
  slurmWorkingDir=$(echo "$thisSControl" | grep WorkDir | cut -d = -f 2)
  
  #slurmDurationSec=$(($(date -d $slurmEndTime +%s) - $(date -d $slurmStartTime +%s)))
  
  programName=$(echo "$thisSControl" | grep Command | tr -s ' ' | cut -d = -f 2)

  thisSControlAlloc=$(echo "$thisSControl" | grep AllocTRES | sed 's/AllocTRES=//' | tr ',' '\n')
  if [ ! -z "$thisSControlAlloc" ]; then
    # NB: the "" around $thisSControlAlloc are important to keep it a string without \n$
    # otherwise the condition doesnt work (msg -bash: [: too many arguments)
    # NB: the "" around the variable are important to keep displaying the \n using echo.
    # -z: test if variable empty string. Beware -v only test if variable exists.
    slurmMem=$(echo "$thisSControlAlloc" | grep mem | cut -d = -f 2)
    slurmNTasksPerNode=$(echo "$thisSControlAlloc" | grep cpu | cut -d = -f 2)
    # We suppose that ntasksPerNode=Total nb of tasks (task = cpu) because we'll
    # never require more than 1 node per job.                             @important
  else
    slurmNTasksPerNode=$(echo "$thisSControl" | grep NumTasks | cut -d = -f 2)
    thisSControlAlloc=$(echo "$thisSControl" | grep TRES | sed 's/TRES=//' | tr ',' '\n');
    slurmMem=$(echo "$thisSControlAlloc" | grep mem | cut -d = -f 2)
  fi

  slurmConstraints=$(sacct -j ${slurmFullJobId} -o Constraints | tr -d " " | tr "\n" "," | cut -d , -f 3);
  slurmExport=$(sacct -j ${slurmFullJobId} --env-vars | tr -d " " | tr "\n" "," | cut -d , -f 3)

  read -s -r -d '' slurmVariable << EOM
Slurm variable values.
#############################################################################
isBatch=${isBatch}
SLURM_JOB_ID=${SLURM_JOB_ID};
slurmFullJobId=${slurmFullJobId}; slurmAccount=${slurmAccount};
slurmBatchHost=${slurmBatchHost}; slurmCommand=${slurmCommand};
slurmMailType=${slurmMailType}; slurmMailUser=${slurmMailUser};
slurmPartition=${slurmPartition}; slurmQos=${slurmQos};
slurmStdOut=${slurmStdOut};
slurmLogDir=${slurmLogDir};
slurmTime=${slurmTime}; slurmWorkingDir=${slurmWorkingDir};
programName=${programName}; slurmMem=${slurmMem}; slurmNodeList=${slurmNodeList};
slurmNTasksPerNode=${slurmNTasksPerNode}; slurmConstraints=${slurmConstraints};
slurmExport=${slurmExport};
EOM
  printf "\n${slurmVariable}\n\n"
fi
########################################################################################
# 3. Determine the SubmitLine which is reused in repeating jobs or submitting the next
#   job in the pipeline.
########################################################################################
: '
# Former way to get the sbatch command, for memory.
  sbatchCommand="sbatch --export=${slurmExport} --constraints=${slurmConstraints} "\
"--mail-type=${slurmMailType} --mail-user=${slurmMailUser} "\
"--account=${SLURM_JOB_ACCOUNT} --qos=${slurmQos} "\
"-o ${slurmStdOut} --job-name=${SLURM_JOB_NAME} "\
"--ntasks-per-node=${slurmNTasksPerNode} --mem=${slurmMem} --time=${slurmTime} "\
"--array=${SLURM_ARRAY_TASK_ID} "\
"${slurmCommand}"
  sbatchCommand=$(echo "${sbatchCommand}" | sed -r "s/\-\-[a-z\-]+\=\ //g")
  # To remove all the parameters not set (=followed by space). option -r to activate
  # extended expressions, option g to repeat the substitution every time found.
'

if [[ ${mainBashSource} == *"slurm_script"* ]]; then
  # $mainBashSource defined in main script. Cannot be defined in toolsStart.sh because
  # based on $BASH_SOURCE.
  printf "Running as a slurm sbatch job...\n"
  printf "Submit line of the job:\n"
  printf "sacct -j ${slurmFullJobId} --format SubmitLine%%1000 | awk '/sbatch[^@]+/{ print $0 }' | xargs\n"
  sacct -j ${slurmFullJobId} --format SubmitLine%1000 | awk '/sbatch[^@]+/{ print $0 }' | xargs
  sbatchSubmitLine=$(sacct -j ${slurmFullJobId} --format SubmitLine%1000 | awk '/sbatch[^@]+/{ print $0 }' | xargs)

  if [ -v SLURM_ARRAY_TASK_ID ]; then
    # Occasionally, sacct doesnt return any submit line to this job id, although it can
    # return it later. This is why I take the one of the array job.
    printf "\n\nSubmit line of the array job:\n"
    printf "sacct -j ${SLURM_ARRAY_JOB_ID} --format SubmitLine%%1000 | tr -s ' ' | tr -s '-' | sed '3p;d' | xargs\n"
    sacct -j ${SLURM_ARRAY_JOB_ID} --format SubmitLine%1000 | tr -s ' ' | sed '3p;d' | xargs
    sbatchSubmitLine=$(sacct -j ${SLURM_ARRAY_JOB_ID} --format SubmitLine%1000 | tr -s ' ' | sed '3p;d' | xargs)

    slurmArrayTaskIds=$(echo $sbatchSubmitLine | sed -E "s~[^@]+ --array=([0-9,\-]+) [^@]+~\1~")
  fi

  printf "\nSubmit line kept:\n$(echo $sbatchSubmitLine | sed s~%~%%~g)\n\n"
  # We add sed to escape the %, to prevent their interpretation by printf.

  mainProgramName=${slurmCommand}
  # ${mainProgramName} defined in main .sh script and overriden here.

  # Submit sbatch script updating the efficiency statistics at the end of the log file.
  # NB: dependency should be afterany and not any, otherwise it would generate a killing
  # lock.
  achievedSbatch="sbatch --account=${slurmAccount} --export=NONE --qos=${slurmQos} --time 00:01:00 "\
"-o ${slurmLogDir}endlog${scriptId}-%x-%j.out --dependency=afterany:${slurmFullJobId} ./scripts/toolsJobAchieved.sh "\
"${slurmFullJobId} ${slurmStdOut}"
  printf "Submit performance statistic update job.\n$(echo ${achievedSbatch} | sed s~%~%%~g)\n"
  # the % are interpreted by printf, so we need sed to prevent that in the display.
  ${achievedSbatch}

  # Next similar job submitted after getting the option isToBeRepeated.
else
  printf "Not running as sbatch...\n"
fi
printf "Main program name: ${mainProgramName}\n"

cd "$(dirname "${mainProgramName}")"
#Go to parent of this script, so that correct pathdef.m file is used
cd ..
workingDirectory=$(pwd)
printf "Working directory: ${workingDirectory}\n"
printf "#############################################################################\n"

source scripts/toolsRegions.sh
# In toolsRegions.sh, we need $workingDirectory.

########################################################################################
# 4. Constants of the main script.
########################################################################################

printf "\n\n\n"
printf "#############################################################################\n"
printf "# Parameters\n"
printf "#############################################################################\n"
printf "\n"

# thisSequence set to 0 if unset.
if [ ! -v thisSequence ]; then
  thisSequence=0
fi
  read -s -r -d '' mainScriptDefaultConstant << EOM
Main script default constant values.
#############################################################################
scriptId=${scriptId}; defaultSlurmArrayTaskId=${defaultSlurmArrayTaskId};
expectedCountOfArguments=${expectedCountOfArguments};
inputDataLabels=${inputDataLabels[*]};
outputDataLabels=${outputDataLabels[*]};
filterConfLabel=${filterConfLabel};
mainBashSource=${mainBashSource};
slurmArrayTaskIds=${slurmArrayTaskIds};
mainProgramName=${mainProgramName}; beginTime=${beginTime[*]};

thisRegionType=${thisRegionType}; thisSequence=${thisSequence}
thisSequenceMultiplierToIndices=${thisSequenceMultiplierToIndices}; thisMonthWindow=${thisMonthWindow};
EOM
  printf "\n${mainScriptDefaultConstant}\n\n"
  # Variables defined in main .sh script.

########################################################################################
# 5. Parameters of main script overriden/defined by the pipeline configuration.sh
########################################################################################
# These parameters can still be overriden by the options sent to the script.    @warning
# First parsing of options to get the pipeline.
OPTIND=1
while getopts "A:b:c:d:D:hiI:L:M:noO:q:Q:Rx:y:w:Z:" opt; do
  case $opt in
    Z) pipeLineId="$OPTARG"
    printf "\npipeLineId=${pipeLineId}\n\n";;
  esac
done
if [ -v isBatch ] && [ -v pipeLineId ]; then
  # We cant use namerefs for dynamic variables referencing arrays because bash is 4.2
  # in blanca/alpine and not 4.4.
  # declare -n pipeLineScriptIds=pipeLineScriptIds${pipeLineId}
  # Therefore we use another solution, by putting the arrays in strings in
  # configuration.sh and affecting the dynamic variables this way below.
  tmpRef=pipeLineScriptIdsString${pipeLineId}; pipeLineScriptIds=(${!tmpRef})
  if [[ "${pipeLineScriptIds[@]/${scriptId}//}" == */* ]]; then
    indexInPipeLine=$(echo ${pipeLineScriptIds[@]/${scriptId}//} | cut -d/ -f1 | wc -w | tr -d ' ')
: '
    declare -n pipeLineLabels=pipeLineLabels${pipeLineId}
    declare -n pipeLineRegionTypes=pipeLineRegionTypes${pipeLineId}
    declare -n pipeLineSequences=pipeLineSequences${pipeLineId}
    declare -n pipeLineSequenceMultiplierToIndices=pipeLineSequenceMultiplierToIndices${pipeLineId}
    declare -n pipeLineMonthWindows=pipeLineMonthWindows${pipeLineId}
    declare -n pipeLineParallelWorkersNb=pipeLineParallelWorkersNb${pipeLineId}
'
    tmpRef=pipeLineLabelsString${pipeLineId}; pipeLineLabels=(${!tmpRef})
    tmpRef=pipeLineRegionTypesString${pipeLineId}; pipeLineRegionTypes=(${!tmpRef})
    tmpRef=pipeLineSequencesString${pipeLineId}; pipeLineSequences=(${!tmpRef})
    tmpRef=pipeLineSequenceMultiplierToIndicesString${pipeLineId}; pipeLineSequenceMultiplierToIndices=(${!tmpRef})
    tmpRef=pipeLineMonthWindowsString${pipeLineId}; pipeLineMonthWindows=(${!tmpRef})
    tmpRef=pipeLineParallelWorkersNbString${pipeLineId}; pipeLineParallelWorkersNb=(${!tmpRef})
    if [ $indexInPipeLine -gt 0 ]; then
      inputLabel=${pipeLineLabels[$(( $indexInPipeLine - 1 ))]}
    else
      inputLabel=${pipeLineLabels[${indexInPipeLine}]}
    fi
    outputLabel=${pipeLineLabels[${indexInPipeLine}]}
    thisRegionType=${pipeLineRegionTypes[${indexInPipeLine}]}
    thisSequence=${pipeLineSequences[${indexInPipeLine}]}
    thisSequenceMultiplierToIndices=${pipeLineSequenceMultiplierToIndices[${indexInPipeLine}]}
    thisMonthWindow=${pipeLineMonthWindows[${indexInPipeLine}]}
    parallelWorkersNb=${pipeLineParallelWorkersNb[${indexInPipeLine}]}

    read -s -r -d '' pipeLineConstant << EOM
Pipeline default constant values.
#############################################################################
inputLabel=${inputLabel}; outputLabel=${outputLabel};
thisRegionType=${thisRegionType}; thisSequence=${thisSequence};
thisSequenceMultiplierToIndices=${thisSequenceMultiplierToIndices}; thisMonthWindow=${thisMonthWindow};
parallelWorkersNb=${parallelWorkersNb};

EOM
printf "\n${pipeLineConstant}\n\n"
  fi
fi

########################################################################################
# 6. Options called by the main script.
########################################################################################
# NB: Not all scripts can be parametered with these arguments. Check the script codes
# for details.

# ObjectIds, cellIdx, countOfCells, firstToLastIndex.
########################################################################################
# Option -I, objectId of the tile or region or subdivision the script should run on.
# Default on tile h08v04.
# And Option -q, cellIdx, id of the cell in the tile that will be processed, ids going
# from top left to bottom left, top 2nd left to bottom 2nd left, ... top right to bottom
# right, supposing that a tile is divided in countOfCells cells of equal size.
# And Option -Q, number of cells of equal size that divide a tile and that will be
# processed by this process and sibling processes launched in parallel.cellIdx.
objectId=$defaultSlurmArrayTaskId
cellIdx=1
countOfCells=1
if [ -v SLURM_ARRAY_TASK_ID ]; then
  objectId=${SLURM_ARRAY_TASK_ID}
  cellIdx=1
  countOfCells=1
  # If sequence, SLURM_ARRAY_TASK_ID includes objectId in the left and cellIdx in the
  # right.
  # Here, $thisSequence can be defined either in main script constants or in pipeline
  # configuration.
  if [ -v thisSequence ] && [ "$thisSequence" != "0" ]; then
    cellIdx=$((10#${objectId: -3}))
    objectId=${objectId::-3}
    countOfCells=$((10#${slurmArrayTaskIds: -3}))
    # We suppose that all the objects have the same count of cells.
    # WARNING: This is important!                                               @warning
  fi
fi
# Option -b, default first to last index of object/cell to handle.
firstToLastIndex=1-65535
if [ -v thisSequence ] && [ "$thisSequence" != "0" ]; then
  if [ ! -v thisSequenceMultiplierToIndices ]; then
    thisSequenceMultiplierToIndices=1
  fi
  firstToLastIndex=$((($cellIdx - 1) * $thisSequenceMultiplierToIndices + 1))-$((($cellIdx) * $thisSequenceMultiplierToIndices))
    # $firstIndex is always > 0 (like $cellIdx)
fi

# Other options.
########################################################################################
# Option -A, version of ancillary data.
# Default declared in configuration.sh.
versionOfAncillary=${defaultVersionOfAncillary}
if [ ${thoseVersionsOfAncillary[$objectId]} ]; then
  versionOfAncillary=${thoseVersionsOfAncillary[$objectId]}
fi
# Option -c, id of the filter configuration (in configuration_of_filters.csv). 0
# indicates take the filter id of the region configuration, other value points to
# another specific filter configuration.
filterConfId=0
# Option -d, date of today yyyy-MM-dd. By default today or tomorrow if after 19 pm, but
# other dates in the past can be set if we want to see the state of the system at
# another date.
dateOfToday=$(date +%Y-%m-%d)
if [ $(date +%H) -ge 19 ]; then dateOfToday=$(date -d "+1 days" +%Y-%m-%d); fi;
# Option -D, default waterYearDateString.
# $thisMonthWindow can be earlier defined in main script constants and overriden by
# pipeline configuration.
if [ ! -v thisMonthWindow ]; then
  $thisMonthWindow=12
fi
waterYearDateString=$(echo $(date +"%Y-%m-%d")-${thisMonthWindow})
# Option -i, rsync input files from archive to scratch. By default, no rsync.
inputFromArchive=
# Option -L, inputLabel, version of the input files, and also outputLabel when not
# supplied. Can be earlier defined by pipeline configuration.
if [ ! -v inputLabel ]; then
  inputLabel="test"
fi
# Option -M, thisMode, indicates which part of the matlab string is run. By default 0,
# for all.
if [ ! -v thisMode ]; then
  thisMode=0
fi
# Option -o, rsync output files from scratch to archive. Default no rsync.
outputToArchive=
# Option -O, version label of the output files. E.g. v2024.0. Default = LABEL
# Can be earlier defined by pipeline configuration.
if [ ! -v outputLabel ]; then
  outputLabel=$inputLabel
fi
# Option -r, if present, indicates resubmission allowed if error (except specific errors
# such as cancel by user or out of memory).
isToResubmitIfError=
# Option -R, if present, plan a repeat of the job. By default, no repeat
isToBeRepeated=
# Option -v, verbosity level, also called log level. 0 all logs, increased value less
# logs.
verbosityLevel=0
# Option -w, default nb of parallel workers used by parfor loops in matlab.
# No parameter means all cores available. If 0, means no parallelism.
# Can be earlier defined by pipeline configuration.
if [ ! -v parallelWorkersNb ]; then
  parallelWorkersNb=0
  if [ -v slurmFullJobId ]; then
    #tmpVar=$(sacct -j ${slurmFullJobId} --format=AllocCPUS | tail -n 1 | sed -e "s/ //g")
    #if [ -z "${tmpVar//[0-9]}" ] && [ -n "$tmpVar" ]; then
    #  parallelWorkersNb=$tmpVar
    #fi
    parallelWorkersNb=$slurmNTasksPerNode
  fi
fi

# Option -x, location of the scratch Path. By default environment variable.
scratchPath=${espScratchDir}
# Option -y, location of the archive Path. By default environment variable.
archivePath=${espArchiveDir}
# Option -Z, is pipeline and gives the pipeLineId (configuration in configuration.sh).
if [ ! -v pipeLineId ]; then
  pipeLineId=
fi

# Other parameters
# Output file. This variable is not transferred from sbatch to bash, so we define it.
# NB: to split a string, don't put indent otherwise there will be two variables.
#                                                                            @deprecated
THISSBATCH_OUTPUT="${slurmLogDir}${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_"\
"${SLURM_ARRAY_TASK_ID}.out"
# Matlablaunched, used to remove the tmp directories in toolsEnd.sh.
matlabLaunched=

read -s -r -d '' defaultOption << EOM
Option default values.
#############################################################################
objectId=${objectId}; cellIdx=${cellIdx}; countOfCells=${countOfCells};
firstToLastIndex=${firstToLastIndex};
versionOfAncillary=${versionOfAncillary}; filterConfId=${filterConfId};
dateOfToday=${dateOfToday}; waterYearDateString=${waterYearDateString};
inputFromArchive=${inputFromArchive}; inputLabel=${inputLabel};
outputToArchive=${outputToArchive}; outputLabel=${outputLabel}; thisMode=${thisMode};
isToBeRepeated=${isToBeRepeated}; isToResubmitIfError=${isToResubmitIfError};
verbosityLevel=${isToBeRepeated};
parallelWorkersNb=${parallelWorkersNb}; scratchPath=${scratchPath};
archivePath=${archivePath}; pipeLineId=${pipeLineId};
EOM
printf "\n${defaultOption}\n\n"

# Second parsing of options.
OPTIND=1
while getopts "A:b:c:d:D:hiI:L:M:noO:q:Q:Rrx:y:w:Z:" opt
# NB: add a : in string above when option expects a value.
do
  case $opt in
    A) versionOfAncillary="$OPTARG";;
    b) firstToLastIndex="$OPTARG";;
    c) filterConfId="$OPTARG";;
    d) dateOfToday="$OPTARG";;
    D) waterYearDateString="$OPTARG"
      isToBeRepeated=0
      printf "Job wont be scheduled for a repeat because option -D "\
"waterYearDateString is set.\n";;
    h) usage
      exit 1;;
    i) inputFromArchive=1;;
    I) objectId="$OPTARG";;
    L) inputLabel="$OPTARG";;
    M) thisMode="$OPTARG";;
    n) noPipeline=1;;
    o) outputToArchive=1;;
    O) outputLabel="$OPTARG";;
    q) cellIdx="$OPTARG";;
    Q) countOfCells="$OPTARG";;
    r) if [ ! -v isToResubmitIfError ]; then
        isToResubmitIfError=1
      fi
      ;; 
    R) if [ ! -v isToBeRepeated ]; then
        isToBeRepeated=1
      fi
      ;;
    x) scratchPath="$OPTARG";;
    y) archivePath="$OPTARG";;
    v) verbosity="$OPTARG";;
    w) parallelWorkersNb="$OPTARG";;
    Z) pipeLineId="$OPTARG";;
    ?) printf "Unknown option %s\n" $opt
      usage
      exit 1;;
  esac
done

read -r -d '' actualOption << EOM
Option actual values.
#############################################################################
objectId=${objectId}; cellIdx=${cellIdx}; countOfCells=${countOfCells};
firstToLastIndex=${firstToLastIndex};
versionOfAncillary=${versionOfAncillary}; filterConfId=${filterConfId}; 
dateOfToday=${dateOfToday}; waterYearDateString=${waterYearDateString};
inputFromArchive=${inputFromArchive}; inputLabel=${inputLabel};
outputToArchive=${outputToArchive}; outputLabel=${outputLabel}; thisMode=${thisMode};
isToBeRepeated=${isToBeRepeated};  isToResubmitIfError=${isToResubmitIfError};
verbosityLevel=${isToBeRepeated};
parallelWorkersNb=${parallelWorkersNb}; scratchPath=${scratchPath};
archivePath=${archivePath}; pipeLineId=${pipeLineId};
EOM
printf "\n${actualOption}\n\n"

########################################################################################
# 7. Arguments and parameters of the matlab script.
########################################################################################
# Determination of region names, indices, start and end dates,
# Construction of the instantiation strings for Matlab.
firstToLastIndexArray=(${firstToLastIndex//-/ })
firstIndex=${firstToLastIndexArray[0]}
lastIndex=${firstToLastIndexArray[1]}

if [ ! -v regionName ] && [ ${objectId} -lt 1300 ]; then
  regionName=${allRegionNames[$objectId]}
  # $allRegionNames defined in toolsRegions.sh.
fi
# no modis tile can be of id >= 1300.
inputForRegion="'"${regionName}"', '"${regionName}"_mask', espEnv, modisData"

waterYearDateArray=(${waterYearDateString//-/ })
thisYear=${waterYearDateArray[0]}
thisMonth=${waterYearDateArray[1]}
thisDay=${waterYearDateArray[2]}
monthWindow=${waterYearDateArray[3]}
# thisDay cannot be higher than last day of the month
lastDay=$(cal $(date +"%m %Y" -d "${thisYear}-${thisMonth}-01") | awk 'NF {DAYS = $NF}; END {print DAYS}')
thisDay=$(( ${thisDay#0} > ${lastDay#0} ? ${lastDay#0} : ${thisDay#0} ))
# Calculation of start and end dates.
# #0 is used to trim the leading 0 if present to avoid the number being considered
# octal.
# This is tricky, due to behavior of date function.
# See https://stackoverflow.com/questions/13168463/using-date-command-to-get-previous-current-and-next-thisMonth
# https://stackoverflow.com/questions/58430234/subtract-months-from-a-given-date-in-bash
endDate="${thisYear}-${thisMonth}-${thisDay}"

if [[ ${monthWindow} -eq 0 ]]; then
  startDate=$endDate;
elif [[ ${monthWindow} -eq 1 ]]; then
  startDate=$(date +%Y-%m-01 -d "$endDate")
else
  startDate=$(date +%Y-%m-01 -d "$endDate")
  startDate=$(date +%Y-%m-01 --date="$(date --date="$startDate") $(( -$monthWindow + 1 )) month 1 day")
fi

dateOfTodayArray=(${dateOfToday//-/ })
dateOfTodayString="${dateOfTodayArray[0]}, "\
"${dateOfTodayArray[1]}, ${dateOfTodayArray[2]}, WaterYearDate.dayStartTime.HH, "\
"WaterYearDate.dayStartTime.MIN, WaterYearDate.dayStartTime.SS"
inputForWaterYearDate="datetime(${thisYear}, ${thisMonth}, ${thisDay}), "\
"modisData.getFirstMonthOfWaterYear('"${regionName}"'), ${monthWindow}, "\
"dateOfToday = datetime(${dateOfTodayString})"
# NB: month and day can be input as 09 and 01 apparently with Matlab 2021b.

read -r -d '' objectTimeVariable << EOM
Object and time variable values:
firstIndex=${firstIndex}; lastIndex=${lastIndex}; objectId=${objectId};
regionName=${regionName}; thisYear=${thisYear}; thisMonth=${thisMonth};
thisDay=${thisDay}; monthWindow=${monthWindow};
startDate=${startDate}; endDate=${endDate};
# Process work on data for this object from startDate or beginning of waterYear
# to endDate included.
EOM
printf "\n${objectTimeVariable}\n\n"

#set_slurm_array_task_id. NB: shouldnt be useful                               @obsolete

shift $(($OPTIND - 1))

if [[ "$#" -ne $expectedCountOfArguments ]]; then
  # $expectedCountOfArguments defined in main .sh script.
  printf "ERROR: received %0d arguments, %0d expected.\n" $# $expectedCountOfArguments
fi

[[ "$#" -eq $expectedCountOfArguments ]] || \
  error_exit "Line ${LINENO}: Unexpected number of arguments: $# vs "\
"${expectedCountOfArguments} expected."

version_of_ancillary_option=""
# by default we set the version of ancillary data to the one of production.
# this implies that the ancillary data will NEVER be modified by the scripts called
# by this bash script (i.e. no call of scratchShuffleAncillary.sh to destination of
# pl/archive).
inputForModisData="label = '${inputLabel}', versionOfAncillary = '${versionOfAncillary}'"
printf "inputForModisData: ${inputForModisData}\n"
modisDataInstantiation="modisData = MODISData(${inputForModisData}); "
if [[ ${inputLabel} != ${outputLabel} ]] & [ outputDataLabels ]; then
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
espEnvWOFilterInstantiation="espEnvWOFilter = ESPEnv(${inputForESPEnv}, filterMyConfByVersionOfAncillary = 0); "
printf "espEnvWOFilterInstantiation: ${espEnvWOFilterInstantiation}.\n"

read -r -d '' catchExceptionAndExit << EOM
catch thisException;
  fprintf('%s: %s\n', thisException.identifier, thisException.message);
  fprintf('\nmatlabExitCode=%s\n', thisException.identifier);
  if strcmp(thisException.identifier, 'parallel:cluster:PoolRunValidation') && ...
    contains(thisException.message, ...
      ['Parallel pool failed to start with the following error. For more ', ...
      'detailed information, validate the profile']);
    exit(1);
  else;
    exit(1);
  end;
end;
fprintf('\nmatlabExitCode=0\n');
exit(0);

EOM

########################################################################################
# 8. Submit the repeated similar job in the future.
########################################################################################
# Limited to the first task id, = first object of the group which are tackled by
# SLURM_ARRAY_JOB_ID.
if [ -v isBatch ] && [ -v isToBeRepeated ] && [ $isToBeRepeated -eq 1 ] && \
[ $SLURM_ARRAY_TASK_ID -eq $SLURM_ARRAY_TASK_MIN ]; then

  thisTime=$(date +%H:%M:%S)
  repeatBeginTime=
  for beginIdx in $(eval echo {0..$(( ${#beginTime[@]} - 1 ))..1}); do
    if [ $beginIdx -eq 0 ] && [[ $thisTime < ${beginTime[$beginIdx]} ]]; then
      repeatBeginTime=${beginTime[$beginIdx]}
    elif [ $beginIdx -eq $(( ${#beginTime[@]} - 1 )) ] && [[ $thisTime > ${beginTime[$beginIdx]} ]]; then
      repeatBeginTime=${beginTime[0]}
    elif [[ ! $thisTime > ${beginTime[$(( $beginIdx + 1 ))]} ]] && [[ $thisTime > ${beginTime[$beginIdx]} ]]; then
      # the negate ! is to have <=.
      repeatBeginTime=${beginTime[$(( $beginIdx + 1 ))]}
    fi
  done
  # There is probably a smarter way to do this set...

  repeatSubmitLine=$sbatchSubmitLine
  if [[ "${repeatSubmitLine}" =~  .+begin=.+ ]]; then
    repeatSubmitLine="$(echo "${repeatSubmitLine}" | sed -r s~--begin=[0-9\:]+~--begin=${repeatBeginTime}~)"

  else
    repeatSubmitLine="${repeatSubmitLine/sbatch/sbatch --begin=${repeatBeginTime} }"
  fi
  printf "\n\n\n"
  printf "#############################################################################\n"
  printf "Submit schedule for repeated job.\n"
  printf "Time: ${repeatBeginTime}.\n"
  printf "SbatchSubmitLine: ${sbatchSubmitLine}\n"
  printf "Next repeat sbatch: $(echo $repeatSubmitLine  | sed s~%~%%~g)\n"
  $repeatSubmitLine
  printf "#############################################################################\n"
fi

########################################################################################
# 9. Submit the next job of the pipeline in the future.
########################################################################################
# Will launch only if all tasks of
# the array job are achieved successfully. Limited to the first task id, = first
# object of the group which are tackled by SLURM_ARRAY_JOB_ID.

# Update options for next script to submit in the pipeline.
# Most options are defined in the pipeline configuration, with the waterYearDate
# derived from this script waterYearDate.
if [ -v isBatch ] && [ -v pipeLineId ] && [ -v SLURM_ARRAY_TASK_ID ] && \
[ $SLURM_ARRAY_TASK_ID -eq $SLURM_ARRAY_TASK_MIN ] && \
[[ "${pipeLineScriptIds[@]/${scriptId}//}" == */* ]]; then

  indexInPipeLine=$(echo ${pipeLineScriptIds[@]/${scriptId}//} | cut -d/ -f1 | wc -w | tr -d ' ');
  nextIndexInPipeLine=$(( ${indexInPipeLine} + 1 ));

  if [ $nextIndexInPipeLine -lt ${#pipeLineScriptIds[@]} ]; then
    nextScriptId=${pipeLineScriptIds[${nextIndexInPipeLine}]}
    nextJobName=$nextScriptId
    nextScript=${scriptIdFilePathAssociations[${nextScriptId}]};
    nextVersionOfAncillary=$versionOfAncillary

    nextInputLabel=${pipeLineLabels[${indexInPipeLine}]}
    nextOutputLabel=${pipeLineLabels[${nextIndexInPipeLine}]}
    nextRegionType=${pipeLineRegionTypes[${nextIndexInPipeLine}]}
    nextSequence=${pipeLineSequences[${nextIndexInPipeLine}]}
    nextMonthWindow=${pipeLineMonthWindows[${nextIndexInPipeLine}]}
    nextWaterYearDate=${thisYear}-${thisMonth}-${thisDay}-${nextMonthWindow}
    nextSlurmStdOutFileName="%x_%a_${nextWaterYearDate//-/_}_%A.out"
    nextParallelWorkersNb=${pipeLineParallelWorkersNb[${nextIndexInPipeLine}]}
: '      
    declare -n pipeLineTasksPerNode=pipeLineTasksPerNode${pipeLineId}
    declare -n pipeLineMems=pipeLineMems${pipeLineId}
    declare -n pipeLineTimes=pipeLineTimes${pipeLineId}
'
    tmpRef=pipeLineTasksPerNodeString${pipeLineId}; pipeLineTasksPerNode=(${!tmpRef})
    tmpRef=pipeLineMemsString${pipeLineId}; pipeLineMems=(${!tmpRef})
    tmpRef=pipeLineTimesString${pipeLineId}; pipeLineTimes=(${!tmpRef})
  
    nextTasksPerNode=${pipeLineTasksPerNode[${nextIndexInPipeLine}]}
    nextMem=${pipeLineMems[${nextIndexInPipeLine}]}
    nextTime=${pipeLineTimes[${nextIndexInPipeLine}]}

    # Get the current regions and the next regions.
    # Currently only possible to transition to a bigger region e.g. from 292 to 5.
    objectIds=$(echo ${slurmArrayTaskIds} | sed -E 's~[0-9]{3}-[0-9]+~~g')
    nextObjectIdsArray=( ${objectIds//,/ })
    if [ $thisRegionType -eq 0 ] && [ $nextRegionType  -gt 0 ]; then
      nextObjectIds=""
      for thisObject in $nextObjectIdsArray; do
        if ! [[ ${nextObjectIds} =~ (^|,)${bigRegionForTile[${thisObject}]}($|,) ]]; then
          nextObjectIds="$nextObjectIds,${bigRegionForTile[${thisObject}]}"
        fi
      done
      objectIds=${nextObjectIds:1}
      nextObjectIdsArray=(${objectIds//,/ })
    elif [ $thisRegionType -gt 0 ] && [ $nextRegionType  -eq 0 ]; then
      error_exit "Line $LINENO: Pipeline next script: going back to mosdisTiles not implemented."
    fi

    # Add the sequences if required (e.g. 292001-292036,293001-293026).
    nextArray=
    if [ "$nextSequence" != "0" ]; then
      for thisObject in ${nextObjectIdsArray[@]}; do
          nextArray=$nextArray,$(echo $nextSequence | sed -E "s~-([0-9]+)~-${thisObject}\1~" | sed -E "s~^([0-9]+)~${thisObject}\1~")
      done
      nextArray=${nextArray:1}
    else
      nextArray=${objectIds}
    fi

    read -s -r -d '' nextScriptParameters << EOM
Next script in the pipeline parameters.
#############################################################################
nextJobName=${nextJobName}; nextScript=${nextScript};
nextRegionType=${nextRegionType}; nextSequence=${nextSequence};
nextArray=${nextArray}; 
nextVersionOfAncillary=${nextVersionOfAncillary}; nextMonthWindow=${nextMonthWindow};
nextWaterYearDate=${nextWaterYearDate};
nextSlurmStdOutFileName=${nextSlurmStdOutFileName//%/%%};
nextInputLabel=${nextInputLabel}; nextOutputLabel=${nextOutputLabel};
nextParallelWorkersNb=${nextParallelWorkersNb};
nextTasksPerNode=${nextTasksPerNode}; nextMem=${nextMem}; nextTime=${nextTime};
EOM
    printf "\n${nextScriptParameters}\n\n"

    nextSubmitLine=${sbatchSubmitLine}
    nextSubmitLine=$(echo ${nextSubmitLine} | sed -E 's~--begin=[0-9\:]+ ~~' | sed -E "s~/[a-zA-Z0-9\_\%]+\.out( --job-name)~/${nextSlurmStdOutFileName}\1~" | sed -E "s~( --job-name=)[a-zA-Z0-9\-]+ ~\1${nextJobName} ~" | sed -E "s~( --ntasks-per-node=)[0-9]+ ~\1${nextTasksPerNode} ~" | sed -E "s~( --mem=)[0-9]+G ~\1${nextMem} ~" | sed -E "s~( --time=)[0-9:]+ ~\1${nextTime} ~" | sed -E "s~( --array=)[0-9\,\-]+ ~\1${nextArray} ~" | sed -E "s~ \.\/scripts\/[a-zA-Z0-9]+\.sh ~ ${nextScript} ~" | sed -E "s~( -A )[a-zA-Z0-9\.]+ ~\1${nextVersionOfAncillary} ~" | sed -E "s~( -L )[a-zA-Z0-9\.\_\-]+ ~\1${nextInputLabel} ~" | sed -E "s~( -O )[a-zA-Z0-9\.\_\-]+ ~\1${nextOutputLabel} ~" | sed -E "s~( -w )[0-9]+ ~\1${nextParallelWorkersNb} ~" | sed "s~ -R ~ ~")

    if [[ "${nextSubmitLine}" == *" -D "* ]]; then
      nextSubmitLine=$(echo ${nextSubmitLine} | sed -E "s~( -D [0-9]+-[0-9]+-[0-9]+-)[0-9]+ ~\1${nextMonthWindow} ~")
    fi
    # nextSubmitLine=$(echo ${nextSubmitLine} | sed -E "s~( -L )~ -D ${nextWaterYearDate}\1~")

    if [[ "${nextSubmitLine}" != *" --dependency="* ]]; then
      nextSubmitLine=$(echo ${nextSubmitLine} | sed -E "s~(sbatch )~\1--dependency=afterok:${SLURM_ARRAY_JOB_ID} ~")
    else
      nextSubmitLine=$(echo ${nextSubmitLine} | sed -E "s~( --dependency=)[a-zA-Z0-9\:\_\-]+ ~\1afterok:${SLURM_ARRAY_JOB_ID} ~")
    fi

    printf "\n\n\n"
    printf "#############################################################################\n"
    printf "Submit schedule for next job in the pipeline.\n"
    printf "SbatchSubmitLine: ${nextSubmitLine}\n"
    printf "Next pipeline sbatch: $(echo $nextSubmitLine  | sed s~%~%%~g)\n"
    $nextSubmitLine
    printf "#############################################################################\n"
  fi
fi

########################################################################################
# 10. Shuffle ancillary from archive to scratch.
########################################################################################
# NB: the base directories of modis_ancillary version and conf should exist in archive
# and have created in scratch
: '
thisShuffle="/bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s "\
"${archivePath}modis_ancillary/ ${scratchPath}modis_ancillary/"
echo "${thisShuffle}"
$thisShuffle
'

########################################################################################
# 11. Additional log of environment variables.
########################################################################################
: '
The following commands help to debug and have the full context of the job. To uncomment
for execution when necessary.
'
printf "#############################################################################\n"
printf "Environment variables:\n"
printf "#############################################################################\n"
export

if [ -v slurmFullJobId ]; then
  printf "\n\n\n\n"
  printf "#############################################################################\n"
  printf "Scontrol show job variables:\n"
  printf "#############################################################################\n"
  scontrol show job ${slurmFullJobId}

  printf "\n\n\n\n"
  printf "#############################################################################\n"
  printf "Sacct job info:\n"
  printf "#############################################################################\n"
  sacct -j ${slurmFullJobId} -l --json
fi
