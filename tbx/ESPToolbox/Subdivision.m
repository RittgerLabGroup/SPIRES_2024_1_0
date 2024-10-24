classdef Subdivision < handle
    % Centralize the calculations of statistics and aggregates aimed to the snow-today
    % website. These statistics are stored in a stat file (one per big region, all years
    % and subdivisions in it).
    %
    % NB: this class depends on the stability of the configuration_of_variables.csv and
    % configuration_of_landsubdivisions.csv and configuration_of_variableregions.csv and
    % configuration_of_variablesstats.csv and the subdivision masks and the version
    % of ancillary data. Regenerate all statistics for the subdivision if:
    %   - a variable has changed of id, output_name, type, no data, or write_csv and
    %   write_stats values (in conf of variables or conf of variables regions). TO CHECK !!!!!!!!!!!!!!
    %   - the subdivision mask has changed.
    %   - a new tile has been added/removed to the big region (new version of ancillary
    %   data required.
    %   - a subdivision has changed properties, has been added removed for the big region
    %   in configuration_of_landsubdivisions.csv.
    %
    % SIER_405: create this class to replace the runStatsForLinePlots.m script, not well
    %   optimized for the extension to new big regions (Alaska, Himalayas, Andes).
    % NB: I used the table class in matlab to store the stats, although the use is still
    %   a bit convoluted in matlab. Because some stat (e.g. percentile) are not
    %   available for tables, I handle a conversion into array to perform the
    %   aggregates (2023-09-07).
    % NB: I checked the possibility to store the stats in a sqlite database, but the
    %   current version of Matlab is still immature for an easy and clear
    %   implementation (2023-09-07).
    % NB: the Class handles the possible different versions of ancillary data v3.1 and
    %   v3.2 for tiles part of a subdivision, e.g. Canada (2023-09-30).
    %
    % NB: If a subdivision is on a unavailable tile, the data on that tile are put
    %   aside in the calculations. This happens for the start of v2024.0 spires
    %   westernUS.
    %
    % Possible evolutions: The generation of the historics takes time, we could generate
    %   from the stc rather than daily mosaics and we could generate in parallel one
    %   file per year and then merge them.                                       @tothink
%{
    % Use cases. Header.
    % ------------------
    scratchPath = ['/rc_scratch/', getenv('USER'), '/']; %'C:\Users\X\Documents\Tmp_data';
    modisData = MODISData(label = 'v2024.0d', versionOfAncillary = 'v3.1');
    espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath, ...
        filterMyConfByVersionOfAncillary = 0);
    espEnv.setAdditionalConf('landsubdivision');
        % IMPORTANT: the landsubdivision conf is not loaded by default!
        %
        % NB: within the methods, a copy of espEnv is created to handle the possible
        % different version of ancillary data for tiles, e.g. between h08v04 v3.1 and
        % h08v03 v3.2, both part of Canada (v3.2).
    espEnv.setAdditionalConf('variablestat');
    espEnv.setAdditionalConf('webname');
    regionName = 'westernUS'; % we need this only for the water Year start, without
        % which stats can't be calculated.
        % NB: for Canadian subdivisions, split between westernUS and USAlaska big
        % regions, we can use USAlaska as big region of the subdivision.
    subdivisionId = 11726; %26000; % corresponding to the subdivision westernUS (different from
        % the region westernUS, which has 0 as id in toolsRegions.sh and
        % 5 in configuration_of_regions.csv).
    region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);
    subdivision = Subdivision(subdivisionId, region);

    % Use case 1.
    % -----------
    waterYearDate = WaterYearDate(datetime(2024, 6, 7), ...
        region.getFirstMonthOfWaterYear(), 1);
    subdivision.calcDailyStats(waterYearDate);
    subdivision.writeStatCsvAndJson();

    % Use case 2.
    % -----------
    % Takes time ....
    espEnv.configParallelismPool(20);
    parfor waterYear = 2020:2022
        waterYearDate = WaterYearDate.getLastWYDateForWaterYear(waterYear, ...
            region.getFirstMonthOfWaterYear(), 12);
        subdivision.calcDailyStats(waterYearDate);
    end

    % Use case 3.
    % -----------
    % After generation of all the historic daily stats for the subdivision (Use case 2).
    % NB: here, we don't need to parameter filterMyConfByVersionOfAncillary = 0 for
    % espEnv.
    waterYearDate = WaterYearDate(datetime(2023, 1, 2), ...
        region.getFirstMonthOfWaterYear(), 1);
    subdivision.calcAggregates(waterYearDate);

    % Use case 4.
    % -----------
    % Once historic aggregates and daily calculations are done, we can generate
    % the csv and json file. (Another process calling ExporterToWebsite) will export
    % them to the website.
    % uncondensedJson = 1;
    % subdivision.writeStatCsvAndJson(uncondensedJson);
