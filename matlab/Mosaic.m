classdef Mosaic
    % Handles the daily mosaic files that join tiles together
    % for an upper-level region and provide the values
    % for variables required to generate the data expected by the SnowToday
    % website
    properties
        region     % Regions object pointing to the upper-level region, e.g.
                    % westernUS
    end
    methods
        function obj = Mosaic(region)
            % Constructor
            %
            % Parameters
            % ----------
            % region: Regions object
            %
            % Return
            % ------
            % obj: Mosaic object
            obj.region = region;
        end
        function buildTileSet(obj, waterYearDate, dataLabel)
            % Generate the daily Mosaic files over several months of a waterYear by
            % assembling the daily tile Mosaic files. For instance, for 2023/1/2
            % westerUS, I assemble the Mosaics for 2023/1/2 of h08v04, h08v05, h09v04,
            % h09v05, h10v04.
            % NB: ends generation if a tile lacks for a day.
            % NB: Mosaic became ambiguous as it can mean the type of dataset (here) or
            % the assembly of tiles / tileset.
            %
            % Parameters
            % ----------
            % dataLabel: char. E.g. VariablesMatlab (classic), modspiresdaily
            %     (for spires > v2024.0f).
            % 1. Initialize.
            fprintf(['%s: Start Mosaic tileset generation for waterYearDate', ...
                ' %s - %d, dataLabel %s...\n'], ...
                    mfilename(), string(waterYearDate.thisDatetime, 'yyyyMMdd'), ...
                    waterYearDate.monthWindow, dataLabel);
            espEnv = obj.region.espEnv;
            espEnv.configParallelismPool(10);
            dateRange = waterYearDate.getDailyDatetimeRange();

            objectName = obj.region.name;
            varName = '';
            complementaryLabel = '';

            % 2. Build tileset for the big region for each day of waterYearDate,
            % with stop when a tile isn't available.
            parfor dateIdx = 1:length(dateRange)
                % 2.1. Information on date, tile and region filepaths,
                % mapCellsReferences.
                thisDate = dateRange(dateIdx);
                filePath = espEnv.getFilePathForDateAndVarName(objectName, ...
                    dataLabel, thisDate, varName, complementaryLabel);
                % espEnv.MosaicFile(obj.region, thisDate); obsolete 20241008.
                mapCellsReference = obj.region.getMapCellsReference();
                tileRegions = obj.region.getTileRegions();
                tileFilePaths = {};
                tileMapCellsReferences = map.rasterref.MapCellsReference.empty();
                for tileIdx = 1:length(tileRegions)
                    tileRegion = tileRegions(tileIdx);
                    tileObjectName = tileRegion.name;
                    tileFilePaths{tileIdx} = espEnv.getFilePathForDateAndVarName( ...
                        tileObjectName, dataLabel, thisDate, varName, ...
                        complementaryLabel);
                    % tileFilePaths{tileIdx} = espEnv.MosaicFile(tileRegion, thisDate); obsolete 20241008.
                    tileMapCellsReferences(tileIdx) = tileRegion.getMapCellsReference();
                end

                % 2.2. Generation of the Mosaic tileset.
                tileSetIsGenerated = Tools.buildTileSet(tileFilePaths, ...
                    tileMapCellsReferences, filePath, mapCellsReference);
                if tileSetIsGenerated == 0
                    warning('%s: No tileset for %s.\n', mfilename(), ...
                        string(thisDate - 1, 'yyyyMMdd'));
                    %break; parfor doesn't accept break.
                end
            end
            fprintf(['%s: Done Mosaic tileset generation for waterYearDate', ...
                '%s - %d...\n'], ...
                    mfilename(), string(waterYearDate.thisDatetime, 'yyyyMMdd'), ...
                    waterYearDate.monthWindow);
        end
        function delete(obj, waterYearDate)
            % Erase all mosaic files for a waterYearDate to regenerate them.
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object. Period for which to erase the files.
            espEnv = obj.region.espEnv;
            objectName = obj.region.name;
            dataLabel = 'VariablesMatlab';
            theseDates = waterYearDate.getDailyDatetimeRange();
            varName = '';
            complementaryLabel = '';
            fprintf('%s: Deleting mosaic daily .mat files for %s, %s...\n', ...
                mfilename(), objectName, waterYearDate.toChar());
            parfor dateIdx = 1:length(theseDates)
                thisDate = theseDates(dateIdx);
                fprintf('%s: Handling %s...\n', ...
                        mfilename(), string(thisDate, 'yyyy-MM-dd'));
                [filePath, fileExists, ~] =  ...
                    espEnv.getFilePathForDateAndVarName(objectName, dataLabel, ...
                    thisDate, varName, complementaryLabel);
                if fileExists
                    delete(filePath);
                    fprintf('%s: Deleted %s...\n', mfilename(), filePath);
                end
            end
            fprintf('%s: Deleted mosaic daily .mat files for %s, %s.\n', ...
                mfilename(), objectName, waterYearDate.toChar());
        end
        function writeSolarData(obj, waterYearDate)
            fprintf(['%s: Starting solar data mosaic .mat generation/writing for ', ...
                'region %s, date %s...\n'], ...
                mfilename(), obj.region.name, waterYearDate.toChar());

            espEnv = obj.region.espEnv;

            % For solar_azimuth and zenith environment, we get the data from v2023.0e mosaics.
            modisData = MODISData(label = 'v2023.0e', versionOfAncillary = 'v3.1');
            espEnv2023 = ESPEnv(modisData = modisData, scratchPath = espEnv.scratchPath);

            solVarNames = {'solar_zenith', 'solar_azimuth'};
            varMetadataNames = {'type', 'units', 'multiplicator_for_mosaics', ...
                'divisor', 'min', 'max', 'nodata_value'};
            objectName = obj.region.name;
            dataLabel = 'VariablesMatlab';
            thisDate = '';
            varName = '';
            complementaryLabel = '';

            % espEnv.configParallelismPool(10);

                % NB: Uncomment above when you want to use parallelization
                % using parfor loop below to launch several days in parallel.
                % You can replace 10 by the number of days you want to have in
                % parallel. Beware
                % the more in parallel, the more you'll consume memory and you may
                % have concurrent access to files.
                % NB: I'm not certain if this work for simultaneous read access to the
                % same .h5 file.

            % For each day of waterYearDate, we get the solar_azimuth and zenith
            % from v2023.0e mosaic .mat (only works for westernUS and 2000-2023/09),
            % then the variables in the spires water year output .h5 file,
            % save the variables in v2024.0 mosaic .mat file, we calculate albedo
            % and similarly save it.
            %---------------------------------------------------------------------------
            theseDates = waterYearDate.getDailyDatetimeRange();
            try
                parfor dateIdx = 1:length(theseDates)
                    % Here we may replace for by parfor loop to benefit from matlab
                    % parallel computing
                    thisDate = theseDates(dateIdx);
                    varName = '';
                    [outFilePath, fileExists, ~] = ...
                        espEnv.getFilePathForDateAndVarName(objectName, ...
                        dataLabel, thisDate, varName, complementaryLabel);
                    fprintf(['%s: Starting file %s...\n'], mfilename(), outFilePath);
                    appendFlag = 'append';
                    if ~fileExists
                        appendFlag = 'new_file';
                    end

                    % Get and save solar variables and metadata...
                    %-----------------------------------------------------------------------
                    [filePath, fileExists, ~] = espEnv2023.getFilePathForDateAndVarName( ...
                            objectName, dataLabel, thisDate, varName, complementaryLabel);
                    if ~fileExists
                        thisException = MException('Mosaic:nov20230efile', ...
                            sprintf(['%s: writeSolarDataInMosaics: ', ...
                            'No v2023.0e file %s. ', ...
                            'Generate or sync them to scratch and rerun.\n'], ...
                            mfilename(), filePath));
                        throw(ME);
                    end
                    varData = struct();
                    for varIdx = 1:length(solVarNames)
                        varName = solVarNames{varIdx};
                        varData.(varName) = espEnv2023.getDataForDateAndVarName( ...
                            objectName, dataLabel, thisDate, varName, complementaryLabel);
                        for metadataIdx = 1:length(varMetadataNames)
                            varMetadataName = [varName, '_', varMetadataNames{metadataIdx}];
                            varData.(varMetadataName) = ...
                                load(filePath, varMetadataName).(varMetadataName);
                        end
                    end
                    Tools.parforSaveFieldsOfStructInFile(outFilePath, ...
                            varData, appendFlag);
                    appendFlag = 'append';
                    fprintf(['%s: Saved solar variables and metadata in %s.\n'], ...
                        mfilename(), outFilePath);
                    varData.solar_azimuth = [];
                end
            catch(thatException)
                errorStruct.identifier = ...
                    thatException.identifier;
                errorStruct.message = thatException.message;
                error(errorStruct);
            end
            fprintf(['%s: Done solar data mosaic .mat generation/writing for ', ...
                'region %s, date %s...\n'], ...
                mfilename(), obj.region.name, waterYearDate.toChar());
        end
        function writeFiles(obj, waterYearDate, availableVariables)
            % Generate and write the mosaic files over several months of a waterYear
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object
            %   waterYearDate for which generating the mosaics.
            % availableVariables: array of cells
            %   list of information about the variables to include in the mosaics
            %   filtered from the data obtained by espEnv.configurationOfVariables.
            % NB: 2023/07/11: I tried to reduce memory consumption through
            % a quick and dirty
            % @todo
            %
            % NB: Generation restricted to a per tile basis and not full mosaic any
            % more for v2023.0, because of the collect of gap files. 2025-01-17.

            % 1. Initialize
            %--------------
            tic;
            fprintf('%s: Start mosaic generation and writing\n', mfilename());
            espEnv = obj.region.espEnv;
            modisData = obj.region.modisData;
            region = obj.region;
            regionName = obj.region.regionName;

            % Array of the tile regions that compose the upper-level region
            tileRegionsArray = obj.region.getTileRegions();

            varIndexes = 1:size(availableVariables, 1);
            for varIdx=varIndexes
                varNameInfos = availableVariables(varIdx, :);
                varNames{varIdx} = varNameInfos.('output_name'){1};
                varIds(varIdx) = varNameInfos.('id')(1);
            end

            % 2. Convert monthly STC data into daily Mosaic data and save
            %------------------------------------------------------------
            monthRange = waterYearDate.getMonthlyFirstDatetimeRange();

            % Start or connect to the local pool (parallelism)
            % Trial and error: this process is a real memory pig
            espEnv.configParallelismPool(5);
            missingFileFlags = zeros(size(monthRange), 'uint8');
            parfor monthDatetimeIdx = 1:length(monthRange)
                % 2.1. Initialize the parfor variables
                %------------------------------------
                monthDatetime = monthRange(monthDatetimeIdx);
                fprintf('%s: Starting mosaic for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));
                % Stores data that will be saved in Mosaic files
                mosaicData = struct();
                % Stores data necessary to assemble the Mosaic from
                % the tiles (matrix assembly).
                mosaicDataForAllDays = struct();
                % Stores individual info on tiles to handle them before
                % assembly
                tileData = struct();

                % 2.2. Check that all tiles have the monthly STC file
                % And construct the list of days that have data on all tiles
                % and for which mosaic files could be generated.
                %
                % NB: Because of the way the STC cubes are constructed: if a
                % tile STC file exist, all days within it are continuous. The
                % last day present in the STC file is the last observation day.
                % Then if tile STC files A and B have 3 and 5 number of days
                % for the same month, it implies that the last observation in A
                % is the 3rd day of the month and the last in B is the 5th day
                % of the month. Then, only the mosaic files for the first 3 days
                % of the month will be constructed.
                %---------------------------------------------------------------
                if  month(monthDatetime) == month(waterYearDate.thisDatetime)
                    dayRange = monthDatetime:waterYearDate.thisDatetime;
                else
                    dayRange = monthDatetime:datetime(year( ...
                    monthDatetime), month(monthDatetime) + 1, 1) - days(1);
                end

                for tileId = 1:length(tileRegionsArray)
                    tileRegions = tileRegionsArray(tileId);
                    tileSTCFile = espEnv.SCAGDRFSFile(...
                        tileRegions, 'SCAGDRFSSTC', monthDatetime);
                    mosaicData.files{tileId, 1} = tileRegions.regionName;
                    mosaicData.files{tileId, 2} = tileSTCFile;
                    if ~isfile(tileSTCFile)
                        warning(['%s: Missing interp STC file %s. Mosaic files' ...
                            ' not generated for this month.\n'], mfilename(), ...
                            tileSTCFile);
                        missingFileFlags(monthDatetimeIdx) = 1;
                        break;
                    end
                    tileDatetimes = datetime(load(tileSTCFile, 'datevals').datevals, ...
                        'ConvertFrom', 'datenum');
                    if daysdif(tileDatetimes(end), dayRange(end)) > 0
                        dayRange = dayRange(1):tileDatetimes(end);
                    end
                end
                if missingFileFlags(monthDatetimeIdx)
                    continue;
                end
                fprintf('%s: Got list of files mosaic for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));
                % Map projection information
                obj.region.espEnv.modisData.setModisSensorConfForSTC();
                mosaicData.mstruct = obj.region.espEnv.modisData.mstruct;

                % 2.2b. Extract gap viewable_snow_fraction to get initial
                % viewable_snow_fraction_status for 2000-2022 data v2023.0 -> v2023.0e.
                % 2025-01-17.
                if ismember(modisData.versionOf.VariablesMatlab, ...
                    {'v2023.0e', 'v2023.0.1'}) && ...
                    strcmp(modisData.versionOf.SCAGDRFSSTC, 'v2023.0')
                    if length(tileRegionsArray) ~= 1
                        error('Mosaic:gapFileOnlyForOneTile', ...
                        ['Generation of .mat files with Mosaic.WriteFiles() has', ...
                        'been restricted to single tiles.\n']);
                    end
                    objectName = regionName;
                    dataLabel = 'SCAGDRFSGap';
                    thisDate = monthDatetime;
                    complementaryLabel = '';
                    varName = 'viewable_snow_fraction';
                    gapFilePath = espEnv.getFilePathForDateAndVarName( ...
                        objectName, dataLabel, thisDate, varName,...
                        complementaryLabel);
                    gapIsNoData = isnan(espEnv.getDataForDateAndVarName( ...
                        objectName, dataLabel, thisDate, varName,...
                        complementaryLabel));
                    gapDates = load(gapFilePath, 'datevals').datevals;
                    gapDates = datetime(gapDates, ConvertFrom = 'datenum');
                    gapIsNoData = ...
                        gapIsNoData(:, :, ...
                        month(gapDates) == month(monthDatetime));
                    % Some gap files have missing days, we need to incorporate them...
                    gapDates = gapDates(month(gapDates) == month(monthDatetime));
                    expectedDates = monthDatetime:datetime(year(monthDatetime), ...
                        month(monthDatetime), eomday(year(monthDatetime), ...
                        month(monthDatetime)));
                    if length(gapDates) ~= length(expectedDates)
                        isNoData = ones([size(gapIsNoData, 1), ...
                            size(gapIsNoData, 2), length(expectedDates)], 'logical');
                        [expectedDateIsOK, idxInGapDates] = ...
                            ismember(expectedDates, gapDates);
                        firstDateIdx = -1;
                            % this idx helps to handle start of record with missing day.
                        for dateIdx = 1:length(expectedDates)
                            if expectedDateIsOK(dateIdx) == 1
                                if firstDateIdx == -1
                                    firstDateIdx = dateIdx;
                                end
                            elseif firstDateIdx ~= -1
                                isNoData(:, :, firstDateIdx:(dateIdx - 1)) = ...
                                    gapIsNoData(:, :, ...
                                    idxInGapDates(firstDateIdx:(dateIdx - 1)));
                                firstDateIdx = -1;
                            end
                        end
                        if firstDateIdx ~= -1
                            isNoData(:, :, firstDateIdx:dateIdx) = ...
                                gapIsNoData(:, :, ...
                                idxInGapDates(firstDateIdx:dateIdx));
                        end
                    else
                        isNoData = gapIsNoData;
                        gapIsNoData = [];
                    end
                end % if strcmp(modisData.versionOf.VariablesMatlab, 'v2023.0e') && ...
                    % (modisData.versionOf.SCAGDRFSSTC, 'v2023.0')

                % 2.3. Collect individual tile information (RefMatrix, rowNb,
                %  colNb) to construct the regional RefMatrix of the Mosaic
                % (previously BigRMap).
                % NB: RefMatrix is deprecated in Matlab and should be replaced
                % by another object.
                %-------------------------------------------------------------
                tileData.RefMatrices = zeros(length(tileRegionsArray), 3, 2);
                tileData.sizes = zeros(length(tileRegionsArray), 2);
                tileData.lr = zeros(length(tileRegionsArray), 2); % check what is exactly lr

                for tileId = 1:length(tileRegionsArray)
                    tileSTCFile = mosaicData.files{tileId, 2};
                    tileSTCData = matfile(tileSTCFile);

                    tileData.RefMatrices(tileId, :, :) = tileSTCData.RefMatrix;
                    tileData.sizes(tileId, :) = [size(tileSTCData, 'snow_fraction', 1) ...
                        size(tileSTCData, 'snow_fraction', 2)];
                    tileData.lr(tileId, :) = [tileData.sizes(tileId, :) 1] * ...
                        squeeze(tileData.RefMatrices(tileId, :, :));

                    % This indirection is due to matfile 7.3 limitation
                    % It won't allow us to directly index into
                    % structure fields
                    % thisSTC = tileRegionsArray(tileId).STC;                  @obsolete
                    if ismember('stcStruct', fieldnames(tileSTCData))
                        mosaicData.stcStruct(tileId) = tileSTCData.stcStruct; % new, 2023-11-09.
                    elseif ismember('STC', fieldnames(tileSTCData))
                        warning('off', 'MATLAB:structOnObject');
                        mosaicData.stcStruct(tileId) = struct(tileSTCData.STC);
                            % 2023-12-29, to use v2023.0 STC for westernUS v2023.0e
                            % for 2001-2022 waterYears.
                        warning('on', 'MATLAB:structOnObject');
                    end
                    mosaicData.mindays(tileId) = {mosaicData.stcStruct(tileId).mindays};
                    mosaicData.zthresh(tileId) = {mosaicData.stcStruct(tileId).zthresh};
                end
                fprintf('%s: Got first metadata for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));
                warning('off', 'MATLAB:structOnObject');
                mosaicData.stcStruct = mosaicData.stcStruct(1); % 2023-11-09, was formerly struct(region.STC); % SIER_289
                    % This changed after the inline possibility to override the stc conf
                    % of the region in bash runUpdateSTCMonthCubes.sh
                warning('on', 'MATLAB:structOnObject');
                mosaicData.RefMatrix = zeros(3,2);
                mosaicData.RefMatrix(3, 1) = min(tileData.RefMatrices(:, 3, 1));
                mosaicData.RefMatrix(2, 1) = tileData.RefMatrices(1, 2, 1); % pixel size
                mosaicData.RefMatrix(1, 2) = tileData.RefMatrices(1, 1, 2); % pixel size
                mosaicData.RefMatrix(3, 2) = max(tileData.RefMatrices(:, 3, 2));

                mosaicXy = [max(tileData.lr(:, 1)) min(tileData.lr(:, 2))];
                [mosaicRowNb, mosaicColNb] = map2pix(mosaicData.RefMatrix, mosaicXy);
                 % previously sBig
                 % NB: map2pix is a deprecated function

                % 2.4. Metadata of Variables and initialization of the assembly matrix
                % mosaicDataForAllDays to type int and no data values
                %---------------------------------------------------------------------
                for varIdx=varIndexes
                    varNameInfosForVarIdx = availableVariables(varIdx, :);
                    varName = varNames{varIdx};
                    mosaicData.([varName '_type']) = ...
                        varNameInfosForVarIdx.type{1};
                    mosaicData.([varName '_units']) = ...
                        varNameInfosForVarIdx.unit{1};
                    mosaicData.([varName '_multiplicator_for_mosaics']) = ...
                        varNameInfosForVarIdx.multiplicator_for_mosaics;
                    mosaicData.([varName '_divisor']) = varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_min']) = varNameInfosForVarIdx.min * ...
                        varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_max']) = varNameInfosForVarIdx.max * ...
                        varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_nodata_value']) = ...
                        varNameInfosForVarIdx.nodata_value;
                    % Set mosaicDataForAllDays.viewable_snow_fraction_status for v2023.0.
                    % 2023-12-29.
                    % 2024-03-21. Replace initialization to unavailable by initialization to
                    %   temporary (= unknown). These temporary should be not included in the
                    %   count of days without observation
                    if strcmp(varName, 'viewable_snow_fraction_status')
                        thisDefaultValue = Variables.dataStatus.temporary;
                    else
                        thisDefaultValue = mosaicData.([varName '_nodata_value']);
                    end
                    mosaicDataForAllDays.(varName) = ...
                        thisDefaultValue * ...
                        ones(round([mosaicRowNb, mosaicColNb, ...
                            eomday(year(monthDatetime), month(monthDatetime))]), ...
                            varNameInfosForVarIdx.type{1});
                end
                % Update viewable_snow_fraction_status for v2023.0 -> v2023.0e.
                % 2025-01-17.
                if ismember(modisData.versionOf.VariablesMatlab, ...
                    {'v2023.0e', 'v2023.0.1'}) && ...
                    strcmp(modisData.versionOf.SCAGDRFSSTC, 'v2023.0')
                    mosaicDataForAllDays.('viewable_snow_fraction_status') = ...
                        uint8(isNoData) * Variables.dataStatus.noObservation + ...
                        uint8(~isNoData) * Variables.dataStatus.observed;
                    isNoData = [];
                end
                fprintf('%s: Got variable metadata for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));

                % 2.5. Insert the tile data values at the right position in the mosaic
                % with replacement of NaN by nodata_value and cast to int type
                %---------------------------------------------------------------------
                for tileId = 1:length(tileRegionsArray)
                    [tileX, tileY] = pix2map(squeeze(tileData.RefMatrices(tileId, :, :)), ...
                        [1 tileData.sizes(tileId, 1)], ...
                        [1 tileData.sizes(tileId, 2)]);
                    [tileRow, tileCol] = map2pix(mosaicData.RefMatrix, tileX, tileY);
                    tileRow = round(tileRow);
                    tileCol = round(tileCol);

                    tileSTCFile = mosaicData.files{tileId, 2};
                    tileSTCData = matfile(tileSTCFile);
                    tileSTCFieldnames = fieldnames(tileSTCData);
                    for varIdx = varIndexes
                        varNameInfosForVarIdx = availableVariables(varIdx, :);
                        varName = varNames{varIdx};
                        if ~ismember(varName, tileSTCFieldnames)
                            warning('%s: Missing variable %s in interp STC file %s\n', ...
                                mfilename(), varName, tileSTCFile);
                            continue;
                        end
                        varSTCData = tileSTCData.(varName) * ...
                            mosaicData.([varName '_multiplicator_for_mosaics']);
                        varSTCData(isnan(varSTCData)) = ...
                            mosaicData.([varName '_nodata_value']);
                        mosaicDataForAllDays.(varName)(tileRow(1):tileRow(2), ...
                                tileCol(1):tileCol(2), ...
                                1:size(varSTCData, 3)) = ...
                            cast(varSTCData, varNameInfosForVarIdx.type{1});
                        varSTCData = [];
                    end
                end
                fprintf('%s: Got data for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));

                % 2.6. Thresholding
                %------------------
                % NB: Thresholds must be ordered with viewable_snow_fraction first.
                thresholds = region.thresholdsForMosaics( ...
                    strcmp(region.thresholdsForMosaics.lineName, ''), :);
                for thresholdId = 1:size(thresholds, 1)
                    thresholdedVarname = thresholds{thresholdId, 'thresholded_varname'}{1};
                    thresholdValue = thresholds{thresholdId, 'threshold_value'};
                    replacedVarname = thresholds{thresholdId, 'replaced_varname'}{1};
                    valueForUnreliableData = availableVariables{ ...
                        find(strcmp(availableVariables.output_name, replacedVarname)), ...
                        'value_for_unreliable'};
                    if isempty(valueForUnreliableData)
                        continue;
                    end
                        % 2023-12-07: case when thresholded variable is not in the
                        % variables to be included in the mosaic (e.g. albedos).
                    isLow = mosaicDataForAllDays.(thresholdedVarname) ...
                        < thresholdValue & ...
                        mosaicDataForAllDays.(thresholdedVarname) ~= 0;
                    mosaicDataForAllDays.(replacedVarname)(isLow) = ...
                        valueForUnreliableData;

                    if thresholdValue > 0
                        mosaicDataForAllDays.(replacedVarname) ...
                            (mosaicDataForAllDays.(thresholdedVarname) == 0) = ...
                            valueForUnreliableData;
                    end
                      % 2025-02-05. Added after observed differences in snow_fraction
                      % between v2023.0 and v2023.0.1. But didn't change dynamics for
                      % setting viewable_snow_fraction_status flag.
                      
                    % SIER_151 viewable_snow_fraction_status
                    if strcmp(replacedVarname, 'viewable_snow_fraction')
                        mosaicDataForAllDays.viewable_snow_fraction_status ...
			                (isLow & ismember( ...
                                mosaicDataForAllDays.viewable_snow_fraction_status, ...
                                [Variables.dataStatus.observed, ...
                                    Variables.dataStatus.temporary])) = ...
                                Variables.dataStatus.lowValue;
                    end
                end
                fprintf('%s: Filtered data for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));

                % 2.7. Generate and write the daily Mosaic Files
                %-----------------------------------------------
                % Split loop in two loops to reduce memory consumption 2023/07/11.
                % I did a quick and dirty                                          @todo
                for dayIdx = 1:length(dayRange)
                    thisDatetime = dayRange(dayIdx);
                    mosaicFile = espEnv.MosaicFile(region, thisDatetime);
                    mosaicData.dateval = datenum(thisDatetime) + 0.5;
                    % NB: Because of a 'Transparency violation error.' occuring
                    % with the upper-level
                    % parfor loop, it is required to save the mosaic files using
                    % another function (in our Tools package).
                    Tools.parforSaveFieldsOfStructInFile(mosaicFile, ...
                        mosaicData, 'new_file');
                    fprintf('%s: Saved base mosaic data to %s\n', mfilename(), ...
                        mosaicFile);
                end
                fprintf('%s: Saved minimal mosaic files for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));

                % Add filter for high solar zenith angle 2023-12-28 v2023.0e, v2023.1a-d.
                maxSolarZenithAngle = Tools.valueInTableForThisField( ...
                    obj.region.filter.mosaic, ...
                    'lineName', 'AngleAboveWhichToApplySolarZenithMask', ...
                    'minValue');

                if maxSolarZenithAngle <= 90
                    fprintf('%s: Update status if solar zenith above %0.1f...\n', ...
                        mfilename(), maxSolarZenithAngle);
                    solarZenithIsNotOK = ...
                        (mosaicDataForAllDays.('solar_zenith') > maxSolarZenithAngle);
                            % NB: No use to filter the nodata values here.
                    mosaicDataForAllDays.('viewable_snow_fraction_status') ...
                        (ismember( ...
                            mosaicDataForAllDays.('viewable_snow_fraction_status'), ...
                            [Variables.dataStatus.observed, ...
                                Variables.dataStatus.highSolarZenith, ...
                                Variables.dataStatus.temporary]) & ...
                            solarZenithIsNotOK) = ...
                        Variables.dataStatus.highSolarZenith;
                            % NB: there should be no observed.                @toimprove
%{
                    % 2024-03-21. We don't set to nodata when high solar zenith.
                    %   no data will be set in a another method, based on the number of
                    %   days without observation.
                    for varIdx = varIndexes
                        varId = varIds(varIdx);
                        varName = varNames{varIdx};
                        if ~ismember(varId, [13, 14, 46])
                            % exclude solar zenith/azimuth and
                            % viewable_snow_fraction_status
                            mosaicDataForAllDays.(varName)(solarZenithIsNotOK) = ...
                                mosaicData.([varName '_nodata_value']);
                        end
                    end
%}
                    solarZenithIsNotOK = []; % Cannot use clear in the parfor context.
                end

                % Add filter for anomalous solar zenith angle = 0 on pixels without
                % observed data.
                % 2024-01-09 v2023.0e, v2023.1a-d.
                minSolarZenithDiffBetweenZeroAndNextMin = ...
                    Tools.valueInTableForThisField( ...
                        obj.region.filter.mosaic, 'lineName', ...
                        'ApplySolarZenithMaskWhenDiffZeroAngleAndNextMinimum', ...
                        'minValue');

                if minSolarZenithDiffBetweenZeroAndNextMin <= 90
                    fprintf(['%s: Set to no data if solar zenith = 0 and next ', ...
                        'minimum value above %0.1f...\n'], ...
                        mfilename(), minSolarZenithDiffBetweenZeroAndNextMin);
                    solarZenithUniques = unique(mosaicDataForAllDays.('solar_zenith'));
                    if (length(solarZenithUniques) == 1 & ...
                        solarZenithUniques(1) == 0) | ...
                        (length(solarZenithUniques) ~= 1 & ...
                        solarZenithUniques(1) == 0 & ...
                        solarZenithUniques(2) - solarZenithUniques(1) >= ...
                        minSolarZenithDiffBetweenZeroAndNextMin)
                        solarZenithIsNotOK = ...
                            (mosaicDataForAllDays.('solar_zenith') == 0 & ...
                            ismember( ...
                            mosaicDataForAllDays.('viewable_snow_fraction_status'), ...
                            [Variables.dataStatus.observed, ...
                                Variables.dataStatus.temporary, ...
                                Variables.dataStatus.unavailable]));
                                % NB: No use to filter the nodata values here.
                        mosaicDataForAllDays.('viewable_snow_fraction_status') ...
                            (solarZenithIsNotOK) = ...
                            Variables.dataStatus.unknownSolarZenith;
%{
                        % @obsolete. 2025/01/10. Set to no value when solar zenith is
                        % not ok.
                        for varIdx = varIndexes
                            varId = varIds(varIdx);
                            varName = varNames{varIdx};
                            if ~ismember(varId, [46])
                                % exclude viewable_snow_fraction_status
                                mosaicDataForAllDays.(varName)(solarZenithIsNotOK) = ...
                                    mosaicData.([varName '_nodata_value']);
                            end
                        end
%}
                        solarZenithIsNotOK = []; % Cannot use clear in the parfor context.
                    end % if (length(solarZenithUniques) == 1 & ...
                end % if minSolarZenithDiffBetweenZeroAndNextMin <= 90

                % Add filter for false positives (dry lakes for low season).
                % 2023-12-28 v2023.0e, v2023.1a-d.
                firstMonthForFalsePositiveManualMaskInLowSeason = ...
                    Tools.valueInTableForThisField( ...
                        obj.region.filter.mosaic, ...
                        'lineName', 'applyFalsePositiveManualMaskInLowSeason', ...
                        'minValue');
                lastMonthForFalsePositiveManualMaskInLowSeason = ...
                    Tools.valueInTableForThisField( ...
                        obj.region.filter.mosaic, ...
                        'lineName', 'applyFalsePositiveManualMaskInLowSeason', ...
                        'maxValue');
                if firstMonthForFalsePositiveManualMaskInLowSeason ~= 0 & ...
                    ~isnan(lastMonthForFalsePositiveManualMaskInLowSeason)
                    if (month(monthDatetime) >= ...
                        firstMonthForFalsePositiveManualMaskInLowSeason & ...
                       month(monthDatetime) <= ...
                       lastMonthForFalsePositiveManualMaskInLowSeason)
                        fprintf('%s: Apply false positive mask...\n', mfilename());
                        falsePositive = espEnv.getDataForObjectNameDataLabel( ...
                            regionName, 'falsepositive');
                        falsePositive = repmat(falsePositive, [1, 1, ...
                            size(mosaicDataForAllDays. ...
                            ('viewable_snow_fraction_status'), 3)]);
                        falsePositive = ...
                            ismember( ...
                            mosaicDataForAllDays.('viewable_snow_fraction_status'), ...
                            [Variables.dataStatus.observed, ...
                                Variables.dataStatus.temporary]) & falsePositive;
                        mosaicDataForAllDays.('viewable_snow_fraction_status') ...
                            (falsePositive) = ...
                                Variables.dataStatus.falsePositive;
                        for varIdx = varIndexes
                            varId = varIds(varIdx);
                            varName = varNames{varIdx};
                            if ismember(varId, [36, 40]) % snow_fraction(s).
                                mosaicDataForAllDays.(varName)(falsePositive) = 0;
                            elseif ~ismember(varId, [13, 14, 46])
                                mosaicDataForAllDays.(varName)(falsePositive) = ...
                                    mosaicData.([varName '_nodata_value']);
                            end
                        end
                        falsePositive = [];
                    end
                end

                for dayIdx = 1:length(dayRange)
                    mosaicData = struct(); % dirty way to reduce memory consumption 2023/07/11 @todo
                    thisDatetime = dayRange(dayIdx);
                    mosaicFile = espEnv.MosaicFile(region, thisDatetime);

                    for varIdx = varIndexes
                        mosaicData = struct(); % dirty way to reduce memory consumption 2023/07/11 @todo
                        varName = varNames{varIdx};
                        mosaicData.(varName) = ...
                            mosaicDataForAllDays.(varName)(:, :, dayIdx);
                        % NB: Because of a 'Transparency violation error.' occuring
                        % with the upper-level
                        % parfor loop, it is required to save the mosaic files using
                        % another function (in our Tools package).
                        Tools.parforSaveFieldsOfStructInFile(mosaicFile, ...
                            mosaicData, 'append');
                    end
                    fprintf('%s: Saved variables in mosaic data to %s\n', mfilename(), ...
                        mosaicFile);
                end
                fprintf('%s: Saved mosaic for %s\n', mfilename(), ...
                    char(monthDatetime, 'yyyy-MM-dd'));
            end % end parfor
            t2 = toc;
            fprintf('%s: Finished mosaic generation and writing in %s seconds.\n', ...
                mfilename(), num2str(roundn(t2, -2)));
            if sum(missingFileFlags)
                errorStruct.identifier = 'Mosaic:MissingFiles';
                errorStruct.message = sprintf( ...
                    '%s: One or more missing STC file.\n', mfilename());
                error(errorStruct);
            end
        end
        function writeSpiresData(obj, waterYearDate, inputDataLabel, ...
            outputDataLabel)
            % inputDataLabel: char. E.g. modisspiressmoothbycell.
            % outputDataLabel: char. E.g. VariablesMatlab, modspiresdaily.

            espEnv = obj.region.espEnv;
            fprintf(['%s: Starting mosaic .mat generation/writing for ', ...
                'region %s, date %s...\n'], ...
                mfilename(), obj.region.name, waterYearDate.toChar());
            % inputDataLabel = 'modisspiressmoothbycell';
            % outputDataLabel = 'VariablesMatlab';
            [outputVariable, ~] = espEnv.getVariable(outputDataLabel, ...
              inputDataLabel = inputDataLabel);

            varMetadataNames = {'type', 'units', 'multiplicator_for_mosaics', ...
                'divisor', 'min', 'max', 'nodata_value'};
            objectName = obj.region.name;
            thisDate = '';
            varName = '';
            complementaryLabel = '';

            [elevation, ~, ~] = ...
                espEnv.getDataForObjectNameDataLabel( ...
                obj.region.name, 'elevation');
            % NB: if you need slope and aspect, you can use the same method replacing
            % 'elevation' by 'slope' or 'aspect'.

            % espEnv.configParallelismPool(10);

                % NB: Uncomment above when you want to use parallelization
                % using parfor loop below to launch several days in parallel.
                % You can replace 10 by the number of days you want to have in
                % parallel. Beware
                % the more in parallel, the more you'll consume memory and you may
                % have concurrent access to files.
                % NB: I'm not certain if this work for simultaneous read access to the
                % same .h5 file.

            % For each day of waterYearDate, we get the solar_azimuth and zenith
            % from v2023.0e mosaic .mat (only works for westernUS and 2000-2023/09),
            % then the variables in the spires water year output .h5 file,
            % save the variables in v2024.0 mosaic .mat file, we calculate albedo
            % and similarly save it.
            %---------------------------------------------------------------------------
            theseDates = waterYearDate.getDailyDatetimeRange();
            parfor dateIdx = 1:length(theseDates)
                % Here we may replace for by parfor loop to benefit from matlab
                % parallel computing
                dataLabel = outputDataLabel;
                thisDate = theseDates(dateIdx);
                varName = '';
                [outFilePath, fileExists, ~] = ...
                    espEnv.getFilePathForDateAndVarName(objectName, ...
                    dataLabel, thisDate, varName, complementaryLabel);
                fprintf(['%s: Starting file %s...\n'], mfilename(), outFilePath);
                appendFlag = 'append';
                if ~fileExists
                    if ismember(outputDataLabel, {'modspiresdaily', 'vnpspiresdaily'})
                        if dateIdx < length(theseDates) - 6
                            error('Mosaic:NoSpiresDailyFile', ...
                                sprintf(['%s: No %s file %s. ', ...
                                'Generate or sync them to scratch and rerun.\n'], ...
                                mfilename(), outputDataLabel, outFilePath));
                        else
                            warning('%s: Absent last files %s.',  mfilename(), ...
                                outFilePath);
                            continue;
                        end
                    else % case VariablesMatlab
                        appendFlag = 'new_file';
                    end
                end
%{
                % Get and save solar variables and metadata...
                %-----------------------------------------------------------------------
                [filePath, fileExists, ~] = espEnv2023.getFilePathForDateAndVarName( ...
                        objectName, dataLabel, thisDate, varName, complementaryLabel);
                if ~fileExists
                    errorStruct.identifier = ...
                        'Mosaic:No20230eFile';
                    errorStruct.message = sprintf(['%s: No v2023.0e file %s. ', ...
                        'Generate or sync them to scratch and rerun.\n'], ...
                        mfilename(), filePath);
                    error(errorStruct);
                end
                varData = struct();
                for varIdx = 1:length(solVarNames)
                    varName = solVarNames{varIdx};
                    varData.(varName) = espEnv2023.getDataForDateAndVarName( ...
                        objectName, dataLabel, thisDate, varName, complementaryLabel);
                    for metadataIdx = 1:length(varMetadataNames)
                        varMetadataName = [varName, '_', varMetadataNames{metadataIdx}];
                        varData.(varMetadataName) = ...
                            load(filePath, varMetadataName).(varMetadataName);
                    end
                end
                Tools.parforSaveFieldsOfStructInFile(outFilePath, ...
                        varData, appendFlag);
                appendFlag = 'append';
                fprintf(['%s: Saved solar variables and metadata in %s.\n'], ...
                    mfilename(), outFilePath);
                varData.solar_azimuth = [];
%}
                % Get and save spires variables and metadata...
                % NB: the spires smooth files are saved by chunks-cells split files
                % and need to be combine/aggregate to form a full tile.         @warning
                %-----------------------------------------------------------------------
                varData2 = struct();
                dataLabel = inputDataLabel;
                varName = '';
                patternsToReplaceByJoker = ...
                    {'rowStartId', 'rowEndId', 'columnStartId', 'columnEndId'};
                    % Here the input consists in cell-split files, to be combine in 1
                    % tile file only.
                [filePath, fileExists, ~] = espEnv.getFilePathForDateAndVarName( ...
                    objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                    patternsToReplaceByJoker = patternsToReplaceByJoker);
                if sum(cell2mat(fileExists)) ~= 36
                    % NB: Hard-coded 36 cell files expected. Improve....           @todo
                    ME = MException('Mosaic:writeSpiresDataNoFile', ...
                        sprintf(['%s: No 36 v2024.0b spires cell files for %s, ', ...
                        ' %s, %s. Generate or sync them to scratch and rerun', ...
                        '.\n'], mfilename(), objectName, dataLabel, ...
                        string(thisDate, 'yyyy-MM-dd')));
                    throw(ME);
                end
                % Test one file whether the input files have the date, we suppose that
                % if one of the input file has the date, all have, which can be false
                % if the smoothing process failed for some of the cells.        @warning
                inputFileInfo = h5info(filePath{1});
                for filePathIdx = 2:length(filePath)
                  thisFilePath = filePath{filePathIdx};
                  fprintf('Testing validity of %s...\n', thisFilePath);
                  h5info(thisFilePath);
                    % Raise an error if inexistent file or file corrupted (but don't
                    % detect all corruption cases.                              @warning
                end
                inputFileDates = datetime( ...
                    inputFileInfo.Attributes(1).Value, convertFrom = 'datenum');
                if ~ismember(thisDate, inputFileDates)
                    warning('%s: SKIP - No data for %s.\n', mfilename(), ...
                        char(thisDate, 'yyyy-MM-dd'), varName);
                    continue;
                end
                if ismember(outputDataLabel, {'modspiresdaily', 'vnpspiresdaily'})
                    % Using the save -append method with
                    % Tools.parforSaveFieldsOfStructInFile() on existing files
                    % corrupt file. We use here matfile() hoping that will solve the
                    % issue...                                                  @warning
                    fprintf('matfile loop...');
                    for varIdx = 1:size(outputVariable, 1)
                        varName = outputVariable.name{varIdx};
                        varData2.(varName) = espEnv.getDataForDateAndVarName( ...
                            objectName, dataLabel, thisDate, varName,...
                            complementaryLabel, ...
                            patternsToReplaceByJoker = patternsToReplaceByJoker);
                        if isempty(varData2.(varName))
                            warning('%s: No data for %s, variable %s.\n', ...
                                mfilename(), ...
                                char(thisDate, 'yyyy-MM-dd'), varName);
                            continue;
                        end
                        espEnv.saveData(varData2.(varName), objectName, ...
                            outputDataLabel, theseDate = thisDate, varName = varName);

                        % Metadata from the configuration file for this variable...
                        %---------------------------------------------------------------
                        if espEnv.slurmEndDate <= ...
                            datetime('now') + ...
                                seconds(espEnv.slurmSafetySecondsBeforeKill)
                            error('ESPEnv:TimeLimit', ...
                                'Error, Job has reached its time limit.');
                        end
                        thisMatfile = matfile(outFilePath, Writable = true);
                        thisMatfile.([varName '_type']) = ...
                            outputVariable.type{varIdx};
                        thisMatfile.([varName '_units']) = ...
                            outputVariable.unit{varIdx};
                        thisMatfile.([varName '_multiplicator_for_mosaics']) = ...
                            outputVariable.multiplicator_for_mosaics(varIdx);
                        thisMatfile.([varName '_divisor']) = ...
                            outputVariable.divisor(varIdx);
                        thisMatfile.([varName '_min']) = outputVariable.min(varIdx) * ...
                            outputVariable.divisor(varIdx);
                        thisMatfile.([varName '_max']) = outputVariable.max(varIdx) * ...
                            outputVariable.divisor(varIdx);
                        thisMatfile.([varName '_nodata_value']) = ...
                            outputVariable.nodata_value(varIdx);
                        thisMatfile.statusOfTimeSmoothing = 1;
                        thisMatfile = [];
                    end

                else
                    dayIsNotToBeSaved = 0;
                    for varIdx = 1:size(outputVariable, 1)
                        varName = outputVariable.name{varIdx};
                        varData2.(varName) = espEnv.getDataForDateAndVarName( ...
                            objectName, dataLabel, thisDate, varName,...
                            complementaryLabel, ...
                            patternsToReplaceByJoker = patternsToReplaceByJoker);
                        if isempty(varData2.(varName))
                            warning(['%s: No data for %s, variable %s, day not ', ...
                                'saved.\n'], mfilename(), ...
                                char(thisDate, 'yyyy-MM-dd'), varName);
                            dayIsNotToBeSaved = 1;
                            break;
                        end

                        % Metadata from the configuration file for this variable...
                        %-------------------------------------------------------------------
                        varData2.([varName '_type']) = ...
                            outputVariable.type{varIdx};
                        varData2.([varName '_units']) = ...
                            outputVariable.unit{varIdx};
                        varData2.([varName '_multiplicator_for_mosaics']) = ...
                            outputVariable.multiplicator_for_mosaics(varIdx);
                        varData2.([varName '_divisor']) = outputVariable.divisor(varIdx);
                        varData2.([varName '_min']) = outputVariable.min(varIdx) * ...
                            outputVariable.divisor(varIdx);
                        varData2.([varName '_max']) = outputVariable.max(varIdx) * ...
                            outputVariable.divisor(varIdx);
                        varData2.([varName '_nodata_value']) = ...
                            outputVariable.nodata_value(varIdx);
                    end
                    if espEnv.slurmEndDate <= ...
                        datetime('now') + seconds(espEnv.slurmSafetySecondsBeforeKill)
                        error('ESPEnv:TimeLimit', 'Error, Job has reached its time limit.');
                    end
                    if ~dayIsNotToBeSaved
                        Tools.parforSaveFieldsOfStructInFile(outFilePath, ...
                            varData2, appendFlag);
                        appendFlag = 'append';
                        fprintf(['%s: Saved spires variables and metadata in %s.\n'], ...
                            mfilename(), outFilePath);
                        varData2.snow_fraction_s = [];
                        varData2.viewable_snow_fraction_s = [];
                        varData2.shade_fraction_s = [];
                    end
                end


%{
                % Conversion of variables into double
                % (necessary for albedo calculation)...
                %-----------------------------------------------------------------------
                varData.solar_zenith = cast( ...
                    varData.solar_zenith, 'double');
                varData.solar_zenith( ...
                    varData.solar_zenith == intmax('uint8')) = NaN;
                varData2.grain_size_s = cast(varData2.grain_size_s, 'double');
                    % initially uint16 / 65535. Divisor: 1.
                varData2.grain_size_s(varData2.grain_size_s == intmax('uint16')) = NaN;
                varData2.dust_concentration_s = ...
                    cast(varData2.dust_concentration_s, 'double') / 10;
                    % initially uint16 / 65535. Divisor: 10.
                varData2.dust_concentration_s( ...
                    varData2.dust_concentration_s == intmax('uint16')) = NaN;

                % Calculation albedo...
                %-----------------------------------------------------------------------
                varName = 'albedo_s';
                varData3.(varName) = NaN(size(varData2.grain_size_s), 'double');
                indicesForNotNaN = find(~isnan(varData2.grain_size_s) & ...
                    ~isnan(varData2.dust_concentration_s) & ...
                    ~isnan(varData.solar_zenith));
                varData3.(varName)(indicesForNotNaN) = ...
                    AlbedoLookup(varData2.grain_size_s(indicesForNotNaN), ...
                        cosd(varData.solar_zenith(indicesForNotNaN)), ...
                    [], elevation(indicesForNotNaN), LAPname = 'dust', ...
                    LAPconc = varData2.dust_concentration_s(indicesForNotNaN));

                % Metadata from the configuration file for albedo and save all...
                %-----------------------------------------------------------------------
                varIdx = find(strcmp(varConf.output_name, 'albedo_s'), :);
                varData3.([varName '_type']) = ...
                    varConf.type_in_mosaics{varIdx};
                varData3.([varName '_units']) = ...
                    varConf.units_in_mosaics{varIdx};
                varData3.([varName '_multiplicator_for_mosaics']) = ...
                    varConf.multiplicator_for_mosaics(varIdx);
                varData3.([varName '_divisor']) = varConf.divisor(varIdx);
                varData3.([varName '_min']) = varConf.min(varIdx); * ...
                    varConf.divisor(varIdx);
                varData3.([varName '_max']) = varConf.max(varIdx); * ...
                    varConf.divisor(varIdx);
                varData3.([varName '_nodata_value']) = ...
                    varConf.nodata_value(varIdx);                if

                Tools.parforSaveFieldsOfStructInFile(outFilePath, ...
                    varData3, appendFlag);
                fprintf(['%s: Saved albedo and metadata in %s.\n'], ...
                    mfilename(), outFilePath);
 %}
            end % parfor dateIdx.
            fprintf(['%s: Done mosaic .mat generation/writing for ', ...
                'region %s, date %s...\n'], ...
                mfilename(), obj.region.name, waterYearDate.toChar());
        end
        function runWriteFiles(obj, waterYearDate)
            % Generation and write the mosaic files for a water year
            % with variables in configurationOfVariables.
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object
            %   waterYearDate for which generating the mosaics.

            espEnv = obj.region.espEnv;

            % List of Variables
            %------------------
            availableVariables = innerjoin(espEnv.myConf.variable, ...
                espEnv.myConf.versionvariable( ...
                    strcmp(espEnv.myConf.versionvariable.outputDataLabel, ...
                    'VariablesMatlab') & ...
                    strcmp(espEnv.myConf.versionvariable.inputDataLabel, ...
                    'SCAGDRFSSTC'), :), ...
                LeftKeys = 'id', RightKeys = 'varId', ...
                LeftVariables = {'id', 'output_name', 'multiplicator_for_mosaics', ...
                    'value_for_unreliable'});
            obj.writeFiles(waterYearDate, availableVariables);
        end

        function Dt = getMostRecentMosaicDt(obj, waterYearDate)
            % Gets the datetime of the most recent mosaic file
        % in this water year, or NaT if no mosaic file is found

            Dt = NaT;
            dateRange = waterYearDate.getDailyDatetimeRange();
              for i=length(dateRange):-1:1
                mosaicFilename = obj.region.espEnv.MosaicFile( ...
                          obj.region, dateRange(i));
                if isfile(mosaicFilename)
                    Dt = dateRange(i);
                    break;
                end
              end
        end
    end
end
