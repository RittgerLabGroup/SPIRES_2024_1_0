#!/bin/bash
#
# Functions to get infos on jobs and write in logs.

# Functions.
########################################################################################
# On Blanca, seff is not systematically found. We bypass this by a direct handling
# using sacct (2023-12-19).
get_time_in_seconds(){
  # Convert time string into seconds.
  # NB: probably not all cases included...                                      warning
  # Parameters
  # ----------
  # $1: char. Time string. 1-04:02:03 or 04:02:03 or 02:03.254 only
  if [[ "$1" == *"-"* ]]; then
    # The string contains a day (and we suppose hours, mins, and secs without
    # decimals.
    echo $1 | sed 's/-/:/' | awk -F: '{ print $1 * 86400 + $2 * 3600 + $3 * 60 + $4 }'
  elif [[ "$1" == *"."* ]]; then
    # The string contains secs with decimals (and we suppose no day and no hour).
    echo $1 | awk -F: '{ print $1 * 60 + $2 }'
  elif [ ! -z fullValue ]; then
    #We suppose that it's 00:00:00, but maybe more complicated?               tocheck
    echo $1 | awk -F: '{ print $1 * 3600 + $2 * 60 + $3 }'
  else
    echo ""
  fi
}

get_mem_in_Gb(){
  # Convert memory string into gigabytes value.
  # Parameters
  # ----------
  # $1: char. Memory string. value and a K M G T P E at the end (if kb, Mb, Gb, ...)
  fullValue=$1
  if [ ! -z fullValue ]; then
    val=$(echo ${fullValue::-1})
    if [[ "$1" == *"K" ]]; then
      echo $(echo "scale=10; $val / 1024^2 " | bc)
      # NB: in bc power is ^ while in bash power is **.
    elif [[ "$1" == *"M" ]]; then
      echo $(echo "scale=10; $val / 1024^1 " | bc)
    elif [[ "$1" == *"G" ]]; then
      echo $(echo "scale=10; $val / 1024^0 " | bc)
    elif [[ "$1" == *"T" ]]; then
      echo $(echo "scale=10; $val * 1024^1 " | bc)
    elif [[ "$1" == *"P" ]]; then
      echo $(echo "scale=10; $val * 1024^2 " | bc)
    elif [[ "$1" == *"E" ]]; then
      echo $(echo "scale=10; $val * 1024^3 " | bc)
    fi
  else
    echo ""
  fi
}

