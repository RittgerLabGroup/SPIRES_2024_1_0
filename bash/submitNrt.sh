#!/bin/bash
########################################################################################
# Submit the daily run pipeline of id pipelineId, starting at the required step
# indicated by the argument scriptId. See options and arguments in usage() function.

########################################################################################

shopt -s expand_aliases
source ~/.bashrc
  # to have access to alias.

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-E thisEnvironment] [-T controlTime] [-U thisStepOnly] [-v verbosity]
    [-W espWebExportConfId] [-y archivePath] [-Z pipelineId] [scriptId]
    Submit the near real time spires pipeline, starting by a step (scriptId).
    NB: You must launch this script when in root directory of the project.
   
  Options:
    -E thisEnvironment: String, obligatory. E.g. SpiresV202410, Dev.
      Gives the environment version, to distinguish between different version of the
      algorithm used to calculate snow properties.
    -T controlTime: String format 00:00:00, optional. Wall-time of the runSubmitter.sh
      execution, beyond which the monitoring of the pipeline will be stopped. By
      default, time indicated in configuration.sh for the pipeline
      ($pipeLineControlTime).
    -U thisStepOnly: Int, optional. Default: 0, all steps after the script scriptId
      will be executed. 1: only the given step will be executed (=break the pipeline
      after the step).
    -v verbosity: Int, optional. Default: 0, all logs, including prompts. 10: all logs,
      but no prompt.
    -W espWebExportConfId: Int, optional. Configuration id of the target of web export
      server. 0: Prod (default), 1: Integration, 2: QA. 
    -y archivePath: String, optional. Default $espArchiveDirOps defined in .bashrc.
      Directory path of the archive from which are
      collected the most up-to-date data of previous days to the scratch of the user,
      and to which output data are rsync from this scratch.
    -Z pipelineId: Int, obligatory. E.g. 1. Should refer to a pipelineId defined in
      configuration.sh (or configurationV.sh, with V the environment version, e.g
      V202410).
 
  Arguments:
    - scriptId: String, optional. Default: First script of the pipeline. Code of the
        script to
        start the pipeline with. Should have values in $pipeLineScriptIdsX defined in
        configuration.sh (or configurationV.sh), with X the pipelineId given by -Z.
  Sbatch parameters:
    No slurm use.
  Output:
    Terminal.

EOM
  printf "$thisUsage\n" 1>&2
}

workingDirectory=$(pwd)/
printf "Working directory: ${workingDirectory}.\n";

# Parsing of options.
########################################################################################
controlTime=
thisStepOnly=0
verbosity=0
espWebExportConfId=0

OPTIND=1
thisGepOptsString="E:T:U:v:W:y:Z:"
while getopts ${thisGepOptsString} opt; do
  case $opt in
    E) thisEnvironment="$OPTARG";;
    T) controlTime="$OPTARG";;
    U) thisStepOnly="$OPTARG";;
    v) verbosity="$OPTARG";;
    W) espWebExportConfId="$OPTARG";;
    y) archivePath="$OPTARG";;
    Z) pipelineId="$OPTARG";;
    ?) printf "Unknown option %s\n" $opt
    usage
    exit 1;;
  esac
done

webExportPlatforms=("PRODUCTION SNOW-TODAY" INTEGRATION QUALIFICATION);
webExportPlatform=${webExportPlatforms[espWebExportConfId]};

read -r -d '' scriptOptions << EOM
Script options:
#############################################################################
thisEnvironment= ${thisEnvironment}; controlTime= ${controlTime};
thisStepOnly= ${thisStepOnly}; verbosity= ${verbosity};
espWebExportConfId= ${espWebExportConfId} (${webExportPlatform});
pipelineId= ${pipelineId};
EOM
printf "\n${scriptOptions}\n"

shift $(($OPTIND - 1))

# External configuration setting.
########################################################################################
printf "Load bash/configuration${thisEnvironment}.sh...\n"
source bash/configuration${thisEnvironment}.sh # include source env/.matlabEnvironmentVariables${thisEnvironment^}
printf "Load bash/toolsRegions.sh...\n"
source bash/toolsRegions.sh

