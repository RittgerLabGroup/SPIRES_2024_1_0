#!/bin/bash
########################################################################################
# Submit a set of file synchronizations between 2 data spaces. See options and arguments in usage() function.

########################################################################################

shopt -s expand_aliases
source ~/.bashrc
  # to have access to alias.

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-B bigRegionId] [-e startYear] [-f endYear] [-h] [-u slurmCluster] [-v verbosity]
    [-x sourcePath] [-y targetPath]
    Submit a set of file synchronization in parallel from a source data space to a
    target data space. Using the alias rsync defined in ~.bashrc, update is carried out
    only if source is more recent.
    NB: You must launch this script when in root directory of the project.
   
  Options:
    -B bigRegionId: int, obligatory. Identifying the big region (e.g. 5 for westernUS).
      Only one big region per run.
    -e startYear: int, optional. Smallest year of run, e.g. 2024. If not given,
      startYear = endYear.
    -f endYear: int, obligatory.
      Highest year of run, of year of run, e.g. 2025.
    -h: display help message and exit.
    -u slurmCluster: int, optional. Id of the slurm cluster configuration.
      0 for Alpine (default), 1 for Blanca. Defines the slurm cluster and a
      part of the options of slurm submission.
    -v verbosity: int, optional. Default: 0, all logs, including prompts. 10: all
      logs, but no prompt.
    -x: sourcePath: string, obligatory. Source data space base path.
    -y: targetPath: string, obligatory. Target data space base path.

  Argument:
    thisFolder: String, obligatory. E.g. 'modis/intermediary/spiresfill_v2024.0d/v006/'.
      Folder path to be synchronized
EOM
  printf "$thisUsage\n" 1>&2
}
########################################################################################

workingDirectory=$(pwd)/
printf "Working directory: ${workingDirectory}.\n";

# Slurm cluster configuration constants.
########################################################################################
slurmNames=(${slurmName1} ${slurmName2})
slurmAccounts=(${slurmAccount1} ${slurmAccount2})
slurmQoss=(${slurmQos1} ${slurmQos2})
slurmLogDirs=(${espLogDir} ${espLogDir})
  # all these variables are defined in ~.bashrc.

sbatchNTasksPerNode=1;
sbatchMem=1G
sbatchTime=05:30:00
sbatchScript=bash/runRsync.sh
objectId=1
  # array of tasks for slurm, unused but necessary for runSubmitter.sh.

# Parsing of options.
########################################################################################
slurmCluster=0
verbosity=0

OPTIND=1
thisGepOptsString="B:e:f:hu:v:x:y:"
# NB: add a : in string above when option expects a value.
while getopts ${thisGepOptsString} opt
# NB: all these options whould correspond to the options caught above.
do
  case $opt in
    B) bigRegionId="$OPTARG";;
    e) startYear="$OPTARG";;
    f) endYear="$OPTARG";;
    h) usage
      exit 1;;
    u) slurmCluster="$OPTARG";;
    v) verbosity="$OPTARG";;
    x) sourcePath="$OPTARG";;
    y) targetPath="$OPTARG";;
    ?) printf "Unknown option %s\n" $opt
      usage
      exit 1;;
  esac
done

# External configuration setting.
########################################################################################
printf "Load bash/toolsRegions.sh...\n"
source bash/toolsRegions.sh

# Argument setting and check options/argument.
########################################################################################
expectedCountOfArguments=1

shift $(($OPTIND - 1))

if [[ "$#" -ne $expectedCountOfArguments ]]; then
  printf "ERROR: received %0d arguments, %0d expected (Line ${LINENO}).\n" $# $expectedCountOfArguments
  exit 1
else
  thisFolder=$1
  if [[ ! -d "${sourcePath}${thisFolder}" || ! -d "${targetPath}" ]]; then
    printf "ERROR: option -x sourcePath ${sourcePath} or argument thisFolder ${thisFolder} on source or or option -y targetPath ${targetPath} are not valid directories (Line ${LINENO}).\n"
  exit 1
  fi
fi

if [[ -z $bigRegionId || ! -v bigRegionId[$bigRegionId] ]]; then
  printf "ERROR: -B bigRegionId ${bigRegionId} is not configured (Line ${LINENO}).\n"
  exit 1
fi

declare -a years=({"$startYear".."$(($endYear))"})

# Determine variables for submission.
########################################################################################
printf "Starting submission of runRsync...\n"

sbatchExcludeNodes=""; # "--exclude=bgpu-mktg1,bgpu-g4-18";

ml slurm/${slurmNames[$slurmCluster]};
slurmAccount=${slurmAccounts[$slurmCluster]}; 
slurmLogDir=${slurmLogDirs[${slurmCluster}]};
slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
slurmQos=${slurmQoss[${slurmCluster}]};

regionNames=$(get_region_names_from_object_ids_string $(get_object_ids_from_big_region_object_ids_string $bigRegionId)),${allRegionNames[$bigRegionId]}
regionNamesArray=($(echo "$regionNames" | tr ',' ' '))

submitScriptIdJobName=sSyH${bigRegionId}
scriptIdJobName=synH${bigRegionId}

read -s -r -d '' scriptParameters << EOM
Script parameters.
#############################################################################
region= $bigRegionId - ${allRegionNames[$bigRegionId]}
regionNames= ${regionNames}
years= ${years[0]} - ${years[-1]}
thisFolder= ${thisFolder}
sourcePath= ${sourcePath}
targetPath= ${targetPath}
thisScriptIdJobName= ${scriptIdJobName} + year 2 last digits
slurmLogDir= ${slurmLogDir}
sbatchExcludeNodes= $sbatchExcludeNodes
EOM
printf "\n${scriptParameters}\n\n"

# Submit jobs. 
########################################################################################

# Instantiate submitLine and submit the controling job of the daily run.
########################################################################################

read -r -d '' thisHeader << EOM
Job to be submitted:
#############################################################################
EOM
printf "\n${thisHeader}\n"

submitLine="sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptIdJobName}XX --cpus-per-task=1 --ntasks-per-node=${sbatchNTasksPerNode} --mem=${sbatchMem} --time=${sbatchTime} --array=${objectId} ${sbatchScript} -x ${sourcePath}${thisFolder}XX/XX/ -y ${targetPath}${thisFolder}/XX/XX/"

echo "${submitLine}"
printf "\n"
if [[ verbosity -eq 0 ]]; then
  read -p "Do you want to proceed submission of rsync from ${sourcePath} to ${targetPath}? (y/n) " yn

  case $yn in 
    y )
      ;;
    n ) echo "Submission aborted.";
      exit;;
    * ) echo "Invalid response";
      exit 1;;
  esac
fi

for regionName in ${regionNamesArray[@]}; do
  for year in ${years[@]}; do
    thisScriptIdJobName=${scriptIdJobName}${year: -2};

    submitLine="sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${thisScriptIdJobName} --cpus-per-task=1 --ntasks-per-node=${sbatchNTasksPerNode} --mem=${sbatchMem} --time=${sbatchTime} --array=${objectId} ${sbatchScript} -x ${sourcePath}${thisFolder}${regionName}/${year}/ -y ${targetPath}${thisFolder}${regionName}/${year}/"
    
    ${submitLine}
  done
done;

# NB: runSubmitter.sh not adapted to track results of runRsync.sh yet.             @todo
