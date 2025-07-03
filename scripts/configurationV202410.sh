#!/bin/bash
#
# Initialize all configuration parameters, including versions of files.

# Script core.
########################################################################################
source env/.matlabEnvironmentVariablesV202410

# Configuration of scriptIds associated to script relative filePaths.
########################################################################################
# scriptIds=(mod09gaI spiFillC spiSmooC moSpires scdInCub daMosaic snoStep3 webExpSn)
declare -A scriptIdFilePathAssociations
scriptIdFilePathAssociations[mod09gaI]="./scripts/runGetMod09gaFiles.sh"
scriptIdFilePathAssociations[spiFillC]="./scripts/runSpiresFill.sh"
scriptIdFilePathAssociations[spiSmooC]="./scripts/runSpiresSmooth.sh"
scriptIdFilePathAssociations[moSpires]="./scripts/runUpdateMosaicWithSpiresData.sh"
scriptIdFilePathAssociations[scdInCub]="./scripts/runUpdateWaterYearSCD.sh"
scriptIdFilePathAssociations[daNetCDF]="./scripts/runESPNetCDF.sh"
scriptIdFilePathAssociations[daMosBig]="./scripts/runUpdateMosaicBigRegion.sh"
scriptIdFilePathAssociations[daGeoBig]="./scripts/runUpdateGeotiffBigRegion.sh"
scriptIdFilePathAssociations[daStatis]="./scripts/runUpdateDailyStatistics.sh"
scriptIdFilePathAssociations[webExpSn]="./scripts/runWebExportSnowToday.sh"
scriptIdFilePathAssociations[ftpExpor]="./scripts/runFtpExport.sh"

########################################################################################
# Versions of ancillary data.
########################################################################################
declare -A thoseVersionsOfAncillary
# For all regions.
defaultVersionOfAncillary=v3.2
# but specific case for regions: h08v04 h08v05 h09v04 h09v05 h10v04 westernUS.
thoseVersionsOfAncillary[292]=v3.1
thoseVersionsOfAncillary[293]=v3.1
thoseVersionsOfAncillary[328]=v3.1
thoseVersionsOfAncillary[329]=v3.1
thoseVersionsOfAncillary[364]=v3.1
thoseVersionsOfAncillary[5]=v3.1

########################################################################################
# Month/monthwindow configuration for generation of historics.
########################################################################################

declare -A monthsForConfOfMonths
monthsForConfOfMonths[10]="3 6 9 12"
monthsForConfOfMonths[11]="1 2 3 4 5 6 7 8 9 10 11 12"
monthsForConfOfMonths[20]="12"
monthsForConfOfMonths[21]="10 11 12"
monthsForConfOfMonths[30]="3 6 9"
monthsForConfOfMonths[31]="1 2 3 4 5 6 7 8 9"
monthsForConfOfMonths[41]="6 7 8 9"
monthsForConfOfMonths[51]="9"
monthsForConfOfMonths[120]="3"
monthsForConfOfMonths[121]="1 2 3"
monthsForConfOfMonths[130]="6 9 12"
monthsForConfOfMonths[131]="4 5 6 7 8 9 10 11 12"
monthsForConfOfMonths[141]="12"

declare -A monthWindowsForConfOfMonths
monthWindowsForConfOfMonths[10]=3
monthWindowsForConfOfMonths[11]=1
monthWindowsForConfOfMonths[20]=3
monthWindowsForConfOfMonths[21]=1
monthWindowsForConfOfMonths[30]=3
monthWindowsForConfOfMonths[31]=1
monthWindowsForConfOfMonths[41]=1
monthWindowsForConfOfMonths[51]=12
monthWindowsForConfOfMonths[120]=3
monthWindowsForConfOfMonths[121]=1
monthWindowsForConfOfMonths[130]=3
monthWindowsForConfOfMonths[131]=1
monthWindowsForConfOfMonths[141]=1

########################################################################################
# Configuration of pipelines with succession of scripts and versions of file data.
########################################################################################
# Implemented like this because not possible to put arrays in values of a dictionary.

########################################################################################
# Pipeline 1, for regions with implementation < v2024.0f, i.e. v2024.0d westernUS.
########################################################################################
pipeLineBigRegionId1=5 # westernUS.
pipeLineVersionOfAncillary1=v3.1
pipeLineInputProductAndVersion1=mod09ga.061
pipeLineControlScriptId1=stnr2410
pipeLineControlTime1=11:30:00
pipeLineScriptIds1=(mod09gaI spiFillC spiSmooC moSpires scdInCub daNetCDF daMosBig daGeoBig daStatis ftpExpor webExpSn)
pipeLineLabels1=(v061 v2024.0d v2024.0d v2024.0d v2024.0d v2024.1.0 v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d)
pipeLineRegionTypes1=(0 0 0 0 0 0 1 1 1 1 10)
  # 0: tile, 1: big region, 10: all regions.
pipeLineSequences1=(0 0 001-036 0 0 0 0 0 001-033 0 0)
pipeLineSequenceMultiplierToIndices1=(1 1 1 1 1 1 1 1 3 1 1)
pipeLineMonthWindows1=(2 2 12 12 12 12 12 0 12 12 12)
pipeLineParallelWorkersNb1=(0 18 10 10 0 2 6 0 0 0 0)

# sbatch parameters
pipeLineTasksPerNode1=(1 18 10 10 5 2 6 1 1 1 1)
pipeLineMems1=(1G 140G 30G 40G 30G 5G 30G 8G 8G 1G 3G)
pipeLineTimes1=(01:30:00 02:45:00 02:30:00 00:30:00 00:20:00 00:30:00 00:40:00 00:20:00 04:00:00 01:30:00 01:30:00)
# NB: daGeoBig: time for generation of the last day only.
# NB: daStatis: time for 3 subdivisions only.
# spiFillC from 02:15 to 02:45 2025-01-25.

# Bypassing the unavailability of declare -n in bash 4.2.
# declare -n could have been used in toolsStart.sh to reference these arrays, but
# it's only available in bash 4.4, while blanca/login/alpine nodes are in bash 4.2
printf -v pipeLineScriptIdsString1 '%s ' ${pipeLineScriptIds1[@]}
printf -v pipeLineLabelsString1 '%s ' ${pipeLineLabels1[@]}
printf -v pipeLineRegionTypesString1 '%s ' ${pipeLineRegionTypes1[@]}
printf -v pipeLineSequencesString1 '%s ' ${pipeLineSequences1[@]}
printf -v pipeLineSequenceMultiplierToIndicesString1 '%s ' ${pipeLineSequenceMultiplierToIndices1[@]}
printf -v pipeLineMonthWindowsString1 '%s ' ${pipeLineMonthWindows1[@]}
printf -v pipeLineParallelWorkersNbString1 '%s ' ${pipeLineParallelWorkersNb1[@]}
printf -v pipeLineTasksPerNodeString1 '%s ' ${pipeLineTasksPerNode1[@]}
printf -v pipeLineMemsString1 '%s ' ${pipeLineMems1[@]}
printf -v pipeLineTimesString1 '%s ' ${pipeLineTimes1[@]}
