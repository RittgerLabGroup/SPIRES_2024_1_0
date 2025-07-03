#!/bin/bash
shopt -s expand_aliases
source ~/.bashrc
  # to have access to alias.

# Submit the snow-today daily run v2024.1.0 starting at the required step indicated by
# the argument scriptId.
#
# Arguments:
# - scriptId: Optional. Default: mod09gaI. Code of the script to start the pipeline
#     with. Should have values in $authorizedScriptIds below.
#
# Author: Seba
# Last edit: 2025-01-16.

# Argument setting.
########################################################################################
authorizedScriptIds=(mod09gaI spiFillC spiSmooC moSpires scdInCub daNetCDF daMosBig \
daGeoBig daStatis webExpSn ftpExpor)
expectedCountOfArguments=1
if [[ "$#" -eq 0 ]]; then
  scriptId=${authorizedScriptIds[0]};
elif [[ "$#" -ne $expectedCountOfArguments ]]; then
  printf "ERROR: received %0d arguments, %0d expected.\n" $# $expectedCountOfArguments
  exit 1
else
  scriptId=$1
  if [[ ! " ${authorizedScriptIds[*]} " =~ [[:space:]]${scriptId}[[:space:]] ]]; then
    printf "ERROR: received scriptId '%s' not in authorized list '" ${scriptId}
    printf "%s " ${authorizedScriptIds[*]}
    printf "'.\n" ${scriptId} ${authorizedScriptIds[*]}
    exit 1
  fi
fi

# Instantiate step-independent variables.
########################################################################################
printf "Starting submission daily run...\n"

gEsp; 
printf "Working directory: ";
pwd;
git status;
ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirOps};
scratchPath=${slurmScratchDir1}; slurmLogDir=${projectDir}slurm_out/; slurmQos=${slurmQos2};
versionOfAncillary=v3.1; inputProductAndVersion=mod09ga.061;
controlScriptId=stnr2410;
slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
pipeLine="-Z 1"

# Instantiate begin and exclude variables, which might change depending on
# required time of launch or presence of defective nodes.
########################################################################################
beginTime="";
  # if the start is later, for instance at 19:30 the same day, replace by: beginTime="--begin=19:30:00"
exclude="";
  # if some nodes have a know hardware failure, for instance nodes bmem-rico1 and bgpu-bortz1, replace by: exclude="--exclude=bmem-rico1,bgpu-bortz1"

# Instantiate step-dependent variables.
########################################################################################
case "$scriptId" in
  ${authorizedScriptIds[0]})
    # Start at step 01. mod09gaI. Download mod09ga.
    inputLabel=v061; outputLabel=v061;
    objectId=292,293,328,329,364;
    scriptPath=./scripts/runGetMod09gaFiles.sh
    thisTasksPerNode=1
    thisMem=1G
    thisTime=01:30:00
    workers="-w 0"
    stepId=1
    ;;

  ${authorizedScriptIds[1]})
    # Start at step 02. spiFillC. Generate gap files.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=292,293,328,329,364;
    scriptId=spiFillC;
    scriptPath=./scripts/runSpiresFill.sh
    thisTasksPerNode=18
    thisMem=140G
    thisTime=02:15:00
    workers=""
    stepId=2
    ;;

  ${authorizedScriptIds[2]})
    # Start at step 03. spiSmooC. Generate interpolated files.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=292001-292036,293001-293036,328001-328036,329001-329036,364001-364036;
    scriptId=spiSmooC;
    scriptPath=./scripts/runSpiresSmooth.sh
    thisTasksPerNode=10
    thisMem=30G
    thisTime=02:30:00
    workers=""
    stepId=3
    ;;

  ${authorizedScriptIds[3]} | ${authorizedScriptIds[4]} | ${authorizedScriptIds[5]} )
    # Start at step 04. moSpires. Generate daily .mat files.
    # Start at step 05. scdInCub. Calculate snow cover days in .mat files.
    # Start at step 06. daNetCDF. Generate daily .netcdf files.
    # For these 2 steps, you can restart at step 04, since step 04 is not that long.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=292,293,328,329,364;
    scriptId=moSpires;
    scriptPath=./scripts/runUpdateMosaicWithSpiresData.sh
    thisTasksPerNode=10
    thisMem=90G
    thisTime=00:30:00
    workers=""
    stepId=4
    ;;

  ${authorizedScriptIds[6]})
    # Start at step 07. daMosBig. Generate westernUs Mosaic.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=5;
    scriptId=daMosBig;
    scriptPath=./scripts/runUpdateMosaicBigRegion.sh
    thisTasksPerNode=6
    thisMem=60G
    thisTime=00:30:00
    workers=""
    stepId=7
    ;;
  ${authorizedScriptIds[7]})
    # Start at step 08. daGeoBig. Generate projected geotiff.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=5;
    scriptId=daMosBig;
    scriptPath=./scripts/runUpdateGeotiffBigRegion.sh
    thisTasksPerNode=1
    thisMem=8G
    thisTime=01:00:00
    workers=""
    stepId=8
    ;;
  ${authorizedScriptIds[8]})
    # Start at step 09. daStatis. Generate statistics.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=5001-5033;
    scriptId=daStatis;
    scriptPath=./scripts/runUpdateDailyStatistics.sh
    thisTasksPerNode=1
    thisMem=8G
    thisTime=04:00:00
    workers="-w 0"
    stepId=9
    ;;
  ${authorizedScriptIds[9]})
    # Start at step 10. webExpSn. Generate statistics.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=5;
    scriptId=webExpSn;
    scriptPath=./scripts/runWebExportSnowToday.sh
    thisTasksPerNode=1
    thisMem=3G
    thisTime=01:30:00
    workers="-w 0"
    stepId=10
    ;;
  ${authorizedScriptIds[10]})
    # Start at step 11. ftpExpor. Export to archive.
    inputLabel=v2024.0d; outputLabel=v2024.0d;
    objectId=5;
    scriptId=ftpExpor;
    scriptPath=./scripts/runFtpExport.sh
    thisTasksPerNode=1
    thisMem=1G
    thisTime=01:30:00
    workers="-w 0"
    stepId=11
    ;;
