#!/bin/bash
#
# Transfer output snowtoday daily files to archive and public ftp

#SBATCH --constraint=spsc
#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-D yyyy-MM-dd-monthWindow] [-h] [-i] [-I objectId] [-o]
    [-x scratchPath] [-y archivePath]
    Imports mog09ga v6.1 tiles for a region and period.
  Options:
    -D: string waterYearDateString, format yyyy-MM-dd-monthWindow. Date parameters
    allowing to determine override which period the script is run.
    E.g. 2024-03-26-1. The period ends by the date defined by yyyy-MM-dd, here
    2024-03-26, and monthWindow, the number of months before this date covering the
    period: 12: 1 full year period, 1: the month of the date, from 1 to the date,
    0: only the date. Default: date of today with monthWindow = 2. NB: if dd > than
    the last day of the month, then code set it to last day.
    -h: display help message and exit.
    -i: update input data from archive to scratch. Default: no update.
    -I: objectId, id of the tile to import, e.g. 292 for h08v04. Full list in
    toolsRegion.sh. Default: 292. Value of array job overrides the value of this
    option.
    -L inputLabel: string with version label for directories. For mod09ga, is v006 or
    v061, for version 6.0 or version 6.1 of the tiles. NB: v6.0 is deprecated and
    shouldnt be used in this script.
    -o: update output data from scratch to archive. Default: no update.
    -O outputLabel: string with version label for output files.
    If -O not precised, inputLabel is used for both input and output files.
    -R: repeat the job later with same parameters. Default: no repeat. Option -D
    overrides this option and set the job to no repeat.
    -v verbosityLevel: int. Also called log level. Default: 0, all logs. Increased
    values: less logs.
    -x: scratchPath: string, scratch storage location. This temporary location is
    for increased performance in read/write, compared to archive. The output
    files can later be sync back to archive. Logs are also stored in scratch.
    Default: environment variable $espScratchDir.
    NB: the scratchPath is dependent on the cluster alpine or blanca, and each
    cluster cannot access to the scratch of the other cluster.
    -y: archivePath: string, permanent storage location.
    Default: environment variable $espArchiveDir.
    -Z: pipeLineId: if set, indicates that a next script will be launch when the array
    job is achieved in success. The next script and version are determined based on
    the pipelineId. If set to 0, no pipeline. Additionally, indicates the end of the
    list of options for the pipeline parser and MUST always be positioned at the end
    of options.
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
    --array=292,293: list of objectIds. Ids of the tiles on which the script should
    run. List of ids in toolsRegion.sh. This parameter override the -I script
    option. Variable SLURM_ARRAY_TASK_ID in the script.
  Output:
    Scratch and archive, subfolder modis/input/mod09ga/

EOM
  printf "$thisUsage\n" 1>&2
}

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

source scripts/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

if [[ $inputLabel == 'v2024.0d' ]]; then

  # RSync of westernUS Netcdf to archive [hard-coded].
  ######################################################################################
  # No check that the rsync jobs are correctly achieved!
  printf "Submission of jobs to rsync netcdfs back to archive...\n"
  years=( {2025..2024..-1} );
  regionNames=(h08v04 h08v05 h09v04 h09v05 h10v04);
  slurmAccount=${SLURM_JOB_ACCOUNT};
  scratchPath=${slurmScratchDir1}; slurmLogDir=${projectDir}slurm_out/; slurmQos=${SLURM_JOB_QOS};
  slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
  exclude="";
  scriptPath=./scripts/runRsync.sh

  sourceBasePath=${scratchPath}modis/variables/scagdrfs_netcdf_${inputLabel}/v006/; #modis/intermediary/scagdrfs_stc_
  targetBasePath=${archivePath}output/mod09ga.061/spires/v2024.1.0/netcdf/
    # $archivePath and $scratchPath defined in toolsStart.sh.

  for year in ${years[@]}; do
    scriptId=sync${year};
    for regionName in ${regionNames[@]}; do
      jobName=$scriptId-${regionName};
      targetPath=${targetBasePath}${regionName}/
      sourcePath=${sourceBasePath}${regionName}/${year}
      mkdir -p ${targetPath}
      submitLine="sbatch --export=NONE --account=${slurmAccount} --qos=${slurmQos} ${exclude} -o ${slurmOutputPath} --job-name ${jobName} --ntasks-per-node=1 --mem 1G --time 03:15:00 ${scriptPath} -x ${sourcePath} -y ${targetPath}"
      printf "${submitLine}\n"
      ${submitLine}
    done
  done
  sleep $(( 60 * 10 ))
    # Suppose rsync sbatch jobs will last less than 10 mins, not really necessary...
fi

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
inputFolderForGeotiff="modis/variables/scagdrfs_geotiff_${versionLabel}/v006/${bigRegionName}/EPSG_3857/LZW/{year}/{datePattern}*"
inputFolderForMat="modis/variables/scagdrfs_mat_${versionLabel}/v006/{regionName}/{year}/{regionName}_Terra_{datePattern}*mat"
outputFolderForGeotiff="snow-today/WY${waterYear}_tmp/${bigRegionName}/geotiff_mosaic/"
outputFolderForMat="snow-today/WY${waterYear}_tmp/${bigRegionName}/mat_tile/{regionName}/"

echo "Start sync to ftp..."

if [ -d $outputFolderForGeotiff ]; then
  mkdir -p $outputFolderForGeotiff
fi

for datePattern in ${datePatterns[@]}; do
  inputPath="${scratchDir}${inputFolderForGeotiff//\{year\}/${datePattern::-1}}"
  inputPath="${inputPath//\{datePattern\}/${datePattern}}"
  
  /bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s ${inputPath} ${ftpDir}${outputFolderForGeotiff}


  inputPath="${scratchDir}${inputFolderForMat//\{year\}/${datePattern::-1}}"
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
source scripts/toolsStop.sh
