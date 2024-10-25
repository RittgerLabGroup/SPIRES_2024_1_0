#!/bin/bash
#
# script to run job array to update the last available day geotifs for a big region.
#
# Set up the SBATCH nodes/ntasks-per-node for 1 matlab job, trial-and-error
# with top monitoring shows job currently
# only uses 1 task but needs up to 35GB memory and I can't seem to
# request only 1 task with this much memory
#
# Arguments:
#
#SBATCH --export=NONE
#SBATCH --qos normal
# Caller can override this job-name with specifics
#SBATCH --job-name upMos
#SBATCH --time=01:15:00
#SBATCH --ntasks-per-node=32
#   Rather use 5-10 when submitting for modis tiles.
#SBATCH --nodes=1
# formerly SBATCH --partition=amilan 2023-11-21
#SBATCH --account=ucb-general
#SBATCH -o /scratch/alpine/%u/slurm_out/%x-%A_%a.out
# Set the system up to notify upon completion
#SBATCH --mail-type END,FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,STAGE_OUT
#SBATCH --array=5
  # regionId. Should have only 1 id right now.

# Functions.
########################################################################################
usage() {
  echo "" 1>&2
  echo "Usage: ${PROGNAME} [-A LABEL_ANCILLARY]" 1>&2
  echo "  [-h] [-L LABEL] " 1>&2
  echo "  [-O outputLabel] [-x scratchPath]" 1>&2
  echo "  Job array to update REGIONNAME daily variable files for a set of water years" 1>&2
  echo "Options: "  1>&2
  echo "  -A LABEL_ANCILLARY: string with version of ancillary data" 1>&2
  echo "     e.g. for operational processing, use -A v3.1 for westernUS " 1>&2
  echo "     or -A v3.2 for USAlaska" 1>&2
  echo "  -c filterConfId: int id of the region configuration to use to carry out " 1>&2
  echo "     calculations. If not precised, use the configuration indicated " 1>&2
  echo "     in configuration_of_regions.csv" 1>&2
  echo "  -h: display help message and exit" 1>&2
  echo "  -L LABEL: string with version label for directories" 1>&2
  echo "     e.g. for operational processing, use -L v2023.x" 1>&2
  echo "  -O outputLabel: string with version label for output files" 1>&2
  echo "     If -O not precised, LABEL is used for both input and output files" 1>&2
  echo "  -x scratchPath: string indicating where is the scratch, where are " 1>&2
  echo "     temporarily input and ouput files, and permanently the logs. " 1>&2
  echo "Arguments: " 1>&2
  echo "  None." 1>&2
  echo "Output: " 1>&2
  echo "  Output location is controlled in Matlab scripts and -L LABEL" 1>&2
  echo "Notes: " 1>&2
  echo "  Scripts stdout/stderr are written to user's scratch " 1>&2
  echo "  where directory /scratch/alpine/$USER/slurm_out/ " 1>&2
  echo "  is assumed to exist" 1>&2
  echo "  When calling with sbatch, set --job-name=upMos" 1>&2
  echo "  When calling with sbatch, set --array=yStart-yStop" 1>&2
  echo "  Run this script on the tiles before" 1>&2
  echo "    running it on big Regions (such as westernUS)." 1>&2
}

export SLURM_EXPORT_ENV=ALL

########################################################################################
# Main script constants. 
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=daGeoBig
defaultSlurmArrayTaskId=5
expectedCountOfArguments=
inputDataLabels=(VariablesMatlab modspiresdaily vnpspiresdaily)
outputDataLabels=(VariablesGeotiff)
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=1
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=0

# Matlab package paths added.
matlabPackages=(rasterReprojection)

source scripts/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting
# None.

if [[ $inputLabel == 'v2024.0d' ]]; then
  source scripts/toolsMatlab.sh

  # Matlab.
  ######################################################################################
  read -r -d '' matlabString << EOM