%}
    properties
        region  % Regions obj. Crucial only to determine the start of the waterYear.
        id  % Subdivision unique id.
    end
    properties(Constant)
        fakeWaterYearForGlobalStats = cast(1, 'uint16');
            % used in .calcStatsOverWaterYearRange() to be
            % stored in the rows of the stat file table (rather than storing 2000-2022
            % for instance).
    end
    methods
        function obj = Subdivision(id, region)
            % Parameters
            % ----------
            % id: int. Unique id of the subdivision. Indicated in
            % configuration_of_subdivisions.csv and present as values in the masks of
            % landsubdivisions
            % region: Regions obj.
            obj.id = id;
            obj.region = region;
        end
        function calcAggregates(obj, waterYearDate)
            % Calculate the statistical aggregates min, percentile 25, median/sum/mean,
            % percentile 75, max for each variable over the record period of
            % the sensor, for this subdivision,
            % and save them into a table and the stat file (same as the daily stat
            % file).
            %
            % Parameters
            % ----------
            % waterYearDate: WaterYearDate. WaterYearDate of the ongoing year, excluded
            %   from the aggregates.
            %
            % The structure of the table is defined in .calcDailyStats() method of this
            % class. WaterYear is set to 1 (arbitrary convention), and statId has a
            % value which description is in configuration_of_landsubdivisionstats.csv,
            % e.g. 7 for the year where the variable had a minimal value compared to
            % other years.
            % NB: If no daily stats have been calculated, the method will attribute 0
            % as value for all stats.
            % NB: The method calculates the stats for all required variables and for
            % the full previous period, except if no modification has been done on
            % the previous period. E.g., if a modification is done for the ongoing
            % 2023 waterYear and no modification done on previous years, the method
            % will let the stats as such. But if a modification has been done for 2022,
            % the method updates the full stats (for the lines corresponding to the full
            % period).
            %
            % NB: the stats are based on parametering of the variables in
            % configuration_of_variables.csv, id and landSubdivisionStatId. If this
            % parametering of these 2 columns changes, it is required to regenerate
            % all statistics from scratch.                                       @beware
            espEnv = obj.region.espEnv;
            dayRange = cast(1:WaterYearDate.maxDaysByYear, 'uint16');

            % Get all the daily data to calculate the aggregates.
            [statTableOrig, statFilePath] = obj.mergeDailyStatTables();
            statTable = statTableOrig( ...
                statTableOrig.waterYear < waterYearDate.getWaterYear(), :);
            varIds = unique(statTable.varId);
            allWaterYears = unique(statTable.waterYear);
            varConf = innerjoin(espEnv.myConf.variable( ...
                ismember(espEnv.myConf.variable.id, varIds), {'id', 'output_name'}), ...
                espEnv.myConf.variablestat(ismember( ...
                    espEnv.myConf.variablestat.landSubdivisionStatType, [2:5]), :), ...
                LeftKeys = 'id', RightKeys = 'varId', ...
                LeftVariables = {'id', 'output_name'}, ...
                RightVariables = {'landSubdivisionStatId', 'landSubdivisionStatType'});
            varConf = sortrows(varConf, {'id', 'landSubdivisionStatId', ...
                'landSubdivisionStatType'});
                % Temporary sort, adapted for filling below, and will be later resorted
                % by id, as in StatTable.
                % NB: This sort is very important to fill the table correctly.

            % Aggregate table fields.
            % Number of stats: var-stat couple x days
            % (median, percentile 25, percentile 75, value for min year, for max year,
            % and year of min and max).
            waterYear = repelem(obj.fakeWaterYearForGlobalStats, ...
                length(dayRange) * size(varConf, 1))';
            thisDay = repmat(dayRange', [size(varConf, 1), 1]);
            subdivisionId = repmat(cast(obj.id, 'uint16'), size(waterYear));
            varId = repelem(cast(varConf.id, 'uint8'), length(dayRange));
            statId = repelem(cast(varConf.landSubdivisionStatId, 'uint8'), ...
                length(dayRange));
            statValue = zeros(size(waterYear), 'single');
            fprintf( ...
                ['%s: Initialized table fields for aggregates of ', ...
                'subdivision %d.\n'], mfilename(), obj.id);

            % Stat calculations.
            % NB: unfortunately, matlab still doesn't offer possibility of grpstats for
            % median and percentile (2023-09-29) so we do it explicitly below. Note
            % that the 1D structure of stats increase execution time compared to
            % previous 2D structure which didn't require a loop over days. To see if
            % we can improve this although not urgent since it's not done daily.
            %                                                                      @todo
            fprintf(['%s: Calculating aggregates for subdivision %d, ' ...
                'over years %d to %d...\n'], mfilename(), obj.id, ...
                min(allWaterYears), max(allWaterYears));
            for varStatIdx = 1:size(varConf, 1)
                fprintf(['%s: Calculating aggregates for variable %d %s, ', ...
                    'stat %d...\n'], mfilename(), varConf.id(varStatIdx), ...
                    varConf.output_name{varStatIdx}, ...
                    varConf.landSubdivisionStatId(varStatIdx));
                % Determine if we have to calculate an aggregate per year.
                switch varConf.landSubdivisionStatId(varStatIdx)
                    case 20
                        aggregate = 'mean'; % mean of each year
                    case 21
                        aggregate = 'median'; % median of each year
                    case {22, 60}
                        aggregate = 'sum'; % sum of each year
                end
                % If necessary, calculate this aggregate.
                % NB: Really important that varConf is sorted in the order specified
                % above.
                tmpVarId = varConf.id(varStatIdx);
                    % variable on which min/max is calculated. For stats 60 and 70,
                    % which are supplied in v2023.1 csv and older, the variable is
                    % snow_fraction. Assumed to be 40 (don't change this value
                    % in conf file) we could also put this in a constant.          @todo
                if varConf.landSubdivisionStatId(varStatIdx) == 60
                    tmpVarId = 40;
                end
                % Determine the min and max year in function of the stat, mean, median
                % or sum.
                switch varConf.landSubdivisionStatId(varStatIdx)
                    case {20, 21, 22, 60}
                        thisDailyStatTable = statTable( ...
                            statTable.varId == tmpVarId, :);
                        aggregateOfDailyStatTable = ...
                            groupsummary(thisDailyStatTable, ...
                                'waterYear', aggregate, 'statValue');
                        aggregateFieldName = [aggregate, '_statValue'];
                        minYear = max(allWaterYears);
                        maxYear = max(allWaterYears);
                        if sum(~isnan(aggregateOfDailyStatTable.(aggregateFieldName)))
                            minYear = aggregateOfDailyStatTable( ...
                                aggregateOfDailyStatTable.(aggregateFieldName) == ...
                                min(aggregateOfDailyStatTable.(aggregateFieldName)), ...
                                    :).waterYear(1);
                            maxYear = aggregateOfDailyStatTable( ...
                                aggregateOfDailyStatTable.(aggregateFieldName) == ...
                                max(aggregateOfDailyStatTable.(aggregateFieldName)), ...
                                    :).waterYear(1);
                        end
                end
                % Calculate the stat for each julian day.
                for dayIdx = 1:length(dayRange)
                    thisDailyStatTable = statTable( ...
                        statTable.varId == varConf.id(varStatIdx) & ...
                        statTable.thisDay == dayIdx, :);
                    rowIdx = length(dayRange) * (varStatIdx - 1) + (dayIdx - 1) + 1;

                    if isempty(thisDailyStatTable)
                        % Shouldn't occur but who knows...
                        statValue(rowIdx) = 0;
                    else
                        % Calculate and fill the aggregate stat table.
                        switch varConf.landSubdivisionStatId(varStatIdx)
                            case 10
                                statValue(rowIdx) = ...
                                    median(thisDailyStatTable.statValue); % median.
                            case 11
                                statValue(rowIdx) = ...
                                    prctile(thisDailyStatTable.statValue, 25);
                                        % percentile 25.
                            case 12
                                statValue(rowIdx) = ...
                                    prctile(thisDailyStatTable.statValue, 75);
                                        % percentile 75.
                            case {20, 21, 22, 60}
                                statValue(rowIdx) = ...
                                    thisDailyStatTable.statValue( ...
                                        thisDailyStatTable.waterYear == maxYear);
                            case {30, 31, 32, 70}
                                statValue(rowIdx) = ...
                                    thisDailyStatTable.statValue( ...
                                        thisDailyStatTable.waterYear == minYear);
                            case {40, 41, 42}
                                statValue(rowIdx) = maxYear;
                            case {50, 51, 52}
                                statValue(rowIdx) = minYear;
                        end % switch
                    end % if
                end % dayIdx
            end % varStatIdx
            fprintf(['%s: Done aggregate calculations for subdivision ', ...
                '%d.\n'], mfilename(), obj.id);

            % Construct the table of additional record, merge
            % and save in daily stat .csv file associated to subdivision.
            updateDate = repmat(datetime('now'), size(waterYear));
            addStatTable = table(waterYear, thisDay, subdivisionId, varId, ...
                statId, statValue, updateDate);
            statTable = [statTableOrig; addStatTable];
            % Sort...
            statTable = sortrows(statTable, [1, 2, 3, 4, 5]);

            % Save in file...
            thisDate = '';
            varName = '';
            complementaryLabel = '';
            [statFilePath, ~, ~] = ...
                espEnv.getFilePathForDateAndVarName(obj.id, ...
                'SubdivisionStatsAggregCsv', thisDate, varName, complementaryLabel);
            writetable(statTable, statFilePath);
            fprintf( ...
                ['%s: Done and saved water year range stats for subdivision %d, ', ...
                'from %d to %d into %s.\n'], ...
                mfilename(), obj.id, min(allWaterYears), max(allWaterYears), ...
                statFilePath);
        end
        function calcDailyStats(obj, waterYearDate)
            % Calculate the daily stats for the subdivision, based on the data for each
            % modis tile in variables/scagdrfs_mat_vxx/ and on the diverse
            % landsubdivision masks available in the ancillary data. The results are
            % saved in a csv file containing all stats linked to the subdivision.
            %
            % NB: Filters/thresholds. This calculation takes into account filters given
            % in configuration_of_filters.csv. However, the current implementation has
            % several limits:
            % - only one value for elevation filter, or no elevation filter (represented
            % by the zero min value in the csv file.
            % - only snow_fraction as other filter. Different values are possible.
            % - the other configurations aren't taken into account in this code.
            % - it's important that the id of snow_fraction variable be smaller than the
            %   id of the filtered variables (in configuration_of_variables.csv).
            %   The code presently doesn't take into consideration the filter order
            %   indicated in the configuration_of_filters.csv.
            %
            % The daily stat table contains the fields: waterYear, thisDay (julian day),
            % subdivisionId (id of the subdivision, which description is in
            % configuration_of_landsubdivisions.csv, e.g. 26000 for westernUS),
            % varId (id of variable, description in configuration_of_variables.csv, e.g.
            % 40 for snow_fraction), statId (id of statistics, description in
            % configuration_of_landsubdivisionstats.csv, e.g. 3 for median), statValue
            % (the value of the statistic, calculated in this method), updateDate (the
            % date when the statistic was calculated).
            %
            % NB: having a 1-D storage format of stats, rather than a 2-D like in the
            % previous version runStatsForLinPlots.m might increase the time for the
            % calculations of global stats by .calcStatsOverWaterYearRange() but ease
            % further handling through a table software.
            %
            % NB: We should really store the real date of each daily stat, or a ref
            % to the first day of the waterYear.                                   @todo

            fprintf('%s: Initializing parameters for subdivision %d ...\n', ...
                mfilename(), obj.id);
            espEnv = obj.region.espEnv;
            tmpEspEnv = espEnv; % this tmp copy to shift between espEnv linked to
                % different versions of ancillary data, e.g. v3.1 or v3.2 for Canada.

            dateRange = waterYearDate.getDailyDatetimeRange();
                % A waterYearDate mechanism prevents dates in the future.
            dayRange = waterYearDate.getDayRange();
            givenWaterYear = waterYearDate.getWaterYear();

            subdivisionPerTiles = espEnv.getDataForObjectNameDataLabel( ...
                '', 'landsubdivisionidpertileandtype'); % Type = label. to modify  @todo
            subdivisionPerTiles = subdivisionPerTiles( ...
                subdivisionPerTiles.landSubdivisionId == obj.id, :);

            % Get the subdivision masks per tile
            % (in a 3d matrix with tile in 3rd dimension).
            subdivisionMaskPerTiles = zeros( ...
                espEnv.modisData.sensorProperties.tiling.rowPixelCount, ...
                espEnv.modisData.sensorProperties.tiling.columnPixelCount, ...
                size(subdivisionPerTiles, 1), 'uint16');
                    % NB: if ids go greater than 65535, change type!           @tofollow
            tileEspEnv = ESPEnv.empty(); % List of espEnv for each tile.
                % some tiles can have a different versionOfAncillary
                % and we need to access to the correct filePath (espEnv filters the
                % filePath according to the versionOfAncillary of the modisData
                % property.
            inputDataLabel = SpiresInversor.dataLabels.(espEnv.modisData.inputProduct);
            % Specific case for former stc and spires westernUS handling 20241001.
            if isequal(espEnv.modisData.versionOf.ancillary, 'v3.1')
                inputDataLabel = 'VariablesMatlab';
            end
            outputDataLabel = 'SubdivisionStatsDailyCsv';
            inputVersionRegions = espEnv.myConf.versionregion( ...
                strcmp(espEnv.myConf.versionregion.outputDataLabel, ...
                outputDataLabel) & ...
                strcmp(espEnv.myConf.versionregion.outputVersion, ...
                espEnv.modisData.versionOf.(inputDataLabel)), :);
                % Handling of the different versions of VariablesMatlab depending
                % on the tile and output version of SubdivisionStatsDailyCsv.
            if isempty(inputVersionRegions)
                error('Subdivision:configurationDailyStats', ...
                    ['%s: No association in version region configuration between', ...
                    ' inputDataLabel %s %s and outputDataLabel %s %s.\n'], ...
                    mfilename, inputDataLabel, ...
                    espEnv.modisData.versionOf.(inputDataLabel), ...
                    outputDataLabel, ...
                    espEnv.modisData.versionOf.(outputDataLabel));
            end
%{           
            % former implementation of varconf on variableregion.
            varConf = espEnv.myConf.variableregion( ...
                strcmp(espEnv.myConf.variableregion.regionName, obj.region.name) ...
                & espEnv.myConf.variableregion.writeStats == 1, {'varId'});
            varConf = innerjoin(varConf, ...
                espEnv.myConf.variable, ...
                LeftKeys = 'varId', RightKeys = 'id', ...
                LeftVariables = {}, ...
                RightVariables = {'id', 'output_name'});
%}
            [varConf, ~, ~] = espEnv.getVariable(outputDataLabel, ...
              inputDataLabel = inputDataLabel);
            varConf = innerjoin(varConf, espEnv.myConf.variablestat( ...
                espEnv.myConf.variablestat.landSubdivisionStatType == 1, :), ...
                LeftKeys = 'id', RightKeys = 'varId', ...
                LeftVariables = {'id', 'name'}, ...
                RightVariables = {'landSubdivisionStatId'});
                % varConf will be ordered based on the order of snow_fraction filter
                % a few lines below.
             
            for tileIdx = 1:size(subdivisionPerTiles, 1)
                tmpRegionName = subdivisionPerTiles.regionName{tileIdx};
                tileEspEnv(tileIdx) = ESPEnv.getESPEnvForRegionNameFromESPEnv(...
                    tmpRegionName, espEnv);
                tileEspEnv(tileIdx).modisData.versionOf.(inputDataLabel) = ...
                    inputVersionRegions( ...
                    strcmp(inputVersionRegions.regionName, tmpRegionName), ...
                    :).inputVersion{1};
                tmpEspEnv = tileEspEnv(tileIdx);
                subdivisionMaskPerTiles(:, :, tileIdx) = ...
                    tmpEspEnv.getDataForObjectNameDataLabel( ...
                        tmpRegionName, ...
                        subdivisionPerTiles.dataLabel{tileIdx});
            end
            % memory usage reduction of subdivisionMaskPerTiles.
            subdivisionMaskPerTiles(subdivisionMaskPerTiles ~= obj.id) = 0;
            subdivisionMaskPerTiles(subdivisionMaskPerTiles == obj.id) = 1;
            subdivisionMaskPerTiles = cast(subdivisionMaskPerTiles, 'uint8');
            fprintf('%s: Loaded masks for subdivision %d.\n', ...
                mfilename(), obj.id);

            % Check if stats must be calculated with an elevation threshold or not,
            % and if yes, determine the pixels to keep.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            elevationFilterConf = obj.region.filter.statistic( ...
                strcmp(obj.region.filter.statistic.thresholdedVarName, ...
                'elevation'), :);
            elevationIsToTake = [];
            if max(elevationFilterConf.minValue) > 0
              % Determination of elevation by tile (tile in 3rd dimension)
              % NB: depending on memory performance we can do that during the
              % variable loop each time ...                                       @tocheck
              % elevation store
              elevation = 0;
              for tileIdx = 1:size(subdivisionPerTiles, 1)
                  tmpEspEnv = tileEspEnv(tileIdx);
                  [elevationTileData, ~, ~] = ...
                      tmpEspEnv.getDataForObjectNameDataLabel( ...
                          subdivisionPerTiles.regionName{tileIdx}, 'elevation');
                  % Initialize elevation 3D array.
                  if elevation == 0
                      elevation = zeros([size(elevationTileData), ...
                          size(subdivisionPerTiles, 1)], class(elevationTileData));
                  end
                  elevation(:, :, tileIdx) = elevationTileData;
              end
              clear elevationTileData;
              fprintf('%s: Loaded elevation data for subdivision %d.\n', ...
                  mfilename(), obj.id);

              % Determination of the elevation and snow_fraction filters.
              % Filters determined at the big Region level, not at the
              % tile or the subdivision level.
              %
              % The user assumes that big regions do not overlap, which is not the case
              % for the integration of Canada.
              % It's too memory costly to have several elevation filters, as it's
              % possible to parameter in the configuration_of_filters.csv. So this code
              % will only consider either no elevation, or elevation filter with only 1
              % minimal value. So if the file indicates elevation filter 800 m for one
              % variable and 500 m for another variable, this code will filter elevation
              % on 800 m for both variables. However, if elevation filter is 0 for a
              % variable, there won't be any filter (0 considered nodata in that case).
              % To reduce memory too, this filter is in uint8 rather than single.
              %
              % NB: these filters are there only to mute the dry lake
              % spotting difficulty and the difficult handling of low snow
              % fractions by modscagdrfs stc.
              % NB: Only filters on elevation and snow_fraction are allowed,
              % although the configuration_of_filters.csv suggests filters
              % on other variables are possible.

              elevationIsToTake = cast( ...
                  elevation >= max(elevationFilterConf.minValue), 'uint8');
              clear elevation;
            else
              % elevation min = 0, no threshold applied.
              elevationIsToTake = ones([ ...
                espEnv.modisData.sensorProperties.tiling.rowPixelCount, ...
                espEnv.modisData.sensorProperties.tiling.columnPixelCount, ...
                height(subdivisionPerTiles)] , 'uint8');
            end % max(elevationFilterConf.minValue) > 0

            snowFractionFilterConf = obj.region.filter.statistic( ...
                ismember(obj.region.filter.statistic.thresholdedVarName, ...
                {'snow_fraction', 'snow_fraction_s'}), :);
            fprintf(['%s: Determined filters for subdivision %d from ', ...
                'region %s.\n'], mfilename(), obj.id, obj.region.regionName);

            % Order of the variables in varConf, based on the snow_fraction filter
            % order. snow_fraction should be in first, crucial for this code!
            [~, filterOrder] = ismember(snowFractionFilterConf.replacedVarName, ...
                varConf.name);
            varConf = varConf(filterOrder(filterOrder ~= 0), :);

            fprintf('%s: Ordered variables based on snow_fraction(_s) filters.\n', ...
                mfilename());

            % Table fields.
            % Ordered by waterYear (only one waterYear), thisDay, subdivisionId (only
            % current one), varId, statId (here only 1 statId per varId).
            waterYear = repelem(givenWaterYear, ...
                length(dateRange) * size(varConf, 1))';
            thisDay = repelem(dayRange, size(varConf, 1))';
            subdivisionId = repmat(cast(obj.id, 'uint16'), size(waterYear));
            varId = repmat( ...
                cast(varConf.id, 'uint8'), [length(dateRange), 1]);
            statId = repmat( ...
                cast(varConf.landSubdivisionStatId, 'uint8'), [length(dateRange), 1]);
            statValue = zeros(size(waterYear), 'single');
            fprintf( ...
                ['%s: Initialized daily stat columns for subdivision %d from %s ', ...
                'to %s.\n'], mfilename(), obj.id, ...
                string(dateRange(1), 'yyyy-MM-dd'), ...
                string(dateRange(end), 'yyyy-MM-dd'));

            % Calculate the stats for each date and variable.
            for dateIdx = 1:length(dateRange)
                % Parallelism not put here, because of memory usage linked to overhead
                % by elevation and subdivision masks, which would be copied at each
                % iteration?
                thisDate = dateRange(dateIdx);

                % Calculate stats and save for each variable.
                % NB: we store the value of snow_fraction by tile during the full loop
                % because it's used as a filter.
                % snowFractionData store the values of snow_fraction for each tile, with
                % tile in 3rd dim, because snow_fraction is used as a filter at each
                % varIdx iteration (variable level).
                snowFractionData = 0;
                snowFractionSData = 0;
                complementaryLabel = '';
                for varIdx = 1:size(varConf, 1)
                    varName = varConf.name{varIdx};

                    % Get filtered data for variable by tile.
                    % varData is the 3-D array storing the data for each tile (3rd dim).
                    varData = 0;
                    for tileIdx = 1:size(subdivisionPerTiles, 1)
                        % Get varData for the current tile and subdivision
                        tmpEspEnv = tileEspEnv(tileIdx);
                        varTileData = tmpEspEnv.getDataForDateAndVarName( ...
                            subdivisionPerTiles.regionName{tileIdx}, ...
                            inputDataLabel, thisDate, varName, complementaryLabel);
                        if isempty(varTileData)
                            % Should occur only when data were not shuffled to scratch.
                            % Or for spires when Alaska is not deployed.
                            % Important to set this here, because we can't use
                            % intmax(class(varTileData)).
                            [filePath, ~] = tmpEspEnv.getFilePathForDateAndVarName( ...
                            subdivisionPerTiles.regionName{tileIdx}, ...
                            inputDataLabel, thisDate, varName, complementaryLabel);
                            warning(['%s: Unavailable %s or unavailable file %s ', ...
                                ' for subdivision %d.\n'], ...
                                mfilename(), varName, filePath, obj.id);
                            continue;
                        end
                        % Subdivision mask.
                        varTileData(~subdivisionMaskPerTiles(:, :, tileIdx)) = ...
                            intmax(class(varTileData));

                        % Initialize varData and snowFractionData/snowFractionSData.
                        if size(varData, 1) == 1
                            varData = intmax(class(varTileData)) * ...
                                ones(size(subdivisionMaskPerTiles), ...
                                class(varTileData));
                        end
                        if strcmp(varName, 'snow_fraction') % snow_fraction should be
                            % the first variable to be handled, controlled by
                            % varId in configuration_of_variables.csv.
                            if snowFractionData == 0
                                snowFractionData = varData; % NB: matlab copy the data
                                    % and it is what we expect.
                            end
                            snowFractionData(:, :, tileIdx) = varTileData;
                        elseif strcmp(varName, 'snow_fraction_s') % snow_fraction_s
                            % should be
                            % the first variable to be handled, controlled by
                            % varId in configuration_of_variables.csv.
                            if snowFractionSData == 0
                                snowFractionSData = varData; % NB: matlab copy the data
                                    % and it is what we expect.
                            end
                            snowFractionSData(:, :, tileIdx) = varTileData;
                        end

                        % Elevation and snow_fraction filters and set to nodata.
                        % (after the setup of snowFractionData/snowFractionSData).
                        if ~isempty(elevationFilterConf( ...
                            strcmp(elevationFilterConf.replacedVarName, varName) & ...
                            elevationFilterConf.minValue ~= 0, :))
                            varTileData(~elevationIsToTake(:, :, tileIdx)) = ...
                                intmax(class(varTileData));
                        end

                        thisVarSnowFractionFilterConf = ...
                            snowFractionFilterConf(strcmp( ...
                            snowFractionFilterConf.replacedVarName, varName), :);
                        if strcmp(thisVarSnowFractionFilterConf.thresholdedVarName, ...
                            'snow_fraction')
                            varTileData(snowFractionData(:, :, tileIdx) == ...
                                intmax(class(snowFractionData)) | ...
                                snowFractionData(:, :, tileIdx) < ...
                                thisVarSnowFractionFilterConf.minValue(1)) = ...
                                    intmax(class(varTileData));
                        elseif ...
                            strcmp(thisVarSnowFractionFilterConf.thresholdedVarName, ...
                                'snow_fraction_s')
                            varTileData(snowFractionSData(:, :, tileIdx) == ...
                                intmax(class(snowFractionSData)) | ...
                                snowFractionSData(:, :, tileIdx) < ...
                                thisVarSnowFractionFilterConf.minValue(1)) = ...
                                    intmax(class(varTileData));
                        end
                        varData(:, :, tileIdx) = varTileData;
                    end % for tileIdx
                    clear varTileData;
                    if size(varData, 1) == 1
                        % Should occur only when data were not shuffled to scratch.
                        warning(['%s: Unavailable %s or unavailable file for ', ...
                            'all tiles of subdivision %d, date %s.\n'], ...
                            mfilename(), varName, ...
                            obj.id, string(thisDate, 'yyyy-MM-dd'));
                        continue;
                    end
                    fprintf(['%s: Loaded and filtered data subdivision %d, ', ...
                        ' %s, %s.\n'], ...
                        mfilename(), obj.id, varName, string(thisDate, 'yyyy-MM-dd'));

                    % Calculate the stat based on the filtered varData.
                    dataForStat = varData(varData ~= intmax(class(varData)));
                    clear varData;
                    tmpStatValue = 0;
                    switch varConf.landSubdivisionStatId(varIdx)
                        case 1 % surface.
                        % calculation of the surface in km2 from a percent
                        % snow_fraction.
                            tmpStatValue = single(sum(dataForStat) * ...
                            (espEnv.modisData.pixSize_500m^2 / 1000^2) ./ 100);
                        case 2 % mean
                            tmpStatValue = mean(single(dataForStat));
                        case 3 % median
                % SIER_326. Albedo stat smoothing. Strictly speaking, the matlab
                % median function does its job by yielding a int value from the
                % list of int values of albedos. But this masks the variability at
                % the decimal level and creates artificial bumps in the stats.
                % Here, we consider that the count of pixels having an albedo value X
                % has a equal distribution from X - 0.5 to X + 0.5, and we correct
                % the median albedo by the proportion of this interval necessary to
                % reach the half of the count of pixels.
                            tmpMedian = median(single(dataForStat));
                            tmpStatValue = (length(dataForStat)/2 - ...
                                length(find(dataForStat < tmpMedian))) / ...
                                (length(find(dataForStat == tmpMedian)) + 0.1) ...
                                + tmpMedian - 0.5;
                    end
                    clear dataForStat;
                    statValue((dateIdx - 1) * size(varConf, 1) + varIdx) = tmpStatValue;
                    fprintf(['%s: Calculated stat subdivision %d, %s, %s.\n'], ...
                        mfilename(), obj.id, varName, ...
                        string(dateRange(dateIdx), 'yyyy-MM-dd'));
                end % for varIdx
            end % for dateIdx

            % Construct the table of additional record, load the daily stat table, merge
            % and save in daily stat .csv file associated to subdivision.
            updateDate = repmat(datetime('now'), size(waterYear));
            addDailyStatTable = table(waterYear, thisDay, subdivisionId, varId, ...
                statId, statValue, updateDate);
            [dailyStatTable, dailyStatFilePath] = obj.setDailyStatTableAndFilePath( ...
                waterYearDate, varConf);
            % Addition of the updated data and removal of old data.
            dailyStatTable(dailyStatTable.waterYear == givenWaterYear & ...
                ismember(dailyStatTable.thisDay, dayRange) & ...
                dailyStatTable.updateDate ~= updateDate(1), :) = addDailyStatTable;
            % Sort
            dailyStatTable = sortrows(dailyStatTable, [1, 2, 3, 4, 5]);
            writetable(dailyStatTable, dailyStatFilePath);
            fprintf( ...
                ['%s: Done and saved daily stats for subdivision %d, ', ...
                'from %s to %s, %s.\n'], ...
                mfilename(), obj.id, string(dateRange(1), 'yyyy-MM-dd'), ...
                string(dateRange(end), 'yyyy-MM-dd'), dailyStatFilePath);
        end
        function [statTable, statFilePath] = mergeDailyStatTables(obj)
            % Return
            % ------
            % statTable: table. Table of merged yearly stats.
            % statFilePath: char. File path where the stat table is saved.

            espEnv = obj.region.espEnv;
            yearRange = espEnv.modisData.beginWaterYear:year(datetime('today'));
            thisDate = '';
            varName = '';
            complementaryLabel = '';
            statTable = '';
            
            statTable = espEnv.getDataForDateAndVarName(obj.id, ...
                'SubdivisionStatsDailyCsv', thisDate, varName, ...
                complementaryLabel, ...
                patternsToReplaceByJoker = {'thisDate', 'thisYear', 'monthWindow'});
                % Should concatenate all .csv corresponding to this subdivision.
            
            % Remove potential duplicates based on update dates.
            tempGroupTable = groupsummary(statTable, ...
                {'waterYear', 'thisDay', 'subdivisionId', 'varId', 'statId'}, ...
                'max', {'updateDate'}); 
            tempGroupTable.updateDate = tempGroupTable.max_updateDate; 
            statTable = innerjoin(statTable, tempGroupTable, ...
                Keys = {'waterYear', 'thisDay', 'subdivisionId', 'varId', 'statId', ...
                'updateDate'}, ...
                LeftVariables = {'waterYear', 'thisDay', 'subdivisionId', 'varId', ...
                'statId', 'statValue', 'updateDate'}, RightVariables = {});
            
            thisDate = '';
            [statFilePath, ~, ~] = espEnv.getFilePathForDateAndVarName(obj.id, ...
                    'SubdivisionStatsAggregCsv', thisDate, varName, complementaryLabel);
            writetable(statTable, statFilePath);
            fprintf('%s: Saved merged stat table for %d into %s.\n', mfilename(), ...
                obj.id, statFilePath);
        end
        function [dailyStatTable, dailyStatFilePath] = setDailyStatTableAndFilePath( ...
            obj, waterYearDate, varConf)
            % Check existence and content of the daily stat file for the subdivision
            % and year of the waterYearDate, and
            % if necessary initialize the daily stat table with only the waterYear
            % linked to the given
            % waterYearDate, with 0 values for all days and variables.
            %
            % The stat Table is initialized from start of data to the waterYear of the
            % date of today.
            %
            % NB: If file exists, the method don't generate rows for the lacking years
            % except the current year.
            %
            % Parameters
            % ----------
            % waterYearDate: WaterYearDate. Will initialize the file for the waterYear
            %   associated to this waterYearDate.
            % varConf: Table(id, name, landSubdivisionStatId). Configuration of
            %   the variables that should be included in the daily stat table and file.
            %
            % Return
            % ------
            % dailyStatTable: table(waterYear int, thisDay int, landsubdivisionId int
            %   varId int, statValue single, updateDate date). Table covering all
            %   daily stats for the subdivision, over the waterYear associated with the
            %   waterYearDate.
            % dailyStatFilePath: char. File path of the daily stat file for the
            %   subdivision and waterYear.

            % Initialize ...
            espEnv = obj.region.espEnv;

            subdivisionConf = espEnv.myConf.landsubdivision( ...
                espEnv.myConf.landsubdivision.id == obj.id, :);
            dayRange = cast(1:WaterYearDate.maxDaysByYear, 'uint16');

            varName = '';
            thisDate = waterYearDate.thisDatetime;
            complementaryLabel = '';
            [dailyStatFilePath, fileExists, ~] = ...
                espEnv.getFilePathForDateAndVarName(obj.id, ...
                'SubdivisionStatsDailyCsv', thisDate, varName, complementaryLabel, ...
                monthWindow = waterYearDate.monthWindow);

            % If inexistent statfile, generate the file with zero data
            % for the wateryear of the waterYearDate and each of the 366 days, and each
            % variable to integrate as defined in
            % and configuration_of_variables.csv.
            % NB: we create waterYears even for big region that don't have data for
            % some waterYears. E.g., waterYears 2001 to 2023 are created for AMAndes
            % although JPL data are only available after 2017. The code will consider
            % years full of zeros and exclude them from yearly aggregates.
            % Check if remark still valid???                                    @tocheck
            if ~fileExists | waterYearDate.monthWindow == 12
                if fileExists && waterYearDate.monthWindow == 12
                    delete(dailyStatFilePath);
                    warning( ...
                      ['%s: Deleted former daily stat filr for subdivision %d ', ...
                      'over waterYear %d, %s.\n'], mfilename(), obj.id, ...
                      waterYearDate.getWaterYear(), dailyStatFilePath);
                end
                fprintf( ...
                    ['%s: Initializing daily stat table for subdivision %d over ', ...
                    'waterYear %d ...\n'], mfilename(), obj.id, ...
                    waterYearDate.getWaterYear());

                % Table fields default filling, table creation and save in csv file.
                waterYear = repelem(waterYearDate.getWaterYear(), ...
                    length(dayRange) * size(subdivisionConf, 1) * size(varConf, 1))';
                thisDay = repelem(dayRange, ...
                    size(subdivisionConf, 1) * size(varConf, 1))';
                subdivisionId = repmat(cast(obj.id, 'uint16'), size(waterYear));
                varId = repmat( ...
                    cast(varConf.id, 'uint8'), ...
                    [length(dayRange) * size(subdivisionConf, 1), 1]);
                statId = repmat( ...
                    cast(varConf.landSubdivisionStatId, 'uint8'), ...
                    [length(dayRange) * size(subdivisionConf, 1), 1]);
                statValue = NaN(size(waterYear), 'single');
                updateDate = repmat(datetime('now'), size(waterYear));

                dailyStatTable = table(waterYear, thisDay, subdivisionId, varId, ...
                    statId, statValue, updateDate);

                fprintf(['%s: Initialized daily stat table for subdivision %d, ', ...
                    ' waterYear %d, %s.\n'], mfilename(), obj.id, ...
                    waterYearDate.getWaterYear(), dailyStatFilePath);
            else
                fprintf( ...
                    ['%s: Loading daily stat table for subdivision %d ...\n'], ...
                    mfilename(), obj.id);
                dailyStatTable = espEnv.getDataForDateAndVarName(obj.id, ...
                    'SubdivisionStatsDailyCsv', thisDate, varName, ...
                    complementaryLabel, monthWindow = waterYearDate.monthWindow);
                fprintf(['%s: Loaded daily stat table for subdivision %d.', ...
                    ' %s.\n'], mfilename(), obj.id, dailyStatFilePath);
            end
        end
        function writeStatCsvAndJson(obj, uncondensedJson) %
            % Write the csv and json stat file later ingested by the SnowToday webapp
            % to display the plots of the website (in combination with the
            % variables and subdivision .json files).
            %
            % Parameters
            % ----------
            % uncondensedJson: int. If 0, condense the geojsn files by removing new
            %   lines/spaces. Otherwise set 1.
            %
            % NB: the csv is only used by the v2023.1 of the website and also pushed
            % later to a public FTP. (The v2023.1 website doesn't accept the json).
            %
            % NB: Takes the last waterYear in the stat file as current waterYear.
            %
            % NB: There is an error in the code which doesn't handle the historics
            % correctly for bissectil/non bissectile year. For bissectile years, the 
            % historics of 3/1 of non bissectile years is aggregated/displayed as 2/28.
            %                                                                      @todo

            % Initialize ...
            espEnv = obj.region.espEnv;
            subdivisionConf = espEnv.myConf.landsubdivision( ...
                espEnv.myConf.landsubdivision.id == obj.id, :);

            thisDate = '';
            varName = '';
            complementaryLabel = '';
            statTable = espEnv.getDataForDateAndVarName( ...
                obj.id, 'SubdivisionStatsAggregCsv', thisDate, varName, ...
                complementaryLabel);
            if isempty(statTable)
                errorStruct.identifier = 'Subdivision:NoSubdivisionStatsAggregCsv';
                errorStruct.message = sprintf( ...
                    '%s: No file %s for subdivision %d. \n', mfilename(), ...
                    statFilePath, obj.id);
                error(errorStruct);
            end

            thisWaterYear = max(statTable.waterYear);
            data = struct(); % Important! Otherwise affectation data.thisDateRange
                % converts the array of datetimes in array of cells (don't know why :D).
            thisWaterYearDate = WaterYearDate.getLastWYDateForWaterYear( ...
                thisWaterYear, obj.region.getFirstMonthOfWaterYear(), 12, ...
                dateOfToday = ...
                datetime(thisWaterYear, obj.region.getFirstMonthOfWaterYear(), ...
                eomday(thisWaterYear, obj.region.getFirstMonthOfWaterYear())) + ...
                caldays(1));
                % A way to force waterYearDate goes to the end of the waterYear, even
                % if it's in the future.
            data.thisDateRange = thisWaterYearDate.getDailyDatetimeRange();
            currentDay = max(statTable( ...
                statTable.waterYear == thisWaterYear & ...
                ~isnan(statTable.statValue), :).thisDay);
            startWaterYear = min(statTable.waterYear(statTable.waterYear ~= ...
                obj.fakeWaterYearForGlobalStats));

            varIds = unique(statTable(statTable.waterYear == thisWaterYear & ...
                ~isnan(statTable.statValue), :).varId);

            varConf = innerjoin(espEnv.myConf.variable, ...
                espEnv.myConf.variablestat( ...
                    espEnv.myConf.variablestat.landSubdivisionStatType == 1, :), ...
                LeftKeys = 'id', RightKeys = 'varId', ...
                LeftVariables = {'id', 'name_unique', 'output_name', 'label', ...
                    'units_in_map'}, ...
                RightVariables = {'landSubdivisionStatId'});
            varConf = varConf(ismember(varConf.id, varIds), :);

            snowFractionVarConf = varConf(strcmp(varConf.name_unique, ...
                'snow_fraction_s'), :);
                % NB: We use snow_fraction_s, but should be snow_fraction for the old
                % website 2024-02-17.                                           @warning
            minSnowFractionYear = statTable( ...
                statTable.waterYear == obj.fakeWaterYearForGlobalStats & ...
                statTable.varId == snowFractionVarConf.id(1) & ...
                statTable.statId == 52, :).statValue(1);
            maxSnowFractionYear = statTable( ...
                statTable.waterYear == obj.fakeWaterYearForGlobalStats & ...
                statTable.varId == snowFractionVarConf.id(1) & ...
                statTable.statId == 42, :).statValue(1);

            currentDay = data.thisDateRange(currentDay);
            firstDayOfWaterYear = data.thisDateRange(1);
            data.thisDateRange = arrayfun(@(x) char(x, 'yyyy-MM-dd'), ...
                data.thisDateRange, UniformOutput = false);
            if size(data.thisDateRange, 1) == WaterYearDate.maxDaysByYear - 1
                data.thisDateRange(end + 1) = NaT;
            end
            for varIdx = 1:size(varConf, 1)
                % Determine the filePath.
                dataLabel = 'SubdivisionStatsWebCsvv20231';
                thisDatetime = datetime(thisWaterYear, 1, 1);
                varName = varConf.id(varIdx);
                complementaryLabel = '';
                [webCsvFilePath, ~, ~] = espEnv.getFilePathForDateAndVarName( ...
                    obj.id, dataLabel, ...
                    thisDatetime, varName, complementaryLabel);
                    % NB: Maybe better to group files in folders by object Ids? @tocheck
                    % (as for json).
                dataLabel = 'SubdivisionStatsWebJson';
                [webJsonFilePath, ~, ~] = espEnv.getFilePathForDateAndVarName( ...
                    obj.id, dataLabel, ...
                    thisDatetime, varName, complementaryLabel);

                % Csv Header metadata
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                fileID = fopen(webCsvFilePath, 'w');

                fprintf(fileID, 'SnowToday %s Statistics To Date : %s\n', ...
                    varConf.label{varIdx}, ...
                    char(currentDay, 'yyyy-MM-dd'));
                fprintf(fileID, 'Units : %s\n', varConf.units_in_map{varIdx});
                fprintf(fileID, 'Water Year : %04d\n', thisWaterYear);
                fprintf(fileID, 'Water Year Begins : %s\n', ...
                    char(firstDayOfWaterYear, 'yyyy-MM-dd'));
                fprintf(fileID, 'SubRegionName : %s\n', subdivisionConf.name{1});
                fprintf(fileID, 'SubRegionID : %s\n', subdivisionConf.code{1});

                fprintf(fileID, 'Historical Years : %04d-%04d\n', startWaterYear, ...
                    thisWaterYear - 1);
                    % NB: We suppose that the aggreg stats have been done on all the
                    % waterYears in the table... can be wrong if historics partly run.

                fprintf(fileID, 'Lowest Snow Year : %04d\n', minSnowFractionYear);
                        % statId codes in configuration_of_landsubdivisionstats.csv.
                fprintf(fileID, 'Highest Snow Year : %04d\n', maxSnowFractionYear);
                fprintf(fileID, '------------------------\n');
                fprintf(fileID, '\n');
                fprintf(fileID, strcat('day_of_water_year,min,prc25,', ...
                    'median,prc75,max,year_to_date\n'));

                fclose(fileID);
                fprintf('%s: Wrote %s\n', mfilename(), webCsvFilePath);

                % Csv historic statistics + year to date statistics
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % NB: the data are stored as table columns in files, as rows in the
                % fields of data (and in the json output) and as columns in the csv
                % output.
                data.thisDay = statTable( ...
                    statTable.waterYear == thisWaterYear & ...
                    statTable.varId == varConf.id(varIdx) & ...
                    statTable.statId == ...
                    varConf.landSubdivisionStatId(varIdx), :).thisDay';
                    % statId codes in configuration_of_landsubdivisionstats.csv.
                data.statValueforMinYear = statTable(statTable.waterYear == ...
                    minSnowFractionYear & statTable.varId == ...
                    varConf.id(varIdx) & statTable.statId == ...
                    varConf.landSubdivisionStatId(varIdx), :).statValue';
                data.prc25HistoricStatValue = statTable( ...
                    statTable.waterYear == ...
                    obj.fakeWaterYearForGlobalStats & statTable.varId == ...
                    varConf.id(varIdx) & statTable.statId == 11, :).statValue';
                data.medianHistoricStatValue = statTable( ...
                    statTable.waterYear == ...
                    obj.fakeWaterYearForGlobalStats & statTable.varId == ...
                    varConf.id(varIdx) & statTable.statId == 10, :).statValue';
                data.prc75HistoricStatValue = statTable( ...
                    statTable.waterYear == ...
                    obj.fakeWaterYearForGlobalStats & statTable.varId == ...
                    varConf.id(varIdx) & statTable.statId == 12, :).statValue';
                data.statValueforMaxYear = statTable(statTable.waterYear == ...
                    maxSnowFractionYear & statTable.varId == ...
                    varConf.id(varIdx) & statTable.statId == ...
                    varConf.landSubdivisionStatId(varIdx), :).statValue';
                data.statValueToDate = statTable( ...
                    statTable.waterYear == thisWaterYear & ...
                    statTable.varId == varConf.id(varIdx) & ...
                    statTable.statId == ...
                    varConf.landSubdivisionStatId(varIdx), :).statValue';
                csvTable = table(data.thisDay', data.statValueforMinYear', ...
                    data.statValueforMaxYear', data.prc25HistoricStatValue', ...
                    data.medianHistoricStatValue', data.prc75HistoricStatValue', ...
                    data.statValueToDate');
                writetable(csvTable, webCsvFilePath, 'WriteMode','Append');
                fprintf(['%s: Saved stat data in %s.\n'], mfilename(), webCsvFilePath);

                % Json stat file.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % NB: NaN are converted into null by jsonencode.
                thisStruct = struct();
                thisStruct.data = data;
                thisStruct.metadata.minYear = minSnowFractionYear;
                thisStruct.metadata.maxYear = maxSnowFractionYear; % TO CHANGE BECAUSE NEED TO BE MAX YEAR OF THE SPECIFIC VAR.
                ancillaryOutput = AncillaryOutput(espEnv, ...
                    uncondensedJson = uncondensedJson);
                dataLabel = 'SubdivisionStatsWebJson';
                outFilePath = webJsonFilePath;
                ancillaryOutput.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                    outFilePath);

                fprintf('%s: Wrote %s\n', mfilename(), webJsonFilePath);
            end
        end
    end
end
