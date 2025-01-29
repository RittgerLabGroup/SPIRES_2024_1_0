#!/bin/bash
#
# script to launch jobs and handle pipelines, logs, and resubmit jobs which failed
# in certain errors (cancelled due to time limit, identity mis-mapping, failed to
# start pool of parallel workers.
#
# NB: only works with Slurm (no independent launching of script).

#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME} submitLine
    Handles pipelines and resubmission of failed jobs.
  Arguments:
    submitLine: string. Full command to launch in a job, starting with sbatch ...
  Sbatch parameters:
    --account=${slurmAccount}: string, obligatory. Account used to connect to the
    slurm partitions. Differs from blanca to alpine.
    --exclude=xxx. string list, optional. List nodes you dont want your job be
    allocated on. List is of one node, or several nodes stuck and separated with
    commas. Mostly used when some blanca nodes have problems to run your script
    correctly, because those nodes have a more heterogeneous configuration than on
    alpine.
    --export=NONE: to prevent local variables to override your environment variables.
    Important when using blanca to avoid the no matlab module error.
    --job-name=submitte: string. Name of the job.
    --ntasks-per-node=1: number of cores to be allocated.
    --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS: sends e-mail when
    job in error or requeued by sys admin. ARRAY_TASKS indicates that one e-mail
    per array task id is sent. If want in all cases, add values BEGIN,END,STAGE_OUT.
    If want no e-mail, replace the full string by NONE.
    --mail-user=xxx@xxx: e-mail addresses to where the e-mails are sent. If not set,
    default to user e-mail.
    --mem=1G: memory to be allocated. On Alpine qos normal, memory is dependent on
    the number of cores, each core having 3.8G, and this parameter can override
    ntasks-per-node. E.g. here if I set --mem 5G, alpine will require 2 cores
    instead of 1. On Blanca qos preemptable, the 2 parameters are independent.
    NB: this mem is the peak of memory you will be allowed. If the script requires
    a higher peak at some point, slurm stops the job with an out of memory error.
    -o=${slurmLogDir}%x-%A_%a.out: string. Location of the log file. %x for the job
    name, %A for the id of the job and %a for the array task id.
    NB: This location should be on the correct scratch of the alpine or blanca
    cluster. Each cluster cannot access to the scratch of the other cluster.
    NB: the directory of the log file MUST exis otherwise slurm doesnt write the
    logs.
    NB: this output log filepath is not transferred to the script as a variable. So
    we have to redefine it in toolStart.sh as $THISSBATCH_OUTPUT. Keep the -o string
    to %x-%A_%a.out, or change both $THISSBATCH_OUTPUT and the -o string.
    --qos=${slurmQos}: string, obligatory. Indicates which pool of nodes you ask your
    allocation for. For alpine --qos=normal, for blanca --qos=preemptable. Other
    qos are also available.
    --time=HH:mm:ss: string format time, obligatory. Indicate the time at which slurm
    will automatically cancel the job.
    --array=1: Unused, keep to 1.
  Output:
    Scratch and archive, subfolder slurm_out/

EOM
  printf "$thisUsage\n" 1>&2
}

check_scancel_for_submitter() {
  # Check if scancel is required for the ongoing runSubmitter job, based on a flag file
  # on operator's scratch, espJobs/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_scancel.txt
  
  scancelSubmitterFilePath=${espScratchDir}espJobs/${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}_scancel.txt

  if [[ -f ${scancelSubmitterFilePath} ]]; then
    printf "\n\n\n\n"
    printf "#############################################################################\n"
    printf "Detected flag file ${scancelSubmitterFilePath}:\n"
    printf "Cancelling job ...\n"
    printf "#############################################################################\n"
    printf "Submitter job cancelled. (Pipeline stopped).\n"
    printf "\nend:ERROR.\n"
    exit 1
  fi
}

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
fileSeparator='/'
sleep 5
# Might help to make work sacct (sacct not fully informed at the beginning of a job).

if [ ! -v SLURM_JOB_ID ]; then
  printf "runSubmitter.sh should be launched using submission to Slurm.\n"
  exit 1
fi

source scripts/toolsJobs.sh
  # Include $slurmTerminatedStates

# Get info on the runSubmitter job.
submitterSlurmFullJobId=${SLURM_JOB_ID}
printf "Job ${SLURM_JOB_ID}.\n"

