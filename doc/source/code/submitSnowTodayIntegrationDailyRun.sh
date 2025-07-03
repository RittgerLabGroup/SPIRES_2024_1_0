#!/bin/bash
shopt -s expand_aliases
source ~/.bashrc
  # to have access to alias.

# Submit the snow-today daily run v2025.0.1 for integration platform starting at the
# required step indicated by the argument scriptId.
#
# Arguments:
# - scriptId: Optional. Default: mod09gaI. Code of the script to start the pipeline
#     with. Should have values in $authorizedScriptIds below.
#
# Author: Seba
# Last edit: 2025-05-21.

# Argument setting.
########################################################################################
authorizedScriptIds=(mod09gaI spiInver spiTimeI moSpires daNetCDF \
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

gDevEsp; # development platform on supercomputer.
printf "Working directory: ";
pwd;
git status;
ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirOps};
scratchPath=${slurmScratchDir1}; slurmLogDir=${projectDir}slurm_out/; slurmQos=${slurmQos2};
versionOfAncillary=v3.2; inputProductAndVersion=mod09ga.061;
controlScriptId=stnr2501;
slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
pipeLine="-Z 3"
platform="-W 1" # 1: integration platform on NSIDC web-app.

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
    objectId=1057,1093;
    scriptPath=./scripts/runGetMod09gaFiles.sh
    thisTasksPerNode=1
    thisMem=1G
    thisTime=01:30:00
    workers="-w 0"
    stepId=1
    ;;

  ${authorizedScriptIds[1]})
    # Start at step 02. spiInv. Carry out spectral unmixing and generate gap files.
    # NB: By default, mode of this script is for each day, skip if everything has already been done for the recorded input file, otherwise ingest + calculations.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=1057,1093;
    scriptId=spiInv;
    scriptPath=./scripts/runSpiresInversor.sh
    thisTasksPerNode=14
    thisMem=44G
    thisTime=02:15:00
    workers=""
    stepId=2
    ;;

  ${authorizedScriptIds[2]})
    # Start at step 03. spiSmooC. Generate interpolated files.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=1057001-1057036,1093001-1093036;
    scriptId=spiSmooC;
    scriptPath=./scripts/runSpiresTimeInterpolator.sh
    thisTasksPerNode=10
    thisMem=60G
    thisTime=02:30:00
    workers=""
    stepId=3
    ;;

  ${authorizedScriptIds[3]} | ${authorizedScriptIds[4]})
    # Start at step 04. moSpires. Determine albedo and generate final daily .tif files.
    # Start at step 05. daNetCDF. Generate daily .netcdf files.
    # For these 2 steps, you can restart at step 04, since step 04 is not that long.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=1057,1093;
    scriptId=moSpires;
    scriptPath=./scripts/runUpdateMosaicWithSpiresData.sh
    thisTasksPerNode=18
    thisMem=60G
    thisTime=04:30:00
    workers=""
    stepId=4
    ;;

  ${authorizedScriptIds[5]})
    # Start at step 06. daGeoBig. Generate projected geotiff.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=5;
    scriptId=daGeoBig;
    scriptPath=./scripts/runUpdateGeotiffBigRegion.sh
    thisTasksPerNode=1
    thisMem=8G
    thisTime=01:00:00
    workers=""
    stepId=5
    ;;
  ${authorizedScriptIds[6]})
    # Start at step 07. daStatis. Generate statistics.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=7001;
    scriptId=daStatis;
    scriptPath=./scripts/runUpdateDailyStatistics.sh
    thisTasksPerNode=1
    thisMem=8G
    thisTime=04:00:00
    workers="-w 0"
    stepId=6
    ;;
  ${authorizedScriptIds[7]})
    # Start at step 08. webExpSn. Generate statistics.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=7;
    scriptId=webExpSn;
    scriptPath=./scripts/runWebExportSnowToday.sh
    thisTasksPerNode=1
    thisMem=3G
    thisTime=01:30:00
    workers="-w 0"
    stepId=7
    ;;
  ${authorizedScriptIds[8]})
    # Start at step 09. ftpExpor. Export to archive.
    inputLabel=v2025.0.1; outputLabel=v2025.0.1;
    objectId=7;
    scriptId=ftpExpor;
    scriptPath=./scripts/runFtpExport.sh
    thisTasksPerNode=1
    thisMem=1G
    thisTime=01:30:00
    workers="-w 0"
    stepId=8
    ;;
esac

# Instantiate submitLine and submit the controling job of the daily run.
########################################################################################

submitLine="sbatch ${exclude} --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --cpus-per-task=1 --ntasks-per-node=${thisTasksPerNode} --mem=${thisMem} --time=${thisTime} --array=${objectId} ${scriptPath} -A ${versionOfAncillary} -L ${inputLabel} -O ${outputLabel} -p ${inputProductAndVersion} ${workers} -x ${scratchPath} -y ${archivePath} ${platform} ${pipeLine}"
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
