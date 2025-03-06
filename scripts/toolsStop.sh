#printf "$(pStart): Exit before execution"
#exit 1
#: '
if [ $matlabLaunched ] && [ ${#matlabString} -gt 0 ]; then
  printf "\n\n\n\n"
  printf "#############################################################################\n"
  printf "Matlab string:\n"
  printf "#############################################################################\n"

  printf '%s' "$matlabString"
  printf "\n\n"

  matlabString=$(printf '%s' "$matlabString" | sed -E "s~%[%]+$~~g" | sed -E "s~% [^$]+$~~g" | sed "s~\.\.\.~~g" | awk '{ printf "%s", $0 }' | tr -s ' ')

  printf '%s' "$matlabString"
  printf "\n\n"
  matlab -nodesktop -nodisplay -r "${matlabString}"
  exitCode=$?
  #exitCode=0
  printf "\nexitCode=${exitCode}\n"
  sleep 3
    # To make sure that log was written in slurmStdOut
  matlabExitCode=
  if [ ! -v $slurmStdOut ]; then
    matlabExitWithError=$(tail -n 20 $slurmStdOut | grep "Error: ")
    matlabExitWithExecutionError=$(tail -n 20 $slurmStdOut | grep -E "[a-zA-Z ]+Error: ")
      # Wasn't able to discriminate by using grep -E "^Error: "
    if [[ ! -z $matlabExitWithError && -z $matlabExitWithExecutionError ]]; then
      # Matlab string incorrectly formulated, but exclude the cases when Matlab execution error.
      exitCode=99;
      printf "\nUpdated exitCode=${exitCode}\n"
      matlabExitCode="no, Matlab not executed. $(echo $matlabExitWithError | cut -d ':' -f 2 | xargs)"
    else 
      matlabExitCode="$(tail -n 20 $slurmStdOut | grep "matlabExitCode=" | tail -1 | cut -d = -f 2)"
      matlabExitCode=$(echo $matlabExitCode)
      # To remove newlines
    fi
  fi
  printf "Bash got matlabExitCode=${matlabExitCode}\n"
  #Clean up temporary directory for matlab job storage
  echo "${programName}: Removing TMPDIR=$TMPDIR..."
  rm -rf $TMPDIR
  
  thisMessage="Exit=${exitCode}, matlab=";
  if [ ! -v "$matlabExitCode" ]; then
    thisMessage="${thisMessage}${matlabExitCode}, "
    if [[ "$matlabExitCode" == "parallel:cluster:PoolRunValidation" ]]; then
      thisMessage="${thisMessage}Parallel pool did not start."
    elif [ $exitCode -ne 0 ]; then
      thisMessage="${thisMessage}Line $LINENO: Matlab."
    else
      thisMessage="${thisMessage}Matlab executed."
    fi
  else
    matlabExitCode="no, Matlab not executed."
    thisMessage="${thisMessage}${matlabExitCode}"
  fi
  if [ $exitCode -ne 0 ] || [ "$matlabExitCode" == "no" ]; then
    error_exit "$thisMessage"
  fi
elif [ ${#matlabString} -gt 0 ]; then
  error_exit "Exit=, matlab=no, Matlab not executed."
fi
#'
#sleep 50
thisMessage="Exit=0, matlab=0, Matlab executed."
log_level_1 "end:DONE" "$thisMessage"