pwd
printf "Github branch: $(git rev-parse --abbrev-ref HEAD)\n"
printf "$(bash --version | grep version | head -1)\n"
printf "#############################################################################\n\n"

printf "\n\n\n\n"
printf "#############################################################################\n"
printf "Scontrol show job variables:\n"
printf "#############################################################################\n"
scontrol show job ${SLURM_JOB_ID}

# NB: scontrol only works for ongoing jobs.
submitterSControl=$(scontrol show job ${submitterSlurmFullJobId} | tr -s ' ' | tr ' ' '\n' | tr -s '\n')
submitterSlurmStdOut=$(echo "$submitterSControl" | grep StdOut | cut -d = -f 2)
# slurmStdErr=slurmStdOut.
# Should be constructed as "${slurmLogDir}${SLURM_JOB_NAME}-${SLURM_ARRAY_JOB_ID}_${SLURM_ARRAY_TASK_ID}.out"
slurmLogDir=$(dirname "${submitterSlurmStdOut}")${fileSeparator}

# Get info on job and tasks (object ids) to submit and submit it.
submitLine="$1"
echo "${submitLine}"
thatArrayJobId=$($submitLine)
printf "$thatArrayJobId\n"
thatArrayJobId=$(echo ${thatArrayJobId} | grep "Submitted batch job" | cut -d ' ' -f 4)
printf "thatArrayJobId: $thatArrayJobId\n"
# There's a set of jobs to log-track
# There's one synthesis file per set of jobs (=step) for a pipeline, or if no pipeline,
# there's only 1 synthesis file.
jobSynthesisFilePath=
isFatalError=

while [ ! -z $thatArrayJobId ]; do
  check_scancel_for_submitter
  jobName=$(echo $submitLine | sed -E 's~[^@]+ --job-name=([/_%\.0-9a-zA-Z]+) [^@]+~\1~')
  printf "Track logs of ${jobName} ${thatArrayJobId}, for submitLine:\n"
  echo $(date '+%H:%M:%S')": ${submitLine}"
  logFilePathPattern=$(echo $submitLine | sed -E 's~[^@]+ -o ([/_%\.0-9a-zA-Z\-]+) [^@]+~\1~')
    # Nb: \- should always be at the end of a regexp pattern.
  echo "$logFilePathPattern"

  # taskIds form the list of unique objects for which the job is required.
  taskIds=",$(echo ${submitLine} | sed -E 's~sbatch [^@]+ --array=([0-9,\-]+) [^@]+~\1~'),"
  taskIds=$(echo $taskIds | sed -E 's~,([0-9]+)-([0-9]+)~ for i in $(seq \1 \2); do printf "$i "; done;~g' | sed -E 's~,([0-9]+)~ printf "\1 "; ~g' | tr ',' ' ' )
  taskIds=$(eval $taskIds);
  countOfTaskId=$(echo $taskIds | wc -w)
  taskIds=($taskIds)

  if [ -z $jobSynthesisFilePath ]; then
    jobSynthesisFilePath="${slurmLogDir}${submitterSlurmFullJobId}_${jobName}_${thatArrayJobId}_job_synthesis.csv"
    printf "\nSynthesis file: ${jobSynthesisFilePath}.\n"
  fi

  # arrayJobIds and tasksForArrayJobIds form the list of couples arrayJobId - taskId
  # (=objectId) submitted. These lists
  # are increased each time we relaunch the job for an object. So there can be several
  # lines for 1 taskId if the job has been resubmitted several times for this taskId.
  # currentArrayJobIdForTaskIds has the same number of elements as taskIds and indicates
  # the current arrayJobId in preparation or running for the taskId as a key of the
  # array. That array is updated each time a job is resubmitted for a taskId.
  printf "Creation of arrayJobIds with parent ${thatArrayJobId} and ${countOfTaskId} taskIds.\n"
  arrayJobIds=($(printf "%1.0s${thatArrayJobId}" $(seq 1 "${countOfTaskId}")))
  tasksForArrayJobIds=("${taskIds[@]}")
    # Copy array.
  arrayJobIdsStatus=($(printf "0 %.0s" $(seq 1 "${countOfTaskId}")))
    # 0 if job non ended, 1 if ended and stats updated in log.

  currentArrayJobIdForTaskIds=()
  for ((idx = 0 ; idx < ${countOfTaskId} ; idx++ )); do
    thisTaskId=${taskIds[$idx]}
    thisArrayJobId=${arrayJobIds[$idx]}
    printf "currentArrayJobIdForTaskIds[${thisTaskId}]=${thisArrayJobId}\n"
    currentArrayJobIdForTaskIds[$thisTaskId]=${arrayJobIds[$idx]}
  done

  read -r -d '' updatedSynthesisHeader << EOM
