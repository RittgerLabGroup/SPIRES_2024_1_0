#!/bin/bash
#
# Initialize configuration parameters specific to generation of historics for SPIReS v2024.1.0.

# Script/Step-specific constants.
########################################################################################
# defaultBigRegionId=5
defaultControlTime=23:59:00
defaultInputProductAndVersion="mod09ga.061"
authorizedScriptIds=(mod09gaI spiFillC spiSmooC moSpires scdInCub daNetCDF daMosBig daStatis)
: '
  - mod09gaI: Download mod09ga.
  - spiFillC: Generate intermediary gap files from mod09ga input using SPIReS spectral
    unmixing.
  - spiSmooC: Generate gap-filled data files (without false positives) + 
    temporal interpolation + albedo calculations using ParBal.
  - moSpires: Generate daily .mat files (dubbed mosaics).
  - scdInCub: Calculate snow cover days in daily .mat files.
  - daNetCDF: Generate output netcdf files.
  - daMosBig: Generate output big mosaic .mat files.
  - daStatis: Generate .csv daily statistic files
'

submitScriptIdJobNames=(sMod sSFi sSSm sMoS sScd sNet sMoB sSta)
scriptIdJobNames=(mod0 sFil sSmo moSp scdI netC moBi stat)
scriptLabels=(v061 v2024.0d v2024.0d v2024.0d v2024.0d v2024.1.0 v2024.0d v2024.0d)
scriptModes=(0 0 0 0 0 0 0 1)
scriptRegionTypes=(0 0 0 0 0 0 1 1)
  # 0: tile, 1: big region, 10: all regions.
scriptSequences=(0 0 001-036 0 0 0 0 001-033)
scriptSequenceMultiplierToIndices=(1 1 1 1 1 1 1 3)
scriptParallelWorkersNbs=(0 18 10 10 0 2 6 0)

# sbatch parameters
sbatchNTasksPerNodes=(1 18 10 10 5 2 6 1)
sbatchMems=(1G 140G 30G 40G 30G 5G 30G 8G)
sbatchTimes=(02:00:00 04:00:00 02:30:00 00:30:00 00:20:00 00:30:00 00:40:00 04:00:00)
# for: 3-months 3-months 12-months(wateryear) 12-months(wateryear) 12-months(wateryear) 12-months(wateryear) 12-months(wateryear) 12-months(wateryear)