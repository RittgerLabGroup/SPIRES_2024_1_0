#!/bin/bash
#
# script to get all mod09ga files from DAAC for specific tiles and range of dates.

#   Cancel this one, only available on blanca. SBATCH --constraint=spsc
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

function downloadTileFromDaacURLToLocal() {
    # Download a DAAC file stored in a https remote server (url) for a certain
    # region or tile (~granule).
    #
    # Parameters
    # ----------
    # regionName: char. Name of the region or tile or granule, used to filter the files
    #   available in the remote server.
    # remoteDirectoryUrl: char. Url of the html page listing all the files (for a
    #   product and version and day of observation).
    # localDirectoryPath: char. Absolute directory path where the file is downloaded.
    regionName=$1
    remoteDirectoryUrl=$2
    localDirectoryPath=$3

    if [ ! -d "$localDirectoryPath" ]; then
        mkdir -p "$localDirectoryPath"
    fi
    # Loop through each filename matching the pattern
    curl -b ~/.urs_cookies -L -n "$remoteDirectoryUrl" | \
    grep -oP '(?<=href=")[^"]*\.hdf' | \
    grep "$regionName" | \
    sort -u | \
    while read -r full_url; do
        # Extract just the filename from the full URL
        remoteFilename="${full_url##*/}" # Extract everything after the last '/'

        # Local path for the file, including the output directory
        localFilePath="${localDirectoryPath}${remoteFilename}" 

        downloadInformationToPrint=$(cat << EOM

-----------------------------------------------------------------
Destination: ${localFilePath}.
Date: ${thisDate} - $(date -d @"${thisDate}" +%Y-%m-%d) - $(date -d @"${thisDate}" +%Y%j).
-----------------------------------------------------------------

EOM
)

        # 1. Get remote file information (size and last modified date)
        printf "\n"
        informationOnRemoteFile=$(curl -s -b ~/.urs_cookies -L -n --head "${remoteDirectoryUrl}${remoteFilename}")
        sizeOfRemoteFile=$(echo "$informationOnRemoteFile" | grep -i 'Content-Length:' | awk '{print $2}' | tr -d '\r')
        timestampOfRemoteFile=$(echo "$informationOnRemoteFile" | grep -i 'Last-Modified:' | sed 's/^[Ll]ast-[Mm]odified: //g' | tr -d '\r')

        # Convert remote timestamp to epoch for comparison
        epochOfRemoteFile=$(date -d "${timestampOfRemoteFile}" +%s 2>/dev/null)

        # 2. Check if local file exists and compare sizes and timestamps
        if [ -f "$localFilePath" ]; then
            sizeOfLocalFile=$(stat -c %s "$localFilePath")
            timestampOfLocalFile=$(date -r "$localFilePath" +%s)

            if [ -n "$sizeOfRemoteFile" ] && [ -n "$epochOfRemoteFile" ]; then # Ensure remote info is available
                if [ "$sizeOfRemoteFile" -eq "$sizeOfLocalFile" ] && [ "$epochOfRemoteFile" -le "$timestampOfLocalFile" ]; then
                    echo "Skipping ${remoteFilename}: Local file is the same or newer."
                    continue
                fi
            fi
            printf "%s\n" "${downloadInformationToPrint}"
            echo "Local file exists but is different or remote info unavailable. Checking for interrupted download or new version of ${remoteFilename}..."
        else
            printf "%s\n" "${downloadInformationToPrint}"
            echo "Local file does not exist for ${remoteFilename}. Downloading..."
        fi

        # 3. Download the file, resuming if interrupted

        curl -b ~/.urs_cookies -L -n --continue-at - "${remoteDirectoryUrl}${remoteFilename}" -o "$localFilePath"
    done
}

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=mod09gaI
defaultSlurmArrayTaskId=292
expectedCountOfArguments=
inputDataLabels=(mod09ga)
outputDataLabels=(mod09ga)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=(19:45:00)

# Following can be overriden by pipeling configuration.sh
thisRegionType=0
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=2

source bash/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

log_level_1 "start"

# Launch the ingest.
########################################################################################

# 0. Constants
scienceBaseDirectoryUrl=https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/61/MOD09GA/ # needs to give access to LAADS Web in https://urs.earthdata.nasa.gov/users/${meAsAUser}/authorized_apps
nrtBaseDirectoryUrl=https://nrt3.modaps.eosdis.nasa.gov/api/v2/content/archives/allData/61/MOD09GA/ # apparently doesn't need a token any more?

# Token personal to user, in environment variable in .~/.bshrc
# nrtDownloadToken=$nrt3ModapsEosdisNasaGovToken # Unused as of 2025-08-20.

# 1. Variables
# regionName=h08v04 # RegionName set by toolsStart.sh
directoryPath=${scratchPath}modis/input/mod09ga/v006/ # scratchPath set by toolsStart.sh through option -x
printf "Import to ${directoryPath}...\n"

theseDates=$(seq  $(date -d "$startDate" +%s) 86400 $(date -d "$endDate + 1 day" +%s))
# I dont know why seq doesnt include the $endDate and we need to add a day for that.
# If we want an array, we add outer (), like ($(seq  $(date -d "$startDate" +%s) 86400 $(date -d "$endDate" +%s)))
# But in that case we cannot use for in anymore.


# Core.
########################################################################################
# Debug only (easier to handle arrays vs sequences):
# theseDates=(${theseDates[@]})
# thisDate=${theseDates[0]}
thoseDates=(${theseDates[@]})
echo "Downloading date: ${thoseDates[0]} - $(date -d @"${thoseDates[0]}" +%Y-%m-%d) - $(date -d @"${thoseDates[0]}" +%Y%j) to date: ${thoseDates[-1]} - $(date -d @"${thoseDates[-1]}" +%Y-%m-%d) - $(date -d @"${thoseDates[-1]}" +%Y%j)"

for thisDate in $theseDates; do

  localDirectoryPath="${directoryPath}${regionName}/$(date -d @"$thisDate" +%Y)/"
    # Local download directory

  # 2. download of the nrt product for the last 7 days
  nrtIsAvailable=$([[ $thisDate -ge $(date --date "7 days ago" +'%s') ]] && echo 1 || echo 0)
  nrtDirectoryUrl="${nrtBaseDirectoryUrl}$(date -d @"$thisDate" +%Y)/$(date -d @"$thisDate" +%j)/"

  if [[ $nrtIsAvailable -eq 1 ]]; then
      downloadTileFromDaacURLToLocal $regionName $nrtDirectoryUrl $localDirectoryPath
  fi

  # 3. download of the science (=archive) product
  # Base URL of the directory
  scienceDirectoryUrl="${scienceBaseDirectoryUrl}$(date -d @"$thisDate" +%Y)/$(date -d @"$thisDate" +%j)/"

  downloadTileFromDaacURLToLocal $regionName $scienceDirectoryUrl $localDirectoryPath
done

source bash/toolsStop.sh
