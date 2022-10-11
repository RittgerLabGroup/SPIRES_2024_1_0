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
        dayStartTime = struct('HH', 12, 'MIN', 0, 'SS', 0);
        defaultMonthWindow = 3;
    end
    
    methods
        function obj = WaterYearDate(thisDatetime, monthWindow)
            % WaterYearDate constructor
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
        
        function waterYear = getWaterYear(obj)
            % Gets the WaterYear associated with the date
            [waterYear, thisMonth, ~] = ymd(obj.thisDatetime);
            if thisMonth >= obj.waterYearFirstMonth
                waterYear = waterYear + 1;
            end
        end
        
        function dateRange = getDailyDatetimeRange(obj)
            % Get the arrays of dates to handle for daily file selection
            % and variable and stat calculations
            monthWindow = obj.monthWindow;
            [thisYYYY, thisMM, thisDD] = ymd(obj.thisDatetime);
            
            % 1. Determining the last date of the range
            % Last month: from the 1st of the month 12:00 to the day 
            % of thisDatetime 12:00
            lastDate = datetime(thisYYYY, thisMM, thisDD, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);
            
            if thisDD ~= obj.monthFirstDay
                monthWindow = monthWindow - 1;
            end
            
            % 2. Months before: capped to the starting month of the year (oct)
            monthCountSinceWaterYearFirstMonth = thisMM - obj.waterYearFirstMonth;
            if thisMM < 10
                monthCountSinceWaterYearFirstMonth = ...
                    monthCountSinceWaterYearFirstMonth + 12;
            end

            monthWindow = min(monthWindow, monthCountSinceWaterYearFirstMonth);

            % 3. Determining the first date of the range
            firstMonth = thisMM - monthWindow;
            firstYear = thisYYYY;
            if firstMonth < 0
                firstMonth = 12 + firstMonth;
                firstYear = firstYear - 1;
            end
            firstDate = datetime(firstYear, firstMonth, obj.monthFirstDay, ...
                obj.dayStartTime.HH, obj.dayStartTime.MIN, ...
                obj.dayStartTime.SS);

            dateRange = firstDate:lastDate;
        end

        function monthRange = getMonthlyFirstDatetimeRange(obj)
            % Get the arrays of dates (first day of month) separated by
            % calendar months to handle for monthly file selection and
            % variable calculations
            % e.g. 10/01/2021, 11/01/2021, 12/01/2021

            dateRange = obj.getDailyDatetimeRange();
            firstMonthDate = datetime(year(dateRange(1)), month(dateRange(1)), 1);
            lastMonthDate = datetime(year(dateRange(end)), month(dateRange(end)), 1);
            monthRange = firstMonthDate:calmonths(1):lastMonthDate;
        end
    end
end