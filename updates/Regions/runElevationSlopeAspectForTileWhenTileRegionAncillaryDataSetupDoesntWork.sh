# This script to be used to generate topographic tiles where rasterReprojection cannot.
# NB: bilinear reprojection/interpolation doesn't give exactly same results with gdal
# and with rasterReprojection, I dont know why. With gdal, seems smoother. Differences
# are usually below 50 m, occasionally up to 100 m. 2024-03-07.

# 1. Reproject the topographic tiles into modis sinusoidal.
########################################################################################

: '
Data from the USGS Gmted2010 product
https://topotools.cr.usgs.gov/gmted_viewer/viewer.htm (median 7.5 arc sec.)
NB: we suppose that the set of Gmted2010 files in variable elevationSourceFilenames
cover the full spectruum of the region modis tiles, but we dont know exactly which
file covers what.
%
NB: The Gmted2010 median 7.5 arc sec dont cover Greenland and Antarctica. 2024-02-23.
  We need to get the mean 30 arc sec and then increase the resolution of those tiles,
  and merge them with median 7.5 arc, by replacing 0 values in 7.5 arc sec by values
  from the mean 30 arc sec.                                                   @warning
                                                                                 @todo
NB: For lowering resolution, we must use a not nearest neighbor, to have not-weird
  aspect/slope values. => choose an appropriate method.                          @todo
NB: Theres a problem with extreme Asia East (~ 180E/W), which are cut between 2.
                                                                              @tocheck
'

topographicType=aspect #aspect #elevation # aspect slope

ml purge
printf "ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0"
ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0

# Gdal library Path
osgeoUtilsPath=/projects/${USER}/software/anaconda/envs/myqgis.3.36.0/lib/python3.12/site-packages/osgeo_utils/
  
scratchPath=$espScratchDir
sourceDirectoryPath=${espScratchDir}modis_ancillary/${topographicType}_tmp/
targetDirectoryPath=${espScratchDir}modis_ancillary/${topographicType}_tmp_sinu2/

fileNames=( $(ls ${sourceDirectoryPath}) )
pixelSize=463.312716569384691
nodataValue=32767
proj4='+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs +nadgrids=@null +wktext'
wkt2="PROJCS['MODIS Sinusoidal',GEOGCS['User with datum World Geodetic Survey 1984',DATUM['unnamed',SPHEROID['unnamed',6371007.181,0]],PRIMEM['Greenwich',0],UNIT['degree',0.0174532925199433,AUTHORITY['EPSG','9122']]],PROJECTION['Sinusoidal'],PARAMETER['longitude_of_center',0],PARAMETER['false_easting',0],PARAMETER['false_northing',0],UNIT['metre',1,AUTHORITY['EPSG','9001']],AXIS['Easting',EAST],AXIS['Northing',NORTH]]"
targetSRS=$proj4

for fileName in ${fileNames[@]}; do
  outputFileName=${fileName/\.tif/\.sinu\.tif}
  printf "Reprojecting ${fileName} into ${outputFileName}...\n"
  
  gdalwarp -overwrite -t_srs "${targetSRS}" -dstnodata ${nodataValue} -r bilinear -of GTiff -co COMPRESS=LZW ${sourceDirectoryPath}${fileName} ${targetDirectoryPath}${fileName}
  
  # I chose bilinear because I decrease resolution
done


# 2. Join all into a vrt.
########################################################################################

topographicType=aspect #aspect #elevation # aspect slope

ml purge
printf "ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0"
ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0

# Gdal library Path
osgeoUtilsPath=/projects/${USER}/software/anaconda/envs/myqgis.3.36.0/lib/python3.12/site-packages/osgeo_utils/
  
scratchPath=$espScratchDir
sourceDirectoryPath=${espScratchDir}modis_ancillary/${topographicType}_tmp_sinu2/
targetDirectoryPath=${espScratchDir}modis_ancillary/${topographicType}_tmp_sinu2/
inputListFilePath=${targetDirectoryPath}vrtListFilePath.txt
vrtFilePath=${targetDirectoryPath}${topographicType}.vrt

ls ${sourceDirectoryPath}*.tif > $inputListFilePath
cd $sourceDirectoryPath
gdalbuildvrt -overwrite -resolution average -r bilinear -input_file_list ${inputListFilePath} ${vrtFilePath}


# 3. Cut each modis tiles
########################################################################################
topographicType=slope #aspect #elevation # aspect slope

ml purge
printf "ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0"
ml miniforge; ml gcc/11.2.0; ml gdal/3.5.0; conda env list; conda activate myqgis.3.36.0

# Gdal library Path
osgeoUtilsPath=/projects/${USER}/software/anaconda/envs/myqgis.3.36.0/lib/python3.12/site-packages/osgeo_utils/

scratchPath=$espScratchDir
sourceDirectoryPath=${espScratchDir}modis_ancillary/${topographicType}_tmp_sinu2/
polygonDirectoryPath=${espScratchDir}modis_ancillary/v3.2/modispolygon/
targetDirectoryPath=${espScratchDir}modis_ancillary/v3.2/${topographicType}_gdal/
vrtFilePath=${sourceDirectoryPath}${topographicType}.vrt

pixelSize=463.312716569384691
nodataValue=32767
proj4='+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs +nadgrids=@null +wktext'
targetSRS=$proj4

polygonFilePaths=( $(ls ${polygonDirectoryPath}*.shp) )

polygonNames=(h11v01 h12v01 h13v01 h14v01)

for polygonName in ${polygonNames[@]}; do
  polygonFilePath=${polygonDirectoryPath}${polygonName}_land_mod44_50.shp
  outputFileName=$(echo ${polygonFilePath} | cut -d '/' -f 8 | sed "s~_land_mod44_50.shp~_${topographicType}_gmted_med075.tif~")
  printf "Generating ${outputFileName} from ${polygonFilePath}...\n"
  gdalwarp -overwrite -t_srs "${targetSRS}" -tr ${pixelSize} ${pixelSize} -dstnodata ${nodataValue} -r med -of GTiff -co COMPRESS=LZW -cutline ${polygonFilePath} ${vrtFilePath} ${targetDirectoryPath}${outputFileName}
done

: '
for polygonFilePath in ${polygonFilePaths[@]}; do
  outputFileName=$(echo ${polygonFilePath} | cut -d '/' -f 8 | sed 's~_land_mod44_50.shp~_elevation_gmted_med075.tif~')
  printf "Generating ${outputFileName} from ${polygonFilePath}...\n"
  gdalwarp -overwrite -t_srs "${targetSRS}" -tr ${pixelSize} ${pixelSize} -dstnodata ${nodataValue} -r med -of GTiff -co COMPRESS=LZW -cutline ${polygonFilePath} ${vrtFilePath} ${targetDirectoryPath}${outputFileName}
done
'
