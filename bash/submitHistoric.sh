#!/bin/bash
########################################################################################
# Submit the generation of historics for modis tiles for a big region.
# The step of generation must be indicated by the option scriptId. See all options in
# usage() function below.
########################################################################################

shopt -s expand_aliases
source ~/.bashrc
  # to have access to alias.

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-A versionOfAncillary] [-B bigRegionId] [-c filterConfId] [-C confOfMonthId]
    [-D yyyy-MM-dd-monthWindow] [-e startYear] [-f endYear] [-h] [-I objectId]
    [-L inputLabel] [-M thisMode] [-O outputLabel] [-s scriptId]
    [-t lagTimeBetweenSubmissionOfYears]
    [-u slurmCluster] [-U slurmExecutionOptions] [-v verbosity]
    [-x scratchPath] [-y archivePath]
    Submit and monitor a step (scriptId) of the generation of stc historics.
    NB: You must launch this script when in root directory of the project.
  Options:
    -A versionOfAncillary: string, optional. E.g. v3.1 or v3.2.
      Version of the ancillary data. If not
      given, takes the version in conf/configuration_of_regions.csv.
    -B bigRegionId: int, obligatory. Identifying the big region (e.g. 5 for westernUS).
      Only one big region per run.
    -c, filterConfId, int, optional. Identifies the algorithm configuration and
      thresholds
      in configuration_of_filters.csv used by the algorithm. Default 0 indicates take
      the filter id of the region configuration, other value points to another
      specific filter configuration.
    -C confOfMonthId: int, obligatory. Identify the group of months that will be
      generated within each job.
      # 0: Parameter overriden by option -D.
      # 10: Full year, by trimester. 11: Full year, by month.
      # 20: 10-12 by trimester. 21: 10-12 by month. 
      # 30: 1-9 by trimester. 31: 1-9 by month. 41: 6-9 by month.
      # 51: Full water year from Oct to Sept.
      # 120: 1-3 by trimester. 121: 1-3 by month.
      # 130: 4-12 by trimester. 131: 4-12 by month. 141: 12 by month.
      NB: This parameter should be set to 0 if a period misses input data in the first
      months, and overriden by an adequate waterYearDate.
    -D waterYearDateString, string, format yyyy-MM-dd-monthWindow, obligatory and
      activated only if option -C is set to 0. Gives the date
      window over which the generation is done. E.g. 2024-03-26-1.
      The period ends by the date defined by yyyy-MM-dd, here
      2024-03-26, and monthWindow, the number of months before this date covering the
      period: 12: 1 full year period, 1: the month of the date, from 1 to the date,
      0: only the date. Default: date of today with monthWindow = 2. NB: if dd > than
      the last day of the month, then code (in the called script) sets it to last day.
      NB: if a water year misses input data in the first months, the monthwindow
      should be adapted so as not to include the missing months. For instance, if
      water year 2024 misses october, WaterYearDate covering the full wateryear should
      be set to 2024-09-30-11.
    -e startYear: int, optional. Smallest year of run, e.g. 2024. If not given,
      startYear = endYear. Option overriden by -D.
    -E thisEnvironment: String, obligatory. E.g. "SpiresV202410" or "SpiresV202501".
      Gives the environment
      version, to distinguish between different version of the algorithm used to
      calculate snow properties.
    -f endYear: int, obligatory and activated only if option -C is not set to 0.
      Highest year of run, of year of run, e.g. 2025.
      NB: if we run 10/2024 for westernUS over a monthwindow of 1 month only, although
      this period is affected to water year 2025, endYear should be 2024 in that case.
      Option overriden by -D.
    -h: display help message and exit.
    -I objectId: string, optional. String of the ids of the tiles to generate,
      separated by a comma.
      E.g. 292,328 for h08v04 and h09v04. Default empty (generates all the tiles of
      the big region). Full list in conf/configuration_of_regions.csv.
    -L inputLabel: string, optional. String with version label for directories.
      E.g. v2024.1.0.
      For mod09ga, is v061, for version 6.1 of the tiles.
    -M thisMode: int, optional. Default: 0. Certain steps need to run in a specific
      mode, among others to avoid running the full step as it is done in the NRT
      pipeline
    -O outputLabel: string, optional. String with version label for output files.
      E.g. v2024.1.0.
      If -O not given, inputLabel is used for both input and output files.
    -s scriptId: string, obligatory, must be a member of authorizedScriptIds indicated in configurationForHistoricsV.sh.
    -T controlTime: String format 00:00:00, optional. Wall-time of the runSubmitter.sh
      execution, beyond which the monitoring of the pipeline will be stopped. By
      default, time indicated in configurationForHistoricsV.sh.
    -t lagTimeBetweenSubmissionOfYears: string, optional. E.g. 5m. Sleep lag time
      between
      submission of years, to reduce load to slurm. If not given, not lag time.
    -u slurmCluster: int, optional. Id of the slurm cluster configuration.
      0 for Alpine (default), 1 for Blanca. Defines the slurm cluster and a
      part of the options of slurm submission.
    -U slurmExecutionOptions: string, optional. E.g. "--ntasks-per-node=10 \
      --mem=80G --time=01:10:00 --exclude=bmem-rico1,bgpu-bortz1". If not given, takes
      default specific to each scriptId, without excluded node. NB: excluded node
      must be part of the cluster, otherwise slurm will reject submission.
    -v verbosity: int, optional. Default: 0, all logs, including prompts. 10: all
      logs, but no prompt.
    -x: scratchPath: string, optional. Scratch storage location. This temporary
      location is
      for increased performance in read/write, compared to archive. The output
      files can later be sync back to archive.
      Default: environment variable $espScratchDir.
    -y: archivePath: string, optional. Permanent storage location.
      Default: environment variable $espArchiveDirNrt.
  Arguments:
    None.
  Sbatch parameters:
    No slurm use.
  Output:
    Terminal.

