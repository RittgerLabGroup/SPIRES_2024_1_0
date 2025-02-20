classdef WaterYearDate < handle
% Handles the dates for ESP, in particular the several-month
% window to calculates some variables and statistics
    properties
        % NB: this class has a copy method to update if update properties here.
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
        dateOfToday % datetime of the date which is considered today, allows
            % handling of stop of data supply by JPL or DAAC for more than 1 month 2023-11-07.
            % this property value can be changed manually in scripts.
    end
    properties(Constant)
        dayStartTime = struct('HH', 12, 'MIN', 0, 'SS', 0);
        defaultFirstMonthForNorthTiles = 10;
        defaultFirstMonthForSouthTiles = 4; % 7 for New Zealand, dev a new call    @todo
        fakeDate = datetime(1, 1, 1);
        maxDaysByYear = 366;
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
        function dayInWaterYear = getDayInWaterYear(thisDate, firstMonthOfWaterYear)
            % Parameters
            % ----------
            % thisDate: datetime. For which the day number will be given. E.g.
            %   2024-01-02 will give 94 for region h08v04.
            % firstMonthOfWaterYear: int. E.g. 10 for westernUS.
            %
            % Return
            % ------
            % dayInWaterYear: int. from 1 to 366.
            waterYear = WaterYearDate.getWaterYearFromDate(thisDate, ...
              firstMonthOfWaterYear);
            dayInWaterYear = daysact( ...
                datetime(waterYear - 1, firstMonthOfWaterYear, ...
                WaterYearDate.monthFirstDay) - 1, ...
                dateshift(thisDate, start = 'day'));
                % Floor because daysact can give decimal numbers if times are different.
        end
        function countOfDayInWaterYear = getCountOfDayInWaterYear(thisDate, ...
            firstMonthOfWaterYear)
            % Parameters
            % ----------
            % firstMonthOfWaterYear: int. E.g. 10 for westernUS.
            %
            % Return
            % ------
            % countOfDayInWaterYear: int. 365 or 366.
            waterYear = WaterYearDate.getWaterYearFromDate(thisDate, ...
              firstMonthOfWaterYear);
            lastMonth = min(max(firstMonthOfWaterYear - 1, 0), 12);
            lastDate = datetime(waterYear, lastMonth, eomday(waterYear, lastMonth));
            firstDate = datetime(waterYear - 1, firstMonthOfWaterYear, ...
                WaterYearDate.monthFirstDay);
            countOfDayInWaterYear = floor(daysact(firstDate, lastDate)) + 1;
                % Floor because daysact can give decimal numbers if times are different.
        end
        function thisDate = getDateAdjusted(thisDate)
          % Parameters
          % ----------
          % thisDate: datetime. Date to set to noon.
          % Return
          % ------
          % thisDate: datetime. Date set at noon.
          thisDate = datetime(year(thisDate), month(thisDate), day(thisDate), ...
              WaterYearDate.dayStartTime.HH, ...
              WaterYearDate.dayStartTime.MIN, WaterYearDate.dayStartTime.SS);
        end
        function thisDate = getDateForToday()
          % Return
          % ------
          % thisDate: datetime. Today set at noon.
          thisDate = datetime('today') + duration(WaterYearDate.dayStartTime.HH, ...
              WaterYearDate.dayStartTime.MIN, WaterYearDate.dayStartTime.SS);
        end
        function lastWYDateForWaterYear = getLastWYDateForWaterYear(waterYear, ...
            firstMonth, monthWindow, varargin)
            % Parameters
            % ----------
            % waterYear: int.
            % firstMonth: int[1-12]. First month of the waterYear.
            % monthWindow: int[1-12], optional. Extent of the waterYearDate in months.
            % dateOfToday: datetime, optional. Force the date of today to a specific
            %   date, mainly for testing purposes (new website, debug).
            %
            % Return
            % ------
            % lastWYDateForWaterYear: WaterYearDate.
            %   Last WaterYearDate for a waterYear.
            %
            % NB/WARNING: We suppose that the waterYear is ALWAYS the year of the
            %   last WaterYearDate.
            % NB: sometimes waterYearDate is in the future, but the range of dates
            % returned by methods are always in the past.
            if ~exist('monthWindow', 'var')
                monthWindow = WaterYearDate.yearMonthWindow;
            end
            
            p = inputParser;
            addParameter(p, 'dateOfToday', datetime('today'));
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            dateOfToday = p.Results.dateOfToday;
            
            lastWYDateForWaterYear = WaterYearDate(datetime(waterYear, ...
                firstMonth, WaterYearDate.monthFirstDay, ...
                WaterYearDate.dayStartTime.HH, WaterYearDate.dayStartTime.MIN, ...
                WaterYearDate.dayStartTime.SS) - caldays(1), firstMonth, ...
                monthWindow, dateOfToday = dateOfToday);
        end
        function waterYear = getWaterYearFromDate(thisDate, firstMonthOfWaterYear)
            % Parameters
            % ----------
            % thisDate: datetime. For which the day number will be given. E.g.
            %   2024-01-02 will give 94 for region h08v04.
            % firstMonthOfWaterYear: int. E.g. 10 for westernUS.
            %
            % Return
            % ------
            % waterYear: int.  WaterYear associated with the date and region.
            [waterYear, thisMonth, ~] = ymd(thisDate);
            waterYear = cast(waterYear, 'uint16');
            if thisMonth >= firstMonthOfWaterYear
                waterYear = waterYear + 1;
            end
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
            getWaterYearDateForInterpAndTrailingStatus(thisDate, monthWindow, ...
            referenceWaterYearDate)
            % Parameters
            % ----------
            % thisDate: datetime. For which we want the set of months. Should be 1st of
            %   the month.
            % monthWindow: int[1-12], optional. Window over which interpolation will be
            %   done.            %
            % referenceWaterYearDate: WaterYearDate, that allows to get the first month
            %   of the waterYear and the date of today (which can be changed to take
            %   into account stop of data supply by JPL or DAAC 2023-11-07.
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
            if (1 == month(thisDate) && year(thisDate) == ...
                    year(referenceWaterYearDate.dateOfToday) ...
                && month(referenceWaterYearDate.dateOfToday) < 3)
                waterYearDate = WaterYearDate(thisDate, ...
                    referenceWaterYearDate.firstMonth, monthWindow);
                trailingMonthStatus = 'trailing';
            elseif (month(thisDate) == month(referenceWaterYearDate.dateOfToday) && ...
                year(thisDate) == year(referenceWaterYearDate.dateOfToday))
                waterYearDate = WaterYearDate(thisDate, ...
                    referenceWaterYearDate.firstMonth, monthWindow - 1);
                trailingMonthStatus = 'centered';
            % Default case: centered.
            else
                thisDatePlusOneMonth = thisDate + calmonths(1);
                waterYearDate = WaterYearDate(datetime(year(thisDatePlusOneMonth), ...
                    month(thisDatePlusOneMonth), eomday(year(thisDatePlusOneMonth), ...
                    month(thisDatePlusOneMonth))), ...
                    referenceWaterYearDate.firstMonth, monthWindow);
                trailingMonthStatus = 'centered';
            end

            % Permit the possibility to overlap on the previous/subsequent
            % year for interpolation.
            waterYearDate.overlapOtherYear = 1;
        end
        function waterYearDate = getWYDateForToday(firstMonthOfWaterYear)
            % Parameters
            % ----------
            % firstMonthOfWaterYear: int, 1-12. 10 for north hemisphere, 4 for south.
            %
            % Return
            % ------
            % waterYearDate: WaterYearDate. Which has the last date the date of today.
            waterYearDate = WaterYearDate(WaterYearDate.getDateForToday(), ...
                firstMonthOfWaterYear, WaterYearDate.yearMonthWindow);
        end
    end

    methods
        function obj = WaterYearDate(thisDatetime, firstMonth, monthWindow, varargin)
            % WaterYearDate constructor
            % NB: datetimes are forced to obj.dayStartTime.HH, .MIN, .SS
            % NB: WaterYearDate are capped to today - 1 (no WaterYearDate covering
            % future.
            %
            % Parameters
            % ----------
            % thisDatetime: datetime.
            %   Date to handle.
            % firstMonth: int.
            %   First month of the waterYear (10 in northern hemisphere, 7 in south).
            % monthWindow: int.
            %   Number of months to handle before thisDatetime, knowing
            %   that only the months of the water year associated with
            %   thisDatetime will be handled.
            % dateOfToday: datetime, optional. Force the date of today to a specific
            %   date, mainly for testing purposes (new website, debug).
            % 
            % overlapOtherYear: int, optional. Default 0, no overlap with previous
            %   waterYear. 1: overlap possible with previous waterYear. That means that 
            %   if the ongoing waterYear has M months past and we asked N > M months of
            %   window, we don't cap M to N as we do when no overlap.
            % NB: thisDatetime may be in the future, depending on dateOfToday. In that
            % case, some functions only return the range of dates linked to the
            % WaterYearDate which are restricted to the past.                   @warning
            % NB: thisDatetime should be <= dateOfToday or at least belong to the
            % same waterYear (verif not implemented!!!).                        @warning
            %
            % NB: this class has a copy method, to update if you add properties.
            %

%{
            % A way to force waterYearDate goes to the end of the waterYear, even
            % if it's in the future.
            thisWaterYearDate = WaterYearDate.getLastWYDateForWaterYear( ...
                thisWaterYear, obj.region.getFirstMonthOfWaterYear(), 12, ...
                dateOfToday = ...
                datetime(thisWaterYear, obj.region.getFirstMonthOfWaterYear(), ...
                eomday(thisWaterYear, obj.region.getFirstMonthOfWaterYear())) + ...
                caldays(1));   
%}

%{
            % NB: A default waterYearDate covering today only can be generated with:
            modisData = MODISData(label = 'v2023.1', versionOfAncillary = 'v3.1');
            espEnv = ESPEnv(modisData = modisData);
            regionName = 'westernUS'; % we need this only for the water Year start.
            region = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
            waterYearDate = WaterYearDate(datetime('today'), ...
                espEnv.modisData.getFirstMonthOfWaterYear(region), 0);
%}
            
            p = inputParser;
            addParameter(p, 'dateOfToday', datetime('today'));
            addParameter(p, 'overlapOtherYear', 0);
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            
            [thisYYYY, thisMM, thisDD] = ymd(p.Results.dateOfToday);
            obj.dateOfToday = datetime(thisYYYY, thisMM, thisDD, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS); % 2023-11-07 following JPL stop.
                % .dateOfToday must be with same time as .thisDatetime for date range
                % calculations.

            [thisYYYY, thisMM, thisDD] = ymd(thisDatetime);
            obj.thisDatetime = datetime(thisYYYY, thisMM, thisDD, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
            obj.overlapOtherYear = p.Results.overlapOtherYear;
            
            % Cap to Yesterday. No calculations for the future right now.
            % SIER_245 we handle all dates of waterYearDate until the day before today
            % if last month = today's month.
            % NB: Has it an impact for the early data in 2000?
            if obj.thisDatetime >= obj.dateOfToday
                thatDatetime = obj.thisDatetime;
                obj.thisDatetime = obj.dateOfToday - caldays(1);
                % Correction of monthwindow if thisDatetime was corrected by
                % dateOfToday.
                if monthWindow > 1
                    thatDatetimeToFirst = dateshift(thatDatetime, 'start', 'month');
                    thatDateOfTodayToFirst = ...
                        dateshift(obj.dateOfToday, 'start', 'month');
                    % Remove the number of calendar months to window month.
                    calendarMonthlagBetweenDates = split(between( ...
                        thatDateOfTodayToFirst, thatDatetimeToFirst, 'months'), ...
                        'months');
                    monthWindow = max(monthWindow - calendarMonthlagBetweenDates, 1);
                end
            end

            if exist('firstMonth', 'var') & firstMonth <= obj.yearMonthWindow
                obj.firstMonth = firstMonth;
            end
            
            % monthWindow.
            [thisYYYY, thisMM, thisDD] = ymd(obj.thisDatetime);

            % Cap the monthWindow to the starting month of the year (oct)
            % except if overlap on other year is permitted.
            % NB: should rather be in constructor, impact?            @todo
            if ~obj.overlapOtherYear
                monthCountSinceWaterYearFirstMonth = ...
                    obj.getMonthWindowFromMonths( ...
                        obj.firstMonth, thisMM);
                obj.monthWindow = min(monthWindow, ...
                    monthCountSinceWaterYearFirstMonth);
            else
                obj.monthWindow = monthWindow;
            end
%{
            fprintf('%s: WaterYearDate: %s, firstMonth %d, monthWindow: %d.\n', ...
                mfilename(), obj.toChar(), ...
                obj.firstMonth, obj.monthWindow);
%}
        end
        function waterYearDate = copy(obj)
          % Copy and create a second WaterYearDate object.
          waterYearDate = WaterYearDate( ...
            obj.thisDatetime, obj.firstMonth, obj.monthWindow, ...
            dateOfToday = obj.dateOfToday, overlapOtherYear = obj.overlapOtherYear);
        end
        function dateRange = getDailyDatetimeRange(obj)
            % Return
            % ------
            % dateRange: range(datetime)
            %   Get the arrays of dates to handle for daily file selection
            %   and variable and stat calculations
            %
            % NB: only give the dates in the past (and so is based on date of today).
            monthWindow = obj.monthWindow;
%{
            thisCorrectedDate = obj.thisDatetime;
            if thisCorrectedDate >= obj.dateOfToday
                thisCorrectedDate = obj.dateOfToday - days(1);
            end
            [thisYYYY, thisMM, thisDD] = ymd(thisCorrectedDate);
%}
            [thisYYYY, thisMM, thisDD] = ymd(obj.thisDatetime);
%{
            % 1. Cap the monthWindow to the starting month of the year (oct)
            % except if overlap on other year is permitted.
            % NB: should rather be in constructor, impact?            @todo
            if ~obj.overlapOtherYear
                monthCountSinceWaterYearFirstMonth = ...
                    obj.getMonthWindowFromMonths( ...
                        obj.firstMonth, thisMM);
                monthWindow = min(monthWindow, monthCountSinceWaterYearFirstMonth);
            end
%}
            % 2. Determining the first date of the range
            firstMonthOfTheRange = thisMM - monthWindow + 1;
            firstYear = thisYYYY;
            if firstMonthOfTheRange <= 0
                thatFactor = floor((obj.yearMonthWindow - firstMonthOfTheRange) / ...
                    obj.yearMonthWindow);
                firstMonthOfTheRange = thatFactor * obj.yearMonthWindow + ...
                    firstMonthOfTheRange;
                firstYear = firstYear - thatFactor * 1;
            end
            firstDate = datetime(firstYear, firstMonthOfTheRange, obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
%{
            if firstDate > thisCorrectedDate %when monthWindow == 0
                firstDate = thisCorrectedDate;
            end

            dateRange = firstDate:thisCorrectedDate;
%}
            if firstDate > obj.thisDatetime %when monthWindow == 0
                firstDate = obj.thisDatetime;
            end

            dateRange = firstDate:obj.thisDatetime;
        end
        function dayRange = getDayRange(obj)
            % Return
            % ------
            % dayRange: array(int)
            %   Get the arrays of days count since start of waterYear for each daily
            %   date of the waterYearDate obj. Used for stat calculations.
            % 
            % NB: can give negative days if overlapOtherYear = 1.               @warning
            dayRange = daysdif(obj.getFirstDatetimeOfWaterYear(), ...
                obj.getDailyDatetimeRange()) + 1;
        end
        function firstDatetimeOfWaterYear = getFirstDatetimeOfWaterYear(obj)
            % Return
            % ------
            % firstDateOfWaterYear: datetime.
            %   First date of the wateryear of the current waterYearDate.
            % NB: doesn't give the first datetime of the waterYearDate, which can
            % be before the first date of waterYear, if overlapOtherYear = 1.   @warning

            % Northern Hemisphere. Adapt for Southern Hemisphere @todo
            yearForFirstDate = obj.getWaterYear() - 1;
            firstDatetimeOfWaterYear = datetime(yearForFirstDate, ...
                obj.firstMonth, ...
                obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
        end
        function lastActualDateOfWaterYear = getLastActualDateOfWaterYear(obj)
            % Return
            % ------
            % lastActualDateOfWaterYear: datetime.
            %   Last date of the wateryear of the current waterYearDate, can go beyond
            %   today.
            lastActualDateOfWaterYear = datetime(obj.getWaterYear(), ...
                obj.firstMonth, ...
                obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS) - days(1);
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
        function nrtOrHist = getNrtOrHist(obj)
          % Return
          % ------
          % nrtOrHist: char. Nrt if dateOfToday has same water year as the waterYearDate
          %   object.
          nrtOrHist = 'nrt';
          if obj.getWaterYear() ~= obj.getWaterYearFromDate( ...
              obj.dateOfToday, obj.firstMonth)
              nrtOrHist = 'hist';
          end
        end
        function waterYear = getWaterYear(obj)
            % Gets the WaterYear associated with the date
            [waterYear, thisMonth, ~] = ymd(obj.thisDatetime);
            waterYear = cast(waterYear, 'uint16');
            if thisMonth >= obj.firstMonth
                waterYear = waterYear + 1;
            end
        end
        function lastMonth = getWaterYearLastMonth(obj)
            % Return
            % ------
            % lastMonth: int. Last month of the waterYear associated to this object.
            lastMonth = obj.firstMonth - 1;
            if lastMonth <= 0
                lastMonth = 12 + lastMonth;
            end
        end
        function waterYearDate = shortenToDate(obj, thisDate)
            % Parameters
            % ----------
            % thisDate: datetime, anterior to obj.thisDatetime but posterior to start
            % of obj, consistently with obj.monthWindow.
            %
            % Return
            % ------
            % waterYearDate: WaterYearDate obj. Corresponds to the same period as obj,
            % but shorten to thisDate.
            %
            % NB: Not tested for overlapping dates...                           @warning
            thisFunction = 'WaterYearDate.shortenToDate';
            theseDate = obj.getDailyDatetimeRange();
            thisDate = datetime(year(thisDate), month(thisDate), day(thisDate), ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, obj.dayStartTime.SS);
                % Some dates may be recorded not at 12:00 for older versions of code.
            if thisDate > theseDate(end) | thisDate < theseDate(1)
                warning('WaterYearDateShorten:badDate', ...
                    sprintf(['%s: Date %s should be included in the period covered', ...
                        ' by waterYearDate %s.\n'], thisFunction, ...
                        string(thisDate, 'yyyy-MM-dd'), obj.toChar()));
                waterYearDate = obj; 
                return;
            end
            waterYearDate = obj;
            if ~ismember(waterYearDate.monthWindow, [0, 1])
                waterYearDate.monthWindow = split(between(theseDate(1), ...
                    daysadd(dateshift(thisDate, start = 'month'), 5), 'months'), ...
                    {'months'}) + 1;
                % We add days to handle the different nb of days by month 30 31 29 28.
                % There's probably a smarter way to do it.
            end
            waterYearDate.thisDatetime = datetime(year(thisDate), month(thisDate), ...
                day(thisDate), obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
        end
        function waterYearDateChar = toChar(obj)
            % Return
            % ------
            % waterYearDateChar: char. Text corresponding to the waterYearDate, used
            %   in logs for instance.
            waterYearDateChar = [char(obj.thisDatetime, 'yyyy-MM-dd'), ...
                ' firstMonth: ', num2str(obj.firstMonth), ' monthWindow: ', ...
                num2str(obj.monthWindow)];
                % NB: num2str returns a char, not a string.
        end
    end
end
