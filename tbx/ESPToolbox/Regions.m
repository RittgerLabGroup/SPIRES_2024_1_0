classdef Regions < handle
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
        geotiffCompression = 'LZW';
        webGeotiffEPSG = 3857;
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
            obj.STC = STC(mObj.stcStruct); % SIER_289
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
            rasterReference = obj.getMapCellsReference();

            outputProjection = projcrs(geotiffEPSG);
            InRR = rasterReference;
            InS = InRR.ProjectedCRS;
            OutS = outputProjection;
            [XIntrinsic, YIntrinsic] =...
                meshgrid([1 InRR.RasterSize(2)],[1 InRR.RasterSize(1)]);
            % NB: @todo. this calculation of intrinsic coordinates seem incorrect. 
            % to investigate SIER_337                                               TODO
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
            mapCellsReference = obj.getMapCellsReference();
            pixelSize = mapCellsReference.CellExtentInWorldX;

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
        function mapCellsReference = getMapCellsReference(obj)
            % Return
            % ------
            % mapCellsReference: MapCellsReference object. Of the region object.
            % SIER_320 and SIER_163.
            % Encapsulates the MODISData getMapCellsReference. Here
            % we need to have the list of all tiles that compose the big region,
            % which we can't have if we only base on the MODISData object.
            horizontalTileIds = zeros([1, length(obj.tileIds)], 'uint8');
            verticalTileIds = zeros([1, length(obj.tileIds)], 'uint8');
            for idx = 1:length(obj.tileIds)
                positionalTileData = ...
                    obj.modisData.getTilePositionIdsAndColumnRowCount( ...
                    obj.tileIds{idx});
                horizontalTileIds(idx) = positionalTileData.horizontalId;
                verticalTileIds(idx) = positionalTileData.verticalId;
            end
            positionalData.horizontalId = min(horizontalTileIds);
            positionalData.verticalId = min(verticalTileIds);
            positionalData.columnCount = ...
                obj.modisData.georeferencing.tileInfo.columnCount * ...
                length(unique(horizontalTileIds));
            positionalData.rowCount = ...
                obj.modisData.georeferencing.tileInfo.rowCount * ...
                length(unique(verticalTileIds));
                
            mapCellsReference = obj.modisData.getMapCellsReference(positionalData);
        end
        function size1 = getSizeInPixels(obj)
            % Return
            % ------
            % Array of the number of rows and columns
            % (number of pixels on the vertical and horizontal axes)
            mapCellsReference = obj.getMapCellsReference();
            size1 = mapCellsReference.RasterSize;
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
        % SIER_289. Method updated so as not to save objects but structs to have more
        % flexibility when small developments on the ESPEnv, MODISData and
        % STC classes.
        function saveEnvironment(obj, outFilename)
            % Appends runtime environment variables to outFilename

            % make a copy so variable references in save will work
            warning('off', 'MATLAB:structOnObject');
            espEnvStruct = struct(obj.espEnv);
            modisDataStruct = struct(obj.modisData);
            stcStruct = struct(obj.STC);
            warning('on', 'MATLAB:structOnObject');
            save(outFilename, '-append', 'espEnvStruct', 'modisDataStruct', 'stcStruct');
                fprintf("%s: Appended espEnv/modisData/STC to %s\n", ...
                    class(obj), outFilename);

        end

        function writeGeotiffs(obj, ...
            varName, waterYearDate, geotiffEPSG)
            % Write the geotiffs of the upper level region
            % over a period up to a date to output directory.
            % The geotiff is cropped according geotiffCrop properties
            % of the regions object.
            % The geotiffs are generated from Public Mosaics, which
            % replace unreliable data from Mosaics by default values
            %
            % Parameters
            % ----------
            % availableVariables: Table. Parameter removed SIER_163.           @obsolete
            % outputDirectory: Str. Parameter removed SIER_163.                @obsolete
            % varName: str, Optional
            %         name of the variable on which the stats are aggregated
            %         e.g. albedo_clean_muZ, albedo_observed_muZ, snow_fraction
            %         must be in configuration_of_variables.csv.
            %         When input, write output csv files only for varName.
            %         When not input, write csv files for all variables.
            % waterYearDate: waterYearDate, Optional
            %         Dates for which stats are calculated.
            % geotiffEPSG: int. Code EPSG of the projection or geographic system.
            %   SIER_163.
    
            tic;
            fprintf(['%s: Start regional geotiffs generation and writing for', ...
                ' region %s, EPSG %d, waterYear %d ...\n'], mfilename(), ...
                obj.regionName, geotiffEPSG, year(waterYearDate.thisDatetime));
            espEnv = obj.espEnv;
            publicMosaic = PublicMosaic(obj);
            
            % Dates
            %%%%%%%
            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end

            % Variables and output directory
            %-------------------------------
            confOfVar = espEnv.configurationOfVariables();
            availableVariables = confOfVar(...
                confOfVar.write_geotiffs == 1, :);                

            % instantiate the variable indexes on which to loop
            % ------------------------------------------------------------
            % NB: I put varName(1) because || operator works only if the two members
            % have the same number of elements (matlab specific). Same in WriteStats.
            if ~exist('varName', 'var') || isnan(varName(1))
                availableVariablesSize = size(availableVariables);
                varIndexes = 1:availableVariablesSize(1);
            else
                % Check if the varName is ok
                index = find(strcmp(availableVariables.output_name, varName));
                if isempty(index)
                    ME = MException('Regions:WriteGeotiffs_UnauthorizedVarName', ...
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
            % Convert matlab-obsolete RefMatrix to new class RasterReference matlab
            % function.
            inMapCellsReference = obj.getMapCellsReference();% RasterReprojection
            % package.
            % NB mstruct of regions are wrong and cannot be used here.
            
            % We'll preload the variables used for thresholding in the parforloops.
            % NB: the smaller nb of preloaded variables, the better is, given the
            % structure of the code. All this is done to lower memory consumption
            % and quicken the process. SIER_163.
            % NB: We suppose that the preloaded variable is only thresholded by itself
            % or by elevation.
            varnamesToPreLoad = intersect( ...
                availableVariables.output_name, ...
                unique(obj.thresholdsForPublicMosaics.thresholded_varname));

            % Obtain output projection/system.
            % For this we load the first available mosaic values for variable 
            % viewable_snow_fraction.
            % This is required to use the functions within the RasterProjection package.
            % @todo. Maybe we could use a different function to avoid that.         TODO
            varDataIsObtained = 0;            
            varName = varnamesToPreLoad{1};
            for dateIdx=1:length(dateRange)
                thisDatetime = dateRange(dateIdx);                
                publicMosaicData = publicMosaic.getThresholdedData(varName, ...
                    thisDatetime, struct());
                if ~isempty(fieldnames(publicMosaicData))
                    varData = publicMosaicData.(varName);
                    publicMosaicData = [];
                    varDataIsObtained = 1;
                    fprintf(['%s: Output reference system determined from ', ...
                        'variable %s for date %s.\n'], mfilename(), ...
                        varName, string(thisDatetime, 'yyyy-MM-dd'));
                    break;
                end
                if varDataIsObtained == 1
                    break;
                end
            end

            % Then we start as if we reproject, using the functions within the
            % RasterProjection package, to obtain the coordinates Xq, Yq required for
            % interpolation in the output projection or geographic system.
            % @todo. We could save these coordinates in a file rather than recalculate
            % them every time.                                                      TODO

            % Reprojection
            % ------------
            % using RasterReprojection package with parameters:
            % - varData (publicMosaicData.(varName)) (A): input 2D raster
            % - inMapCellsReference (InR): mapping raster reference of varData
            % - outputProjection (OutProj): projcrs projection object, indicates
            % the target projection for output
            % - pixelSize (pixelsize): removed SIER_163 because unnecessary
            %   (and generates error for geographic).
            % - xLimit (Xlimit): vector of length 2: minimum & maximum
            %           of output x-coordinates (default is to cover extent of A)
            % - yLimit (YLimit): vector of length 2: minimum & maximum
            %           of output y-coordinates (default is to cover extent of A)
            % Add different cases for SIER_163. SIER_333. We put this outside of the
            % parforloop
            % by not using the rasterProjection function any more, because the
            % calculation of the Xq, Yq coordinates consume cpu and memory
            % and is expected to give identic results for all variables of all mosaics.

            % Code adapted from the RasterReprojection package by Jeff Dozier.
            % This is to bypass the array copies present in the
            % rasterReprojection functions (for reduce memory use).
            % NB: @todo. Might be better in a dedicated class, but presently
            % only used here. Might be better to use gdal too. SIER_163.    TODO
            % parse inputs.
            % BEWARE: only accepts 4326 as geographic system.

            % Obtain the output CellsReference, either geographic or map
            % projected. The outCellsReference is used to calculate the coordinates Xq,
            % Yq of the output raster and to generate the geotiff file.            
            if geotiffEPSG == 4326
                % output in geographic reference.
                % NB: no crop possible becayse the Regions.getGeotiffExtent()
                % only work with projected EPSG 3857 (coordinates in the Regions object)
                %                                                                  @todo
                [~, outCellsReference, ~, ~, ~, ~, ~, ~, ~] = ...
                    parseReprojectionInput(varData, inMapCellsReference);
            elseif geotiffEPSG == Regions.webGeotiffEPSG
                % output in projected system.
                % EPSG 3857 for website snowToday and other projections
                % are possible.         
                [xLimit, yLimit] = obj.getGeotiffExtentMinusCrop(geotiffEPSG);
                [~, outCellsReference, ~, ~, ~, ~, ~, ~, ~] = ...
                    parseReprojectionInput(varData, inMapCellsReference, ...
                    OutProj = projcrs(geotiffEPSG), ...
                    Xlimit = xLimit, Ylimit = yLimit);
            else
                % Other projection cases.
                [~, outCellsReference, ~, ~, ~, ~, ~, ~, ~] = ...
                    parseReprojectionInput(varData, inMapCellsReference, ...
                    OutProj = projcrs(geotiffEPSG));
            end
            clear varData;

            % Obtain the coordinates in the input CellsReference
            % for which values will be interpolated to get the output in the
            % ouput CellsReference.
            if contains(class(outCellsReference), 'map.rasterref.Map', ...
                'IgnoreCase', true)
                [XWorld, YWorld] = meshgrid( ...
                    (outCellsReference.XWorldLimits(1) + ...
                        outCellsReference.CellExtentInWorldX / 2 : ...
                    outCellsReference.CellExtentInWorldX: ...
                    outCellsReference.XWorldLimits(2) - ...
                        outCellsReference.CellExtentInWorldX / 2), ...
                    (outCellsReference.YWorldLimits(2) - ...
                        outCellsReference.CellExtentInWorldY / 2: ...
                    -outCellsReference.CellExtentInWorldY: ...
                    outCellsReference.YWorldLimits(1) + ...
                        outCellsReference.CellExtentInWorldY / 2));
                [lat,lon] = projinv(outCellsReference.ProjectedCRS, ...
                    XWorld, YWorld);
            elseif contains(class(outCellsReference),'Geographic')
                [lat, lon] = meshgrid( ...
                    (outCellsReference.LatitudeLimits(2) - ...
                        outCellsReference.CellExtentInLatitude / 2 : ...
                    -outCellsReference.CellExtentInLatitude: ...
                    outCellsReference.LatitudeLimits(1) + ... 
                        outCellsReference.CellExtentInLatitude / 2), ...
                    (outCellsReference.LongitudeLimits(1) + ...
                        outCellsReference.CellExtentInLongitude / 2 : ...
                    outCellsReference.CellExtentInLongitude: ...
                    outCellsReference.LongitudeLimits(2) - ...
                        outCellsReference.CellExtentInLongitude / 2)); 
                lat = lat';
                lon = lon';
            end
            [Xq, Yq] = projfwd(inMapCellsReference.ProjectedCRS, ...
                lat, lon);

            % Generation
            % ----------
            % Start or connect to the local pool (parallelism)
            % This processing tends to be a memory hog, with each worker
            % needing as much as 70GB memory.
            % So, plan to run this system on alpine with 32 tasks in order
            % to get all the memory on the node, and then limit workers here
            % SIER_163 and SIER_333 should have solve this problem.
            espEnv.configParallelismPool(length(varIndexes)); % currently 8 variables
              
            for dateIdx=1:length(dateRange)
                logger = Logger('geotiffDate');
                thisDatetime = dateRange(dateIdx);
                fprintf('%s: Starting geotiff generation for date %s.\n', ...
                    mfilename(), string(thisDatetime, 'yy-MM-dd'));
                % Check if Mosaic file is available.
                if ~isfile(espEnv.MosaicFile(obj, thisDatetime))
                    warning(['%s: Unavailable mosaic. No Geotiff generation for ', ...
                        '%s\n'], mfilename(), string(thisDatetime, 'yyyy-MM-dd'));
                    continue;
                end
                outputDirectory = ...
                    obj.espEnv.SnowTodayGeotiffDir(obj, geotiffEPSG, ...
                    year(thisDatetime));
                % Set up output directories by day
                % This will make transfers to NSIDC easier
                outputDirectory2 = fullfile(outputDirectory, ...
            			string(thisDatetime, 'yyyyMMdd'));
                if ~isfolder(outputDirectory2)
                    mkdir(outputDirectory2);
                end
                % Get the variables necessary to filter/threshold the other variables.
                % There should be only 1, snow_fraction (or viewable_snow_fraction) and
                % elevation.
                initPublicMosaicData = struct();
                for varIdx = 1:length(varnamesToPreLoad)
                    varName = varnamesToPreLoad{varIdx};
                    initPublicMosaicData = publicMosaic.getThresholdedData(varName, ...
                        thisDatetime, initPublicMosaicData);
                end
                
                % We handle each variable to generate a geotiff.
                parfor varIdx=1:length(varIndexes)
                    % varName info
                    % ------------
                    % get the output name and units
                    varNameInfos = availableVariables(varIndexes(varIdx), :);
                    varName = varNameInfos.('output_name'){1};
                    fprintf('%s: Starting geotiff generation for variable %s ...\n', ...
                        mfilename(), varName);

                    % Data load
                    % ---------
                    publicMosaicData = publicMosaic.getThresholdedData(varName, ...
                        thisDatetime, initPublicMosaicData);
                    fprintf('%s: Public mosaic for variable %s OK.\n', ...
                        mfilename(), varName);
                    if ~ismember(varName, fieldnames(publicMosaicData))
                        warning('%s: No Geotiff generation for %s on %s\n', ...
                            mfilename(), varName, string(thisDatetime, 'yyyy-MM-dd'));
                    else
                        varData = publicMosaicData.(varName);
                        publicMosaicData = [];

                        % Get the data interpolated at the  coordinates of the output
                        % reference system. SIER_163.
                        %---------------------------------------------------------------
                        varData = single(varData);
                        varData(varData == varNameInfos.nodata_value) = NaN;
                        if contains(class(outCellsReference), 'map.rasterref.Map', ...
                            'IgnoreCase', true)
                            varData = mapinterp(varData, inMapCellsReference, ...
                                Xq, Yq, 'nearest');
                        else
                            varData = geointerp(varData, inMapCellsReference, ...
                                Yq, Xq, 'nearest');
                        end
                        varData(isnan(varData)) = varNameInfos.nodata_value;
                        varData = cast(varData, varNameInfos.type{1});
                        fprintf('%s: Interpolated variable %s OK.\n', ...
                            mfilename(), varName);
                        % Geotiff writing
                        % ---------------
                        
                        outFilename = obj.espEnv.SnowTodayGeotiffFile(...
                            obj, outputDirectory2, 'Terra', thisDatetime, ...
                            varName);
                        geotiffwrite(outFilename, ...
                            varData, ...
                            outCellsReference, ...
                            'CoordRefSysCode', geotiffEPSG, ...
                            'TiffTags', struct('Compression', obj.geotiffCompression));
                        fprintf('%s: Wrote %s\n', mfilename(), outFilename);

                        % Generation of the no-processed layer which indicates the NaNs
                        if strcmp(varName, 'snow_fraction')
                            notProcessedData = varData == Variables.uint8NoData;
                            varData = [];
                            outFilename = obj.espEnv.SnowTodayGeotiffFile(...
                                obj, outputDirectory2, 'Terra', thisDatetime, ...
                                'notprocessed');
                            geotiffwrite(outFilename, ...
                                notProcessedData, ...
                                outCellsReference, ...
                                'CoordRefSysCode', geotiffEPSG, ...
                                'TiffTags', ...
                                struct('Compression', obj.geotiffCompression));
                            fprintf('%s: Wrote %s\n', mfilename(), ...
                                outFilename);
                            notProcessedData = [];
                        end
                        varData = [];
                    end
                end
                logger.printDurationAndMemoryUse(dbstack);
                fprintf('%s: Ended geotiff generation for date %s.\n', ...
                    mfilename(), string(thisDatetime, 'yy-MM-dd'));
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

            if ~exist('varName', 'var') || isnan(varName(1))
                availableVariablesSize = size(availableVariables);
                varIndexes = 1:availableVariablesSize(1);
            else
                % Check if the varName is ok
                index = find(strcmp(availableVariables.output_name, varName));
                if isempty(index)
                    ME = MException('Regions:WriteStats_UnauthorizedVarName', ...
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
