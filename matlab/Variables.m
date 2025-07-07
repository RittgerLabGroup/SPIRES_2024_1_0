classdef Variables
    % Handles the calculations to obtain the variables
    % e.g. snow_cover_days
    properties
        region         % Regions object, on which the calculations are done
    end
    properties(Constant)
        uint8NoData = cast(255, 'uint8');
        uint16NoData = cast(65535, 'uint16');
        albedoScale = 100.; % Factor to multiply albedo obtained from
                             % ParBal.spires_albedo
        albedoDeltavisScale = 100.; % Factor for deltavis in albedo_observed
                                    % calculations
        albedoDownscaleFactor = 0.63; % Factor for albedo_clean in albedo_observed
                                      % calculations
        albedoMinGrainSize = 1;  % Min grain size accepted to calculate albedo
                                    % spires in parBal package
        albedoMaxGrainSize = 1999;  % Max grain size accepted to calculate albedo
                                    % spires in parBal package
        dataStatus = ...
            struct(observed = uint8(1), ...
                unavailable = uint8(0), ...
                cloudyOrOther = uint8(10), ...
                highSolarZenith = uint8(20), ...
                unknownSolarZenith = uint8(21), ...
                lowValue = uint8(30), ...
                notForGeneralPublic = uint8(40), ...
                falsePositive = uint8(50), ...
                noInput = uint8(60), ...
                noObservation = uint8(61), ...
                poorQuality = uint8(62), ...
                noReflectance = uint8(63), ...
                lowNdsi = uint8(64), ...
                lowSnowFraction = uint8(65), ...
                lowGrainSize = uint8(66), ...
                lowNbOfObservationsOverTime = uint8(67), ...
                water = uint8(68), ...
                lowElevation = uint8(69), ...
                temporary = uint8(255)); % possible values
            % for the viewable_snow_fraction_status variable to indicate
            % observed and reliable/unobserved/interpolated data.
            % False positive: dry lakes.
        dataStatusForNoObservation = [Variables.dataStatus.unavailable, ...
            Variables.dataStatus.cloudyOrOther, ...
            Variables.dataStatus.highSolarZenith, ...
            Variables.dataStatus.unknownSolarZenith, ...
            Variables.dataStatus.falsePositive, ...
            Variables.dataStatus.cloudyOrOther, ...
            Variables.dataStatus.highSolarZenith, ...
            Variables.dataStatus.lowValue, ...
            Variables.dataStatus.falsePositive, ...
            Variables.dataStatus.noInput, ...
            Variables.dataStatus.noObservation, ...
            Variables.dataStatus.poorQuality, ...
            Variables.dataStatus.noReflectance, ...
            Variables.dataStatus.lowNdsi, ...
            Variables.dataStatus.lowSnowFraction, ...
            Variables.dataStatus.lowGrainSize, ...
            Variables.dataStatus.lowNbOfObservationsOverTime, ...
            Variables.dataStatus.water, ...
            Variables.dataStatus.lowElevation]; % Data status values that indicate no
            % observation, used to calculate days_without_observation.
        highSolarZenith = 67.5; % solar zenith value above which the observed data is
            % considered unreliable.
        varIdsForSnowCoverDays = [45, 61];
    end

    methods
        function obj = Variables(region)
            % Constructor of Variables
            %
            % Parameters
            % ----------
            % region: Regions object
            %   Region on which the variables are handled

            obj.region = region;
        end
        function calcDaysWithoutObservation(obj, waterYearDate, varargin)
            % Calculates days_without_observation and days_since_last_observation,
            % from viewable_snow_fraction_status variable,
            % and updates the daily mosaic data files with the value.
            %
            % 1. days_without_observation:
            % For a specific pixel/day, days_without_observation =0 if there is an
            % observation for the day. If there is no observation for the day,
            % days_without_observation = the number of days without observations
            % surrounding the studied day. E.g. if day 1 has observation, and then day
            % 2 to 10 don't have observation, and day 11 has observation,
            % days_without_observation will equal [0, 9, 9, 9, 9, 9, 9, 9, 9, 9, 0].
            % Absence of observation is caused by low values, high solar zenith (for
            % v2023.0/v2023.0e and by nodata in modscag data, clouds, noise, low values,
            % high solar zenith in versions >= v2023.1. NB: pixels/days having
            % unavailable modscag data are considered temporary, same as pixels having
            % modscag data for v2023.0, v2023.e, k, and thus are considered observed,
            % contrary to >= v2023.1.
            %
            % 2. days_since_last_observation: for a pixel/day, 0 if observation,
            % otherwise number of days after the day of last observation + 1 for the
            % ongoing day. In the case above, days_since_last_observation will equal:
            % [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0].
            %
            % Called by runSnowTodayStep2.sh \ runUpdateDaysWithoutObservation.sh
            %
            % Parameters
            % ----------
            % waterYearDate: WaterYearDate obj. Date and range of days before over
            %   which calculation should be carried out.
            % optim: struct(cellIdx, countOfCells, logLevel, parallelWorkersNb).
            %   cellIdx: int, optional. Index of the cell part of the tile to update. 1
            %     by default. Index are counted starting top to bottom column 1, top to
            %     bottom column 2, ... until bottom of last column.
            %   countOfCellPerDimension: array(int), optional. Number of cells dividing the tile to
            %     update. 1 by default.
            %   countOfPixelPerDimension: array(int).
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.

            % 0. Initialization, variables, dates...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            tic;
            thisFunction = 'Variables.calcDaysWithoutObservations';
            espEnv = obj.region.espEnv;
            p = inputParser;
            optim = struct(cellIdx = [1, 1], countOfCellPerDimension = [1, 1], ...
                countOfPixelPerDimension = [ ...
                  espEnv.modisData.georeferencing.tileInfo.rowCount, ...
                  espEnv.modisData.georeferencing.tileInfo.columnCount], ...
                logLevel = 0, parallelWorkersNb = 0);
            addParameter(p, 'optim', optim);
            p.StructExpand = false;
            parse(p, varargin{:});
            optimFieldNames = fieldnames(p.Results.optim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = p.Results.optim.(thisFieldName);
                end
            end % fieldIx.
            fprintf(['%s: Starting, region: %s, waterYearDate: %s, ', ...
                'cellIdx: %d, countOfCells: %d, logLevel: %d, ', ...
                'parallelWorkersNd: %d...\n'], thisFunction, obj.region.name, ...
                waterYearDate.toChar(), optim.cellIdx, optim.countOfCellPerDimension(1), ...
                optim.logLevel, optim.parallelWorkersNb);

            [startIdx, endIdx, ~] = espEnv.getIndicesForCell( ...
                optim.cellIdx, optim.countOfCellPerDimension, ...
                optim.countOfPixelPerDimension);
            indices = struct();
                % To keep former code with indices below, but could be replaced.   @todo
            indices.rowStartId = startIdx(1);
            indices.rowEndId = endIdx(1);
            indices.columnStartId = startIdx(2);
            indices.columnEndId = endIdx(2);

            inputDataLabel = 'VariablesMatlab';
            outputDataLabel = 'VariablesMatlab';
            outputMeasurementTypeId = [47, 75, 115];
            % 47. days_without_observation, 75. days_since_last_observation
            % 115. calculated_from_rare_observation
            [variable, variableLink] = espEnv.getVariable(outputDataLabel, ...
                inputDataLabel = inputDataLabel, ...
                outputMeasurementTypeId = outputMeasurementTypeId);

            objectName = obj.region.name;
            dataLabel = inputDataLabel;
            theseDates = waterYearDate.getDailyDatetimeRange();
            inputVarId = unique(variableLink.inputVarId);

            % For each group of variables (e.g. modis stc, modis spires, ...)
            for inputVarIdx = 1:length(inputVarId)
                % 1. Loading status data...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                thisInputVarId = inputVarId(inputVarIdx);
                varName = thisInputVarId;
                fprintf('%s: Starting varId %d...\n', thisFunction, thisInputVarId);
                dayWithout = innerjoin( ...
                    variable(variable.measurementTypeId == 47, :), ...
                    variableLink(variableLink.inputVarId == thisInputVarId, :), ...
                    LeftKeys = 'id', RightKeys = 'outputVarId');
                daySince = innerjoin( ...
                    variable(variable.measurementTypeId == 75, :), ...
                    variableLink(variableLink.inputVarId == thisInputVarId, :), ...
                    LeftKeys = 'id', RightKeys = 'outputVarId');

                % Add properties for Mask of rare observations for v2023.0e. 2025-01-17.
                calculatedFromRareObservation = innerjoin( ...
                    variable(variable.measurementTypeId == 115, :), ...
                    variableLink(variableLink.inputVarId == thisInputVarId, :), ...
                    LeftKeys = 'id', RightKeys = 'outputVarId');
                thisDaySince = reshape( ...
                    cast(espEnv.getDataForWaterYearDateAndVarName( ...
                        objectName, dataLabel, waterYearDate, varName, ...
                        optim = optim), ...
                    dayWithout.type{1}), ...
                    [numel(indices.rowStartId:indices.rowEndId) * ...
                        numel(indices.columnStartId:indices.columnEndId), ...
                        length(theseDates)])';
                % actually it is iniatlly thiStatus.
                % Each column = temporal series of a pixel.

                % 2. Calculations...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % Determine which day is without observation.
                isNoObservation = ismember(thisDaySince, ...
                    cast(obj.dataStatusForNoObservation, class(thisDaySince)));
                thisDaySince = cast(isNoObservation, 'int16');
                    % int16 to make diff, which can be negative.
                isNoObservation = [];
                indicesForPeriods = cumsum([ones(1, size(thisDaySince, 2)); ...
                    abs(diff(thisDaySince, 1, 1))]);
                isEqualSuccessiveIndicesForPeriods = ...
                    int16([ones(1, size(thisDaySince, 2)); ...
                        indicesForPeriods(1:end - 1, :)] == ...
                        indicesForPeriods);
                indicesForPeriods = [];

                for rowIdx = 2:size(thisDaySince, 1)
                    thisDaySince(rowIdx, :) = ...
                        isEqualSuccessiveIndicesForPeriods(rowIdx, :) ...
                        .* thisDaySince(rowIdx - 1, :) + thisDaySince(rowIdx, :);
                end

                thisDayWithout =  thisDaySince;
                for rowIdx = size(thisDayWithout, 1) - 1: -1: 1
                    thisDayWithout(rowIdx, :) = ...
                        isEqualSuccessiveIndicesForPeriods(rowIdx + 1, :) ...
                        .* thisDayWithout(rowIdx + 1, :) + ...
                        int16(~isEqualSuccessiveIndicesForPeriods(rowIdx + 1, :)) ...
                        .* thisDayWithout(rowIdx, :);
                end
                isEqualSuccessiveIndicesForPeriods = [];
%{
                % Previous implementation too slow. 2024-03-25. Seb.

                thisStatus = cast(thisStatus, dayWithout.type{1});
                thisDayWithout = sum(thisStatus, 1, 'native');
                thisDaySince = cumsum(thisStatus, 1);
                isSet = ismember(thisDayWithout, [0, ...
                    length(theseDates)]);
                thisDayWithout = repmat(thisDayWithout, [length(theseDates), 1]);

                parfor(pixelIdx = 1:size(thisStatus, 2), optim.parallelWorkersNb)
                    % We don't run the calculations if the pixel temporal series is full
                    % of observed or full of unobserved.
                    if ~isSet(pixelIdx)
                        unobserved = int16(thisStatus(:, pixelIdx));
                            %
                        indicesForPeriods = cumsum([1; diff(unobserved) ~= 0]);
                            % An additional 1 to get the same size as unobserved.
                        cumSumForPeriods = arrayfun(@(idxForPeriod) ...
                            cumsum(unobserved(indicesForPeriods == idxForPeriod)), ...
                            1:indicesForPeriods(end), UniformOutput = false);
                        thisDaySinceLastObservation = cat(1, cumSumForPeriods{:});

                        maxOfCumSumForPeriods = arrayfun(@(idxForPeriod) ...
                            repmat( ...
                                max(thisDaySinceLastObservation( ...
                                    indicesForPeriods == idxForPeriod)), ...
                                [length(find(indicesForPeriods == idxForPeriod)), ...
                                1]), ...
                            1:indicesForPeriods(end), UniformOutput = false);

                        thisDaySince(:, pixelIdx) = ...
                            thisDaySinceLastObservation;
                        thisDayWithout(:, pixelIdx) = ...
                            cat(1, maxOfCumSumForPeriods{:});
                    end % isSet.
                end % pixelIdx.
%}
                thisDaySince = ...
                    cast(reshape(thisDaySince', ...
                        [numel(indices.rowStartId:indices.rowEndId), ...
                        numel(indices.columnStartId:indices.columnEndId), ...
                        length(theseDates)]), daySince.type{1});
                thisDayWithout = ...
                    cast(reshape(thisDayWithout', ...
                        [numel(indices.rowStartId:indices.rowEndId), ...
                        numel(indices.columnStartId:indices.columnEndId), ...
                        length(theseDates)]), dayWithout.type{1});


                % 3. Saving, collection of units and divisor...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                fprintf('%s: Saving varId %d output...\n', thisFunction, ...
                    thisInputVarId);
                output = struct();
                theseVariables = {daySince, dayWithout};

                % Add properties for Mask of rare observations for v2023.0e. 2025-01-17.
                isCalculatedFromRareObservationIfDaysWithoutObsAbove = ...
                    Tools.valueInTableForThisField( ...
                        obj.region.filter.mosaic, ...
                        'lineName', ...
                        'isCalculatedFromRareObservationIfDaysWithoutObsAbove', ...
                        'minValue');
                if isCalculatedFromRareObservationIfDaysWithoutObsAbove < 366
                    theseVariables = {daySince, dayWithout, ...
                        calculatedFromRareObservation};
                end

                for varIdx = 1:size(theseVariables, 2)
                    thisVariable = theseVariables{varIdx};
                    varName = thisVariable.name{1};

                    output.([varName '_divisor']) = thisVariable.divisor(1);
                    output.([varName '_min']) = thisVariable.min(1);
                    output.([varName '_max']) = thisVariable.max(1);
                    output.([varName '_nodata_value']) = ...
                        thisVariable.nodata_value(1);
                    output.([varName '_type']) = thisVariable.type{1};
                    output.([varName '_units']) = thisVariable.unit{1};

                end % varIdx

                dataLabel = outputDataLabel;
                varName = '';
                complementaryLabel = '';
                theseFieldNames = fieldnames(output);

                % 2025-02-14. Warning for cases when all pixels having more than
                % the threshold of observations are set to nodata.
                if isCalculatedFromRareObservationIfDaysWithoutObsAbove < 366
                    warning(['Rare observation mask applied, updating most ', ...
                        'variables in daily files...']);
                end
                parfor(dateIdx = 1:length(theseDates), optim.parallelWorkersNb)
                    thisDate = theseDates(dateIdx);

                    [thisFilePath, thisFileExists, ~] = ...
                        espEnv.getFilePathForDateAndVarName(objectName, dataLabel, ...
                        thisDate, varName, complementaryLabel);
                    if ~thisFileExists
                        warning('%s: Inexistent file %s.\n', mfilename, thisFilePath);
                    else
                        fprintf('Updating %s...\n', thisFilePath);
                        thisFileObj = matfile(thisFilePath, Writable = true);
                        thisFileObj.(daySince.name{1})(...
                            indices.rowStartId:indices.rowEndId, ...
                            indices.columnStartId:indices.columnEndId) = ...
                            thisDaySince(:, :, dateIdx);
                            % daily .mat files have only 2 dims.
                        thisFileObj.(dayWithout.name{1})(...
                            indices.rowStartId:indices.rowEndId, ...
                            indices.columnStartId:indices.columnEndId) = ...
                            thisDayWithout(:, :, dateIdx);

                        for fieldIdx = 1:length(theseFieldNames)
                            thisFieldName = theseFieldNames{fieldIdx};
                            thisFileObj.(thisFieldName) = output.(thisFieldName);
                        end % fieldIdx.

                        % Add mask of rare observations for v2023.0.1 = v2023.0e + v2023.0. 2025-01-17.
                        if isCalculatedFromRareObservationIfDaysWithoutObsAbove < 366
                            thatCalculatedFromRareObservation = ...
                                thisDayWithout(:, :, dateIdx) > ...
                                isCalculatedFromRareObservationIfDaysWithoutObsAbove;
                            thisFileObj.(calculatedFromRareObservation.name{1})(...
                                indices.rowStartId:indices.rowEndId, ...
                                indices.columnStartId:indices.columnEndId) = ...
                                thatCalculatedFromRareObservation;

                            % 2025-02-14. All pixels having more than the threshold
                            % of observations should be set to nodata ("masked'),
                            % except the layers expressed in unit days and angles and
                            % flags.
                            unitsOfUnmaskedVariables = {'day', 'degree', 'unitless'};
                            thoseVariables = espEnv.getVariable( ...
                                dataLabel, inputDataLabel = dataLabel);
                            thoseVariables = thoseVariables( ...
                                ~ismember(thoseVariables.unit, ...
                                    unitsOfUnmaskedVariables), :);
                            for varIdx = 1:height(thoseVariables)
                                thoseData = ...
                                    thisFileObj.(thoseVariables.name{varIdx}) ...
                                    (indices.rowStartId:indices.rowEndId, ...
                                    indices.columnStartId:indices.columnEndId);
                                thoseData(thatCalculatedFromRareObservation) = ...
                                    thoseVariables.nodata_value(varIdx);
                                thisFileObj.(thoseVariables.name{varIdx}) ...
                                    (indices.rowStartId:indices.rowEndId, ...
                                    indices.columnStartId:indices.columnEndId) = ...
                                    thoseData;
                            end
                        end % if isCalculatedFromRareObservationIfDaysWithoutObsAbove
                        % < 366
                    end % thisFileExists.
                end % dateIdx.
                fprintf('%s: Done varId %d output...\n', thisFunction, ...
                    thisInputVarId);
            end % inputVarIdx
            t2 = toc;
            fprintf(['%s: Done in %.2f seconds.\n'], thisFunction, t2);
%{
            % NB: Older code used in v2023.1.                                  @obsolete

            % 1. Initial daysWithoutObservation.
            %---------------------------------------------------------------------------
            % Taken from the day preceding the date range (in the daily
            % modaic data file of the day before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0.
            lastDaysWithoutObservation = zeros(obj.region.getSizeInPixels(), 'single');
            if dateRange(1) ~= waterYearDate.getFirstDatetimeOfWaterYear()
                thisDatetime = daysadd(dateRange(1) , -1); % date before.
                dataFilePath = espEnv.MosaicFile(obj.region, thisDatetime);
                unavailableDataFlag = false;
                if ~isfile(dataFilePath)
                    unavailableDataFlag = true;
                else
                    data = load(dataFilePath, aggregateVarName);
                    fprintf('%s: Loading %s from %s\n', ...
                            mfilename(), aggregateVarName, dataFilePath);
                    if isempty(data) | ...
                        ~ismember(aggregateVarName, fieldnames(data))
                        unavailableDataFlag = true;
                    else
                        lastDaysWithoutObservation = cast(data.days_without_observation, 'single');
                            % Don't forget that in mosaics type is not single.
                        lastDaysWithoutObservation( ...
                            lastDaysWithoutObservation == thisVarConf.nodata_value) ...
                            = NaN;
                    end
                end
                if unavailableDataFlag
                    warning('%s: Missing file or no %s variable in %s\n', ...
                        mfilename(), aggregateVarName, dataFilePath);
                    lastDaysWithoutObservation = NaN(obj.region.getSizeInPixels(), 'single');
                end
            end

            % 2. Update each daily mosaic file for the full
            % period by calculating days_without_observation from
            % viewable_snow_fraction_status.
            %---------------------------------------------------------------------------
            for thisDateIdx=1:length(dateRange) % No parfor here.
                % 2.a. Loading of the daily mosaic file
                %-----------------------------------------------
                dataFilePath = espEnv.MosaicFile(obj.region, dateRange(thisDateIdx));

                unavailableDataFlag = false;
                if ~isfile(dataFilePath)
                    unavailableDataFlag = true;
                else
                    data = load(dataFilePath, baseVarName);
                    fprintf('%s: Loading %s from %s\n', ...
                            mfilename(), baseVarName, dataFilePath);
                    if isempty(data) | ...
                        ~ismember(baseVarName, fieldnames(data))
                        unavailableDataFlag = true;
                    end
                end
                if unavailableDataFlag
                    warning(['%s: Stop updating days_without_observation. ', ...
                        'Missing file or no %s variable in %s\n'], ...
                        mfilename(), baseVarName, dataFilePath);
                    break;
                else
                    % 2.b. If viewable_snow_fraction_status equals certain values,
                    % the pixel doesn't have reliable observations and was interpolated.
                    % Therefore we increase the counter of days without observations
                    % otherwise we reset it to zero.
                    %-----------------------------------------------------------------------
                    isObserved = ~ismember(data.(baseVarName), ...
                        obj.dataStatusForNoObservation);
                    lastDaysWithoutObservation(isObserved) = 0;
                    lastDaysWithoutObservation(~isObserved) = ...
                        lastDaysWithoutObservation(~isObserved) + 1;
                end
                lastDaysWithoutObservation(isnan(lastDaysWithoutObservation)) = ...
                    thisVarConf.nodata_value;
                mosaicData.(aggregateVarName) = cast(lastDaysWithoutObservation, ...
                    thisVarConf.type_in_mosaics{1});
                mosaicData.data_status_for_no_observation = obj.dataStatusForNoObservation;
                save(dataFilePath, '-struct', 'mosaicData', '-append');
                fprintf('%s: Saved %s to %s\n', mfilename(), ...
                    aggregateVarName, dataFilePath);
            end
            t2 = toc;
            fprintf('%s: Finished %s update in %s seconds\n', ...
                mfilename(), aggregateVarName, ...
                num2str(roundn(t2, -2)));
%}
        end
        function calcSnowCoverDays(obj, waterYearDate, varargin)
            % Calculates snow cover days from snow_fraction variable (modis + spires)
            % and updates the daily mosaic data files with the value
            % Cover days are calculated if elevation and snow cover fraction
            % are above thresholds defined at the Region level (attribute
            % snowCoverDayMins.
            % Cover days is NaN after the first day (included) without snow fraction
            %   data.
            %
            % Called by runSnowTodayStep1.sh \ runUpdateWaterYearSCD.sh \
            % updateWaterYearSCDFor.m
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object.
            %   Date and range of days before over which calculation
            %   should be carried out.
            %
            % NB: Calculation was previously on the STC Cubes but are now on Mosaics
            %   (upd. 2023-12-28).
            % NB: Refactored following how I refactored calcDaysWithoutObservations().
            %   2024-03-23.
            tic;
            thisFunction = 'Variables.calcSnowCoverDays';
            fprintf(['%s: Starting, region: %s, waterYearDate: %s...\n'], ...
              thisFunction, obj.region.name, ...
                waterYearDate.toChar());

            espEnv = obj.region.espEnv;

            inputDataLabel = 'VariablesMatlab';
            outputDataLabel = 'VariablesMatlab';
            outputMeasurementTypeId = [45];
            % 45. snow_cover_days.
            [variable, variableLink, inputVariable] = espEnv.getVariable( ...
                outputDataLabel, inputDataLabel = inputDataLabel, ...
                outputMeasurementTypeId = outputMeasurementTypeId);

            objectName = obj.region.name;
            dataLabel = inputDataLabel;
            theseDates = waterYearDate.getDailyDatetimeRange();
            inputVarId = inputVariable.id;
            if isempty(inputVarId)
                error('Variables:configurationSCD', ...
                    ['%s: No snow fraction in configuration versionvariable for ', ...
                    'inputDataLabel %s %s, outputDataLabel %s %s.\n'], ...
                    mfilename, inputDataLabel, ...
                    espEnv.modisData.versionOf.(inputDataLabel), ...
                    outputDataLabel, ...
                    espEnv.modisData.versionOf.(outputDataLabel));
            end
            % For each group of variables (e.g. modis stc, modis spires, ...)
            for inputVarIdx = 1:length(inputVarId)
                % 1. Loading status data...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                thisInputVarId = inputVarId(inputVarIdx);
                varName = thisInputVarId;
                fprintf('%s: Starting varId %d...\n', thisFunction, thisInputVarId);
                snowCoverDay = innerjoin( ...
                    variable, ...
                    variableLink(variableLink.inputVarId == thisInputVarId, :), ...
                    LeftKeys = 'id', RightKeys = 'outputVarId');
                nameOfSnowCoverDay = snowCoverDay.name{1};

                snowFraction = inputVariable(inputVariable.id == thisInputVarId, :);

                theseData = ...
                    espEnv.getDataForWaterYearDateAndVarName( ...
                        objectName, dataLabel, waterYearDate, varName);
                        % theseData is first the retrieved snow_fraction. After several
                        % filters, theseData is converted in snow_cover_days.
                theseData = cast(theseData, snowCoverDay.type{1});
                  % Cast from uint8 to uint16.
                isNoData = theseData == ...
                    snowFraction.nodata_value(1);
                % snow_fraction, uint8 to uint16. 3rd dimension = temporal series of
                % a pixel located in 1st + 2nd dim.

                % 3. Filtering low snow fraction
                % (set to 0), low elevation (set to no data), and calculating
                % snow_cover_days...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                mins = obj.region.filter.snowCoverDay( ...
                    obj.region.filter.snowCoverDay.replacedVarId == thisInputVarId, :);
                snowThreshold = Tools.valueInTableForThisField( ...
                    mins, 'thresholdedVarId', thisInputVarId, 'minValue');
                if length(snowThreshold) ~= 0 % 0 could be a threshold too.
                    isLowSnow = theseData < snowThreshold;
                    theseData(isLowSnow) = 0;
                    theseData(~isLowSnow) = 1;
                    isLowSnow = [];
                    
                else
                    theseData = ones( ...
                        size(theseData), snowCoverDay.type{1});
                end
                theseData(isNoData) = snowCoverDay.nodata_value(1);
                isNoData = [];
                elevationThreshold = Tools.valueInTableForThisField( ...
                    mins, 'thresholdedVarName', 'elevation', 'minValue');
                if length(elevationThreshold) ~= 0 % 0 could be a threshold too.
                    theseData( ...
                        repmat(espEnv.getDataForObjectNameDataLabel( ...
                        obj.region.regionName, 'elevation') < elevationThreshold, ...
                        [1, 1, size(theseData, 3)])) = ...
                        snowCoverDay.nodata_value(1);
                end

                theseData = cumsum(theseData, 3);
                  % NB: If any nodata (created by the
                  % calculated_from_rare_observation flag v2023.0.1 for instance), the
                  % cumsum shift to no data starting the first day in water year when
                  % there is no data.

                % 4. Saving, collection of units and divisor...
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                fprintf('%s: Saving varId %d output...\n', thisFunction, ...
                    thisInputVarId);
                output = struct();
                theseVariables = {snowCoverDay};
                for varIdx = 1:size(theseVariables, 1)
                    thisVariable = theseVariables{varIdx};
                    varName = thisVariable.name{1};
                    output.([varName '_divisor']) = thisVariable.divisor(1);
                    output.([varName '_min']) = thisVariable.min(1);
                    output.([varName '_max']) = thisVariable.max(1);
                    output.([varName '_nodata_value']) = ...
                        thisVariable.nodata_value(1);
                    output.([varName '_type']) = thisVariable.type{1};
                    output.([varName '_units']) = thisVariable.unit{1};
                end % varIdx

                dataLabel = outputDataLabel;
                varName = '';
                complementaryLabel = '';
                theseFieldNames = fieldnames(output);
                parfor(dateIdx = 1:length(theseDates), 0)
                    thisDate = theseDates(dateIdx);
                    [thisFilePath, thisFileExists, ~] = ...
                        espEnv.getFilePathForDateAndVarName(objectName, dataLabel, ...
                        thisDate, varName, complementaryLabel);
                    if ~thisFileExists
                        warning('%s: Inexistent file %s.\n', mfilename, thisFilePath);
                    else
                        fprintf('Updating %s...\n', thisFilePath);
                        thisFileObj = matfile(thisFilePath, Writable = true);
                        thisFileObj.(nameOfSnowCoverDay) = ...
                                theseData(:, :, dateIdx);
                        for fieldIdx = 1:length(theseFieldNames)
                            thisFieldName = theseFieldNames{fieldIdx};
                            thisFileObj.(thisFieldName) = output.(thisFieldName);
                        end % fieldIdx.
                    end % thisFileExists.
                end % dateIdx.
                fprintf('%s: Done varId %d output...\n', thisFunction, ...
                    thisInputVarId);
            end % inputVarIdx
            t2 = toc;
            fprintf(['%s: Done in %.2f seconds.\n'], thisFunction, t2);

%{
            % NB: Older code used in v2023.x.                                  @obsolete

inputVarName, outputVarName
            % inputVarName: char. Name of the variable over which carrying calculations,
            %   either snow_fraction or snow_fraction_s.
            % ouputVarName: char. Name of the output variable, either snow_cover_days
            %   or snow_cover_days_s.

            tic;
            fprintf('%s: Start %s calculations\n', mfilename(), outputVarName);
            % 1. Initialization, elevation data, dates
            %    and collection of units and divisor for
            %    snow_cover_days
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            espEnv = obj.region.espEnv;
            % mins = obj.region.snowCoverDayMins;                              @obsolete
            mins = obj.region.filter.snowCoverDay(strcmp( ...
                obj.region.filter.snowCoverDay.replacedVarName, inputVarName), :);

            dateRange = waterYearDate.getDailyDatetimeRange();

            [elevation, ~, ~] = ...
                espEnv.getDataForObjectNameDataLabel(obj.region.regionName, 'elevation');

            snowCoverConf = espEnv.myConf.variable(find( ...
                strcmp(espEnv.myConf.variable.output_name, outputVarName)), :);
            snow_cover_days_units = snowCoverConf.units_in_map;
            snow_cover_days_divisor = snowCoverConf.divisor;
            snow_cover_days_type = snowCoverConf.type_in_mosaics{1};
                % Correct field name from ..._divisor_type to _type. 2024-02-08.
            snow_cover_days_nodata_value = snowCoverConf.nodata_value;

            % snow_cover_days_min_elevation = mins.minElevation;               @obsolete
            % snow_cover_days_min_snow_cover_fraction = mins.minSnowCoverFraction;
            snow_cover_days_min_elevation = Tools.valueInTableForThisField( ...
                mins, 'thresholdedVarName', 'elevation', 'minValue');
            snow_cover_days_min_snow_cover_fraction = ...
                Tools.valueInTableForThisField( ...
                    mins, 'thresholdedVarName', inputVarName, 'minValue');

            % 1. Initial snowCoverDays
            %-------------------------
            % Taken from the day preceding the date range (in the monthly
            % interp data file of the month before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0
            lastSnowCoverDays = 0.;

            if dateRange(1) ~= waterYearDate.getFirstDatetimeOfWaterYear()
                dateBefore = daysadd(dateRange(1) , -1);
                STCFile = espEnv.MosaicFile(obj.region, dateBefore);

                if isfile(STCFile)
                    STCData = load(STCFile, ouputVarName);
                    fprintf('%s: Loading %s from %s\n', ...
                            mfilename(), ouputVarName, STCFile);
                    if ~isempty(STCData) && ...
                        any(strcmp(fieldnames(STCData), ouputVarName))
                        lastSnowCoverDays = cast(STCData.(ouputVarName), 'single');
                    else
                        warning('%s: No %s variable in %s\n', ...
                            mfilename(), ouputVarName, STCFile);
                        lastSnowCoverDays = NaN;
                    end
                else
                    warning('%s: Missing mosaic file %s\n', mfilename(), ...
                        STCFile);
                    lastSnowCoverDays = NaN;
                end
            end

            % 2. Update each daily mosaic files for the full
            % period by calculating snow_cover_days from snow_fractions
            %----------------------------------------------------------
            for thisDateIdx=1:length(dateRange) % No parfor here.
                % 2.a. Loading of the monthly interpolation file
                %-----------------------------------------------
                STCFile = espEnv.MosaicFile(obj.region, dateRange(thisDateIdx));
                STCData = struct(inputVarName, []);
                if isfile(STCFile)
                    STCData = load(STCFile, inputVarName);
                end
                if isempty(STCData.(inputVarName))
                    warning('%s: Missing mosaic file %s or missing %s in it.\n', ...
                        mfilename(), STCFile, inputVarName);
                    lastSnowCoverDays = NaN;
                    continue;
                else
                    fprintf('%s: Loaded %s from %s.\n', ...
                            mfilename(), inputVarName, STCFile);
                end

                snowCoverFraction = STCData.(inputVarName); % type 'single' in STCCubde
                % 2.b. Below a certain elevation and fraction, the pixel is not
                % considered covered by snow
                %--------------------------------------------------------------
                snowCoverFraction(...
                    snowCoverFraction < ...
                    snow_cover_days_min_snow_cover_fraction & ...
                    snowCoverFraction ~= intmax(class(snowCoverFraction))) = 0;
                snowCoverFraction(...
                    elevation < snow_cover_days_min_elevation & ...
                    snowCoverFraction ~= intmax(class(snowCoverFraction))) = 0;
                    % Exclusion of no data pixels 2024-02-8.

                % 2.c. Cumulated snow cover days calculation and save
                %----------------------------------------------------
                snowCoverFractionWithoutNaN = snowCoverFraction;
                snowCoverFractionWithoutNaN( ...
                    snowCoverFraction == intmax(class(snowCoverFraction))) = 0;
                    % Correction of the number of days even for nodata when I changed
                    % the calculations from STC Cubes to Mosaics 2024-02-8.
                logicalSnowCoverFraction = cast( ...
                    logical(snowCoverFractionWithoutNaN), ...
                    'single');
                logicalSnowCoverFraction( ...
                    snowCoverFraction == intmax(class(snowCoverFraction))) = NaN;
                snow_cover_days = lastSnowCoverDays + logicalSnowCoverFraction;
                lastSnowCoverDays = snow_cover_days;
                snow_cover_days(isnan(snow_cover_days)) = snow_cover_days_nodata_value;
                    % 2024-02-08.
                snow_cover_days = cast(snow_cover_days, snow_cover_days_type);

                thisStruct = struct();
                suffixes = {'', '_divisor', '_units', '_min_elevation', ...
                    '_min_snow_cover_fraction', '_nodata_value'};
                for suffixId = 1:length(suffixes)
                    thisStruct.([outputVarName, suffixes{suffixId}]) = ...
                        eval(['snow_cover_days', suffixes{suffixId}]);
                end
                save(STCFile, '-struct', 'thisStruct', '-append');
                fprintf('%s: Saved %s to %s\n', mfilename(), outputVarName, ...
                    STCFile);
            end
            t2 = toc;
            fprintf('%s: Finished %s update in %s seconds\n', ...
                mfilename(), outputVarName, ...
                num2str(roundn(t2, -2)));
%}
        end

        function calcAlbedos(obj, waterYearDate)
            % Calculates clean and observed albedos on flat surface (mu0)
            % and on slopes (muZ) from snow_fraction, solar_zenith, solar_azimuth,
            % grain_size, deltavis, topographic slopes and aspect variables.
            % Updates the daily mosaic data files with the values.
            % Fields calculated: albedo_clean_mu0, albedo_observed_mu0,
            % albedo_clean_muZ, albedo_observed_muZ.
            % Albedos are NaN when snow_fraction or grain_size are NaN.
            %
            % Called by runSnowTodayStep2.sh / runUpdateMosaic.sh
            %
            % Parameters
            % ----------
            % waterYearDate: WaterYearDate object.
            %   Date and range of days before over which calculation
            %   should be carried out

            tic;
            fprintf('%s: Start albedos calculations\n', mfilename())

            % 1. Initialization, dates, slopes, aspects
            %------------------------------------------
            espEnv = obj.region.espEnv;
            dateRange = waterYearDate.getDailyDatetimeRange();

            [slope, ~, ~] = ...
                espEnv.getDataForObjectNameDataLabel(obj.region.regionName, 'slope');
            slope = cast(slope, 'double');
            [aspect, ~, ~] = ...
                espEnv.getDataForObjectNameDataLabel(obj.region.regionName, 'aspect');
            aspect = cast(aspect, 'double'); % Slope and aspect are input of cosd within ParBal.sunslope, which only accept double.

            albedoNames = {'albedo_clean_mu0'; 'albedo_clean_muZ'; ...
                'albedo_observed_mu0'; 'albedo_observed_muZ'};
            confOfVar = espEnv.configurationOfVariables();

            % 2. Update each daily mosaic files for the full
            % period by calculating albedos
            %-----------------------------------------------

            % Start or connect to the local pool (parallelism)
            espEnv.configParallelismPool();

            parfor dateIdx=1:length(dateRange)

                % 2.a collection of albedo types, units, divisors
                %    and min-max.
                %------------------------------------------------
                % NB: could have been set outside loop, but since we use a struct
                % within a parloop, it should stay her so as to not trigger transparency
                % error.

                albedos = struct();
                albedoConf = ''; % to prevent Uninitialized Temporaries matlab warning.
                for albedoIdx=1:length(albedoNames)
                    albedoName = albedoNames{albedoIdx};
                    albedoConf = confOfVar(find( ...
                        strcmp(confOfVar.output_name, albedoName)), :);
                    albedos.([albedoName '_type']) = albedoConf.type{1};
                    albedos.([albedoName '_units']) = albedoConf.units_in_map{1};
                    albedos.([albedoName '_divisor']) = albedoConf.divisor;
                    albedos.([albedoName '_min']) = albedoConf.min * albedoConf.divisor;
                    albedos.([albedoName '_max']) = albedoConf.max * albedoConf.divisor;
                    albedos.([albedoName '_nodata_value']) = albedoConf.nodata_value;
                end

                % 2.b. Loading the daily file
                % If snow_fraction is 0 or NaN, set the variables
                %  to NaN to get final albedos to NaN
                % convert all variables to double (and NaN) for
                % parBal package
                % Since Mosaic files are stored as int and the ParBal functions
                % use floats as input arguments, we
                % 1. cast the Mosaic data to the float type and
                %    replace no_data_value by NaNs,
                % 2. use the ParBal functions, and then
                % 3. replace the albedo NaNs by no_data_value and cast
                %    the albedos to integers.
                %----------------------------------------------
                errorStruct = struct();
                mosaicFile = espEnv.MosaicFile(obj.region, dateRange(dateIdx));

                if ~isfile(mosaicFile)
                    warning('%s: Missing mosaic file %s\n', mfilename(), ...
                        mosaicFile);
                    continue;
                end

                mosaicData = load(mosaicFile, 'deltavis', 'grain_size', ...
                    'snow_fraction', 'solar_azimuth', 'solar_zenith');
                if isempty(mosaicData)
                    warning('%s: No variables in %s\n', ...
                        mfilename(), mosaicFile);
                    continue;
                end

                mosaicFieldnames = fieldnames(mosaicData);
                nans = zeros(size(mosaicData.snow_fraction), 'uint8');
                for fieldIdx = 1:length(mosaicFieldnames)
                    fieldname = mosaicFieldnames{fieldIdx};
                    mosaicData.(fieldname) = cast(mosaicData.(fieldname), 'double');
                    if strcmp(fieldname, 'snow_fraction')
                        continue;
                    end
                    varInfos = confOfVar(find( ...
                        strcmp(confOfVar.output_name, fieldname)), :);
                    nans = nans | mosaicData.(fieldname) == varInfos.nodata_value;
                    mosaicData.(fieldname)(mosaicData.(fieldname) == ...
                        varInfos.nodata_value) = NaN;
                    mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                        Variables.uint8NoData | mosaicData.snow_fraction == 0) = NaN;
                end
                % Set to NaN of snow_fraction should be done after the other variables.
                fieldname = 'snow_fraction';
                varInfos = confOfVar(find( ...
                        strcmp(confOfVar.output_name, fieldname)), :);
                nans = nans | mosaicData.(fieldname) == varInfos.nodata_value;
                mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                    Variables.uint8NoData | mosaicData.snow_fraction == 0) = NaN;

                fprintf('%s: Loading snow_fraction and other vars from %s\n', ...
                        mfilename(), mosaicFile);

                % 2.c. Calculations of mu0 and muZ (cosinus of solar zenith)
                % considering a flat surface (mu0) or considering slope and
                % aspect (muZ)
                % + cap of grain size to max value accepted by parBal.spires
                % use of ParBal package: .sunslope and .spires_albedo.
                % spires_albedo needs no data values to be NaNs
                %-----------------------------------------------------------
                mu0 = cosd(mosaicData.solar_zenith);
                mu0(nans) = NaN;

                % phi0: Normalize stored azimuths to expected azimuths
                % stored data is assumed to be -180 to 180 with 0 at North
                % expected data is assumed to be +ccw from South, -180 to 180
                phi0 = 180. - mosaicData.solar_azimuth;
                phi0(phi0 > 180) = phi0(phi0 > 180) - 360;
                phi0(nans) = NaN;

                % Based on conversation with Dozier, Aug 2023:
                % N.B.: phi0 and aspect must be referenced to the same
                % angular convention for this function to work properly
                muZ = sunslope(mu0, phi0, slope, aspect);
                muZ(muZ > 1.0) = 1.0; % 2024-01-05, occasionally ParBal.sunslope()
                    % returns a few 10-16 higher than 1 (h24v05, 2011/01/08)
                    % Patch should be inserted in ParBal.sunslope().


                grainSizeForSpires = mosaicData.grain_size;
                grainSizeForSpires(grainSizeForSpires > ...
                    obj.albedoMaxGrainSize) = obj.albedoMaxGrainSize;
                grainSizeForSpires(grainSizeForSpires < ...
                    obj.albedoMinGrainSize) = obj.albedoMinGrainSize;

                % 2.d. Calculations of clean albedos, corrections to
                % obtain observed albedos
                % sanity check min-max, replacement for nodata and
                % recast to type and save
                %---------------------------------------------------
                albedos.albedo_clean_mu0 = spires_albedo(...
                    grainSizeForSpires, mu0, ...
                    obj.region.atmosphericProfile);
                albedos.albedo_clean_muZ = spires_albedo(...
                    grainSizeForSpires, muZ, ...
                    obj.region.atmosphericProfile);

                albedoObservedCorrection = (cast(mosaicData.deltavis, 'double') / ...
                    Variables.albedoDeltavisScale) * ...
                    Variables.albedoDownscaleFactor;

                albedos.albedo_observed_mu0 = albedos.albedo_clean_mu0 - ...
                    albedoObservedCorrection;
                albedos.albedo_observed_muZ = albedos.albedo_clean_muZ - ...
                    albedoObservedCorrection;

                for albedoIdx=1:length(albedoNames)
                    albedoName = albedoNames{albedoIdx};
					albedos.(albedoName) = albedos.(albedoName) * ...
						Variables.albedoScale * albedoConf.divisor;

                    if min(albedos.(albedoName), [], 'all') < albedos.([albedoName '_min']) ...
                    || max(albedos.(albedoName), [], 'all') > albedos.([albedoName '_max'])
                        errorStruct.identifier = 'Variables:RangeError';
                        errorStruct.message = sprintf(...
                            '%s: Calculated %s %s [%.3f,%.3f] out of bounds\n',...
                            mfilename, obj.region.regionName, ...
                            albedoName, [albedoName '_min'], [albedoName '_max']);
                        error(errorStruct);
                    end
                    albedos.(albedoName)(isnan(albedos.(albedoName))) = ...
                        albedos.([albedoName '_nodata_value']);
                    albedos.(albedoName) = cast(albedos.(albedoName), ...
                        albedos.([albedoName '_type']));
                end

                % 2.e. Save albedos and params in Mosaic Files
                %---------------------------------------------
                Tools.parforSaveFieldsOfStructInFile(mosaicFile, albedos, 'append');
                fprintf('%s: Saved albedo to %s\n', mfilename(), ...
                    mosaicFile);
            end

            t2 = toc;
            fprintf('%s: Finished albedos update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
