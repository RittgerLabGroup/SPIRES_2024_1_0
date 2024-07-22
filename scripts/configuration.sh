#!/bin/bash
#
# Initialize all configuration parameters, including versions of files.

# Script core.
########################################################################################
# Configuration of scriptIds associated to script relative filePaths.
########################################################################################
scriptIds=(mod09gaI spiFillC spiSmooC moSpires scdInCub daMosaic snoStep3 webExpSn)
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
defaultVersionOfAncillary=v3.2
# v3.1 regions: h08v04 h08v05 h09v04 h09v05 h10v04 westernUS.
thoseVersionsOfAncillary[292]=v3.1
thoseVersionsOfAncillary[293]=v3.1
thoseVersionsOfAncillary[328]=v3.1
thoseVersionsOfAncillary[329]=v3.1
thoseVersionsOfAncillary[364]=v3.1
thoseVersionsOfAncillary[5]=v3.1
# v3.2 regions: 255,291,326,327,362,363,398,399,433,434,469,470 USAlaska
thoseVersionsOfAncillary[255]=v3.2
thoseVersionsOfAncillary[291]=v3.2
thoseVersionsOfAncillary[326]=v3.2
thoseVersionsOfAncillary[327]=v3.2
thoseVersionsOfAncillary[362]=v3.2
thoseVersionsOfAncillary[363]=v3.2
thoseVersionsOfAncillary[398]=v3.2
thoseVersionsOfAncillary[399]=v3.2
thoseVersionsOfAncillary[433]=v3.2
thoseVersionsOfAncillary[434]=v3.2
thoseVersionsOfAncillary[469]=v3.2
thoseVersionsOfAncillary[470]=v3.2
thoseVersionsOfAncillary[1]=v3.2

########################################################################################
# Configuration of pipelines with succession of scripts and versions of file data.
########################################################################################
# Implemented like this because not possible to put arrays in values of a dictionnary.

pipeLineScriptIds1=(mod09gaI spiFillC spiSmooC moSpires scdInCub daNetCDF daMosBig daGeoBig daStatis webExpSn)
pipeLineLabels1=(v061 v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d)
pipeLineRegionTypes1=(0 0 0 0 0 0 1 1 1 10)
  # 0: tile, 1: big region, 10: all regions.
pipeLineSequences1=(0 0 001-036 0 0 0 0 0 001-033 0)
pipeLineSequenceMultiplierToIndices1=(1 1 1 1 1 1 1 1 3 1)
pipeLineMonthWindows1=(2 2 12 12 12 12 12 0 12 12)
pipeLineParallelWorkersNb1=(0 18 10 10 0 2 6 0 0 0)

# sbatch parameters
pipeLineTasksPerNode1=(1 18 10 10 5 2 6 1 1 1)
pipeLineMems1=(1G 120G 30G 40G 30G 5G 30G 8G 8G 3G)
pipeLineTimes1=(01:30:00 01:45:00 02:30:00 00:20:00 00:20:00 00:30:00 00:30:00 00:20:00 03:00:00 01:30:00)
# NB: daGeoBig: time for generation of the last day only.
# NB: daStatis: time for 3 subdivisions only.

: '
pipeLineScriptIds1=(mod09gaI spiFillC spiSmooC moSpires scdInCub daNetCDF daMosBig daGeoBig daStatis webExpSn)
pipeLineLabels1=(v061 v2024.0c v2024.0c v2024.0 v2024.0 v2024.0 v2024.0 v2024.0 v2024.0 v2024.0)
pipeLineRegionTypes1=(0 0 0 0 0 0 1 1 1 10)
  # 0: tile, 1: big region, 10: all regions.
pipeLineSequences1=(0 0 001-036 0 0 0 0 0 001-036 0)
pipeLineSequenceMultiplierToIndices1=(1 1 1 1 1 1 1 1 3 1)
pipeLineMonthWindows1=(2 2 12 12 12 12 12 0 12 12)
pipeLineParallelWorkersNb1=(0 18 10 10 0 2 6 0 0 0)

