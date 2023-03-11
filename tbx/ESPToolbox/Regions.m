classdef Regions
    %Regions - information about spatial sub-regions (states/watersheds)
    %   This class contains functions to manage information about our
    %   subregions by state (county) and watersheds at several levels
    properties      % public properties
        archiveDir    % top-level directory with region data
        name          % name of region set
        regionName    % name of the big region which encompasses all the
                      % subregions
        maskName      % name of the mask set
        ShortName     % cell array of short names for file names
        LongName      % cell array of long names for title
        S             % region geometry structures
        indxMosaic    % mask with region IDS
        RefMatrix      % infos on pixel size and others
        atmosphericProfile  % Atmospheric profile of the region (used to calculate
                            % albedo).
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
        geotiffCrop     % Struct(xLeft (double), xRight (double), yTop (double),
                        % yBottom (double))
                        % Data to crop the geotiff reprojected raster for web use
        tileIds         % Names of the source tiles that are assembled in the Mosaic
                        % that constitute the upper level region.
        thresholdsForMosaics % table (thresholded_varname (char),
                        % threshold_value (int), replaced_varname (char)
                        % Minimum values of variables below which the data are
                        % considered unreliable and shouldn't be included in the
                        % Mosaic files.
                        % If the thresholded_varname < threshold_value then
                        % the replaced_varname value is replaced by the value indicated
                        % in the file configuration_of_variables
        thresholdsForPublicMosaics % table (thresholded_varname (char),
                        % threshold_value (int), replaced_varname (char)
                        % Minimum values of variables below which the data are
                        % considered unreliable and shouldn't be released to public.
                        % If the thresholded_varname < threshold_value then
                        % the replaced_varname value is replaced by the value indicated
                        % in the file configuration_of_variables
        modisData       % MODISData object, modis environment paths and methods
        STC             % STC thresholds
    end
    properties(Constant)
        % pixSize_500m = 463.31271653;
        geotiffCompression = 'LZW';
        geotiffEPSG = 3857;
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
            %---------------
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
            obj.RefMatrix = mObj.RefMatrix;
            obj.percentCoverage = mObj.percentCoverage;
            obj.useForSnowToday = mObj.useForSnowToday;
            obj.lowIllumination = mObj.lowIllumination;
            obj.atmosphericProfile = mObj.atmosphericProfile;
            obj.snowCoverDayMins = mObj.snowCoverDayMins;
            obj.geotiffCrop = mObj.geotiffCrop;
            obj.STC = mObj.stc;
            obj.tileIds = mObj.tileIds;
            obj.thresholdsForMosaics = mObj.thresholdsForMosaics;
            obj.thresholdsForPublicMosaics = mObj.thresholdsForPublicMosaics;
        end

        function elevations = getElevations(obj)
            % Return
            % ------
            %   elevations: Array(double)
            %       Array of elevations [m] of the upper-level region
            %       or tile regions.
            %       NB: No implementation for subregions.

            fileName = obj.espEnv.elevationFile(obj);
            try
                mObj = matfile(fileName);
                % Dem file for tiles
                if ismember('Elevation', fieldnames(mObj))
                    elevations = mObj.Elevation;
                    elevations = elevations.Z;
                % Dem file for upper level regions
                else
                    elevations = mObj.Z;
                end
            catch e
                fprintf("%s: Error reading elevation from %s\n", ...
                    mfilename(), fileName);
                rethrow(e);
            end
        end

        function [xExtent, yExtent] = getGeotiffExtent(obj, geotiffEPSG)
            % Returns two vector indicating the x-y limits of the geotiff
            % for the web, after projection, which actually contain data.
            % These limits are used to crop the geotiff
            % in writeGeotiffs().
            % Code based on the code in RasterProjection package, script
            % util.parseReprojectionInput
            %
            % Parameters
            % ----------
            % geotiffEPSG: int.
            %   Output projection system
            %
            % Return
            % ------
            % xExtent: [int int]
            %   Minimum & maximum of projected x-coordinates
            % yExtent: [int int]
            %   Minimum & maximum of projected y-coordinates

            % Convert matlab-obsolete RefMatrix to new class RasterReference matlab function
            rasterReference = refmatToMapRasterReference(obj.RefMatrix, ...
                obj.getSizeInPixels());
            rasterReference.ProjectedCRS = ...
                MODISsinusoidal();% RasterReprojection package
            % NB mstruct of regions are wrong and cannot be used here

            outputProjection = projcrs(geotiffEPSG);
            pixelSize = obj.RefMatrix(2,1); %Size of pixel
            InRR = rasterReference;
            InS = InRR.ProjectedCRS;
            OutS = outputProjection;
            [XIntrinsic, YIntrinsic] =...
                meshgrid([1 InRR.RasterSize(2)],[1 InRR.RasterSize(1)]);
            [xWorld, yWorld] = intrinsicToWorld(InRR, XIntrinsic, YIntrinsic);
                %RasterReprojection package

            [latlim,lonlim] = projinv(InS,xWorld,yWorld);
            [x,y] = projfwd(OutS, latlim, lonlim);
            xExtent = [min(x(:)) max(x(:))];
            yExtent = [min(y(:)) max(y(:))];
        end

        function [xLimit, yLimit] = getGeotiffExtentMinusCrop(obj, geotiffEPSG)
            % Returns two vector indicating the x-y limits of the geotiff
            % for the web, after projection, which actually contain data.
            % These limits are used to crop the geotiff
            % in writeGeotiffs().
            %
            % Parameters
            % ----------
            % geotiffEPSG: int.
            %   Output projection system
            %
            % Return
            % ------
            % xLimit: [int int]
            %   Minimum & maximum of cropped projected x-coordinates
            % yLimit: [int int]
            %   Minimum & maximum of cropped projected y-coordinates

            [xExtent, yExtent] = obj.getGeotiffExtent(geotiffEPSG);
            pixelSize = obj.RefMatrix(2,1); %Size of

            xLimit = [xExtent(1) + ((pixelSize * ...
                obj.geotiffCrop.xLeft) / 2), ...
                xExtent(2) - pixelSize / 2 - ((pixelSize * ...
                obj.geotiffCrop.xRight) / 2)];
            % Remark: There's no correction of xExtent(1) (left) by pixel / 2 as
            % for the other faces of the raster.
            % I speculated there's a minor issue in the RasterReprojection
            % package that doesn't get the correct extent of the new raster at the
            % left of the raster (extent calculated in getGeotiffExtent())
            xLimit = sort(xLimit);
            yLimit = [yExtent(1) + pixelSize / 2  + ((pixelSize * ...
                obj.geotiffCrop.yBottom) / 2), ...
               yExtent(2) - pixelSize / 2 - ((pixelSize * ...
                obj.geotiffCrop.yTop) / 2)];
            yLimit = sort(yLimit);
        end

        function size1 = getSizeInPixels(obj)
            % Return
            % ------
            % Array of the number of rows and columns
            % (number of pixels on the vertical and horizontal axes)
            size1 = size(obj.indxMosaic);
        end

        function regionsArray = getTileRegions(obj)
            % Return
            % ------
            % Array of the regions associated to the tiles that compose
            % this upper-level regions obj
            tileNames = obj.tileIds;
            for tileIdx = 1:length(tileNames)
                tileName = tileNames{tileIdx};
                regionsArray(tileIdx) = Regions(tileName, ...
                    [tileName '_mask'], ...
                    obj.espEnv, obj.modisData);

                % Override any default STC or snowCoverDayMins
                % settings with values from the upper-level regions obj
                regionsArray(tileIdx).STC = obj.STC;
                regionsArray(tileIdx).snowCoverDayMins = ...
                    obj.snowCoverDayMins;
            end
        end

        % FIXME: this method isn't really needed, a better
        % alternative is for the caller to make a temporary structure
        % with elements that should be saved to the output file, and
        % then appending the output file with the structure, using the
        % -s option
        function saveEnvironment(obj, outFilename)
            % Appends runtime environment variables to outFilename

            % make a copy so variable references in save will work
            espEnv = obj.espEnv;
            modisData = obj.modisData;
            STC = obj.STC;
            save(outFilename, '-append', 'espEnv', 'modisData', 'STC');
                fprintf("%s: Appended espEnv/modisData/STC to %s\n", ...
                    class(obj), outFilename);

        end

        function writeGeotiffs(obj, availableVariables, ...
            outputDirectory, varName, waterYearDate)
            % Write the geotiffs of the upper level region
            % over a period up to a date to output directory.
            % The geotiff is cropped according geotiffCrop properties
            % of the regions object.
            % The geotiffs are generated from Public Mosaics, which
            % replace unreliable data from Mosaics by default values
            %
            % Parameters
            % ----------
            % availableVariables: Table
            %        All the variables and their related infos that
            %        can be aggregated in statistics.
            % outputDirectory: Str
            %        Directory where the files are written
            % varName: str, Optional
            %         name of the variable on which the stats are aggregated
            %         e.g. albedo_clean_muZ, albedo_observed_muZ, snow_fraction
            %         must be in configuration_of_variables.csv.
            %         When input, write output csv files only for varName.
            %         When not input, write csv files for all variables.
            % waterYearDate: waterYearDate, Optional
            %         Dates for which stats are calculated.

            tic;
            fprintf('%s: Start regional geotiffs generation and writing\n', mfilename());
            espEnv = obj.espEnv;
            publicMosaic = PublicMosaic(obj);

            % instantiate the variable indexes on which to loop
            % ------------------------------------------------------------
            if ~exist('varName', 'var') | isnan(varName)
                availableVariablesSize = size(availableVariables);
                varIndexes = 1:availableVariablesSize(1);
            else
                % Check if the varName is ok
                index = find(strcmp(availableVariables.output_name, varName));
                if isempty(index)
                    ME = MException('Regions:UnauthorizedVarName', ...
                        sprintf('%s: varName %s not found in the ', ...
                        'list of authorized outputnames in ', ...
                        'ESPEnv.configurationOfVariables()\n',  ...
                        mfilename(), varName));
                    throw(ME)
                else
                    varIndexes = index;
                end
            end

            % Current year (for file naming)
            % ------------------------------
            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getDailyDatetimeRange();

            % Projections and crop extent
            % ---------------------------
            % Convert matlab-obsolete RefMatrix to new class RasterReference matlab function
            rasterReference = refmatToMapRasterReference(obj.RefMatrix, obj.getSizeInPixels());
            rasterReference.ProjectedCRS = MODISsinusoidal();% RasterReprojection package
            % NB mstruct of regions are wrong and cannot be used here

            outputProjection = projcrs(obj.geotiffEPSG); % RasterReprojection package
            pixelSize = obj.RefMatrix(2,1); %Size of pixel

            [xLimit, yLimit] = obj.getGeotiffExtentMinusCrop(Regions.geotiffEPSG);

            % Generation
            % ----------
            % Start or connect to the local pool (parallelism)
            % This processing tends to be a memory hog, with each worker
            % needing as much as 70GB memory.
            % So, plan to run this system on alpine with 32 tasks in order
            % to get all the memory on the node, and then limit workers here
            espEnv.configParallelismPool(3);

            parfor dateIdx=1:length(dateRange)

                thisDatetime = dateRange(dateIdx);

                for varIdx=1:length(varIndexes)
                    % varName info
                    % ------------
                    % get the output name and units
                    varNameInfos = availableVariables(varIndexes(varIdx), :);
                    varName = varNameInfos.('output_name'){1};

                    % Data load
                    % ---------
                    publicMosaicData = publicMosaic.getThresholdedData(varName, ...
                        thisDatetime);
                    if isempty(fieldnames(publicMosaicData))
                        warning('%s: No Geotiff generation for %s\n', mfilename(), ...
                            datestr(thisDatetime, 'yyyy-mm-dd'));
                        break;
                    end
                    varData = publicMosaicData.(varName);

                    % Reprojection and geotiff writing
                    % ------------
                    % using RasterReprojection package with parameters:
                    % - varData (A): input 2D raster
                    % - rasterReference (InR): mapping raster reference of varData
                    % - outputProjection (OutProj): projcrs projection object, indicates
                    % the target projection for output
                    % - pixelSize (pixelsize): 2-element vector specifying height and width
                    % of output cells
                    % - xLimit (Xlimit): vector of length 2: minimum & maximum
                    %           of output x-coordinates (default is to cover extent of A)
                    % - yLimit (YLimit): vector of length 2: minimum & maximum
                    %           of output y-coordinates (default is to cover extent of A)
                    [projectedVarData, RRB, fillvalue] = ...
                        rasterReprojection(varData, ...
                        rasterReference, ...
                        'OutProj', outputProjection, ...
                        'method', 'nearest', ...
                        'pixelsize', pixelSize, ...
                        'Xlimit', xLimit, ...
                        'Ylimit', yLimit);

        		    % Set up output directories by day 
                    % This will make transfers to NSIDC easier
                    outputDirectory2 = fullfile(outputDirectory, ...
            			datestr(thisDatetime, 'yyyymmdd'));
                    if ~isfolder(outputDirectory2)
                        mkdir(outputDirectory2);
                    end
                    outFilename = obj.espEnv.SnowTodayGeotiffFile(...
                        obj, outputDirectory2, 'Terra', thisDatetime, ...
                        varName);
                    geotiffwrite(outFilename, ...
                        projectedVarData, ...
                        RRB, ...
                        'CoordRefSysCode', obj.geotiffEPSG, ...
                        'TiffTags', struct('Compression', obj.geotiffCompression));
                    fprintf('%s: Wrote %s\n', mfilename(), outFilename);

                    % Generation of the no-processed layer which indicates the NaNs
                    if strcmp(varName, 'snow_fraction')
                        notProcessedData = projectedVarData == Variables.uint8NoData;
                		outFilename = obj.espEnv.SnowTodayGeotiffFile(...
                            obj, outputDirectory2, 'Terra', thisDatetime, ...
                            'notprocessed');
                        geotiffwrite(outFilename, ...
                            notProcessedData, ...
                            RRB, ...
                            'CoordRefSysCode', obj.geotiffEPSG, ...
                            'TiffTags', ...
                            struct('Compression', obj.geotiffCompression));
                		fprintf('%s: Wrote %s\n', mfilename(), ...
                            outFilename);
                    end
                end
            end
            t2 = toc;
            fprintf('%s: Finished regional geotiffs generation and writing in %s seconds.\n', ...
                mfilename(), num2str(roundn(t2, -2)));
        end

        function writeStats(obj, historicalStats, ...
            currentStats, availableVariables, ...
            outputDirectory, subRegionIndex, varName, waterYearDate)
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
            %         must be in configuration_of_variables.csv.
            %         When input, write output csv files only for varName.
            %         When not input, write csv files for all variables.
            % waterYearDate: waterYearDate, Optional
            %         Date for which stats are calculated.

            % instantiate the region and variable indexes on which to loop
            % ------------------------------------------------------------

            if ~exist('subRegionIndex', 'var') || isnan(subRegionIndex)
                size1 = size(obj.ShortName);
                countOfSubRegions = size1(1, 1);
                subRegionIndexes = 1:countOfSubRegions;
            else
                subRegionIndexes = subRegionIndex;
            end

            if ~exist('varName', 'var') || strcmp(varName, '')
                availableVariablesSize = size(availableVariables);
                varIndexes = 1:availableVariablesSize(1);
            else
                % Check if the varName is ok
                index = find(strcmp(availableVariables.output_name, varName));
                if isempty(index)
                    ME = MException('WriteStats_UnauthorizedVarName', ...
                        '%s: varName %s not found in the ', ...
                        'list of authorized outputnames in ', ...
                        'ESPEnv.configurationOfVariables()',  mfilename(), varName);
                    throw(ME)
                else
                    varIndexes = index;
                end
            end

            % Current year (for file naming)
            % ------------------------------
            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            waterYear = waterYearDate.getWaterYear();

            for subRegionIdx=subRegionIndexes
                for varIdx=varIndexes
                    % varName info
                    % --------------
                    % get the abbreviation (used as
                    % a suffix or prefix of fields in the historicalStats and
                    % currentStats files) and label and units (for the header)
                    varNameInfos = availableVariables(varIdx, :);
                    varName = varNameInfos.('output_name'){1};
                    abbreviation = varNameInfos.('calc_suffix_n_prefix'){1};
                    label = varNameInfos.('label'){1};
                    units = varNameInfos.('units_in_map'){1};

                    % File
                    % ----
                    fileName = obj.espEnv.SummaryCsvFile(obj, ...
                        subRegionIdx, outputDirectory, varName, waterYear);
                    [path, ~, ~] = fileparts(fileName);
                    if ~isfolder(path)
                        mkdir(path);
                    end

                    % Header metadata
                    % ---------------
                    fileID = fopen(fileName, 'w');

                    fprintf(fileID, 'SnowToday %s Statistics To Date : %s\n', ...
                        label, ...
                        datestr(waterYearDate.thisDatetime, 'yyyy-mm-dd'));
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

        function runWriteGeotiffs(obj, waterYearDate)
            % Parameters
            % ----------
            % waterYearDate: waterYearDate, optional
            %    Date of the run (today, or another day before if necessary)

            % Dates
            %%%%%%%
            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            waterYear = waterYearDate.getWaterYear();

            % Variables and output directory
            %-------------------------------
            confOfVar = obj.espEnv.configurationOfVariables();
            availableVariables = confOfVar(...
                find(confOfVar.write_geotiffs == 1), :);
            outputDirectory = obj.espEnv.SnowTodayGeotiffDir(obj);
            obj.writeGeotiffs(availableVariables, outputDirectory, ...
                NaN, waterYearDate);
        end

        function runWriteStats(obj, waterYearDate)
            % Parameters
            % ----------
            % waterYearDate: waterYearDate, optional
            %    Date of the run (today, or another day before if necessary)

            % Dates
            %------
            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end

            waterYear = waterYearDate.getWaterYear();
            modisBeginWaterYear = obj.modisData.beginWaterYear;
            modisEndWaterYear = waterYear - 1;

            % Retrieval of aggregated data files
            historicalSummaryFile = obj.espEnv.SummarySnowFile(obj, ...
                modisBeginWaterYear, modisEndWaterYear);
            historicalStats = load(historicalSummaryFile);
            fprintf('%s: Reading historical stats from %s\n', mfilename(), ...
                historicalSummaryFile);

            currentSummaryFile = obj.espEnv.SummarySnowFile(obj, ...
                waterYear, waterYear);
            currentStats = load(currentSummaryFile);
            fprintf('%s: Reading current WY stats from %s\n', mfilename(), ...
                currentSummaryFile);

            % Variables and output directory
            %-------------------------------
            variables = obj.espEnv.configurationOfVariables();
            availableVariables = variables(find(variables.write_stats_csv == 1), :);
            outputDirectory = obj.espEnv.SummaryCsvDir(obj, waterYearDate);
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end

            obj.writeStats(historicalStats, currentStats, ...
		availableVariables, outputDirectory, NaN, NaN, waterYearDate);
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
