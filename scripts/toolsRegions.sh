#!/bin/bash
#
# Initialize region parameters. SIER_345.

# Functions.
#---------------------------------------------------------------------------------------
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
    echo $((${horizontalFactor} * 36 + $(echo ${tileName} | cut -c 5-6)))
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


# Script core.
#---------------------------------------------------------------------------------------
tileGroups=(0 1 2 3 4)
tileGroupNames=("westernUS" "USAlaska" "ASHimalaya" "EURAlps" "AMAndes")

# Tile Array String to add as parameter for --array in sbatch job.
# westernUS: "h08v04" "h08v05" "h09v04" "h09v05" "h10v04"
tileArrayForTileGroup0=(h08v04 h08v05 h09v04 h09v05 h10v04)
tileArrayStringForTileGroup0="292,293,328,329,364"
# USAlaska: "h07v03" "h08v03" "h09v02" "h09v03" "h10v02" "h10v03" "h11v02" 
#   "h11v03" "h12v01" "h12v02" "h13v01" "h13v02"
tileArrayForTileGroup1=(h07v03 h08v03 h09v02 h09v03 h10v02 h10v03 h11v02 h11v03 h12v01 h12v02 h13v01 h13v02)
tileArrayStringForTileGroup1="255,291,326,327,362,363,398,399,433,434,469,470"
# ASHimalaya: "h22v04", "h22v05", "h23v04", "h23v05", "h23v06", "h24v04"
#       "h24v05", "h24v06", "h25v05", "h25v06", "h26v05", "h26v06"
tileArrayForTileGroup2=(h22v04 h22v05 h23v04 h23v05 h23v06 h24v04 h24v05 h24v06 h25v05 h25v06 h26v05 h26v06)
tileArrayStringForTileGroup2="796,797,832,833,834,868,869,870,905,906,941,942"
# EURAlps: "h18v04", "h19v04"
tileArrayForTileGroup3=(h18v04 h19v04)
tileArrayStringForTileGroup3="652,688"
# AMAndes: "h10v09", "h10v10", "h11v10", "h11v11", "h11v12", "h12v12", "h12v13",
#       "h13v13", "h13v14"
tileArrayForTileGroup4=(h10v09 h10v10 h11v10 h11v11 h11v12 h12v12 h12v13 h13v13 h13v14)
tileArrayStringForTileGroup4="369,370,406,407,408,444,445,481,482"