esac

# Instantiate submitLine and submit the controling job of the daily run.
########################################################################################

submitLine="sbatch ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --cpus-per-task=1 --ntasks-per-node=${thisTasksPerNode} --mem=${thisMem} --time=${thisTime} --array=${objectId} ${scriptPath} -A ${versionOfAncillary} -L ${inputLabel} -O ${outputLabel} -p ${inputProductAndVersion} ${workers} -x ${scratchPath} -y ${archivePath} ${pipeLine}"
controlingSubmitLineWoParameter="sbatch ${beginTime} ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${controlScriptId} --ntasks-per-node=1 --mem=1G --time=08:30:00 --array=1 ./scripts/runSubmitter.sh"

echo "${controlingSubmitLineWoParameter} \"${submitLine}\""

read -p "Do you want to proceed? (y/n) " yn

case $yn in 
	y )
    ;;
	n ) echo "Submission aborted.";
		exit;;
	* ) echo "Invalid response";
		exit 1;;
esac

printf "Submission...\n"
${controlingSubmitLineWoParameter} "${submitLine}"

: '
# Default start of daily run.
# Start at step 01. mod09gaI. Download mod09ga.

gEsp; git status;
ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirOps};
scratchPath=${slurmScratchDir1}; slurmLogDir=${projectDir}slurm_out/; slurmQos=${slurmQos2};
versionOfAncillary=v3.1; inputProductAndVersion=mod09ga.061;
controlScriptId=stnr2410;
slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
pipeLine="-Z 1"
beginTime=""; # if the start is later, for instance at 19:30 the same day, replace by: beginTime="--begin=19:30:00"
exclude=""; # if some nodes have a know hardware failure, for instance nodes bmem-rico1 and bgpu-bortz1, replace by: exclude="--exclude=bmem-rico1,bgpu-bortz1"


inputLabel=v061; outputLabel=v061;
objectId=292,293,328,329,364;
scriptId=mod09gaI;
scriptPath=./scripts/runGetMod09gaFiles.sh
thisTasksPerNode=1
thisMem=1G
thisTime=01:30:00
workers="-w 0"


submitLine="sbatch ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --cpus-per-task=1 --ntasks-per-node=${thisTasksPerNode} --mem=${thisMem} --time=${thisTime} --array=${objectId} ${scriptPath} -A ${versionOfAncillary} -L ${inputLabel} -O ${outputLabel} -p ${inputProductAndVersion} ${workers} -x ${scratchPath} -y ${archivePath} ${pipeLine}"
echo ${submitLine}
sbatch ${beginTime} ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${controlScriptId} --ntasks-per-node=1 --mem=1G --time=08:30:00 --array=1 ./scripts/runSubmitter.sh "${submitLine}"
'