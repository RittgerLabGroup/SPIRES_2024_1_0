classdef WaterYearDate
% Handles the dates for ESP, in particular the several-month
% window to calculates some variables and statistics
    properties
        thisDatetime    % datetime of the object
        monthWindow     % Int [1-12]. Number of months over which to
                        % recalculate variables or stats.
    end
    properties(Constant)
        waterYearFirstMonth = 10;
        monthFirstDay = 1;
        waterYearLastMonth = 9;
        waterYearLastDay = 30;
        dayStartTime = struct('HH', 12, 'MIN', 0, 'SS', 0);
        defaultMonthWindow = 3;
    end

    methods(Static)
        function monthWindow = getMonthWindowFromMonths(startMonth, endMonth)
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

            % Cap the start of the window to the first month of the waterYear
            if startMonth < WaterYearDate.waterYearFirstMonth & ...
                endMonth >= WaterYearDate.waterYearFirstMonth
                startMonth = WaterYearDate.waterYearFirstMonth;
            end

            monthWindow = endMonth - startMonth + 1;
            if monthWindow <= 0
                monthWindow = monthWindow + 12;
            end
        end

        function waterYearDates = getWaterYearDateRangeBetweenWYDates(...
            startWaterYearDate, endWaterYearDate)
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
                WaterYearDate.waterYearFirstMonth, ...
                month(endWaterYearDate.thisDatetime));
            waterYearDates(idx) = WaterYearDate(endWaterYearDate.thisDatetime, monthWindow);
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

            %
            thisYear = waterYear;
            thisMonth = month;
            if month <= 0
                thisMonth = 12 + month;
                thisYear = waterYear - 1;
            end
        end
    end

    methods
        function obj = WaterYearDate(thisDatetime, monthWindow)
            % WaterYearDate constructor
            % NB: datetimes are forced to obj.dayStartTime.HH, .MIN, .SS
            %
            % Parameters
            % ----------
            % thisDatetime: datetime, optional
            %   Date to handle
            % monthWindow: int, optional
            %   Number of months to handle before thisDatetime, knowing
            %   that only the months of the water year associated with
            %   thisDatetime will be handled
            if ~exist('thisDatetime', 'var')
                thisDatetime = datetime;
            end
            if ~exist('monthWindow', 'var')
                monthWindow = obj.defaultMonthWindow;
            end

            [thisYYYY, thisMM, thisDD] = ymd(thisDatetime);
            obj.thisDatetime = datetime(thisYYYY, thisMM, thisDD, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
            obj.monthWindow = monthWindow;
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
            monthCountSinceWaterYearFirstMonth = ...
                WaterYearDate.getMonthWindowFromMonths( ...
                    WaterYearDate.waterYearFirstMonth, thisMM);
            monthWindow = min(monthWindow, monthCountSinceWaterYearFirstMonth);

            % 2. Determining the first date of the range
            firstMonth = thisMM - monthWindow + 1;
            firstYear = thisYYYY;
            if firstMonth <= 0
                firstMonth = 12 + firstMonth;
                firstYear = firstYear - 1;
            end
            firstDate = datetime(firstYear, firstMonth, obj.monthFirstDay, ...
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
            yearForFirstDate = obj.getWaterYear();
            if month(obj.thisDatetime) >= obj.waterYearFirstMonth
                yearForFirstDate = obj.getWaterYear() - 1;
            end
            firstDatetimeOfWaterYear = datetime(yearForFirstDate, ...
                obj.waterYearFirstMonth, ...
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
            %   with a monthwindow from the waterYearDate argument to the resulting
            %   last day.
            waterYear = obj.getWaterYear();
            monthWindow = obj.monthWindow - 1 + ...
                WaterYearDate.getMonthWindowFromMonths( ...
                month(obj.thisDatetime), WaterYearDate.waterYearLastMonth);
            lastDayWaterYearDate = WaterYearDate(datetime(waterYear, ...
                WaterYearDate.waterYearLastMonth, ...
                WaterYearDate.waterYearLastDay), monthWindow);
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

        function waterYear = getWaterYear(obj)
            % Gets the WaterYear associated with the date
            [waterYear, thisMonth, ~] = ymd(obj.thisDatetime);
            if thisMonth >= obj.waterYearFirstMonth
                waterYear = waterYear + 1;
            end
        end
    end
end