clear;
try;
  ${modisDataInstantiation}
  ${espEnvInstantiation}
  region = Regions(${inputForRegion});
  waterYearDate = WaterYearDate(${inputForWaterYearDate});
  inputDataLabel = 'modspiresdaily';
  if ismember(region.name, {'westernUS'});
    inputDataLabel = 'VariablesMatlab';
  end;
  region.writeGeotiffs(NaN, waterYearDate, region.webGeotiffEPSG, ...
    inputDataLabel = inputDataLabel, parallelWorkersNb = ${parallelWorkersNb});
${catchExceptionAndExit}

EOM
else
# This alternative solution corrects the problem at the margins of the global modis
# sinusoidal that rasterReprojection.m developed by Jeff cannot solve when reprojecting
# into EPSG:3857.
:'
Testing data
scratchPath=$espScratchDir
objectId=7
inputLabel=v2024.0f
'

  # Require gdal.
  # Here what I did, for a temporary solution, knowing that my conda envs are stored in /projects/${USER}/software/anaconda/envs/:
  # gdal_calc not currently available by default in the qgis conda environment (gdal/python bindings not done?)
: '
conda env list
create --name myqgis.3.36.0 --clone qgis.3.36.0
conda activate myqgis.3.36.0
conda install gdal
'
  # Gdal library Path
  osgeoUtilsPath=/projects/${USER}/software/anaconda/envs/myqgis.3.36.0/lib/python3.12/site-packages/osgeo_utils/
  
  # NB: This code only generates the last available day for the website. Not designed to generate a range of dates. @warning
  # Parameters.
  targetSRS="EPSG:3857"

  # Directory/File Patterns of input/output.
  tileNetCDFDirectoryPattern=${scratchPath}modis/variables/scagdrfs_netcdf_${inputLabel}/v006/{regionName}/{thisYear}/
  tileNetCDFFileNamePattern={regionName}_Terra_{thisYear}{thisMonthDay}.${inputLabel}.nc
  tileTifDirectoryPattern=${scratchPath}modis/variables/scagdrfs_geotiff_${inputLabel}/v006/{regionName}/EPSG_3857/LZW/{thisYear}/{thisYear}{thisMonthDay}/
  tileTifFileNamePattern={regionName}_Terra_{thisYear}{thisMonthDay}_{varName}.tif

  # Dynamic variables.
  varNames=
  # varNames=(viewable_snow_fraction_s grain_size_s dust_concentration_s snow_fraction_s snow_cover_days_s albedo_s radiative_forcing_s gap_snow_fraction_s deltavis_s albedo_muZ_s) # Variables determined using gdalinfo below.
  pixelSize=
  thisYear=
  thisMonthDay=

  tiles=($(echo ${tilesForBigRegion[${objectId}]} | tr ',' ' '))
  printf "\nGenerating projected tifs for each tile/variable of big region ${objectId} of the last available day...\n\n"

  # NB: the following loop is slow, I think we cant use the parallel computing with bash...
  # Maybe other ways? Or we send 1 task per tile?
  for (( tileIdx = 0; tileIdx < ${#tiles[@]}; tileIdx++ )); do
    tile=${tiles[$tileIdx]}
    regionName=${allRegionNames[$tile]}
    
    if [[ $tileIdx == 0 ]]; then
      printf "${tile}-${regionName}: NetCDF last available day...\n"
      
      # NB: very specific way to get year and date, to change if directory and file patterns change.    @warning
      tileNetCDFDirectoryPath=${tileNetCDFDirectoryPattern%/}
        # NB: No / at the end.
      tileNetCDFDirectoryPath="${tileNetCDFDirectoryPath//{regionName\}/${regionName}}"
      tileNetCDFDirectoryPath="${tileNetCDFDirectoryPath//{thisYear\}/\*}"
      tileNetCDFDirectoryPath=$(ls -d ${tileNetCDFDirectoryPath} | tail -1)
      thisYear="${tileNetCDFDirectoryPath##*\/}"
      
      tileNetCDFFileName="${tileNetCDFFileNamePattern//{regionName\}/${regionName}}"
      tileNetCDFFileName="${tileNetCDFFileName//{thisYear\}/${thisYear}}"
      tileNetCDFFileName="${tileNetCDFFileName//{thisMonthDay\}/\*}"
      tileNetCDFFilePath=$(ls -d ${tileNetCDFDirectoryPath}/${tileNetCDFFileName} | tail -1)
      
      thisMonthDay=${tileNetCDFFilePath##*\/}
      thisMonthDay=${thisMonthDay##*_}
      thisMonthDay=${thisMonthDay:4:4}
      printf "${tile}-${regionName}: NetCDF last available day: $thisYear - $thisMonthDay.\n"
      
      varNames=($(gdalinfo NETCDF:"${tileNetCDFFilePath}" | grep SUBDATASET.*NAME | cut -d : -f 3))
      printf "${tile}-${regionName}: Variables: "
      printf "%s " "${varNames[@]}" 
      printf ".\n"
    fi
    tileNetCDFFilePath="${tileNetCDFDirectoryPattern}/${tileNetCDFFileNamePattern}"
    tileNetCDFFilePath="${tileNetCDFFilePath//{regionName\}/${regionName}}"
    tileNetCDFFilePath="${tileNetCDFFilePath//{thisYear\}/${thisYear}}"
    tileNetCDFFilePath="${tileNetCDFFilePath//{thisMonthDay\}/${thisMonthDay}}"
    printf "${tile}-${regionName}: NetCDF ${tileNetCDFFilePath}.\n"
    
    tileTifFilePathPattern="${tileTifDirectoryPattern}${tileTifFileNamePattern}"
    tileTifFilePathPattern="${tileTifFilePathPattern//{regionName\}/${regionName}}"
    tileTifFilePathPattern="${tileTifFilePathPattern//{thisYear\}/${thisYear}}"
    tileTifFilePathPattern="${tileTifFilePathPattern//{thisMonthDay\}/${thisMonthDay}}"
    printf "${tile}-${regionName}: Output tif pattern ${tileTifFilePathPattern}.\n"
    tileTifDirectoryPath=$(dirname ${tileTifFilePathPattern})
    if [[ ! -d ${tileTifDirectoryPath} ]]; then
      mkdir -p ${tileTifDirectoryPath}
    fi
    
    printf "${tile}-${regionName}: Projection of variables...\n"

    for (( varIdx = 0; varIdx < ${#varNames[@]}; varIdx++ )); do
      varName=${varNames[$varIdx]}
      if [[ $varIdx == 0 ]]; then
        pixelSize=$(gdalinfo NETCDF:"${tileNetCDFFilePath}":${varName} | grep "Pixel Size" | cut -d '(' -f 2 | cut -d ',' -f 1)
      fi
      nodataValue=$(gdalinfo NETCDF:"${tileNetCDFFilePath}":${varName} | grep "#_Fill" | cut -d = -f 2)
      tileTifFilePath="${tileTifFilePathPattern//{varName\}/${varName}}"
      printf "${tile}-${regionName}: Generating $varName ${tileTifFilePath}...\n"
      gdalwarp -overwrite -t_srs ${targetSRS} -dstnodata ${nodataValue} -tr ${pixelSize} ${pixelSize} -r near -of GTiff -co COMPRESS=LZW NETCDF:"${tileNetCDFFilePath}":${varName} ${tileTifFilePath}
      
      # Handling of notprocessed_s, which is not a variable of the input netcdf.
      if [[ $varName == snow_fraction_s ]]; then
        outputFilePath=${tileTifFilePath//${varName}/notprocessed_s}
        printf "${tile}-${regionName}: Generating $varName ${outputFilePath}...\n"
        python ${osgeoUtilsPath}gdal_calc.py --calc="A=="${nodataValue} --outfile=${outputFilePath} -A ${tileTifFilePath} --A_band=1 --NoDataValue=0 --type=Byte -co COMPRESS=LZW
      fi
    done # end varIdx
  done # end tileIdx

  regionName=${allRegionNames[$objectId]}
  varNames+=(notprocessed_s)
  printf "${objectId}-${regionName}: Merge of tiles for each variable...\n"
  inputFilePathPattern="${tileTifDirectoryPattern}${tileTifFileNamePattern}"
  inputFilePathPattern="${inputFilePathPattern//{thisYear\}/${thisYear}}"
  inputFilePathPattern="${inputFilePathPattern//{thisMonthDay\}/${thisMonthDay}}"
  printf "${objectId}-${regionName}: Input tif pattern ${inputFilePathPattern}.\n"
  outputFilePathPattern="${tileTifDirectoryPattern}${tileTifFileNamePattern}"
  outputFilePathPattern="${outputFilePathPattern//{regionName\}/${regionName}}"
  outputFilePathPattern="${outputFilePathPattern//{thisYear\}/${thisYear}}"
  outputFilePathPattern="${outputFilePathPattern//{thisMonthDay\}/${thisMonthDay}}"
  printf "${objectId}-${regionName}: Output tif pattern ${outputFilePathPattern}.\n"
  for (( varIdx = 0; varIdx < ${#varNames[@]}; varIdx++ )); do
    varName=${varNames[$varIdx]}
    outputFilePath="${outputFilePathPattern//{varName\}/${varName}}"
    outputDirectoryPath=$(dirname ${outputFilePath})
    if [[ ! -d ${outputDirectoryPath} ]]; then
      mkdir -p ${outputDirectoryPath}
    fi
    thisInputFilePathPattern="${inputFilePathPattern//{varName\}/${varName}}"
    inputFilePaths=
    for (( tileIdx = 0; tileIdx < ${#tiles[@]}; tileIdx++ )); do
      tile=${tiles[$tileIdx]}
      tileName=${allRegionNames[$tile]}
      thisInputFilePath="${thisInputFilePathPattern//{regionName\}/${tileName}}"
      
      if [[ $tileIdx == 0 ]]; then
        nodataValue=$(gdalinfo ${thisInputFilePath} | grep "#_Fill" | cut -d = -f 2)
        inputFilePaths=${thisInputFilePath}
      else
        inputFilePaths="${inputFilePaths} ${thisInputFilePath}"
      fi
    done # tileIdx
    printf "${objectId}-${regionName}: Generating $varName ${outputFilePath} from ${inputFilePaths}...\n"
    inputListFilePath=${outputFilePath//\.tif/\.txt}
    echo ${inputFilePaths} | tr ' ' '\n' >> ${inputListFilePath}
     
    ${thisInputFilePath} "${inputFilePaths}" 
    
    vrtFilePath=${outputFilePath//\.tif/\.vrt}
    gdalbuildvrt -overwrite -resolution average -r nearest -input_file_list ${inputListFilePath} ${vrtFilePath}
    gdal_translate -co COMPRESS=LZW ${vrtFilePath} ${outputFilePath}

  : '  
    # The solution gdal_merge doesnt work and I dont know why...
    python ${osgeoUtilsPath}gdal_merge.py -overwrite -n ${nodataValue} -a_nodata ${nodataValue} -co COMPRESS=LZW -ot Byte -of GTiff -o ${outputFilePath} --optfile ${inputListFilePath}
   ' 
  done # end varIdx
  printf "\nDone generating projected tifs for each tile/variable of big region ${objectId} of the last available day.\n\n"
fi
# Launch Matlab and terminate bash script.
source scripts/toolsStop.sh

# SIER_201 remove the tile h07v03 for USAlaska tileset because lack JPL data from
# 2005 to 2018.