# sbatch parameters
pipeLineTasksPerNode1=(1 18 10 10 5 2 6 1 1 1)
pipeLineMems1=(1G 140G 30G 40G 30G 5G 30G 8G 8G 3G)
# 120G replaced by 140G for 2 months may-june.
pipeLineTimes1=(01:30:00 01:45:00 02:30:00 00:20:00 00:20:00 00:30:00 00:30:00 00:20:00 01:00:00 01:00:00)
# NB: daGeoBig: time for generation of the last day only.
# NB: daStatis: time for 3 subdivisions only.
'

: '
pipeLineScriptIds1=(mod09gaI spiFillC spiSmooC moSpires scdInCub daMosBig daGeoBig daStatis webExpSn ftpExpor)
pipeLineLabels1=(v061 v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d)
pipeLineRegionTypes1=(0 0 0 0 0 1 1 1 10 10)
  # 0: tile, 1: big region, 10: all regions.
pipeLineSequences1=(0 0 001-036 0 0 0 0 001-033 0 0)
pipeLineSequenceMultiplierToIndices1=(1 1 1 1 1 1 1 3 1 0)
pipeLineMonthWindows1=(2 2 12 12 12 12 0 12 12 12)
pipeLineParallelWorkersNb1=(0 18 10 10 0 6 0 0 0 0)

# sbatch parameters
pipeLineTasksPerNode1=(1 18 10 10 5 6 1 1 1 1)
pipeLineMems1=(1G 120G 30G 40G 30G 30G 8G 3G 3G 3G)
pipeLineTimes1=(01:30:00 01:45:00 02:30:00 00:20:00 00:20:00 00:30:00 01:00:00 03:00:00 01:30:00 01:00:00)
'

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

########################################################################################
# Pipeline 2, stopping at mosaic .mats.
########################################################################################

pipeLineScriptIds2=(mod09gaI spiFillC spiSmooC moSpires scdInCub)
pipeLineLabels2=(v061 v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d v2024.0d)
pipeLineRegionTypes2=(0 0 0 0 0 0 1 1 1 10)
  # 0: tile, 1: big region, 10: all regions.
pipeLineSequences2=(0 0 001-036 0 0 0 0 0 001-033 0)
pipeLineSequenceMultiplierToIndices2=(1 1 1 1 1 1 1 1 3 1)
pipeLineMonthWindows2=(2 2 12 12 12 12 12 0 12 12)
pipeLineParallelWorkersNb2=(0 18 10 10 0 2 6 0 0 0)

# sbatch parameters
pipeLineTasksPerNode2=(1 18 10 10 5 2 6 1 1 1)
pipeLineMems2=(1G 140G 30G 40G 30G 5G 30G 8G 8G 3G)
pipeLineTimes2=(01:30:00 23:45:00 03:30:00 00:20:00 00:20:00 00:30:00 00:30:00 00:20:00 03:00:00 01:30:00)
# NB: daGeoBig: time for generation of the last day only.
# NB: daStatis: time for 3 subdivisions only.

# Bypassing the unavailability of declare -n in bash 4.2.
# declare -n could have been used in toolsStart.sh to reference these arrays, but
# it's only available in bash 4.4, while blanca/login/alpine nodes are in bash 4.2
printf -v pipeLineScriptIdsString2 '%s ' ${pipeLineScriptIds2[@]}
printf -v pipeLineLabelsString2 '%s ' ${pipeLineLabels2[@]}
printf -v pipeLineRegionTypesString2 '%s ' ${pipeLineRegionTypes2[@]}
printf -v pipeLineSequencesString2 '%s ' ${pipeLineSequences2[@]}
printf -v pipeLineSequenceMultiplierToIndicesString2 '%s ' ${pipeLineSequenceMultiplierToIndices2[@]}
printf -v pipeLineMonthWindowsString2 '%s ' ${pipeLineMonthWindows2[@]}
printf -v pipeLineParallelWorkersNbString2 '%s ' ${pipeLineParallelWorkersNb2[@]}
printf -v pipeLineTasksPerNodeString2 '%s ' ${pipeLineTasksPerNode2[@]}
printf -v pipeLineMemsString2 '%s ' ${pipeLineMems2[@]}
printf -v pipeLineTimesString2 '%s ' ${pipeLineTimes2[@]}