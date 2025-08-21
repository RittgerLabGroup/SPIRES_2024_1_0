#!/bin/bash
#
# Functions handling dates and waterYearDates.

# NB: ${thisEnvironment} should be defined. In classic operations, it is done in
# toolsStart.sh.
if [[ -z $defaultIFS ]]; then 
  defaultIFS=$' \t\n'
fi

########################################################################################
# Functions.
########################################################################################
is_valid_date(){
  # Check if a date is valid
  #
  # Parameters
  # ----------
  # - thisDate: String, e.g. 2024-13-30.
  #
  # Return
  # ------
  # - isValidDate: Int, 1 if valid, 0 if invalid.

  thisDate="$1"
  [[ "$thisDate" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && date -d "$thisDate" >/dev/null 2>&1 && echo 1 || echo 0
}

is_valid_water_year_date(){
  # Check if a waterYearDate string is valid
  #
  # Parameters
  # ----------
  # - waterYearDate: String, e.g. 2024-13-30-02.
  #
  # Return
  # ------
  # - isValidWaterYearDate: Int, 1 if valid, 0 if invalid.
  thisWaterYearDateString="$1"
  waterYearDateArray=(${waterYearDateString//-/ })
  thisYear=${waterYearDateArray[0]}
  thisMonth=${waterYearDateArray[1]}
  thisDay=${waterYearDateArray[2]}
  monthWindow=${waterYearDateArray[3]}
  [[ $(is_valid_date "${thisYear}-${thisMonth}-${thisDay}") -eq 1 && "${monthWindow}" =~ ^[0-9]+$ && "${monthWindow}" -ge 0 && "${monthWindow}" -le 12 ]] && echo 1 || echo 0
}

is_water_year_date_in_the_past(){
  # Check if a waterYearDate string is not today or later.
  #
  # Parameters
  # ----------
  # - waterYearDate: String, e.g. 2024-13-30-02.
  #
  # Return
  # ------
  # - isWaterYearDateInThePast: Int, 1 if in the past, 0 if today or in the future.
  thisWaterYearDateString="$1"
  waterYearDateArray=(${waterYearDateString//-/ })
  thisYear=${waterYearDateArray[0]}
  thisMonth=${waterYearDateArray[1]}
  thisDay=${waterYearDateArray[2]}
  [[ $(is_valid_water_year_date "${thisWaterYearDateString}") -eq 1 && ! "${thisYear}-${thisMonth}-${thisDay}" > $(date +%Y%m%d) ]] && echo 1 || echo 0
}
