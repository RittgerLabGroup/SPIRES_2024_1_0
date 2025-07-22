#!/bin/bash
#
# Initialize region parameters. SIER_345.

# NB: ${thisEnvironment} should be defined. In classic operations, it is done in
# toolsStart.sh.
if [[ -z $fileSeparator ]]; then 
  fileSeparator='/'
fi
if [[ -z $defaultIFS ]]; then 
  defaultIFS=$' \t\n'
fi
if [[ -z $workingDirectory ]]; then 
  workingDirectory=$(pwd)/
fi

regionConfFilePath=${workingDirectory}conf/configuration_of_regions${thisEnvironment}.csv
if [ ! -f $regionConfFilePath ]; then
  regionConfFilePath=${workingDirectory}conf/configuration_of_regions.csv
    # default file.
fi
[ ! -f regionConfFilePath ] || error_exit "Exit=1, matlab=no, inexisting ${regionConfFilePath}."
  # when toolsRegions.sh launched standalone, $thisEnvironment is unset, otherwise set
  # by toolsStart.sh.


########################################################################################
# Functions.
########################################################################################
get_object_ids_from_big_region_object_ids_string() {
  # Extract the big region ids from the parameter objectId, collect the ids of the
  # tiles associated in the region configuration file and return the list.
  #
  # Parameters
  # ----------
  # - objectId: String, e.g. "5" or "5,7". List of ids of big regions (e.g. 5 for
  #   westernUS)
  #
  # Return
  # ------
  # - theseObjectIds: String, e.g. "292,293". List of the ids of the modisTiles
  #   associated to the big region. The ids are unique
  local objectId="$1"
  local theseObjectIds=""

  IFS=',' read -ra bigObjectIdsArray <<< "$objectId"
  IFS=defaulIFS

  for bigObjectId in "${bigObjectIdsArray[@]}"; do
    local additionalObjectIds=$(awk -F',' -v target_id="$bigObjectId" '
      $2 == "modisTile" && $20 == target_id {
        if (line_values == "") {
          line_values = $19
        } else {
          line_values = line_values "," $19
        }
      }
      END { print line_values }
    ' "${regionConfFilePath}")

    if [[ -n "$additionalObjectIds" ]]; then
      theseObjectIds="${theseObjectIds},${additionalObjectIds}"
    fi
  done

  # Remove the leading comma if it exists
  if [[ "${theseObjectIds:0:1}" == "," ]]; then
    theseObjectIds="${theseObjectIds:1}"
  fi

  # Use `tr` to replace commas with newlines, `sort -u` to get unique values,
  # and `tr` again to replace newlines back with commas
  theseObjectIds=$(echo "$theseObjectIds" | tr ',' '\n' | sort -u | tr '\n' ',')

  # Remove the trailing comma (if any)
  theseObjectIds=${theseObjectIds%,}

  echo "$theseObjectIds"
}

get_type_of_region_id(){
  # Gets the type of object a region is.
  #
  # Parameters
  # ----------
  # - objectId: Int, e.g. 5 (for westernUS). Id of the region, as defined in conf/configuration_of_regionsV.csv.
  #
  # Return
  # ------
  # - type: String, e.g. "modisTile" or "bigRegion". Type of the region.
  #   region.
  local objectId="$1"

  # Use awk to filter the CSV and extract column 21
  typeOfRegion=$(awk -F',' -v obj="$objectId" '($19 == obj) {print $2}' "$regionConfFilePath" | head -1)
  echo "$typeOfRegion"
}

get_region_names_from_object_ids_string() {
  # Get the list of region names associated to the list of object ids
  # $theseObjectIds.
  #
  # Parameters
  # ----------
  # - objectIds: String, e.g. "292" or "292,293,5". List of tile or big region ids.
  #
  # Return
  # ------
  # - regionNames: String, e.g. "h08v04,h08v05,westernUS". List of the regionNames
  #   associated with the object ids.
  local objectIds="$1"
  local regionNames=""

  # Convert the comma-separated string of IDs into an array
  IFS=',' read -r -a objectIdArray <<< "$objectIds"
  IFS=defaulIFS

  # Build an awk command to filter and extract
  # The pattern is constructed like "$19 == ID1 || $19 == ID2 || ..."
  awk_pattern=""
  for id in "${objectIdArray[@]}"; do
    if [ -n "$awk_pattern" ]; then
      awk_pattern="$awk_pattern || "
    fi
    awk_pattern="$awk_pattern\$19 == \"$id\""
  done

  # Use awk to filter the CSV and extract column 1 values
  # Then use paste to join the results with commas
  regionNames=$(awk -F',' "$awk_pattern {print \$1}" "$regionConfFilePath" | paste -sd',')

  echo "$regionNames"
}

get_tile_group_id_from_group_name(){
  # Get our internal id from a group name.
  #
  # Parameters
  # ----------
  # $1: char. Tile group name. E.g. "AMAndes", "ASHimalaya", "USAlaska", "westernUS".
  #
  # Return
  # ------
  # internalId: int. E.g. for westernUS: 1.
  for idx in ${!tileGroupNames[@]}; do
    if [ ${tileGroupNames[$idx]} == $1 ]; then
      echo $idx
    fi
  done
}
get_tile_id_from_tile_name(){
  # Get our internal id from a tile name.
  #
  # Parameters
  # ----------
  # $1: char. Tile name. Tiling h00 to h35 and v00 to v17. E.g. "h08v04".
  #
  # Return
  # ------
  # internalId: int. E.g. for h00v00: 0, h01v01: 36.
  tileName=$1
  horizontalFactor=`expr $(echo ${tileName} | cut -c 2-3) + 0`
  echo $((${horizontalFactor} * 36 + $((10#$(echo ${tileName} | cut -c 5-6)))))
  # $((10# set the number base 10, otherwise bash interpret 08 and 09 in base 8 and
  # raise an error because these numbers dont exist in base 10
}
get_tile_name_from_tile_id(){
  # Get the tile name from our internal id
  #
  # Parameters
  # ----------
  # $1: int. Internal id.
  #
  # Return
  # ------
  # tileName: char. E.g. h01v01 for 26. Tiling h00 to h35 and v00 to v17.
  tileId=$1
  horizontalId=$(expr ${tileId} / 36)
  verticalId=$((${tileId} - ${horizontalId} * 36))
  printf -v horizontalId "%02d" ${horizontalId}
  printf -v verticalId "%02d" ${verticalId}
  echo "h${horizontalId}v${verticalId}"
}

get_version_of_ancillary_for_region_id(){
  # Gets the version of ancillary data for a region.
  #
  # Parameters
  # ----------
  # - objectId: Int, e.g. 5 (for westernUS). Id of the region, as defined in conf/configuration_of_regionsV.csv.
  #
  # Return
  # ------
  # - versionOfAncillary: String, e.g. "v3.1". Version of ancillary data associated to
  #   region.
  local objectId="$1"

  # Use awk to filter the CSV and extract column 21
  versionOfAncillary=$(awk -F',' -v obj="$objectId" '($19 == obj) {print $21}' "$regionConfFilePath" | head -1)
  echo "$versionOfAncillary"
}


# Script core.
########################################################################################
# Definition of regions.
########################################################################################
# If script submitted standalone for test.
if [ ! -v workingDirectory ]; then 
  workingDirectory=$(pwd)/
  printf "Working directory: ${workingDirectory}\n"
  printf "#############################################################################\n"
fi
#

# List of all big region ids.
########################################################################################

# Use awk to filter and extract, and pipe the output to mapfile
# mapfile -t reads the input line by line and stores it in the array
# < <(...) uses process substitution to provide the output of awk as input to mapfile
mapfile -t allBigRegionIds < <(awk -F',' '$2 == "bigRegion" && $19 != "" {print $19}' "$regionConfFilePath")
  # NB: mapfile() requires bash 4.+.

# String list of tile object ids associated to all big region ids.
########################################################################################
declare -A regionIdsPerBigRegion
for bigRegionId in "${allBigRegionIds[@]}"; do
  # Use awk to filter column 20 by the current bigRegionId,
  # extract column 19 values, and join them with commas
  # -F',' sets the field delimiter to comma
  # -v search_id="$bigRegionId" passes the shell variable to awk
  # '$20 == search_id' filters rows where column 20 equals the search_id
  # '{print $19}' prints the value of column 19
  # The output of awk (newline-separated values) is piped to paste -sd',' to join with commas
  regionIdsPerBigRegion["$bigRegionId"]=$(awk -F',' -v search_id="$bigRegionId" '$20 == search_id {print $19}' "$regionConfFilePath" | paste -sd',')
done
regionIdsPerBigRegion[0]=0

# Region names for tiles and big regions.
declare -A allRegionNames
eval $(printf "$(cat $regionConfFilePath | grep -E "v3.1|v3.2" | grep -v Comment | grep -v comment | awk -F, '{ printf sep "allRegionNames[" $19 "]=" $1 ";\n" }')")
# Probably a simpler way than accumulate the greps...                              @todo

# First month of waterYear for tiles and big regions.
declare -A allFirstMonthOfWaterYear
eval $(printf "$(cat $regionConfFilePath | grep -E "v3.1|v3.2" | grep -v Comment | grep -v comment | awk -F, '{ printf sep "allFirstMonthOfWaterYear[" $19 "]=" $39 ";\n" }')")

# Big regions for tiles.
declare -A bigRegionForTile
eval $(printf "$(cat $regionConfFilePath)" | grep modisTile | grep -E "v3.1|v3.2" | awk -F, '{ printf sep "bigRegionForTile[" $19 "]=" $20 ";\n" }')
# Not clean way to do it, since configuration files can change columns. And eval is
# dirty...

# List of tiles per big regions.
declare -A tilesForBigRegion
thisTiles=( ${!bigRegionForTile[@]} )
thisTiles=($(echo ${thisTiles[@]} | tr ' ' '\n' | sort -n | tr '\n' ' '))
  # To sort the tiles (keys), which are not sorted when you use ${!bigRegionForTile[@]}
for thisTile in ${thisTiles[@]}; do
  thisBigRegion=${bigRegionForTile[${thisTile}]}
  if [[ ! -n ${thisBigRegion} ]]; then
    continue
  fi
  if [[ -n "${tilesForBigRegion[$thisBigRegion]}" ]]; then
    tilesForBigRegion[$thisBigRegion]=${tilesForBigRegion[$thisBigRegion]},${thisTile}
  else
    tilesForBigRegion[$thisBigRegion]=${thisTile}
  fi
done
# -n string not empty (length <> 0)

# Land subdivisions per big region

# eval $(printf "$(cat ${workingDirectory}conf/configuration_of_landsubdivisions.csv)" | awk -F, '{ printf sep "bigRegionForSubdivision[" $2 "]=" $8 ";\n" }'  | grep -v "=;" | tail -n +3)

subdivisionsByRegionString=$(cat ${workingDirectory}conf/configuration_of_landsubdivisions.csv | awk -F, '{ printf sep "" $8 ":" $2 ":" $12 ";\n" }' | grep -E "^[^:].*" | grep -E "\:[^0];" | tail -n +3)

declare -A countOfSubdivisionsPerBigRegion
for bigRegionId in {1..10}; do
  countOfSubdivisionsPerBigRegion[${bigRegionId}]=$(printf "${subdivisionsByRegionString}" | grep -E "^"${bigRegionId}"\:" | wc -l)
done

#cat ${workingDirectory}conf/configuration_of_landsubdivisions.csv | awk -F, '{ printf sep "bigRegionForSubdivision[" $2 "]=" $8 ";\n" }' | grep -v "=;" | tail -n +3