date%6s; dura.; script  ; job%5s; obj.; cell; date%9s; status%3s; hostname%7s; CPU%%; mem%%; cores; totalMem; message
.....................................................................
EOM

  countOfTaskIdDone=0
  firstTaskInError=0
  # We check job status at regular intervals. If in error, possible resubmission. All
  # status are saved in a variable $updatedSynthesis.
  # If first task in error, end of the loop and full resubmission (as if it was next
  # job in pipeline, but no record in synthesis).
  while [[ $countOfTaskIdDone -ne $countOfTaskId ]] && [[ firstTaskInError -ne 1 ]]; do
    check_scancel_for_submitter
    #sleep $(( 30 * 1 ))
    sleep $(( 60 * 5 ))
      # wait 5 mins
    check_scancel_for_submitter
    date '+%d/%m/%Y %H:%M:%S'
    updatedSynthesis="${updatedSynthesisHeader}\n"
    countOfTasksForArrayJobIds=${#tasksForArrayJobIds[@]}
    theseTaskIdsToResubmit=
    nodesToExclude=

    # Scan the job status.
    for ((idx = 0 ; idx < $countOfTasksForArrayJobIds ; idx++ )); do
      thisTaskId=${tasksForArrayJobIds[$idx]}
      thisArrayJobId=${arrayJobIds[$idx]}
      thisLogFilePath=$(echo $logFilePathPattern | sed -E "s~/%[a-zA-Z_]+%a_([0-9_\-]*)%A~/*${thisTaskId}_\1${thisArrayJobId}~")
      echo ${thisLogFilePath}
      thisStatus=""
      if [ -f ${thisLogFilePath} ]; then
        # Check job state and potentially update log with efficiency stats.
        if [[ ${arrayJobIdsStatus[$idx]} -eq 0 ]]; then
        # obsolete. [[ ! " ${arrayJobIdsWithEndedStatus[*]} " =~ [[:space:]]"${thisArrayJobId}_${thisTaskId}"[[:space:]] ]]; then
          endStatus=$(validate_end_status "${thisArrayJobId}_${thisTaskId}" ${thisLogFilePath})
          echo "endStatus: "$endStatus
          if [[ "$endStatus" == "0" ]]; then
            # obsolete. arrayJobIdsWithEndedStatus+=("${thisArrayJobId}_${thisTaskId}")
            arrayJobIdsStatus[$idx]=1
          fi
        fi
        
        thisStatus=$(cat $thisLogFilePath | grep "dura.; script  ;" -A 2 | tail -1 | sed 's~%~%%~g')
        # If in error with exit 1, add the task in the resubmission list.
        echo "Status: "$thisStatus
: '
        # For testing purpose:
        if [[ $thisTaskId -eq 364001 || $thisTaskId -eq 364002 ]] && [[ ! -v isErrorDone ]]; then
          thisStatus="; end:ERROR; Exit=1, Defective node, impossible to login;"
          isErrorDone=1
        fi
'
        thisCurrentArrayJobIdForTaskId=${currentArrayJobIdForTaskIds[${thisTaskId}]}
        printf "currentArrayJobIdForTaskIds: ${thisCurrentArrayJobIdForTaskId}, thisArrayJobId: ${thisArrayJobId}.\n"
        if [[ $thisStatus == *"end:ERROR"* ]] && [[ ${currentArrayJobIdForTaskIds[${thisTaskId}]} -eq $thisArrayJobId ]]; then
          if [[ $thisStatus == *"Exit=1,"* ]] && [[ $thisStatus != *"MATLAB:load:couldNotReadFile"* ]] && [[ $thisStatus != *"MATLAB:MatFile:NoFile"* ]] && [[ $thisStatus != *"MATLAB:save:NotAMATFile"* ]] && [[ $thisStatus != *"MATLAB:whos:badVariableName"* ]] && [[ $thisStatus != *"MATLAB:imagesci:h5info:unableToFind"* ]]; then
            # MATLAB:load:couldNotReadFile and MATLAB:MatFile:NoFile can occur when
            # files were deleted from scratch and didnt have been synchronized from
            # archive to scratch.
            printf "Error on job ${thisArrayJobId}_${thisTaskId}, inserted into list for resubmission.\n"
            theseTaskIdsToResubmit=${theseTaskIdsToResubmit}${thisTaskId},

            thisNode=$(echo $thisStatus | cut -d ';' -f 9 | xargs)
            echo "Node: "$thisNode
            if ( [[ $thisStatus == *"Defective node, impossible to login"* ]] || [[ $thisStatus == *"Defective node, scratchPath inaccessible"* ]] || [[ $thisStatus == *"matlab=ESPEnv:InvalidScratchPath"* ]]) && [[ $nodesToExclude != *"${thisNode}"* ]]; then
            # NB: if nodesToExclude is array, we would have used this: [[ -z $(printf '%s\0' "${nodesToExclude[@]}" | grep -F -x -z -- "${thisNode}") ]]
                printf "Exclusion of defective node ${thisNode}.\n"
                nodesToExclude=${nodesToExclude}${thisNode},
            fi
            echo "Nodes to exclude: "$nodesToExclude
          else
            printf "Fatal error on job ${thisArrayJobId}_${thisTaskId}, no resubmission.\n"
            isFatal=1
            currentArrayJobIdForTaskIds[${thisTaskId}]=0
          fi
        fi
      fi
      updatedSynthesis="${updatedSynthesis}${thisStatus}\n"
    done

    # Resubmission and update of $currentArrayJobIdForTaskIds.
    if [[ ! -z ${theseTaskIdsToResubmit} ]]; then
      # If first task in error, we cancel the job and resubmit everything (it's because the first task is the one which will launch the next task in pipeline.
      if [[ ${theseTaskIdsToResubmit} == *"${tasksForArrayJobIds[0]}"* ]]; then
        firstTaskInError=1
        printf "First task in error, stopping jobs for ${arrayJobIds[0]}.\n"
        for ((idx = 0 ; idx < $countOfTasksForArrayJobIds ; idx++ )); do
          thisTaskId=${tasksForArrayJobIds[$idx]}
          thisArrayJobId=${arrayJobIds[$idx]}
          touch ${espScratchDir}espJobs/${thisArrayJobId}_${thisTaskId}_scancel.txt
        done
        allAreTerminated=0
        while [[ $allAreTerminated -ne 1 ]]; do
          sleep $(( 30 * 1 ))
          allAreTerminated=1
          for ((idx = 0 ; idx < $countOfTasksForArrayJobIds ; idx++ )); do
            thisTaskId=${tasksForArrayJobIds[$idx]}
            thisArrayJobId=${arrayJobIds[$idx]}
            state=$(sacct --format State -j ${thisArrayJobId}_${thisTaskId} | sed '3q;d' | tr -d ' ')
            if [[ ! " ${slurmTerminatedStates[*]} " =~ [[:space:]]${state}[[:space:]] ]]; then
              allAreTerminated=0
              printf "$(date +'%H:%M:%S'): Jobs not terminated (e.g. ${thisArrayJobId}_${thisTaskId}).\n"
              break
            fi
          done
        done
        # obsolete. 20241205. scancel ${arrayJobIds[0]}
      else
        reSubmitLine=$submitLine;
        theseTaskIdsToResubmit=$(echo $theseTaskIdsToResubmit | sed 's~,$~~')
        reSubmitLine=$(echo ${reSubmitLine} | sed -E "s~ -Z [0-9]+~ ~" | sed -E "s~ --dependency=[a-zA-Z0-9\:\,]+~~" | sed -E "s~( --array=)[0-9\,\-]+ ~\1${theseTaskIdsToResubmit} ~" | sed "s~ -R ~ ~" | sed -E "s~ -Z [0-9]+~ ~")
          # We dont include the pipeline option -Z to prevent duplicate submission
          # of next step  in the pipeline.
          # We also remove the dependency otherwise slurm raises an error (if the
          # dependent job is achieved).
        if [[ ! -z ${nodesToExclude} ]]; then
          nodesToExclude=$(echo $nodesToExclude | sed 's~,$~~')
          if [[ $reSubmitLine == *" --exclude="* ]]; then
            reSubmitLine=$(echo ${reSubmitLine} | sed -E "s~( --exclude=[]\[a-zA-Z0-9\,\-]+) ~\1,${nodesToExclude} ~")
              # NB: regexp requires that if [ is part of a group, it be placed just after
              # the opening [ of the group.
          else
            reSubmitLine=$(echo ${reSubmitLine} | sed -E "s~ --array=~ --exclude=${nodesToExclude} --array=~")
          fi
        fi
        check_scancel_for_submitter
        printf "Resubmission of taskIds in error:\n"
        echo "$reSubmitLine"
        resubmitArrayJobId=$($reSubmitLine)
        printf "$resubmitArrayJobId\n"
        resubmitArrayJobId=$(echo ${resubmitArrayJobId} | grep "Submitted batch job" | cut -d ' ' -f 4)

        theseTaskIdsToResubmit=($(echo ${theseTaskIdsToResubmit} | tr "," " "))
        for ((idx = 0 ; idx < ${#theseTaskIdsToResubmit[@]} ; idx++ )); do
          # Add in overall arrays
          thisTaskId=${theseTaskIdsToResubmit[$idx]}

          arrayJobIds+=(${resubmitArrayJobId})
          tasksForArrayJobIds+=(${thisTaskId})
          arrayJobIdsStatus+=0

          # Update the $currentArrayJobIdForTaskIds
          currentArrayJobIdForTaskIds[${thisTaskId}]=${resubmitArrayJobId}
        done
      fi
    fi

    printf "Synthesis:\n$updatedSynthesis\n"

    countOfTaskIdDone=$(printf "$updatedSynthesis" | grep "end:DONE" | grep "%; " | wc -l)
      # A task is considered done when done in the log + stats in log updated by runSubmitter.sh, validate_end_status() above.
    printf "Jobs done: ${countOfTaskIdDone}/${countOfTaskId}.\n\n"
  done

  if [[ $firstTaskInError -ne 1 ]]; then
    # We save the synthesis only if first task done.
    printf "$updatedSynthesis" >> $jobSynthesisFilePath
    printf "Synthesis for ${jobName} saved in ${jobSynthesisFilePath}\n"
  fi

  #                                                                                @todo
  # USE A PARAM TO ACTIVATE/DEACTIVATE RESUBMISSION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  #if [[ $sbatchSubmitLine == *" -r "* ]]

  # Next jobs in the pipeline.
  # Reset of dependency (necessary if some of tasks went on error exit=1).
  if [ -z $isFatal ]; then

    if [[ $firstTaskInError -eq 1 ]]; then
      # If first task in error we relaunch the full job, the first task in error may
      # have not submitted the next job in pipeline. We also exclude the nodes which
      # failed

      # Adding nodes to exclude (similar code to above).
      if [[ ! -z ${nodesToExclude} ]]; then
        nodesToExclude=$(echo $nodesToExclude | sed 's~,$~~')
        if [[ $submitLine == *" --exclude="* ]]; then
          submitLine=$(echo ${submitLine} | sed -E "s~( --exclude=[]\[a-zA-Z0-9\,\-]+) ~\1,${nodesToExclude} ~")
            # NB: regexp requires that if [ is part of a group, it be placed just after
            # the opening [ of the group.
        else
          submitLine=$(echo ${submitLine} | sed -E "s~ --array=~ --exclude=${nodesToExclude} --array=~")
        fi
      fi

      submitLine=$(echo ${submitLine} | sed -E "s~ --dependency=[a-zA-Z0-9\:\,]+~~")
          # We also remove the dependency otherwise slurm raises an error (if the
          # dependent job is achieved).
      printf "Full resubmission because first task in error, submitLine:\n"
      echo "${submitLine}"
      thatArrayJobId=$($submitLine)
      printf "$thatArrayJobId\n"
      thatArrayJobId=$(echo ${thatArrayJobId} | grep "Submitted batch job" | cut -d ' ' -f 4)
      printf "thatArrayJobId: $thatArrayJobId\n"
    else
      # Otherwise, catch arrayJobId of next job in the pipeline, submitted in first task
      # job.
      
      minTaskId=${tasksForArrayJobIds[0]}
      idxForMinTaskId=0
      for (( i=1; i<${#tasksForArrayJobIds[@]}; i++ )); do
        if [ "${tasksForArrayJobIds[$i]}" -lt "$minTaskId" ]; then
          minTaskId="${tasksForArrayJobIds[$i]}"
          idxForMinTaskId="$i"
        fi
      done
      thisTaskId=${tasksForArrayJobIds[$idxForMinTaskId]}
      thisArrayJobId=${arrayJobIds[$idxForMinTaskId]}
      thisLogFilePath=$(echo $logFilePathPattern | sed -E "s~/%[a-zA-Z_]+%a_([0-9_\-]*)%A~/*${thisTaskId}_\1${thisArrayJobId}~")
      echo $thisLogFilePath
      submitLine=$(cat $thisLogFilePath | grep "Next pipeline sbatch: " -A 1 | tail -2 | sed 's~%~%%~g')
      thatArrayJobId=$(printf "$submitLine" | grep "Submitted batch" | cut -d ' ' -f 4)
      submitLine=$(printf "$submitLine" | head -1 | sed 's~Next pipeline sbatch: ~~')
      if [ ! -z ${thatArrayJobId} ]; then
        printf "Next job ${thatArrayJobId} in ${thisLogFilePath}:\n"
        echo $submitLine
        printf "Reset dependency.\n"
        scontrol update job=${thatArrayJobId} dependency=""
      else
        printf "No further job to launch (Pipeline achieved).\n"
        printf "\nend:DONE.\n"
      fi
    fi
  else
    thatArrayJobId=
    printf "Fatal error. (Pipeline stopped).\n"
    printf "\nend:ERROR.\n"
  fi
done

printf "#############################################################################\n"
printf "Check if submission of similar job day + 1...\n"
printf "#############################################################################\n"
beginTime=(19:45:00)
repeatBeginTime=${beginTime[0]}
printf "Submit line of the runSubmitter.sh job:\n"
printf "sacct -j ${submitterSlurmFullJobId} --format SubmitLine%%1000 | awk '/sbatch[^@]+/{ print \$0 }' | sed 's~sh sbatch~sh \"sbatch~' | sed -E 's~$~\"~' | tr -s ' ' | sed -E 's~^ ~~' | sed -E 's~ \"$~\"~' | xargs -d '\n'"
sacct -j ${submitterSlurmFullJobId} --format SubmitLine%1000 | awk '/sbatch[^@]+/{ print $0 }' | sed 's~sh sbatch~sh "sbatch~' | sed -E 's~$~"~' | tr -s ' ' | sed -E 's~^ ~~' | sed -E 's~ "$~"~' | xargs -d '\n'
# xargs -d '\n' to keep the quotes ".
sbatchSubmitLine=$(sacct -j ${submitterSlurmFullJobId} --format SubmitLine%1000 | awk '/sbatch[^@]+/{ print $0 }' | sed 's~sh sbatch~sh "sbatch~' | sed -E 's~$~"~' | tr -s ' ' | sed -E 's~^ ~~' | sed -E 's~ "$~"~' | xargs -d '\n')
repeatSubmitLine=$sbatchSubmitLine
: '
if [[ "${repeatSubmitLine}" =~  .+begin=.+ ]]; then
  repeatSubmitLine="$(echo "${repeatSubmitLine}" | sed -r s~--begin=[0-9\:]+~--begin=${repeatBeginTime}~)"
  printf "\n\n\n"
  printf "#############################################################################\n"
  printf "Submit schedule for repeated job.\n"
  printf "Time: ${repeatBeginTime}.\n"
  printf "SbatchSubmitLine: ${sbatchSubmitLine}\n"
  printf "Next repeat sbatch: $(echo $repeatSubmitLine  | sed s~%~%%~g)\n"
  $repeatSubmitLine
  printf "#############################################################################\n"
else
'
  #repeatSubmitLine="${repeatSubmitLine/sbatch/sbatch --begin=${repeatBeginTime} }"
  printf "\n\n\n"
  printf "#############################################################################\n"
  printf "Absence of begin in submit line. No submit schedule for repeated job.\n"
  printf "#############################################################################\n"
#fi

