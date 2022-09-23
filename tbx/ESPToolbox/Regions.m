classdef Regions
%Regions - information about spatial sub-regions (states/watersheds)
%   This class contains functions to manage information about our
%   subregions by state (county) and watersheds at several levels
    properties      % public properties
        name          % name of region set
        regionName    % name of the big region which encompasses all the
                      % subregions
        maskName      % name of the mask set
        ShortName     % cell array of short names for file names
        LongName      % cell array of long names for title
        S             % region geometry structures
        indxMosaic    % mask with region IDS
        countOfRowsAndColumns   % Array of the number of rows and columns
                        % (number of pixels on the vertical and horizontal axes)
        percentCoverage % areal percent coverage of the region in our tiles
        useForSnowToday % logical cell array indicating we are using it
        lowIllumination % logical cell array for Northern areas
        espEnv          % ESPEnv object, local environment variables (paths...)
                        % and methods
        snowCoverDayMins % Struct(minElevation (double), minSnowCoverFraction
                         % (double [0:100]))
                         % indicate the minimal elevation and minimal snow cover
                         % fraction to count a pixel as covered by snow.
                         % used in Variables.calcSnowCoverDays()
        modisData       % MODISData object, modis environment paths and methods
    end
    properties(Constant)
        % pixSize_500m = 463.31271653;
    end

    methods         % public methods

        function obj = Regions(regionName, maskName, espEnv, modisData)
            % The Regions constructor initializes the directory
            % for local storage of MODIS tile data
            % NB: This class should take another argument (the real region
            % name 'westernUS')
            %
            % Parameters
            % ----------
            % regionName: str
            %    currently only 'westernUS'
            % maskName: str
            %     group of regions of a certain type. e.g. 'westernUS_mask',
            %    'State_masks', 'HUC2_masks' (for large drainage basins)
            % espEnv: ESPEnv object
            %    local environment variables, peculiarly the directory
            %    where are stored the region masks (= sub-regions,
            %    e.g. for 'State_masks' the entities are 'USAZ',
            %    'USCO', etc ...
            % modisData: MODISData object
            %    Modis environment, with paths

            
            % Masks variable
            %%%%%%%%%%%%%%%%
            if ~exist('maskName', 'var')
                maskName = 'State_masks';
            end
            if ~ischar(maskName)
                ME = MException('Region:inputError', ...
                    '%s: maskName %s is not of char type', ...
                    mfilename(), maskName);
                throw(ME)
            end

            obj.maskName = maskName;
            obj.regionName = regionName;
            obj.espEnv = espEnv;
            obj.modisData = modisData;

            % Fetch the structure with the requested region information
            regionFile = fullfile(espEnv.regionMaskDir, ...
                sprintf("%s.mat", obj.maskName));
            mObj = matfile(regionFile);
            varNames = who(mObj);
            if isempty(varNames)
                errorStruct.identifier = 'Regions:BadRegionsFile';
                errorStruct.message = sprintf(...
                    '%s: empty RegionsFile %s\n', ...
                    mfilename(), regionFile);
                error(errorStruct);
            end

            obj.ShortName = mObj.ShortName;
            obj.LongName = mObj.LongName;
            obj.S = mObj.S;
            obj.indxMosaic = mObj.indxMosaic;
            obj.countOfRowsAndColumns = size(obj.indxMosaic);
            obj.percentCoverage = mObj.percentCoverage;
            obj.useForSnowToday = mObj.useForSnowToday;
            obj.lowIllumination = mObj.lowIllumination;
            
            % Default values for snowCoverDaysMins
            obj.snowCoverDayMins.minElevation = 800;
            obj.snowCoverDayMins.minSnowCoverFraction = 10;

        end

        function out = paddedBounds(obj, ...
                regionNum, ...
                padLongitudePcent, ...
                padLatitudePcent)
           % Returns paddedBounds for the regionNum, for aspect 8:10

           % Get the strict Bounding Box, and pad it by 10% in each
           % dimension
           out.bounds = obj.S(regionNum).BoundingBox;

           width = out.bounds(2, 1) - out.bounds(1, 1);
           height = out.bounds(2, 2) - out.bounds(1, 2);

           padwidth = (width * padLongitudePcent) / 2.;
           padheight = (height * padLatitudePcent) / 2.;

           out.bounds(1, 1) = out.bounds(1, 1) - padwidth;
           out.bounds(2, 1) = out.bounds(2, 1) + padwidth;
           out.bounds(1, 2) = out.bounds(1, 2) - padheight;
           out.bounds(2, 2) = out.bounds(2, 2) + padheight;

        end

        function writeStats(obj, historicalStats, ...
            currentStats, availableVariables, ...
            outputDirectory, subRegionIndex, varName, espDate)
            % writes the year-to-date varName for regionIndex to ouput directory.
            %
            % Parameters
            % ----------
            % historicalStats: Table
            %        historical statistics (all variables).
            % currentStats: Table
            %        current statistics (all variables).
            % availableVariables: Table
            %        All the variables and their related infos that
            %        can be aggregated in statistics.
            % outputDirectory: Str
            %        Directory where the files are written
            % subRegionIndex: Int, Optional
            %        Index of the subregion within all the subregions
            %        contained in the object Regions. E.g. subRegionIndex = 1
            %        for 'USAZ' in the object Regions 'State_masks'
            %        Beware, this index may not be unique.
            %        If not input, write files for all subregions.
            % varName: str, Optional
            %         name of the variable on which the stats are aggregated
            %         e.g. albedo_clean_muZ, albedo_observed_muZ, snow_fraction
            %         must be in field_and_stats_names.csv.
            %         When input, write output csv files only for varName.
            %         When not input, write csv files for all variables.
            % espDate: ESPDate, Optional
            %         Date for which stats are calculated.

            % instantiate the region and variable indexes on which to loop
            % ------------------------------------------------------------

            if ~exist('subRegionIndex', 'var')                
                size1 = size(obj.ShortName);
                countOfSubRegions = size1(1, 1);
                subRegionIndexes = 1:countOfSubRegions;
            else
                subRegionIndexes = subRegionIndex;
            end

            if ~exist('varName', 'var')
                availableVariablesSize = size(availableVariables);
                varIndexes = 1:availableVariablesSize(1);
            else
                % Check if the varName is ok
                index = find(strcmp(availableVariables.name, varName));
                if isempty(index)
                    ME = MException('mfilename():UnauthorizedVarName', ...
                        '%s: varName %s not found in the ', ...
                        'list of authorized varName',  mfilename(), varName);
                    throw(ME)
                else
                    varIndexes = index;
                end
            end

            % Current year (for file naming)
            % ------------------------------
            if ~exist('espDate', 'var')
                espDate = ESPDate()
            end
            waterYear = espDate.getWaterYear();

            for subRegionIdx=subRegionIndexes
                for varIdx=varIndexes
                    % varName info
                    % --------------
                    % get the abbreviation (used as
                    % a suffix or prefix of fields in the historicalStats and
                    % currentStats files) and label and units (for the header)
                    varNameInfos = availableVariables(varIdx, :);
                    varName = varNameInfos.('name'){1};
                    abbreviation = varNameInfos.('calc_suffix_n_prefix'){1};
                    label = varNameInfos.('label'){1};
                    units = varNameInfos.('units'){1};

                    % File
                    % ----
                    fileName = sprintf('SnowToday_%s_%s_WY%4d_yearToDate.csv', ...
                        obj.ShortName{subRegionIdx}, varName, waterYear);
                    fileName = fullfile(outputDirectory, ...
                        fileName);
                    [path, ~, ~] = fileparts(fileName);
                    if ~isfolder(path)
                        mkdir(path);
                    end

                    % Header metadata
                    % ---------------
                    fileID = fopen(fileName, 'w');

                    fprintf(fileID, 'SnowToday %s Statistics To Date : %s\n', ...
                        label, ...
                        datestr(espDate.thisDatetime, 'yyyy-mm-dd'));
                    fprintf(fileID, 'Units : %s\n', units);
                    fprintf(fileID, 'Water Year : %04d\n', ...
                        waterYear);
                    fprintf(fileID, 'Water Year Begins : %04d-10-01\n', ...
                        waterYear - 1);
                    fprintf(fileID, 'SubRegionName : %s\n', ...
                        historicalStats.LongName{subRegionIdx});
                    fprintf(fileID, 'SubRegionID : %s\n', ...
                        historicalStats.ShortName{subRegionIdx});
                    [~, nyears] = size(historicalStats.yrs);
                    fprintf(fileID, 'Historical Years : %04d-%04d\n', ...
                        historicalStats.yrs(1), ...
                        historicalStats.yrs(nyears));
                    fprintf(fileID, 'Lowest Snow Year : %04d\n', ...
                        historicalStats.yr_min(subRegionIdx));
                    fprintf(fileID, 'Highest Snow Year : %04d\n', ...
                        historicalStats.yr_max(subRegionIdx));
                    fprintf(fileID, '------------------------\n');
                    fprintf(fileID, '\n');
                    fprintf(fileID, strcat('day_of_water_year,min,prc25,', ...
                        'median,prc75,max,year_to_date\n'));

                    fclose(fileID);
                    fprintf('%s: Wrote %s\n', mfilename(), fileName);

                    % Data
                    % ----

                    day_of_water_year = (1:366)';

                    yr_min_indx = find(...
                        historicalStats.yrs == historicalStats.yr_min(subRegionIdx));
                    yr_max_indx = find(...
                        historicalStats.yrs == historicalStats.yr_max(subRegionIdx));

                    min = historicalStats.(abbreviation + "_yr") ...
                        (yr_min_indx, :, subRegionIdx)';
                    max = historicalStats.(abbreviation + "_yr") ...
                        (yr_max_indx, :, subRegionIdx)';
                    prc25 = historicalStats.("prc25_" + abbreviation) ...
                        (1, :, subRegionIdx)';
                    median = historicalStats.("median_" + abbreviation) ...
                        (1, :, subRegionIdx)';
                    prc75 = historicalStats.("prc75_" + abbreviation) ...
                        (1, :, subRegionIdx)';

                    year_to_date = ...
                        currentStats.(abbreviation + "_yr")(1, :, subRegionIdx)';

                    dlmwrite(fileName, [day_of_water_year min prc25 median ...
                        prc75 max year_to_date], '-append');
                end
            end
        end

        function runWriteStats(obj, espDate)
            % Parameters
            % ----------
            % espDate: ESPDate, optional
            %    Date of the run (today, or another day before if necessary)



            % Dates
            %%%%%%%
            if ~exist('espDate', 'var')
                espDate = ESPDate();
            end

            waterYear = espDate.getWaterYear();
            modisBeginWaterYear = modisBeginWaterYear.modisBeginWaterYear;
            modisEndWaterYear = waterYear - 1;

            % Retrieval of aggregated data files
            historicalSummaryFile = obj.espEnv.SummarySnowFile(obj.modisData, ...
                obj.regionName, obj.maskName, modisBeginWaterYr, modisEndWaterYr);
            historicalStats = load(historicalSummaryFile);
            fprintf('%s: Reading historical stats from %s\n', mfilename(), ...
                historicalSummaryFile);

            currentSummaryFile = obj.espEnv.SummarySnowFile(obj.modisData, ...
                obj.regionName, obj.maskName, waterYr, waterYr);
            currentStats = load(currentSummaryFile);
            fprintf('%s: Reading current WY stats from %s\n', mfilename(), ...
                currentSummaryFile);

            % Variables and output directory
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            availableVariables = obj.espEnv.field_names_and_descriptions();
            outputDirectory = fullfile(obj.espEnv.dirWith.RegionalStatsCsv, ...
                sprintf('WY%04d', waterYr), ...
                'linePlotsToDate');

            obj.writeStats(historicalStats, ...
                currentStats, availableVariables, outputDirectory);
        end

        function saveSubsetToGeotiff(obj, espEnv, dataDt, data, R, ...
                regionNum, xLim, yLim, statsType)
            % saves data subset by region bounds as geotiff on public FTP

            % Get row/col coords of the subset area in this image
            UL = int16(map2pix(R, xLim(1), yLim(2)));
            LR = int16(map2pix(R, xLim(2), yLim(1)));

            % Get the subset
            sub = data(UL(1):LR(1), UL(2):LR(2));

            % Define the modified R matrix
            subR = R;
            subR(3, :) = [xLim(1), yLim(2)];

            % Set the filename to contain the data of the data
            waterYr = year(dataDt);
            thisMonth = month(dataDt);
            if thisMonth >= 10
                waterYr = waterYr + 1;
            end

            fileName = sprintf('SnowToday_%s_%s_%s.tif', ...
                obj.ShortName{regionNum}, ...
                datestr(dataDt, 'yyyymmdd'), ...
                statsType);
            fileName = fullfile(espEnv.publicDir, ...
                sprintf("WY%04d", waterYr), ...
                obj.ShortName{regionNum}, ...
                fileName);
            [path, ~, ~] = fileparts(fileName);
            if ~isfolder(path)
                mkdir(path);
            end

            geotiffwrite(fileName, sub, subR, 'CoordRefSysCode', 4326);
            fprintf('%s: saved data to %s\n', mfilename(), fileName);

        end

    end

    methods(Static)  % static methods can be called for the class

        function partitionName = getPartitionNameFor(partitionNum)
            % returns partition name for this number
            % First digit corresponds to region,
            % 10 = westernUS (full region)
            % Second digit correcponts to partition of the region
            % 11 = States in westernUS
            % 12 = HUC2 basins in westernUS
            % 14 = HUC4 basins in westernUS, etc

            switch partitionNum
                case 10
                    partitionName = 'westernUS_mask';
                case 11
                    partitionName = 'State_masks';
                case 12
                    partitionName = 'HUC2_masks';
                case 14
                    partitionName = 'HUC4_masks';
                case 16
                    partitionName = 'HUC6_masks';
                case 18
                    partitionName = 'HUC8_masks';
                otherwise
                    errorStruct.identifier = 'Regions:PartitionError';
                    errorStruct.message = sprintf( ...
                        '%s: Unknown partitionNum %d\n', mfilename(), ...
                        partitionNum);
                    error(errorStruct);
            end
        end
    end
end