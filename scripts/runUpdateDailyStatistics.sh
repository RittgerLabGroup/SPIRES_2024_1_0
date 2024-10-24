#!/bin/bash
#
# script to run SnowToday Step3 historical:
#   calculates and save the daily statistics for all the landsubdivisions having a
#   specific source region, e.g. westernUS, for a set of waterYears.

#SBATCH --export=NONE
#SBATCH --qos normal
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --job-name 3HistST
#SBATCH --account=ucb-general
#SBATCH --time=12:00:00
# Assumes 3.74 GB/per node for total of 89.76 GB RAM
#SBATCH --ntasks-per-node=24
#SBATCH --nodes=1
#SBATCH --export=NONE
#SBATCH -o /scratch/alpine/%u/slurm_out_SnowToday/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=2022
#   array: waterYear of year. Daily stats will be calculated for this wateryear only.
#       for a set of waterYear, can be 2001-2022.
#       If waterYear, put as arguments month = last month of waterYear, day = last day
#       of waterYear and  monthWindow = 12.

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY]" 1>&2
  echo "  [-b firstToLastIndex] " 1>&2
  echo "  [-d dateOfToday] " 1>&2
  echo "  [-h] [-i] [-L LABEL] [-M thisMode] [-o] " 1>&2
  echo "  [-O outputLabel] [-x scratchPath] [-w parallelWorkersNb]" 1>&2
  echo "  " 1>&2
  echo "  Calculates daily statistics for a specific WATERYEAR" 1>&2
  echo "  So for this script to run in Oct 2021, set WATERYEAR to 2022" 1>&2
  echo "  Job array for each region group (10=westUS, 11=States, 12=HUC2)" 1>&2
  echo "  Run this script once annually, on or after Oct 1" 1>&2
  echo "Options: "  1>&2
  echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
  echo "     e.g. for operational processing, use -A v3.1 for westernUS " 1>&2
  echo "     or -A v3.2 for USAlaska" 1>&2
  echo "  -b firstToLastIndex: string with pattern int-int. Restrict execution " 1>&2
  echo "      to a range of indices (1st index-last index included)  " 1>&2
  echo "      in the landsubdivisions of the region. " 1>&2
  echo "      These indices are indices in the array of subdivisions, not " 1>&2
  echo "      the ids of subdivisions. " 1>&2
  echo "  -d dateOfToday: char, e.g. 20230930, force the date of today be " 1>&2
  echo "      distinct from today, help handling waterYearDate cap to today " 1>&2
  echo "      behavior when there's a stop of the input data flux. " 1>&2
  echo "  -h: display help message and exit" 1>&2
  echo "  -i: update input data from archive to scratch" 1>&2
  echo "  -L LABEL: string with version label for directories" 1>&2
  echo "     e.g. for operational processing, use -L v2023.x" 1>&2
  echo "  -M thisMode: indicates if code is run only partly. By default 0 runs all" 1>&2
  echo "     1: only runs the historic daily stats. 2: only runs the aggregates." 1>&2
  echo "     3: only runs the historic daily stats and aggregates." 1>&2
  echo "     4: only runs the aggregates and generate json/csv." 1>&2
  echo "  -o: update output data from scratch to archive" 1>&2
  echo "  -O outputLabel: string with version label for output files" 1>&2
  echo "     If -O not precised, LABEL is used for both input and output files" 1>&2
  echo "  -x scratchPath: string indicating where is the scratch, where are " 1>&2
  echo "     temporarily input and ouput files, and permanently the logs. " 1>&2
  echo "  -w parallelWorkersNb: int, number of parallel workers used by " 1>&2
  echo "     Matlab. If no options, all cores are workers. If 0, no parallelism. " 1>&2
  echo "Arguments: " 1>&2
  echo "  None. There should be this though: " 1>&2
  echo "  OUTPUTTYPE : indicates the type of files to be generated." 1>&2
  echo "   0: only the stat files for further use within snowToday backend. " 1>&2
  echo "   1: the stat files for backend + the geotiffs, csv, and json files for" 1>&2
  echo "   snowToday web-app." 1>&2
  echo "Array: YEAR to stop. E.g. 2022. Daily stats will be calculated over " 1>&2
  echo "  the period covered by the waterYearDate constructed from YEAR, " 1>&2
  echo "  MONTH, DAY and MONTHWINDOW." 1>&2
  echo "Output: " 1>&2
  echo "  Output location is controlled in Matlab scripts " 1>&2
  echo "Notes: " 1>&2
  echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
  echo "  where directory /scratch/alpine/$USER/slurm_out_SnowToday/ " 1>&2
  echo "  is assumed to exist" 1>&2
}

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=daStatis
defaultSlurmArrayTaskId=5001
expectedCountOfArguments=
inputDataLabels=(VariablesMatlab)
outputDataLabels=(SubdivisionStatsDailyCsv)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=1
thisSequence=001-036
thisSequenceMultiplierToIndices=3
thisMonthWindow=12

