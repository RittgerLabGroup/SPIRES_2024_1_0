#!/bin/bash
#
# Functions to get infos on jobs.

# Functions.
#---------------------------------------------------------------------------------------
# On Blanca, seff is not systematically found. We bypass this by a direct handling
# using sacct (2023-12-19).
get_time_in_seconds(){
    # Convert time string into seconds.
    # NB: probably not all cases included...                                    @warning
    # Parameters
    # ----------
    # $1: char. Time string. 1-04:02:03 or 04:02:03 or 02:03.254 only
    if [[ "$1" == *"-"* ]]; then
        # The string contains a day (and we suppose hours, mins, and secs without
        # decimals.
        echo $1 | sed 's/-/:/' | awk -F: '{ print $1 * 86400 + $2 * 3600 + $3 * 60 + $4 }'
    elif [[ "$1" == *"."* ]]; then
        # The string contains secs with decimals (and we suppose no day and no hour).
        echo $1 | awk -F: '{ print $1 * 60 + $2 }'
    else
        #We suppose that it's 00:00:00, but maybe more complicated?             @tocheck
        echo $1 | awk -F: '{ print $1 * 3600 + $2 * 60 + $3 }'
    fi
}

get_mem_in_Gb(){
    # Convert memory string into gigabytes value.
    # Parameters
    # ----------
    # $1: char. Memory string. value and a K M G T P E at the end (if kb, Mb, Gb, ...)
    fullValue=$1
    val=$(echo ${fullValue::-1})
    if [[ "$1" == *"K" ]]; then
        echo $(echo "scale=10; $val / 1024^2 " | bc)
        # NB: in bc power is ^ while in bash power is **.
    elif [[ "$1" == *"M" ]]; then
        echo $(echo "scale=10; $val / 1024^1 " | bc)
    elif [[ "$1" == *"G" ]]; then
        echo $(echo "scale=10; $val / 1024^0 " | bc)
    elif [[ "$1" == *"T" ]]; then
        echo $(echo "scale=10; $val * 1024^1 " | bc)
    elif [[ "$1" == *"P" ]]; then
        echo $(echo "scale=10; $val * 1024^2 " | bc)
    elif [[ "$1" == *"E" ]]; then
        echo $(echo "scale=10; $val * 1024^3 " | bc)
    fi
}