# Referencing the parameters on the selected pipeline.
########################################################################################
# Based on pipelinId option and on configuration.sh. Declare -n requires bash 4.3+
declare -n pipeLineBigRegionId="pipeLineBigRegionId${pipelineId}"
declare -n pipeLineVersionOfAncillary="pipeLineVersionOfAncillary${pipelineId}"
declare -n pipeLineInputProductAndVersion="pipeLineInputProductAndVersion${pipelineId}"
declare -n pipeLineControlScriptId="pipeLineControlScriptId${pipelineId}"
declare -n pipeLineControlTime="pipeLineControlTime${pipelineId}"
declare -n pipeLineScriptIds="pipeLineScriptIds${pipelineId}"
declare -n pipeLineLabels="pipeLineLabels${pipelineId}"
declare -n pipeLineRegionTypes="pipeLineRegionTypes${pipelineId}"
declare -n pipeLineSequences="pipeLineSequences${pipelineId}"
declare -n pipeLineSequenceMultiplierToIndices="pipeLineSequenceMultiplierToIndices${pipelineId}"
declare -n pipeLineMonthWindows="pipeLineMonthWindows${pipelineId}"
declare -n pipeLineParallelWorkersNb="pipeLineParallelWorkersNb${pipelineId}"
declare -n pipeLineTasksPerNode="pipeLineTasksPerNode${pipelineId}"
declare -n pipeLineMems="pipeLineMems${pipelineId}"
declare -n pipeLineTimes="pipeLineTimes${pipelineId}"

regionId=${pipeLineBigRegionId}
versionOfAncillary=${pipeLineVersionOfAncillary};
inputProductAndVersion=${pipeLineInputProductAndVersion};
controlScriptId=${pipeLineControlScriptId};
if [[ -z $controlTime ]]; then
  controlTime=${pipeLineControlTime};
fi

# Argument setting.
########################################################################################
expectedCountOfArguments=1

echo ${thisRefToArray[@]}
if [[ "$#" -eq 0 ]]; then
  scriptId=${pipeLineScriptIds[0]};
elif [[ "$#" -ne $expectedCountOfArguments ]]; then
  printf "ERROR: received %0d arguments, %0d expected.\n" $# $expectedCountOfArguments
  exit 1
else
  scriptId=$1
  if [[ ! " ${pipeLineScriptIds[*]} " =~ [[:space:]]${scriptId}[[:space:]] ]]; then
    printf "ERROR: received scriptId '%s' not in authorized list '" ${scriptId}
    printf "%s " ${pipeLineScriptIds[*]}
    printf "'.\n" ${scriptId} ${pipeLineScriptIds[*]}
    exit 1
  fi
fi

printf "\nGiven argument, pipeline starts at step ${scriptId}.\n"

# Instantiate step-independent variables.
########################################################################################
printf "Starting submission daily run...\n"

git status;

ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; 
if [[ -z $archivePath ]]; then
  archivePath=${espArchiveDirOps};
fi
scratchPath=${slurmScratchDir1}; slurmLogDir=${projectDir}slurm_out/; slurmQos=${slurmQos2};

slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
pipeLine="-Z ${pipelineId}"
if [[ $thisStepOnly -eq 1 ]]; then
  pipeLine="" # break the pipeline after step execution.
fi

# Instantiate begin and exclude variables, which might change depending on
# required time of launch or presence of defective nodes.
########################################################################################
beginTime="";
  # if the start is later, for instance at 19:30 the same day, replace by: beginTime="--begin=19:30:00"
exclude="";
  # if some nodes have a know hardware failure, for instance nodes bmem-rico1 and bgpu-bortz1, replace by: exclude="--exclude=bmem-rico1,bgpu-bortz1"

# Instantiate step-dependent variables.
########################################################################################