source scripts/toolsStart.sh
if [ $? -eq 1 ]; then
  error_exit "Exit=1, matlab=no, toolStart.sh failed at some point."
fi

source scripts/toolsMatlab.sh

# Scratch shuffle.
########################################################################################
# Do the scratch shuffle on complete set of input daily Mosaics (to scratch for speed)
if [ $inputFromArchive ]; then
  for dataType in scagdrfs_mat; do
    ${thisScriptDir}/scratchShuffle.sh -b ${yearStart} -e ${stopWaterYr} \
        TO variables/${dataType}_$LABEL ${regionName} || \
    error_exit "Line $LINENO: scratchShuffle error ${dataType} ${LABEL} ${regionName}"
  done
  echo "${PROGNAME}: Done with shuffle TO scratch..."
fi

# Matlab.
########################################################################################
read -r -d '' matlabString << EOM

clear;
try;
  ${modisDataInstantiation}
  ${espEnvWOFilterInstantiation}
  espEnvWOFilter.setAdditionalConf('landsubdivision');
  espEnvWOFilter.setAdditionalConf('variablestat');
  espEnvWOFilter.setAdditionalConf('webname');
  espEnv = espEnvWOFilter;
  region = Regions(${inputForRegion});
  waterYearDate = WaterYearDate(${inputForWaterYearDate});
  if (${parallelWorkersNb} ~= 0);
    espEnvWOFilter.configParallelismPool(${parallelWorkersNb});
  end;
  subdivisionConf = espEnvWOFilter.myConf.landsubdivision( ...
    espEnvWOFilter.myConf.landsubdivision.sourceRegionId == ${objectId}, :);
  lastIndex = ${lastIndex};
  if lastIndex > size(subdivisionConf, 1);
    lastIndex = size(subdivisionConf, 1);
    fprintf('Last index updated from %d to %d.\n\n', ${lastIndex}, lastIndex);
  end;
  if lastIndex < ${firstIndex};
    error('dailyStats:impossibleIndices', ...
      'warning: lastIndex %d < firstIndex %d.', lastIndex, ${firstIndex});
  end;
  subdivisionConf = subdivisionConf(${firstIndex}:lastIndex, :);
  subdivisionIds = subdivisionConf.id(:);
  parfor (subdivisionIdx = 1:size(subdivisionIds, 1), ${parallelWorkersNb});
    subdivisionId = subdivisionIds(subdivisionIdx);
    subdivision = Subdivision(subdivisionId, region);
    if ismember(${thisMode}, [0, 1, 3]);
    subdivision.calcDailyStats(waterYearDate);
    end;
    if ismember(${thisMode}, [0, 2, 3]);
      subdivision.calcAggregates(waterYearDate);
    end;
    if ismember(${thisMode}, [0, 4]);
      subdivision.writeStatCsvAndJson(1);
    end;
  end;
${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source scripts/toolsStop.sh

# NB: Maybe the geotiff generation per big region (root) is not optimally placed. @checking

# NB: version region should be filled by the version of the tile input and output
# otherwise the code generates an error.

# NB: A waterYearDate mechanism prevents dates in the future.
# dateOfToday = datetime(2023, 4, 15) allows control of today's date for tests or
# when we know that data input has stopped after a specific day.