validate_end_status(){
  # Update log with CPU and memory efficiency, once the slurm job is achieved
  # (the ones we get when running are unreliable).
  #
  # Parameters
  # ----------
  # $1: int. Slurm job id.
  # $2: char. Log filepath.
  #
  # Return
  # ------
  # Status: 0: Job ended and updated with stats. something else: not updated.

  thatJobId=$1
  thatLog=$2
  ml slurmtools

  # The following with seff doesn't systematically work on Blanca nodes, and RC team
  # doesn't know exactly why, and me neither, despite some research.
  # I replaced the code using seff by a more convoluted code using sacct directly.

  # Former code:
  #text=$(printf %q "$(seff ${thatJobId} | grep "CPU Efficiency" | \
  #    awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf "; ")
  #text=${text}$(printf %q "$(seff ${thatJobId} | grep "Memory Efficiency" \
  #    | awk '{print $3}' | sed s/.[0-9][0-9]//)"; printf ";")

  # New code to get info on the job:
  state=$(sacct --format State -j ${thatJobId} | sed '3q;d' | tr -d ' ')
  terminatedStates=(BOOT_FAIL CANCELLED COMPLETED DEADLINE FAILED NODE_FAIL OUT_OF_MEMORY TIMEOUT)
  if [[ ! " ${terminatedStates[*]} " =~ [[:space:]]${state}[[:space:]] ]]; then
    printf "1 - Job not ended"
    return
  fi
  sacct1=($(sacct --format AllocCPUS,ReqMem,TotalCPU,Elapsed -j ${thatJobId} | sed '3q;d' | sed 's/ \{1,\}/;/g' | tr ";" "\n"))
  sacct2=($(sacct --format MaxRSS,Ntasks -j ${thatJobId} | sed '4q;d' | sed 's/ \{1,\}/;/g' | tr ";" "\n"))
  # NB: We could also retrieve State and ExitCode (in a future dev).                 @todo
  # sacct --format JobName,User,Group,State,Cluster,AllocCPUS,REQMEM,TotalCPU,Elapsed,MaxRSS,ExitCode,NNodes,NTasks -j 3058775
  # gives three lines and sacct1 and sacct2 get variable values into arrays to be handled
  # below.

  # Check if the job was cancelled or other errors/kill signals.
  # isError=0 for no error, 1 error but job can be resubmitted, 2 error and job won't be
  # resubmitted.
  isError=0
  if [[ ! -z $(tail -n 12 $thatLog | grep -e "; end:ERROR;") ]]; then
    isError=1
  elif [[ ! -z $(tail -n 12 $thatLog | grep "slurmstepd: error: ***" | sed 's~*~~g') ]]; then
    isError=2
    if [[ ! -z $(tail -n 12 $thatLog | grep -e "slurmstepd: error: ***.* CANCELLED AT .* DUE TO TIME LIMIT ***" | sed 's~*~~g') ]]; then
      isError=1
      thisMessage="Exit=1, matlab=yes, Cancelled due to time limit."
    elif [[ ! -z $(tail -n 12 $thatLog | grep -e "slurmstepd: error: ***.* CANCELLED AT " | sed 's~*~~g') ]]; then
      thisMessage="Exit=2, matlab=?, Cancelled."
    else
      thisMessage=$(tail -n 12 $thatLog | grep -e 'slurmstepd: error: ' | sed 's~slurmstepd: error: ~~' | sed 's~*~~g' | sed 's~;~,~g')
      thisMessage="Exit=2, matlab=?, ${thisMessage}."
    fi
    # NB: We remove the *** (and ;) in the log to the message, otherwise this wildcard is replaced by list of local files.

    # Add to log the end paragraph by extracting the info from the start paragraph.
    # NB: this is dirty, beware if start paragraph changes....                    @warning
    cat $thatLog | grep "dura.; script  ;" -A 3 | sed -E "s~[0-9]{4}T[0-9]{2}:[0-9]{2}; ~$(date '+%m%dT%H:%M'); ~" | sed -E "s~; [0-9]{2}:[0-9]{2}; ~; ${sacct1[3]:0:5}; ~" | sed 's~; start    ~; end:ERROR~' | sed "s~GB; ~GB; ${thisMessage}~" >> $thatLog
  fi

  # CPU efficiency.
  cpuEfficiency=$(get_time_in_seconds ${sacct1[2]})
  cpuElapsed=$(get_time_in_seconds ${sacct1[3]})
  cpuEfficiency=$(echo "scale=10; ${cpuEfficiency} / ${cpuElapsed} / ${sacct1[0]} * 100 " | bc)
  text="$(printf "%0.0f%%; " ${cpuEfficiency})"

  if [[ ${#sacct2[*]} -eq 2 ]]; then
    # Memory efficiency.
    memEfficiency=$(get_mem_in_Gb ${sacct2[0]})
    memEfficiency=$(echo "scale=10; ${memEfficiency} * ${sacct2[1]} " | bc)
    memThatWasRequired=$(get_mem_in_Gb ${sacct1[1]})
    memEfficiency=$(echo "scale=10; ${memEfficiency} / ${memThatWasRequired} * 100 " | bc)
    text="$text$(printf "%0.0f%%;" ${memEfficiency})"
  else
    text="$text$(printf "%0.0f%%;" 0)"
  fi
  sed -ri "s/(; end:[^;]*;[^;]*; )[^;]*;[^;]*;/\1${text}/" ${thatLog}
  printf "0"
}
