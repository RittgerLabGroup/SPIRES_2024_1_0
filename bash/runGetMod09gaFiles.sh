#!/bin/bash
#
# script to get all mod09ga files from DAAC for specific tiles and range of dates.

set -x

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
# Token personal to user, in environment variable in .~/.bshrc
nrtDownloadToken=$nrt3ModapsEosdisNasaGovToken

checkFileAlreadyPresent=1
theseDates=$(seq  $(date -d "$startDate" +%s) 86400 $(date -d "$endDate + 1 day" +%s))
# I dont know why seq doesnt include the $endDate and we need to add a day for that.
# If we want an array, we add outer (), like ($(seq  $(date -d "$startDate" +%s) 86400 $(date -d "$endDate" +%s)))
# But in that case we cannot use for in anymore.


directoryPath=${scratchPath}modis/input/mod09ga/v006/
printf "Import to ${directoryPath}...\n"

cloudLpDaacDirectoryUrl="https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/MOD09GA.061/"

# Core.
########################################################################################
# Debug only (easier to handle arrays vs sequences:
# theseDates=(${theseDates})
# thisDate=${theseDates[0]}
IFS=$'\n'
alias rm=rm # To remove the lock without confirmation.
for thisDate in $theseDates; do
  # Directories of pages of url lists and of files.
  histUrlListDirectoryPath="${directoryPath}histUrlList/$(date -d @"$thisDate" +%Y)/"
  if [ ! -d ${histUrlListDirectoryPath} ]; then
    mkdir -p ${histUrlListDirectoryPath}
  fi
  histUrlListFileName="index_$(date -d   @"$thisDate" +%Y%j).html"

  thisDirectoryPath="${directoryPath}${regionName}/$(date -d @"$thisDate" +%Y)/"
  if [ ! -d ${thisDirectoryPath} ]; then
    mkdir -p ${thisDirectoryPath}
  fi

  # Check file present...
  if [[ "$checkFileAlreadyPresent" -eq 1 ]]; then
    filePresent=$(ls ${thisDirectoryPath} | grep ".A$(date -d @"$thisDate" +%Y%j).h" | grep -v ".met" | grep -v ".xml" | grep -v "NRT" | sort -r | head -n 1);

    if [ $filePresent ]; then
      printf "Skipping ${filePresent}.\n"
      continue
    fi
  fi
  printf "\n\n\n\n-----------------------------------------------------------------\n"
  printf "TIME: $(date +%Y-%m-%dT%H:%M:%S).\n"
  printf "Destination directory: ${thisDirectoryPath}.\n"
  printf "Date: ${thisDate} - $(date -d @"$thisDate" +%Y%j)."
  printf "\n-----------------------------------------------------------------\n\n"

  # Check if we already have the list of urls from previous get for the day otherwise
  # Get the list of urls for tile/day either with a new get...
  # NB: we could optimize this, because we ask the list for each tile each day
  # while the page covers all available tile for a day.                            @todo

  # NB: To be modified. Sometimes daac doesnt update the page, which leads to errors.
  # To be replaced by looking for a json
  # wget -c --no-proxy --server-response -O /${scratchPath}/20230316.json #"https://cmr.earthdata.nasa.gov/search/granules.json?echo_collection_id=C2202497474-LPCLOUD&page_num=1&page_size=500&temporal=2023-03-16T00:00:00.000Z,2023-03-16T23:59:59.999Z&sort_key=producer_granule_id"
  # and then the tile path can be filtered by
  # histListContent=$(cat /rc_scratch/sele7124/20230316.json)
  # pattern=[^@]+(https\:\/\/[a-z\/\.\-]+\/MOD09GA\.061\/MOD09GA\.A2023075\.h00v08\.061\.[0-9]+\/MOD09GA\.A2023075\.h00v08\.061\.[0-9]+\.hdf)[^@]+
  # echo $histListContent | sed -r "s~${pattern}~\1~g"
  # Beware because sometimes in the page there are tiles of the day before too!
  #                                                                                @todo

  histDirectoryUrl="https://data.lpdaac.earthdatacloud.nasa.gov/lp-prod-protected/MOD09GA.061/$(date -d @"$thisDate" +%Y.%m.%d)/"
  modificationDate=$(date -r /${scratchPath}/modis/input/mod09ga/v006/histUrlList/2024/index_2024085.html +%s)

  printf "\nChecking .lock file ${histUrlListDirectoryPath}${histUrlListFileName}.lock and waiting unlock...\n"
  while [[ -f ${histUrlListDirectoryPath}${histUrlListFileName}.lock ]]; do
    sleep 1
  done

  if [[ ! -s ${histUrlListDirectoryPath}${histUrlListFileName} ]] || \