indexInScriptConfigurations=$(echo ${pipeLineScriptIds[@]/${scriptId}//} | cut -d/ -f1 | wc -w | tr -d ' ')
stepId=$((( $indexInScriptConfigurations + 1)))
inputLabel=${pipeLineLabels[${indexInScriptConfigurations}]}
outputLabel=$inputLabel
indexOfPreLastScript=$((( ${#pipeLineScriptIds[@]} - 1 )))
if [[ $indexInScriptConfigurations -lt $indexOfPreLastScript && $scriptId != mod09gaI ]]; then
  outputLabel=${pipeLineLabels[ (( $indexInScriptConfigurations + 1 )) ]}
fi

scriptPath=${scriptIdFilePathAssociations[${scriptId}]}
scriptRegionType=${pipeLineRegionTypes[${indexInScriptConfigurations}]}
scriptSequence=${pipeLineSequences[${indexInScriptConfigurations}]}
scriptSequenceMultiplierToIndice=${pipeLineSequenceMultiplierToIndices[${indexInScriptConfigurations}]}

thisTasksPerNode=${pipeLineTasksPerNode[${indexInScriptConfigurations}]}
thisMem=${pipeLineMems[${indexInScriptConfigurations}]}
thisTime=${pipeLineTimes[${indexInScriptConfigurations}]}
workers="-w ${pipeLineParallelWorkersNb[${indexInScriptConfigurations}]}"

# Instantiate objectId
########################################################################################
# objectId is the parameter --array of the sbatch command.
objectId=
if [[ ${scriptRegionType} -eq 1 || ${scriptRegionType} -eq 10 ]]; then
  objectId=$regionId
else
  regionIdsArray=(${regionId//,/ });
  for thisRegionId in ${regionIdsArray[@]}; do
    objectId="${objectId},${regionIdsPerBigRegion[${thisRegionId}]}";
      # $regionIdsPerBigRegion in toolsRegion.sh.
  done
  objectId=${objectId:1};
fi

# Update objectId and scriptCountOfCell depending on sequence configured.
########################################################################################
objectIdsArray=(${objectId//,/ });

# Add the sequences if required (e.g. 292001-292036,293001-293026).
countOfCells=1
thatSequence=
if [ "$scriptSequence" != "0" ] && [ $scriptRegionType -ne 10 ]; then
  if [[ $scriptSequence == *"-"* ]]; then
    countOfCells=$((10#${scriptSequence: -3}));
      # We supply the count of Cells in the submit line
    thatSequence=$scriptSequence
  fi
  objectId=
  for thisObject in ${objectIdsArray[@]}; do
    # Updating $scriptSequence for the subdivisions, daStatis script.
    if [ "$scriptSequence" == "999" ]; then
      maxOfSequence=$(echo "(${countOfSubdivisionsPerBigRegion[${thisObject}]} - 1) / ${scriptSequenceMultiplierToIndice} + 1" | bc)
        # Here we assume that $thisObject = $bigRegionId. And we round to the ceiling
        # for the division using this bash way.
        # $countOfSubdivisionsPerBigRegion defined in toolsRegions.sh.
      patternOfSequence="001-%03d\n"
      if [[ $maxOfSequence -eq 1 ]]; then
        patternOfSequence="001"
      fi
      thatSequence=$(printf "${patternOfSequence}" ${maxOfSequence});
    fi
    objectId=$objectId,$(echo $thatSequence | sed -E "s~-([0-9]+)~-${thisObject}\1~" | sed -E "s~^([0-9]+)~${thisObject}\1~");
  done
  objectId=${objectId:1};
fi

# Instantiate submitLine and submit the controling job of the daily run.
########################################################################################

read -r -d '' thisHeader << EOM
Job to be submitted:
#############################################################################
EOM
printf "\n${thisHeader}\n"

submitLine="sbatch ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --cpus-per-task=1 --ntasks-per-node=${thisTasksPerNode} --mem=${thisMem} --time=${thisTime} --array=${objectId} ${scriptPath} -A ${versionOfAncillary} -E ${thisEnvironment} -L ${inputLabel} -M 0 -O ${outputLabel} -p ${inputProductAndVersion} -Q ${countOfCells} ${workers} -x ${scratchPath} -y ${archivePath} -W ${espWebExportConfId} ${pipeLine}"
controlingSubmitLineWoParameter="sbatch ${beginTime} ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${controlScriptId} --ntasks-per-node=1 --mem=1G --time=${controlTime} --array=1 bash/runSubmitter.sh"

echo "${controlingSubmitLineWoParameter} \"${submitLine}\""
printf "\n"
if [[ verbosity -eq 0 ]]; then
  read -p "Do you want to proceed submission (${webExportPlatform})? (y/n) " yn

  case $yn in 
    y )
      ;;
    n ) echo "Submission aborted.";
      exit;;
    * ) echo "Invalid response";
      exit 1;;
  esac
fi

printf "Submission...\n"
submissionCatcher=$(${controlingSubmitLineWoParameter} "${submitLine}" 2>&1);
echo "${submissionCatcher}"

thisJobId=$(echo ${submissionCatcher} | grep "Submitted batch job " | cut -d ' ' -f 4);
if [[ ! -z $thisJobId ]]; then
  printf "\nOnce started, you'll be able to track the log of this run here:\n"
  printf "${slurmLogDir}${controlScriptId}_1_${thisJobId}.out\n";
fi