EOM
  printf "$thisUsage\n" 1>&2
}

# Slurm cluster configuration constants.
########################################################################################
slurmNames=(${slurmName1} ${slurmName2})
slurmAccounts=(${slurmAccount1} ${slurmAccount2})
slurmQoss=(${slurmQos1} ${slurmQos2})
slurmLogDirs=(${espLogDir} ${espLogDir})
  # all these variables are defined in ~.bashrc.

# Parsing of options.
########################################################################################
verbosity=0

OPTIND=1
thisGepOptsString="A:B:c:C:D:E:e:f:hI:L:O:p:s:T:t:u:U:x:y:w:"
# NB: add a : in string above when option expects a value.
while getopts ${thisGepOptsString} opt
# NB: all these options whould correspond to the options caught above.
do
  case $opt in
    A) versionOfAncillary="$OPTARG";;
    B) bigRegionId="$OPTARG";;
    c) filterConfId="$OPTARG";;
    C) confOfMonthId="$OPTARG";;
    D) waterYearDateString="$OPTARG";;
    E) thisEnvironment="$OPTARG";;
    e) startYear="$OPTARG";;
    f) endYear="$OPTARG";;
    h) usage
      exit 1;;
    I) objectId="$OPTARG";;
    L) inputLabel="$OPTARG";;
    M) thisMode="$OPTARG";;
    O) outputLabel="$OPTARG";;
    p) inputProductAndVersion="$OPTARG";;
    s) scriptId="$OPTARG";;
    T) controlTime="$OPTARG";;
    t) lagTimeBetweenSubmissionOfYears="$OPTARG";;
    u) slurmCluster="$OPTARG";;
    U) slurmExecutionOptions="$OPTARG";;
    v) verbosity="$OPTARG";;
    x) scratchPath="$OPTARG";;
    y) archivePath="$OPTARG";;
    w) parallelWorkersNb="$OPTARG";;
    ?) printf "Unknown option %s\n" $opt
      usage
      exit 1;;
  esac
done

