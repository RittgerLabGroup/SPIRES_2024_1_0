#!/bin/bash
#
# Transfer output snowtoday daily files to archive and public ftp
# Read bash/configurationForHelp.sh for all options and arguments.
#
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=ftpExpor
defaultSlurmArrayTaskId=5
expectedCountOfArguments=
inputDataLabels=(ftp)
outputDataLabels=(ftp)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=0
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=12

source bash/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

# Years and objects to rsync.
########################################################################################
theseYears=($thisYear  $(($thisYear - 1))) #( {2025..2024..-1} );
theseObjectIds=$objectId,$(get_object_ids_from_big_region_object_ids_string $objectId)
regionNames=($(echo $(get_region_names_from_object_ids_string ${theseObjectIds}) | tr ',' ' ' ))
# get_object.. and get_region.. are in toolsRegions.sh.

# Folders to rsync.
########################################################################################
if [[ $inputLabel == 'v2024.0d' ]]; then
  thisOutputLabel=v2024.1.0
  sourceBasePaths=(
  modis/intermediary/spiresfill_${inputLabel}/v006/ 
  modis/variables/scagdrfs_mat_${inputLabel}/v006/ 
  output/mod09ga.061/spires/${outputLabel}/netcdf/ 
  modis/variables/scagdrfs_geotiff_${inputLabel}/v006/ 
  modis/regional_stats/scagdrfs_csv_${inputLabel}/v006/ 
  modis/subdivisionstats/scagdrfs_aggregcsv_${inputLabel}/v006/
  )
  endSourceBasePaths=(
  "" 
  "" 
  "" 
  EPSG_3857/LZW/ 
  "WY" 
  "")
  targetBasePaths=(
  modis/intermediary/spiresfill_${inputLabel}/v006/ 
  output/mod09ga.061/spires/${thisOutputLabel}/mat/ 
  output/mod09ga.061/spires/${outputLabel}/netcdf/ 
  output/mod09ga.061/spires/${outputLabel}/tif_EPSG3857/ 
  output/mod09ga.061/spires/${outputLabel}/csv/ 
  output/mod09ga.061/spires/${outputLabel}/aggregcsv/
  )
  isAll=(
  0
  0
  0
  0
  1
  )
else
  sourceBasePaths=(
  mod09ga.061/spires/${inputLabel}/int_day/ 
  output/mod09ga.061/spires/${outputLabel}/netcdf/ 
  output/mod09ga.061/spires/${inputLabel}/tif_EPSG3857/
  modis/regional_stats/scagdrfs_csv_${inputLabel}/v006/ 
  modis/subdivisionstats/scagdrfs_aggregcsv_${inputLabel}/v006/
  )
  endSourceBasePaths=(
  "" 
  "" 
  "" 
  "WY" 
  ""
  )
  targetBasePaths=(
  mod09ga.061/spires/${inputLabel}/int_day/
  output/mod09ga.061/spires/${outputLabel}/netcdf/ 
  output/mod09ga.061/spires/${outputLabel}/tif_EPSG3857/ 
  output/mod09ga.061/spires/${outputLabel}/csv/ 
  output/mod09ga.061/spires/${outputLabel}/aggregcsv/
  )
  isAll=(
  0
  0
  0
  0
  1
  )
fi

