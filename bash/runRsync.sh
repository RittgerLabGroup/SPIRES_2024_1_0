#!/bin/bash
##
# Carry out the rsync from one repo to another one, for instance from scratch to
# archive or vice-versa.
# This rsync will only create or update files, it's not a mirror <> copy.
# NB: Use environment variables espArchiveDir and espScratchDir. Don't forget to set
# them.
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

PROGNAME=${BASH_SOURCE[0]}

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-x sourcePath] [-y targetPath]
    Carry out the rsync from one repo to another one, for instance from scratch to
    archive or vice-versa.
  Options:
    -x: sourcePath: string, obligatory, origin of the files to rsync. E.g. '/toto/tata/'
    -y: targetPath: string, obligatory, destination of the files. E.g. '/tutu/to/voila/'
  Arguments:
    None
  Sbatch parameters:
    --account=${slurmAccount}: string, obligatory. Account used to connect to the
    slurm partitions. Differs from blanca to alpine.
    --constraint=spsc: optional. To avoid allocation on nodes having jumbo internet
    connections 9000 instead of the classic 1500, necessary to connect to the daac
    servers. Doesnt seem necessary on alpine nodes.
    --exclude=xxx. string list, optional. List nodes you dont want your job be
    allocated on. List is of one node, or several nodes stuck and separated with
    commas. Mostly used when some blanca nodes have problems to run your script
    correctly, because those nodes have a more heterogeneous configuration than on
    alpine.
    --export=NONE: to prevent local variables to override your environment variables.
    Important when using blanca to avoid the no matlab module error.
    --job-name=mod09ga-${objectId}-${waterYearDateString}: string. Name of the job.
    Should include the id the object and the date over which the script runs.
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
    --array=1: Unused, but keep it. Variable SLURM_ARRAY_TASK_ID in the script.
  Output:
    None

EOM
  printf "$thisUsage\n" 1>&2
}

export SLURM_EXPORT_ENV=ALL

error_exit() {
  # Use for fatal program error
  # Argument:
  #   optional string containing descriptive error message
  #   if no error message, prints "Unknown Error"

  echo "${PROGNAME}: ERROR: ${1:-"Unknown Error"}" 1>&2
  exit 1
}

export SLURM_EXPORT_ENV=ALL

sourcePath=
targetPath=

while getopts "hx:y:" opt
  do
    case $opt in
      h) usage
         exit 1;;

      y) targetPath="$OPTARG";;
      x) sourcePath="$OPTARG";;
      ?) printf "Unknown option %s\n" $opt
         usage
         exit 1;;
    esac
  done

if [[ -z ${sourcePath} ]] || [[ -z ${targetPath} ]]; then
  error_exit "Line $LINENO: Source and/or target base path not given as options."
fi

thisRsync='/bin/rsync -HpvxrltogDu --chmod=ug+rw,o-w,+X,Dg+s'
# By precaution, should be in your ~/.bashrc too.
echo "${thisRsync} $sourcePath $targetPath..."
$thisRsync $sourcePath $targetPath

echo "${PROGNAME}: Done"
