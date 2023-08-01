classdef WaterYearDate < handle
% Handles the dates for ESP, in particular the several-month
% window to calculates some variables and statistics
    properties        
        firstMonth = 10; % SIER_288. Possibility to change first month of 
            % wateryear to 7 (south hemisphere). This should be a constant, and we may
            % tryhave an inherited south hemisphere waterYearDate, but unfortunately
            % constant properties are not editable in inherited classes and inheritance
            % here is not advantageous since except the first date of the waterYear
            % everything else remains the same.
        monthWindow = 3; % Int [1-12]. Number of months over which to
                        % recalculate variables or stats.
        overlapOtherYear = 0; % 1: overlap possible for interpolation. 0: not possible. 
                            % SIER_365.
        thisDatetime    % datetime of the object        
    end
    properties(Constant) 
        dayStartTime = struct('HH', 12, 'MIN', 0, 'SS', 0);
        defaultFirstMonthForNorthTiles = 10;
        defaultFirstMonthForSouthTiles = 7;
        monthFirstDay = 1;
        cubeMonthWindow = 3;
        yearMonthWindow = 12;
    end
    methods(Static)
 %{
        function waterYearDates = getWaterYearDateRangeBetweenWYDates(...
            startWaterYearDate, endWaterYearDate)
            % NB: Currently unused, but might be used in the future          @deprecated
            % Construct an array of WaterYearDates that cover the period between two
            % waterYearDates
            %
            % NB:
            % - only one solution is proposed among several possible arrays
            % - this method was designed to introduce writeGeotiffs in updateMosaicFor
            %   without performing big modifications of the updateMosaicFor (which are
            %   probably necessary in the future because the management of dates is not
            %   uniform from one script to the other)
            %
            % Parameters
            % ----------
            % startWaterYearDate: WaterYearDate
            %   First date
            % endWaterYearDate: WaterYearDate
            %   End date
            %
            % Return
            % ------
            % waterYearDates: array(WaterYearDates)
            %   WaterYearDates between first date and last date
            %   which allow to fully cover the period

            % Construct all the waterYearDates until the waterYear of
            % endWaterYearDate included
            idx = 1;
            waterYearDates(idx) = startWaterYearDate.getLastWYDateOfWaterYear();
            while waterYearDates(idx).getWaterYear() ~= endWaterYearDate.getWaterYear()
                waterYearDates(idx + 1) = WaterYearDate( datetime( ...
                    waterYearDates(idx).getWaterYear() + 1, ...
                    WaterYearDate.waterYearLastMonth, ...
                    WaterYearDate.waterYearLastDay), 12);
                idx = idx + 1;
            end

            % Correct the last WaterYearDate to fit endWaterYearDate
            monthWindow = WaterYearDate.getMonthWindowFromMonths(...
                WaterYearDate.firstMonth, ...
                month(endWaterYearDate.thisDatetime));
            waterYearDates(idx) = WaterYearDate(endWaterYearDate.thisDatetime, monthWindow);
        end
%}
        function lastWYDateForWaterYear = getLastWYDateForWaterYear(waterYear, ...
            firstMonth, monthWindow)
            % Parameters
            % ----------
            % waterYear: int.
            % firstMonth: int[1-12]. First month of the waterYear.
            % monthWindow: int[1-12], optional. Extent of the waterYearDate in months. 
            %
            % Return
            % ------
            % lastWYDateForWaterYear: WaterYearDate.
            %   Last WaterYearDate for a waterYear.
            if ~exist('monthWindow', 'var')
                monthWindow = WaterYearDate.yearMonthWindow;
            end
            lastWYDateForWaterYear = WaterYearDate(datetime(waterYear + 1, ...
                firstMonth, WaterYearDate.monthFirstDay, ...
                WaterYearDate.dayStartTime.HH, WaterYearDate.dayStartTime.MIN, ...
                WaterYearDate.dayStartTime.SS) - caldays(1), firstMonth, monthWindow);
        end
        function [thisYear, thisMonth] = getYearMonthFromWaterYearNegativeMonth( ...
            waterYear, month)
            % Subtraction of the monthly window to dates lead to negative months. These
            % months correspond to the part of the waterYear befor the start of the
            % calendar year. This function correct the negative months to their calendar
            % values and do the same for years.
            %
            % Parameters
            % ----------
            %
            % Return
            % ------
            % thisYear: int
            %   Calendar year
            % thisMonth: int
            %   Calendar month
            thisYear = waterYear;
            thisMonth = month;
            if month <= 0
                thisMonth = 12 + month;
                thisYear = waterYear - 1;
            end
        end
        function [waterYearDate, trailingMonthStatus] = ...
            getWaterYearDateForInterpAndTrailingStatus(thisDate, firstMonth, ...
            monthWindow)
            % Parameters
            % ----------
            % thisDate: datetime. For which we want the set of months. Should be 1st of
            %   the month.
            % firstMonth: int[1-12]. First month of the waterYear.
            % monthWindow: int[1-12], optional. Window over which interpolation will be
            % done.
            %
            % Return
            % ------
            % waterYearDate: WaterYearDate. Covers the 2 to 3-month period over which
            %   the temporal interpolation will be done for the month related to
            %   thisDate. Centered by default around the month of thisDate. If ongoing
            %   month, waterYearDate doesn't include the future month. If January of
            %   this year and we are in Jan or Feb, monthStatus = trailing,
            %   waterYearDate covers the ongoing month + the two previous months.
            % trailingMonthStatus: uint8. 'trailing' or 'centered'. Presently, 
            %   only january can be trailing in some specific cases
            %
            % NB: Code refactored from ESPEnv.rawFilesFor3months().           
            if ~exist('monthWindow', 'var')
                monthWindow = WaterYearDate.cubeMonthWindow;
            end
            % Cases trailing or centered without the subsequent month.
            if (1 == month(thisDate) && year(thisDate) == year(datetime("today")) ...
                && month(datetime("today")) < 3)
                waterYearDate = WaterYearDate(thisDate, firstMonth, monthWindow);
                trailingMonthStatus = 'trailing';
            elseif (month(thisDate) == month(datetime("today")) && ...
                year(thisDate) == year(datetime("today")))
                waterYearDate = WaterYearDate(thisDate, firstMonth, monthWindow - 1);
                trailingMonthStatus = 'centered';
            % Default case: centered.
            else
                thisDatePlusOneMonth = thisDate + calmonths(1);
                waterYearDate = WaterYearDate(datetime(year(thisDatePlusOneMonth), ...
                    month(thisDatePlusOneMonth), eomday(year(thisDatePlusOneMonth), ...
                    month(thisDatePlusOneMonth))), firstMonth, monthWindow);
                trailingMonthStatus = 'centered';
            end

            % Permit the possibility to overlap on the previous/subsequent
            % year for interpolation.
            waterYearDate.overlapOtherYear = 1;
        end
    end

    methods
        function obj = WaterYearDate(thisDatetime, firstMonth, monthWindow)
            % WaterYearDate constructor
            % NB: datetimes are forced to obj.dayStartTime.HH, .MIN, .SS
            %
            % Parameters
            % ----------
            % thisDatetime: datetime, optional.
            %   Date to handle.
            % firstMonth: int, optional.
            %   First month of the waterYear (10 in northern hemisphere, 7 in south).
            % monthWindow: int, optional.
            %   Number of months to handle before thisDatetime, knowing
            %   that only the months of the water year associated with
            %   thisDatetime will be handled.
            
            if ~exist('thisDatetime', 'var')
                thisDatetime = datetime('today');
            end
            
            % Cap to Yesterday. No calculations for the future right now.
            % SIER_245 we handle all dates of waterYearDate until the day before today
            % if last month = today's month.
            % NB: Has it an impact for the early data in 2000?
            if thisDatetime >= datetime('today')
                thisDatetime = datetime('today') - caldays(1);
            end

            [thisYYYY, thisMM, thisDD] = ymd(thisDatetime);
            obj.thisDatetime = datetime(thisYYYY, thisMM, thisDD, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
            if exist('firstMonth', 'var') & firstMonth <= 12
                obj.firstMonth = firstMonth;
            end
            if exist('monthWindow', 'var') & monthWindow <= 12
                obj.monthWindow = monthWindow;
            end
            fprintf('%s: WaterYearDate: %s, firstMonth %d, monthWindow: %d.\n', ...
                mfilename(), string(obj.thisDatetime, 'yyyyMMdd'), ...
                obj.firstMonth, obj.monthWindow);
        end
        function dateRange = getDailyDatetimeRange(obj)
            % Return
            % ------
            % dateRange: range(datetime)
            %   Get the arrays of dates to handle for daily file selection
            %   and variable and stat calculations
            monthWindow = obj.monthWindow;
            [thisYYYY, thisMM, thisDD] = ymd(obj.thisDatetime);

            % 1. Cap the monthWindow to the starting month of the year (oct)
            % except if overlap on other year is permitted.
            % NB: should rather be in constructor, impact?            @todo
            if ~obj.overlapOtherYear
                monthCountSinceWaterYearFirstMonth = ...
                    obj.getMonthWindowFromMonths( ...
                        obj.firstMonth, thisMM);
                monthWindow = min(monthWindow, monthCountSinceWaterYearFirstMonth);
            end

            % 2. Determining the first date of the range
            firstMonthOfTheRange = thisMM - monthWindow + 1;
            firstYear = thisYYYY;
            if firstMonthOfTheRange <= 0
                firstMonthOfTheRange = 12 + firstMonthOfTheRange;
                firstYear = firstYear - 1;
            end
            firstDate = datetime(firstYear, firstMonthOfTheRange, obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
            if firstDate > obj.thisDatetime %when monthWindow == 0
                firstDate = obj.thisDatetime;
            end

            dateRange = firstDate:obj.thisDatetime;
        end
        
        function firstDatetimeOfWaterYear = getFirstDatetimeOfWaterYear(obj)
            % Return
            % ------
            % firstDateOfWaterYear: datetime.
            %   First date of the wateryear of the current waterYearDate.
            
            % Northern Hemisphere. Adapt for Southern Hemisphere @todo
            yearForFirstDate = obj.getWaterYear() - 1;            
            firstDatetimeOfWaterYear = datetime(yearForFirstDate, ...
                obj.firstMonth, ...
                obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
        end

        function lastDayWaterYearDate = getLastWYDateOfWaterYear(obj)
            % Return
            % ------
            % lastDayWaterYearDate: WaterYearDate.
            %   Yields the WaterYearDate for the last day of the water year
            %   linked to the waterYearDate argument,
            %   with a monthWindow from the waterYearDate argument to the resulting
            %   last day.
            waterYear = obj.getWaterYear();
            monthWindow = obj.monthWindow - 1 + ...
                obj.getMonthWindowFromMonths( ...
                month(obj.thisDatetime), obj.getWaterYearLastMonth());
            lastDayWaterYearDate = WaterYearDate(datetime(waterYear + 1, ...
                obj.firstMonth, ...
                obj.monthFirstDay) - caldays(1), obj.firstMonth, monthWindow);
        end

        function monthRange = getMonthlyFirstDatetimeRange(obj)
            % Return
            % monthRange: range(datetime)
            %   Get the arrays of dates (first day of month) separated by
            %   calendar months to handle for monthly file selection and
            %   variable calculations
            %   e.g. 10/01/2021, 11/01/2021, 12/01/2021

            dateRange = obj.getDailyDatetimeRange();
            firstMonthDate = datetime(year(dateRange(1)), month(dateRange(1)), ...
                obj.monthFirstDay);
            lastMonthDate = datetime(year(dateRange(end)), month(dateRange(end)), ...
                obj.monthFirstDay);
            monthRange = firstMonthDate:calmonths(1):lastMonthDate;
        end
        function monthWindow = getMonthWindowFromMonths(obj, startMonth, endMonth)
            % NB: Cap the start of the window to the first month of the waterYear
            %
            % Parameters
            % ----------
            % startMonth: int.
            %   start month of the window.
            % endMonth: int.
            %   end month of the window.
            %
            % Return
            % ------
            % monthWindow: int.
            % the number of months separating start and endMonth
            %
            % NB: this method should be static, but is not because the firstMonth is
            %   not a constant (depends on the location of the region).

            % Cap the start of the window to the first month of the waterYear
            if startMonth < obj.firstMonth & ...
                endMonth >= obj.firstMonth
                startMonth = obj.firstMonth;
            end

            monthWindow = endMonth - startMonth + 1;
            if monthWindow <= 0
                monthWindow = monthWindow + 12;
            end
        end
        function waterYear = getWaterYear(obj)
            % Gets the WaterYear associated with the date
            [waterYear, thisMonth, ~] = ymd(obj.thisDatetime);
            if thisMonth >= obj.firstMonth
                waterYear = waterYear + 1;
            end
        end
        function lastMonth = getWaterYearLastMonth(obj)
            % Return
            % ------
            % lastMonth: int. Last month of the waterYear associated to this object.
            lastMonth = obj.firstMonth - 1;
            if month <= 0
                lastMonth = 12 + lastMonth;
            end
        end
    end
end