# Submission of jobs to rsync to archive.
########################################################################################
# NB: No check that the rsync jobs are correctly achieved!
printf "%77s\n" | tr ' ' '#'
scriptPath=${scriptIdFilePathAssociations["rSynchro"]}
slurmAccount=${SLURM_JOB_ACCOUNT};
slurmLogDir=${projectDir}slurm_out/;
# scratchPath defined in toolsStart.sh.
slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
exclude="";
for pathIdx in $(echo ${!sourceBasePaths[@]}); do
  sourceBasePath=${scratchPath}${sourceBasePaths[$pathIdx]}
  endSourceBasePath=${endSourceBasePaths[$pathIdx]}
  targetBasePath=${archivePath}${targetBasePaths[$pathIdx]}
    # $slurmQos, $archivePath and $scratchPath defined in toolsStart.sh.
  printf "\nSubmission of jobs to rsync ${sourceBasePath} back to ${targetBasePath}...\n"
  if [[ ${isAll[$pathIdx]} -eq 0 ]]; then
    for oneYear in ${theseYears[@]}; do
      scriptId=sync${oneYear};
      for regionName in ${regionNames[@]}; do
        jobName=$scriptId-${regionName};
        targetPath=${targetBasePath}${regionName}/
        sourcePath=${sourceBasePath}${regionName}/${endSourceBasePath}${oneYear}
        if [[ -d $sourcePath ]]; then
          mkdir -p ${targetPath}
          submitLine="sbatch --export=NONE --account=${slurmAccount} --qos=${slurmQos} ${exclude} -o ${slurmOutputPath} --job-name ${jobName} --ntasks-per-node=1 --mem 1G --time 03:15:00 ${scriptPath} -x ${sourcePath} -y ${targetPath}"
          printf "${submitLine}\n"
          ${submitLine}
        else
          printf "WARNING, absent ${sourcePath}.\n"
        fi
      done
    done
  else
    scriptId=syncAll;
    jobName=$scriptId-All;
    targetPath=${targetBasePath}
    sourcePath=${sourceBasePath}
    if [[ -d $sourcePath ]]; then
      mkdir -p ${targetPath}
      submitLine="sbatch --export=NONE --account=${slurmAccount} --qos=${slurmQos} ${exclude} -o ${slurmOutputPath} --job-name ${jobName} --ntasks-per-node=1 --mem 1G --time 03:15:00 ${scriptPath} -x ${sourcePath} -y ${targetPath}"
      printf "${submitLine}\n"
      ${submitLine}
    else
      printf "WARNING, absent ${sourcePath}.\n"
    fi
  fi
done
printf "%77s\n" | tr ' ' '#'
sleep $(( 60 * 10 ))
    # Suppose rsync sbatch jobs will last less than 10 mins, not really necessary...

: '
# Launch the export to the ftp. SPECIFIC TO WESTERN US!
########################################################################################

waterYear=2024
versionLabel=v2024.0
scratchDir=/rc_scratch/sele7124/
ftpDir=/pl/active/rittger_public/
datePatterns=($(( $waterYear - 1 ))1 ${waterYear}0)

regionNamesForGeotiff=(westernUS)
regionNamesForMat=(''h08v04' 'h08v05' 'h09v04' 'h09v05' 'h10v04' 'westernUS'')

bigRegionName=westernUS
#set -o noglob
# prevent wildcard * expansion.
inputFolderForGeotiff="modis/variables/scagdrfs_geotiff_${versionLabel}/v006/${bigRegionName}/EPSG_3857/LZW/{oneYear}/{datePattern}*"
inputFolderForMat="modis/variables/scagdrfs_mat_${versionLabel}/v006/{regionName}/{oneYear}/{regionName}_Terra_{datePattern}*mat"
outputFolderForGeotiff="snow-today/WY${waterYear}_tmp/${bigRegionName}/geotiff_mosaic/"
outputFolderForMat="snow-today/WY${waterYear}_tmp/${bigRegionName}/mat_tile/{regionName}/"

echo "Start sync to ftp..."

if [ -d $outputFolderForGeotiff ]; then
  mkdir -p $outputFolderForGeotiff
fi

for datePattern in ${datePatterns[@]}; do
  inputPath="${scratchDir}${inputFolderForGeotiff//\{oneYear\}/${datePattern::-1}}"
  inputPath="${inputPath//\{datePattern\}/${datePattern}}"
  
  /bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s ${inputPath} ${ftpDir}${outputFolderForGeotiff}


  inputPath="${scratchDir}${inputFolderForMat//\{oneYear\}/${datePattern::-1}}"
  inputPath="${inputPath//\{datePattern\}/${datePattern}}"
  for regionName in ${regionNamesForMat[@]}; do
    regionInputPath="${inputPath//\{regionName\}/${regionName}}"
    regionOutputPath="${ftpDir}${outputFolderForMat//\{regionName\}/${regionName}}"
    if [ -d $regionOutputPath ]; then
      mkdir -p $regionOutputPath
    fi
    /bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s $regionInputPath ${regionOutputPath}
  done
done
#set +o noglob
echo "Done sync to ftp."
'
source bash/toolsStop.sh