[[ ! -s ${histUrlListDirectoryPath}${histUrlListFileName} && $(( $(date +%s) - $modificationDate )) > 3600 ]]; then
    printf "\nCreate .lock file ${histUrlListDirectoryPath}${histUrlListFileName}.lock.\n"
    touch ${histUrlListDirectoryPath}${histUrlListFileName}.lock
    printf "\n\nwget -c --no-proxy --server-response -O ${histUrlListDirectoryPath}${histUrlListFileName} ${histDirectoryUrl}...\n"
    for counterIdx in {1..600}; do
      wgetReturn="A"$(wget -c --no-proxy --server-response -O ${histUrlListDirectoryPath}${histUrlListFileName} ${histDirectoryUrl} 2>&1)
      isError503=$(printf "${wgetReturn}" | grep "HTTP/1.1 503 Service Unavailable" | wc -c)
      # We could have used printf "%s" to escape characters which might be understand as options by printf.
      # Here I preferred adding a "A" at the start of the reponses (to escape potential initial --).
      is202=$(printf "${wgetReturn}" | grep "HTTP/1.1 200 OK" | wc -c)
      if [[ "$isError503" -gt 0 && counterIdx -ne 600 ]]; then
        printf "${wgetReturn}"
        printf "\nRETRY #${counterIdx} in 15 sec...\n"
        sleep 15
      elif [[ "$isError503" -gt 0 && counterIdx -eq 600 ]]; then
        printf "${wgetReturn}"
        printf "\nFAILED. Max number of retrys reached.\n\n"
      elif [[ "$is202" -eq 0 ]]; then
        printf "${wgetReturn}"
        printf "\nFAILED.\n\n"
        break
      else
        printf "Done wget ${histDirectoryUrl}.\n"
        break
      fi
    done
    rm ${histUrlListDirectoryPath}${histUrlListFileName}.lock
    printf "\nDeleted .lock file ${histUrlListDirectoryPath}${histUrlListFileName}.lock.\n"
  fi