# Configuration loading and check option -E thisEnvironment.
########################################################################################
if [[ -z $thisEnvironment ]]; then
  printf "ERROR: -E thisEnvironment is obligatory (Line ${LINENO}).\n"
  exit 1
fi
printf "-E thisEnvironment: ${thisEnvironment}"
set -x
source bash/configuration${thisEnvironment}.sh # include source env/.matlabEnvironmentVariables${thisEnvironment^}
source bash/toolsRegions.sh
source bash/toolsWaterYearDate.sh

source bash/configurationForHistorics${thisEnvironment}.sh
  # Step specific parameters for slurm historics.
set +x

# Determine step-specific variables with option -s scriptId.
########################################################################################
printf "Determine script, slurm, and step-specific variables from conf/configurationForHistorics${thisEnvironment}...\n"
# Option -s, scriptId.
if [[ ! " ${authorizedScriptIds[*]} " =~ [[:space:]]${scriptId}[[:space:]] ]]; then
  printf "ERROR: received scriptId '%s' not in authorized list '" ${scriptId}
  printf "%s " ${authorizedScriptIds[*]}
  printf "' (Line ${LINENO}).\n" ${scriptId} ${authorizedScriptIds[*]}
  exit 1
fi
scriptIdIdx=$(echo ${authorizedScriptIds[@]/${scriptId}//} | cut -d/ -f1 | wc -w | tr -d ' ')
  # Index of $scriptId to get the other parameters.
sbatchScript=${scriptIdFilePathAssociations[${scriptId}]};
  # $scriptIdFilePathAssociations in shared/sh/configuration.sh
submitScriptIdJobName=${submitScriptIdJobNames[${scriptIdIdx}]}${bigRegionId};
scriptIdJobName=${scriptIdJobNames[${scriptIdIdx}]}${bigRegionId};

scriptLabel=${scriptLabels[${scriptIdIdx}]};
scriptRegionType=${scriptRegionTypes[${scriptIdIdx}]};
scriptSequence=${scriptSequences[${scriptIdIdx}]};
scriptSequenceMultiplierToIndice=${scriptSequenceMultiplierToIndices[${scriptIdIdx}]};
if [[ -z $parallelWorkersNb ]]; then
  parallelWorkersNb=${scriptParallelWorkersNbs[${scriptIdIdx}]};
fi

# Determine mode.
if [[ -z $thisMode ]]; then
  thisMode=${scriptModes[${scriptIdIdx}]};
fi

# sbatch parameters.
sbatchNTasksPerNode=${sbatchNTasksPerNodes[${scriptIdIdx}]};
sbatchMem=${sbatchMems[${scriptIdIdx}]};
sbatchTime=${sbatchTimes[${scriptIdIdx}]};
sbatchExcludeNodes=""; # No node excluded by default.

# Determine region and objects with option -B bigRegionId, -I objectId.
########################################################################################
# objectId is the parameter --array of the sbatch command.
printf "Determining region and object...\n"
# Option -B
typeOfRegion=$(get_type_of_region_id $bigRegionId)
if [[ -z $bigRegionId || $typeOfRegion != 'bigRegion' ]]; then
  printf "ERROR: -B bigRegionId ${bigRegionIdx} is obligatory and should correspond to a big region (Line ${LINENO}).\n"
  exit 1
fi
if [[ -z $bigRegionId || $typeOfRegion != 'bigRegion' ]]; then
  printf "ERROR: -B bigRegionId ${bigRegionIdx} is obligatory and should correspond to a big region (Line ${LINENO}).\n"
  exit 1
fi

# Option -I.
if [[ $scriptRegionType -eq 1 ]]; then
  objectId=$bigRegionId
elif [[ -z $objectId ]]; then
  objectId=${regionIdsPerBigRegion[$bigRegionId]};
fi
# Option -A.
if [[ -z $versionOfAncillary ]]; then
  versionOfAncillary=$(get_version_of_ancillary_for_region_id $bigRegionId);
fi

# Determine objectId and scriptCountOfCell depending on sequence configured.
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

# Determine period from -C confOfMonthId -D waterYearDateString -e endYear -f startYear.
########################################################################################
printf "Determine period (years, conf of months, waterYearDate) options...\n"

$allowedConfOfMonthIds=0,10,11,20,21,30,31,41,51,120,121,130,131
if [[ -z $confOfMonthId || $allowedConfOfMonthIds != *"$confOfMonthId"* ]]; then
  printf "ERROR: -C confOfMonthId ${confOfMonthId} is obligatory and should be in the list of allowed values (submitHistoric.sh -h for details) (Line ${LINENO}).\n"
  exit 1
fi
if [[ $confOfMonthId -ne 0 && ( $endYear != "20"* || ${#endYear} -ne 4 ) ]]; then
  printf "ERROR: -e endYear is obligatory and should be between 2000 and 2099 when -C confOfMonthId ${confOfMonthId} is not 0 (submitHistoric.sh -h for details) (Line ${LINENO}).\n"
  exit 1
fi
if [[ $confOfMonthId -eq 0 && ! is_water_year_date_in_the_past "$waterYearDateString" ]]; then 
  printf "ERROR: -D waterYearDate ${waterYearDate} is obligatory and should be the right format YYYY-MM-DD-MonthWindow, with a date no later than yesterday when -C confOfMonthId = 0 (submitHistoric.sh -h for details) (Line ${LINENO}).\n"
  exit 1
fi

if [[ $confOfMonthId -ne 0 ]]; then
  if [[ -z $startYear ]]; then
    years=($endYear); # endYear checked above.
  else
    years=($(eval echo {${endYear}..${startYear}..-1}))
  fi
  months=(${monthsForConfOfMonths[$confOfMonthId]})
  lastDay=31
  monthWindow=${monthWindowsForConfOfMonths[$confOfMonthId]}
else
  waterYearDateArray=(${waterYearDateString//-/ })
  years=(${waterYearDateArray[0]})
  months=(${waterYearDateArray[1]})
  lastDay=${waterYearDateArray[2]}
  monthWindow=${waterYearDateArray[3]}
fi

# Options -L, -O inputLabel and outputLabel, -c filterConfId.
########################################################################################
if [[ -z $inputLabel ]]; then
  inputLabel=${scriptLabels[${scriptIdIdx}]};
fi
if [[ -z $outputLabel && ${scriptIdIdx} -lt $((${#authorizedScriptIds[@]} - 1)) ]]; then
  outputLabel=${scriptLabels[$((${scriptIdIdx} + 1))]};
elif [[ -z $outputLabel ]]; then
  outputLabel=$inputLabel
fi
if [[ -z $inputProductAndVersion ]]; then
  inputProductAndVersion=$defaultInputProductAndVersion; # in configurationForHistoricsV.sh
fi
if [[ -z $filterConfId ]]; then
  filterConfId=0
fi

# Slurm config parameters.
########################################################################################
printf "Determine slurm config parameters...\n"
# Option -x.
if [[ -z $scratchPath ]]; then
  scratchPath=${espScratchDir}; # in ~.bashrc.
fi
# Option -y.
if [[ -z $archivePath ]]; then
  archivePath=${espArchiveDirNrt}; # in ~.bashrc.
fi
# Option -T.
if [[ -z $controlTime ]]; then
  controlTime=$defaultControlTime; # in configurationForHistoricsV.sh
fi
# Option -u.
if [[ -z $slurmCluster ]]; then
  slurmCluster=0; # Alpine by default.
fi
# Option -U.
if [[ ! -z $slurmExecutionOptions ]]; then
  slurmExecutionOptions=($slurmExecutionOptions)
  for slurmExecutionOption in ${slurmExecutionOptions[@]}; do
    thisOptionName=$(echo ${slurmExecutionOption} | cut -d "=" -f 1)
    thisOptionValue=$(echo ${slurmExecutionOption} | cut -d "=" -f 2)
    case $thisOptionName in
      --ntasks-per-node) sbatchNTasksPerNode=$thisOptionValue;;
      --mem) sbatchMem=$thisOptionValue;;
      --time) sbatchTime=$thisOptionValue;;
      --exclude) sbatchExcludeNodes=$slurmExecutionOption;;
    esac
  done
fi

# Check no argument.
########################################################################################
expectedCountOfArguments=0
shift $(($OPTIND - 1))

[[ "$#" -eq $expectedCountOfArguments ]] || { printf "ERROR: received %0d arguments, %0d expected.\n" $# $expectedCountOfArguments ; exit 1; }
  # NB syntax: the ; before the } is crucial.

# Initialize.  
########################################################################################
printf "Initialize submission...\n"
ml slurm/${slurmNames[${slurmCluster}]}; slurmAccount=${slurmAccounts[${slurmCluster}]};
slurmLogDir=${slurmLogDirs[${slurmCluster}]};
slurmQos=${slurmQoss[${slurmCluster}]};

read -s -r -d '' scriptParameters << EOM
Script parameters.
#############################################################################
script= $sbatchScript
region= $bigRegionId
objectIds= $objectId
countOfCells=$countOfCells
years= ${years[0]} - ${years[-1]}
months= ${months[@]}
lastDay= ${lastDay}
monthWindow= $monthWindow
product= $inputProductAndVersion
inputLabel= ${inputLabel}
outputLabel= ${outputLabel}
filterConfId= ${filterConfId}
thisMode= ${thisMode}
scratchPath= ${scratchPath}
archivePath= ${archivePath}
thisSubmitScriptIdJobName= ${submitScriptIdJobName} + year 2 last digits
thisScriptIdJobName= ${scriptIdJobName} + year 2 last digits
slurmLogDir= ${slurmLogDir}
sbatchExcludeNodes= $sbatchExcludeNodes
lagTimeBetweenSubmissionOfYears= ${lagTimeBetweenSubmissionOfYears}
EOM
printf "\n${scriptParameters}\n\n"

# Submit submitter jobs to slurm.
########################################################################################
: ' 
@deprecated:
read -p "$(date +%H:%M:%S): Confirm job submission: (Y/N)" -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
'

if [[ verbosity -eq 0 ]]; then
  read -p "$(date +%H:%M:%S): Do you want to proceed submission? (y/n) " yn

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
for year in ${years[@]}; do
  echo $year
  thisSubmitScriptIdJobName=${submitScriptIdJobName}${year: -2};
  thisScriptIdJobName=${scriptIdJobName}${year: -2};
  for month in ${months[@]}; do
    waterYearDate=${year}-${month}-${lastDay}-${monthWindow};
    slurmOutputPath=${slurmLogDir}%x_%a_${waterYearDate}_%A.out;
    thisSubmitLine=to
    read -r -d '' thisSubmitLine << EOM
sbatch ${scriptExcludeNodes} \
--account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} \
--job-name=${thisScriptIdJobName} --cpus-per-task=1 --ntasks-per-node=${sbatchNTasksPerNode} \
--mem=${sbatchMem} --time=${sbatchTime} --array=${objectId} ${sbatchScript} \
-A ${versionOfAncillary} -c ${filterConfId} -D ${waterYearDate} \
-E ${thisEnvironment} -L ${inputLabel} \
-M 0 -O ${outputLabel} -p ${inputProductAndVersion} -Q ${countOfCells} \
-x ${scratchPath} -y ${archivePath} \
-w ${parallelWorkersNb}
EOM

    sbatch ${scriptExcludeNodes} --account=${slurmAccount} --qos=${slurmQos} \
-o ${slurmLogDir}%x_%a_%A.out --job-name=${thisSubmitScriptIdJobName} --ntasks-per-node=1 \
--mem=1G --time=${controlTime} --array=1 ${sharedScriptRelativeDirectoryPath}runSubmitter.sh "${thisSubmitLine}"
  done;
  if [[ -z lagTimeBetweenSubmissionOfYears ]]; then
    sleep ${lagTimeBetweenSubmissionOfYears}
  fi
done

printf "$(date +%H:%M:%S): DONE submission.\n"