# NB: We could mutualize this way to call wget.                                      @todo
  # From the list of historic urls we get the url of the tile/day.
  tileFileList=()
  # reinitialization of tileFileList important because we use ${tileFileList[@]} in
  # the lines below, which could have kept the files of the previous date.
  if [ -s ${histUrlListDirectoryPath}${histUrlListFileName} ]; then
    histListContent=$(cat ${histUrlListDirectoryPath}${histUrlListFileName})
    thisTitle=$(echo "$histListContent" | grep "<title>" | head -1)
    printf "Title: ${thisTitle}.\n"

    histFileList=$(echo "$histListContent" | sed -r 's/^<img(.*\="MOD.*)/@@@\1/' | sed -r 's/^[^@][^@][^@][^\r^\n].*//' | sed '/^[[:space:]]*$/d' | sed -r 's/@@@[^>]*>[^>]*>(M[^ ^<]*)<\/a>[ ]*([0-9][0-9\-]* [0-9\:]*)[^<]*$/\1/')

    tileFileList=$(echo "$histFileList" | grep $regionName | grep ".A$(date -d @"$thisDate" +%Y%j).h")
    tileFileList=$(echo "${tileFileList[@]}" | tr ' ' '\n' | sort -u)
    # Sometimes the url list contains several times the same file. 2024-03-25.
  else
    printf "No file ${histUrlListDirectoryPath}${histUrlListFileName}.\n"
  fi

  # Case historic files are unavailable, we take nrt if available...
  uploadIsHistoric=1
  nrtIsAvailable=$([[ $thisDate -ge $(date --date "7 days ago" +'%s') ]] && echo 1 || echo 0)
  nrtDirectoryUrl="https://nrt3.modaps.eosdis.nasa.gov/api/v2/content/archives/allData/61/MOD09GA/$(date -d @"$thisDate" +%Y)/$(date -d @"$thisDate" +%j)/"
  if [[ -z $tileFileList && $nrtIsAvailable -eq 1 ]]; then
    uploadIsHistoric=
    # Beware, testing the condition [ $nrtIsAvailable ] is not the same, because
    # that tests if var exists.
    # We get the nrt list even if we already did before (for other tiles)
    # When we'll increase the number of tiles, maybe it should be stored         @todo
    printf "\n\nwget -qO- --no-proxy --server-response ${nrtDirectoryUrl}...\n"
    for counterIdx in {1..600}; do
      nrtListContent="A"$(wget -qO- --no-proxy --server-response ${nrtDirectoryUrl}  2>&1)
      isError503=$(printf "${nrtListContent}" | grep "HTTP/1.1 503 Service Unavailable" | wc -c)
      is202=$(printf "${nrtListContent}" | grep "HTTP/1.1 200 OK" | wc -c)
      if [[ "$isError503" -gt 0 && counterIdx -ne 600 ]]; then
        printf "${nrtListContent}"
        printf "\nRETRY #${counterIdx} in 15 sec...\n"
        sleep 15
      elif [[ "$isError503" -gt 0 && counterIdx -eq 600 ]]; then
        printf "${nrtListContent}"
        printf "\nFAILED. Max number of retrys reached.\n\n"
      elif [[ "$is202" -eq 0 ]]; then
        printf "${nrtListContent}"
        printf "\nFAILED.\n\n"
        break
      else
        break
      fi
    done
    printf "Done wget ${nrtDirectoryUrl}.\n"

    nrtFileList=$(echo "$nrtListContent" | sed -r 's/^<td><a href="([^"]*)"[^\r]*$/@@@\1/' | sed -r 's/^[^@][^@][^@][^\r^\n].*//' | sed '/^[[:space:]]*$/d' | sed -r 's/@@@([^@]*)/\1/')
    tileFileList=$(echo "$nrtFileList" | grep $regionName | grep ".A$(date -d @"$thisDate" +%Y%j).h")
  fi

  # We then download the files, the main file and the metadata file, .hdf.xml or hdf.met...
  set -o noglob
  IFS=$'\n'
  tileFileList=($tileFileList)
  set +o noglob

  if [[ ${#tileFileList[@]} -eq 0 ]]; then
    printf "NO file for ${thisDate}.\n---------------------------------------------------------------\n\n"
    continue;
  fi

  for (( fileIdx=0; fileIdx<${#tileFileList[@]}; fileIdx++ )); do
    thisFileName=${tileFileList[fileIdx]}
    if [[ ${uploadIsHistoric} -eq 1 && ${thisFileName:(-4)} == ".hdf" ]]; then
      thisFileUrl=${cloudLpDaacDirectoryUrl}${thisFileName:0:-4}/${thisFileName}
    elif [[ ${uploadIsHistoric} -eq 1 ]]; then
      thisFileUrl=${histDirectoryUrl}${thisFileName}
    else
      thisFileUrl=${thisFileName}
      # the filename here contains the directory path.
    fi
    for counterIdx in {1..600}; do
      # Retrieve historics. If earthdatacloud, dont use --no-proxy option
      # (cannot find the host in that case)
      if [[ ${uploadIsHistoric} -eq 1 && ${thisFileName:(-4)} == ".hdf" ]]; then
        printf "wget -c -t 20 --random-wait --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl} ...\n"
        wgetReturn="A"$(wget -c -t 20 --random-wait --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl} 2>&1)
          # can't use -N since modification header is not sent by server
          # use .netrc for domain login pwd
      elif [[ ${uploadIsHistoric} -eq 1 ]]; then
        printf "wget -c -t 20 --random-wait --no-proxy --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl}...\n"
        wgetReturn="A"$(wget -c -t 20 --random-wait --no-proxy --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl} 2>&1)
          # can't use -N since modification header is not sent by server
          # use .netrc for domain login pwd
      else
         printf "wget -c -t 20 --random-wait --no-proxy --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl}...\n"
         wgetReturn="A"$(wget -c -t 20 --random-wait --no-proxy --progress=dot:giga --server-response -P ${thisDirectoryPath} ${thisFileUrl} 2>&1)
         # For nrt, need special additional header (doesn't work for historics)
      fi

      isError503=$(printf "%s" "${wgetReturn}" | grep "HTTP/1.1 503 Service Unavailable" | wc -c)
      isError404=$(printf "%s" "${wgetReturn}" | grep "HTTP/1.1 404 Not Found" | wc -c)
      is202=$(printf "%s" "${wgetReturn}" | grep "HTTP/1.1 200 OK" | wc -c)
      # We could also catch other errors...                                  @todo
      # First case is when daac are not updated to the clouds. Did happen week of the 2024-03-20/25
      if [[ "$isError404" -gt 0 && ${uploadIsHistoric} -eq 1 && ${thisFileName:(-4)} == ".hdf" ]]; then
        thisFileUrl=${histDirectoryUrl}${thisFileName}
        echo "${wgetReturn}"
        printf "\nRETRY #${counterIdx} in 15 sec with new url ${thisFileUrl}...\n"
      elif [[ "$isError503" -gt 0 && counterIdx -ne 600 ]]; then
        echo "${wgetReturn}"
        printf "\nRETRY #${counterIdx} in 15 sec...\n"
        sleep 15
      elif [[ "$isError503" -gt 0 && counterIdx -eq 600 ]]; then
        echo "${wgetReturn}"
        printf "\nFAILED. Max number of retrys reached.\n---------------------------------------------------------------\n\n"
      elif [[ "$is202" -eq 0 ]]; then
        echo "${wgetReturn}"
        printf "\nFAILED.\n\n"
        break
      else
        printf "\nDONE wget ${thisFileUrl}.\n---------------------------------------------------------------\n\n"
        break
      fi
    done
  done
  # rsync if tile from westernUS.
  if  [[ $tilesForBigRegion[5] == *"${objectId}"* ]]; then
    /bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s ${thisDirectoryPath} ${thisDirectoryPath/${scratchPath}/${archivePath}}
    printf "\n rsync to archive.\n---------------------------------------------------------------\n\n"
  fi
done

source bash/toolsStop.sh
