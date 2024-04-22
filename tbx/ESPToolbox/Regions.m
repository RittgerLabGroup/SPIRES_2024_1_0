classdef Regions < handle
    %Regions - information about spatial sub-regions (states/watersheds)
    %   This class contains functions to manage information about our
    %   subregions by state (county) and watersheds at several levels
    properties      % public properties
        archiveDir    % top-level directory with region data
        filter        % struct(stc = Table, snowCoverDay = Table, mosaic = Table,
                    % publish = Table, statistic = Table). Pointing to tables
                    % that stores the filter parameters at each generation step of the
                    % pipeline: (1) raw/gap/stc monthly cube files,
                    % (2) snow_cover_days calculation, (3) daily mosaic files,
                    % (4) published geotiff and netcdf files, (5) statistic files.
                    % table = table(thresholdedVarName (char),	
                    % minValue (int), maxValue (int), replacedVarName (char)).
                    % Minimum/max values of variables below which the data are
                    % considered unreliable to perform the operation
                    % (stc, snowCoverDay, etc ...).
                    % If the thresholdedVarName < minValue then
                    % the replacedVarName value is replaced by the value indicated
                    % in the file configuration_of_filters.csv
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
                        % and methods. Include the modisData property.
%{
                                                                               @obsolete
        snowCoverDayMins % Struct(minElevation (double), minSnowCoverFraction
                         % (double [0:100]))
                         % indicate the minimal elevation and minimal snow cover
                         % fraction to count a pixel as covered by snow.
                         % used in Variables.calcSnowCoverDays()
%}
        geotiffCrop     % Struct(xLeft (double), xRight (double), yTop (double),
                        % yBottom (double))
                        % Data to crop the geotiff reprojected raster for web use
        tileIds         % Names of the source tiles that are assembled in the Mosaic
                        % that constitute the upper level region.
        myConf          % struct(variable = table). Stores the info extracted from
                        % the configuration files.
        thresholdsForMosaics % table (thresholded_varname (char),
                        % threshold_value (int), replaced_varname (char)
                        % Minimum values of variables below which the data are
                        % considered unreliable and shouldn't be included in the
                        % Mosaic files.
                        % If the thresholded_varname < threshold_value then
                        % the replaced_varname value is replaced by the value indicated
                        % in the file configuration_of_filters.csv
        thresholdsForPublicMosaics % table (thresholded_varname (char),
                        % threshold_value (int), replaced_varname (char)
                        % Minimum values of variables below which the data are
                        % considered unreliable and shouldn't be released to public.
                        % If the thresholded_varname < threshold_value then
                        % the replaced_varname value is replaced by the value indicated
                        % in the file configuration_of_filters.csv
        modisData       % MODISData object, modis environment paths and methods
                        %                                                    @deprecated
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
            %    'State_mask', 'HUC2_mask' (for large drainage basins)
            % espEnv: ESPEnv object
            %    local environment variables, peculiarly the directory
            %    where are stored the region masks (= sub-regions,
            %    e.g. for 'State_masks' the entities are 'USAZ',
            %    'USCO', etc ...
            % modisData: MODISData object
            %    Modis environment, with paths . SIER_322/345                @deprecated
            % Mask variable
            %---------------
            if ~exist('maskName', 'var')
                maskName = 'State_mask';
            end
            if ~ischar(maskName)
                ME = MException('Region:inputError', ...
                    '%s: maskName %s is not of char type', ...
                    mfilename(), maskName);
                throw(ME);
            end

            obj.maskName = maskName;
            obj.regionName = regionName;
            obj.name = regionName; % NB: duplicate attribute. Improve this!        @todo
            obj.espEnv = espEnv;
            obj.modisData = espEnv.modisData;

            % Fetch the structure with the requested region information
            [regionFilePath, ~] = espEnv.getFilePathForObjectNameDataLabel( ...
                maskName, 'region');
            mObj = matfile(regionFilePath);
            varNames = who(mObj);
            if isempty(varNames)
                ME = MException('Region:BadRegionFile', ...
                    '%s: empty RegionFile %s\n', ...
                    mfilename(), regionFilePath);
                throw(ME);
            end

            obj.ShortName = mObj.ShortName;
            obj.LongName = mObj.LongName;
            obj.S = mObj.S;
            obj.indxMosaic = mObj.indxMosaic;
            obj.RefMatrix = mObj.RefMatrix;
            obj.percentCoverage = mObj.percentCoverage;
            obj.useForSnowToday = mObj.useForSnowToday;
            obj.lowIllumination = mObj.lowIllumination;

            % Configuration of region, links with subregions/tiles, and filtering.
            % In the following we modify the tables and column names stored in
            % configuration_of_thresholds.csv to fit the code elsewhere. This is a
            % temporary solution which should evolve in the future (i.e. we should
            % take the fieldnames in the file                                      @todo
            regionConf = espEnv.myConf.region(find(strcmp(espEnv.myConf.region.name, ...
                regionName)), :);
            obj.myConf = struct();
            obj.myConf.region = regionConf;
            obj.atmosphericProfile = regionConf.atmosphericProfile{1};
            obj.geotiffCrop.xLeft = regionConf.geotiffCropXLeft;
            obj.geotiffCrop.xRight = regionConf.geotiffCropXRight;
            obj.geotiffCrop.yBottom = regionConf.geotiffCropYBottom;
            obj.geotiffCrop.yTop = regionConf.geotiffCropYTop;

            regionLinkConf = espEnv.myConf.regionlink( ...
                strcmp(espEnv.myConf.regionlink.supRegionName, regionName), ...
                'subRegionName');
            obj.tileIds = table2cell(regionLinkConf);

            obj.filter.snowCoverDay = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.snowCoverDayConfId, :);
%{
                                                                               @obsolete                
            % renaming/copying columns: should edit Variables.calcSnowCoverDays()  @todo
            obj.snowCoverDayMins.minElevation = ...
                table2array(obj.filter.snowCoverDay( ...
                    strcmp(obj.filter.snowCoverDay.thresholdedVarName, ...
                        'elevation'), 'minValue'));
            obj.snowCoverDayMins.minSnowCoverFraction = ...
                table2array(obj.filter.snowCoverDay( ...
                    strcmp(obj.filter.snowCoverDay.thresholdedVarName, ...
                        'snow_fraction'), 'minValue'));
%}
            obj.filter.stc = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.stcConfId, :);
            % STC format should be simplified and copied from other filters        @todo
            stcStruct = struct();
            stcParam = {'rawRovDV', 'rawRovRF', 'temporalRovDV', ...
                'temporalRovRF', 'zthresh'};
            for paramIdx = 1:length(stcParam)
                thisLineName = stcParam{paramIdx};
                thisFilter = obj.filter.stc( ...
                    strcmp(obj.filter.stc.lineName, thisLineName), :);
                stcStruct.(thisLineName) = [thisFilter.minValue thisFilter.maxValue];
            end
            stcParam = {'mindays', 'sthreshForGS', 'sthreshForRF', ...
                'setViewableSnowFractionToNoDataIfVegDetectedCloud', ...
                'isViewableSnowFractionTheFilterBase', ...
                'areWeightsXByViewableSnowFraction', 'applyFalsePositiveMask', ...
                'gapAdjustMindaysWithoutNaNDays', ...
                'flattensEndOfTimeInterpolationWOData', ...
                'preIdwSnowFractionThreshold', 'idwMinCountOfPixels', ...
                'idwDefaultValueForgrain_size', 'idwDefaultValueFordrfs_grnsz', ...
                'idwDefaultValueFordeltavis', 'idwDefaultValueForradiative_forcing'
            };
            for paramIdx = 1:length(stcParam)
                thisLineName = stcParam{paramIdx};
                thisFilter = obj.filter.stc( ...
                    strcmp(obj.filter.stc.lineName, thisLineName), :);
                stcStruct.(thisLineName) = thisFilter.minValue;
            end
            stcStruct.canopyAdj = zeros([1 4], 'single');
            stcParam = {'minZForNonForestedAdjust', ...
                'nonForestedScaleFactor', 'minSnowForVegAdjust', 'canopyToTrunkRatio'};
            for paramIdx = 1:length(stcParam)
                thisLineName = stcParam{paramIdx};
                thisFilter = obj.filter.stc( ...
                    strcmp(obj.filter.stc.lineName, thisLineName), :);
                stcStruct.canopyAdj(paramIdx) = thisFilter.minValue;
            end
            
            stcParam = {'idwHalfSizeOfWindow'};
            for paramIdx = 1:length(stcParam)
                thisLineName = stcParam{paramIdx};
                tmpValue = Tools.valueInTableForThisField(obj.filter.stc, ...
                'lineName', thisLineName, 'arrayValues');
                tmpValue = str2double(split(tmpValue, ' '))';
                stcStruct.(thisLineName) = tmpValue;
            end
            
            obj.STC = STC(stcStruct);

            obj.filter.mosaic = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.mosaicConfId, :);
            % renaming/copying of table columns: should edit Mosaic                @todo
            obj.filter.mosaic.threshold_value = ...
                obj.filter.mosaic.minValue;
            obj.filter.mosaic.thresholded_varname = ...
                obj.filter.mosaic.thresholdedVarName;
            obj.filter.mosaic.replaced_varname = ...
                obj.filter.mosaic.replacedVarName;
            obj.thresholdsForMosaics = obj.filter.mosaic;

            obj.filter.publish = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.publishConfId, :);
            % renaming/copying of table columns: should edit Mosaic                @todo
            obj.filter.publish.threshold_value = ...
                obj.filter.publish.minValue;
            obj.filter.publish.thresholded_varname = ...
                obj.filter.publish.thresholdedVarName;
            obj.filter.publish.replaced_varname = ...
                obj.filter.publish.replacedVarName;
            obj.thresholdsForPublicMosaics = obj.filter.publish;

            obj.filter.statistic = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.statisticConfId, :);
            obj.filter.stc = espEnv.myConf.filter( ...
                espEnv.myConf.filter.id == regionConf.stcConfId, :);

            % Variables associated to the region.
            thisTable = obj.espEnv.myConf.variableregion( ...
                strcmp(obj.espEnv.myConf.variableregion.regionName, obj.name), :);
            thisTable = join(thisTable, obj.espEnv.myConf.variable, ...
                LeftKeys = 'varId', RightKeys = 'id', ...
                LeftVariables = {'writeGeotiffs', 'writeStats', 'isDefault'});
            obj.myConf.variable = thisTable;
        end
        function coordinates = buildModisSinuCoordinatesForReprojection(obj, ...
            geotiffEPSG)
            % Generate coordinates and save it in a file.
            %
            % Parameters
            % ----------
            % geotiffEPSG: int. EPSG code of the target reprojection.
            %
            % Then we start as if we reproject, using the functions within the
            % RasterProjection package, to obtain the coordinates Xq, Yq required for
            % interpolation in the output projection or geographic system.
            %
            % Return
            % ------
            % coordinates: struct(inMapCellsReference = mapCellsReference,
            %   outCellsReference = CellsReference, Xq = double(1xn), Yq = double(1xn)).
            %   Xq, Yq coordinates in Modis Sinusoidal
            %   projection for which the data have to be interpolated before projection
            %   into geotiffEPSG. The file additionally contains input and output
            %   cell reference (inMapCellsReference and outCellsReference).
            %   (outCellsReference can be geographic, this is why the name is not
            %   outMapCellsReference).

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
            %
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
            %
            % BEWARE: We stored this projMetadata. If the region changes of extent,
            % this file must be regenerated in a new version of Ancillary data.

            fprintf(['%s: Starting calculation of the input coordinates for ', ...
                'reprojection to EPSG:%s...\n'], mfilename(), num2str(geotiffEPSG));
            coordinates = struct();
            inMapCellsReference = obj.getMapCellsReference();
            outCellsReference = obj.getOutCellsReference(geotiffEPSG);

            % Obtain the coordinates in the input CellsReference
            % for which values will be interpolated to get the output in the
            % ouput CellsReference.
            fprintf('%s: Calculating the meshgrid ...\n', mfilename());
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
            fprintf('%s: Calculating the input coordinates...\n', mfilename());
            [Xq, Yq] = projfwd(inMapCellsReference.ProjectedCRS, ...
                lat, lon);
            [filePath, ~, ~] = obj.espEnv.getFilePathForDateAndVarName( ...
                obj.name, 'reprojectioncoordinates', '', '', ...
                ['EPSG_', num2str(geotiffEPSG)]);
            coordinates.Xq = Xq;
            coordinates.Yq = Yq;
            save(filePath, '-struct', 'coordinates', '-v7.3');
            fprintf(['%s: Saved the input coordinates for reprojection ', ...
                'to EPSG:%s in file .\n'], mfilename(), num2str(geotiffEPSG), filePath);
        end
        function buildTileSet(obj, dataLabel, thisDate, varName, geotiffEPSG)
            % Parameters
            % ----------
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. VariablesGeotiff.
            %   For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            % thisDate: datetime. For which we want the file.
            % varName: char. Name of the variable, otherwise set to ''.
            % geotiffEPSG: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857.
            %
            % NB: Only works for .geotiff (and .mat?) right now.
            complementaryLabel = '';
            if ~strcmp(geotiffEPSG, '')
                complementaryLabel = ['EPSG_', num2str(geotiffEPSG)];
            end
            fprintf('%s: Starting build of tile set for %s, %s, %s, %s, %s...\n', ...
                mfilename(), obj.name, dataLabel, char(thisDate, 'yyyy-MM-dd'), ...
                varName, complementaryLabel);
              
            tileRegions = obj.getTileRegions();
            tileFilePaths = {};
            tileMapCellsReferences = map.rasterref.MapCellsReference.empty();
            for tileIdx = 1:length(tileRegions)
                tileRegion = tileRegions(tileIdx);
                tileFilePaths{tileIdx} = obj.espEnv.getFilePathForDateAndVarName( ...
                    tileRegion.name, dataLabel, thisDate, varName, complementaryLabel);
                tileMapCellsReferences(tileIdx) = ...
                    tileRegion.getOutCellsReference(geotiffEPSG);
            end
            
            filePath = obj.espEnv.getFilePathForDateAndVarName(obj.name, ...
                dataLabel, thisDate, varName, complementaryLabel);
            mapCellsReference = obj.getOutCellsReference(geotiffEPSG);
            
            % 2.2. Generation of the Mosaic tileset.
            fprintf('%s: Building tile set for %s, %s, %s, %s, %s...\n', ...
                mfilename(), obj.name, dataLabel, char(thisDate, 'yyyy-MM-dd'), ...
                varName, complementaryLabel);
            tileSetIsGenerated = Tools.buildTileSet(tileFilePaths, ...
                tileMapCellsReferences, filePath, mapCellsReference);
            if tileSetIsGenerated == 0
                warning('%s: No generated tileset %s.\n', mfilename(), ...
                    filePath);
            else
                fprintf('%s: Saved tile set %s.\n', ...
                mfilename(), filePath);
            end
        end
%{
        function elevations = getElevations(obj)
            %                                                                  @obsolete
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
%}
        function firstMonth = getFirstMonthOfWaterYear(obj)
            % Return
            % ------
            % firstMonth: int. First month of the waterYear on which stats will be
            %   calculated for the region, depends on location of the region.
            % NB: takes the coordinates of the NW corner of the region.
            % NB: implementation doesn't work for north region touching Equator    @todo
            if max(obj.getMapCellsReference().YWorldLimits) > 0 % North Hemisphere
                firstMonth = WaterYearDate.defaultFirstMonthForNorthTiles;
            else % South Hemisphere
                firstMonth = WaterYearDate.defaultFirstMonthForSouthTiles;
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
            modisData = obj.espEnv.modisData;
            horizontalTileIds = zeros([1, length(obj.tileIds)], 'uint8');
            verticalTileIds = zeros([1, length(obj.tileIds)], 'uint8');
            for idx = 1:length(obj.tileIds)
                positionalTileData = ...
                    modisData.getTilePositionIdsAndColumnRowCount( ...
                    obj.tileIds{idx});
                horizontalTileIds(idx) = positionalTileData.horizontalId;
                verticalTileIds(idx) = positionalTileData.verticalId;
            end
            positionalData.horizontalId = min(horizontalTileIds);
            positionalData.verticalId = min(verticalTileIds);
            positionalData.columnCount = ...
                modisData.georeferencing.tileInfo.columnCount * ...
                length(unique(horizontalTileIds));
            positionalData.rowCount = ...
                modisData.georeferencing.tileInfo.rowCount * ...
                length(unique(verticalTileIds));

            mapCellsReference = obj.modisData.getMapCellsReference(positionalData);
        end
        function outCellsReference = getOutCellsReference(obj, geotiffEPSG)
            % Parameters
            % ----------
            % geotiffEPSG: int. EPSG code of the target reprojection.
            %
            % Then we start as if we reproject, using the functions within the
            % RasterProjection package.
            %
            % Return
            % ------
            % outCellsReference: matlab cell reference object. outCellsReference can be
            %   geographic, this is why the name is not outMapCellsReference.

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

            %
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

            fprintf(['%s: Starting calculation of the outCellsReference for ', ...
                'reprojection to EPSG:%s...\n'], mfilename(), num2str(geotiffEPSG));

            inMapCellsReference = obj.getMapCellsReference();
            outCellsReference = [];
            varData = ones(inMapCellsReference.RasterSize, 'uint8');
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
            fprintf(['%s: Determined the output cell reference for ', ...
                'EPSG:%s.\n'], mfilename(), num2str(geotiffEPSG));
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
                    obj.espEnv, obj.espEnv.modisData);

                % Override any default STC or snowCoverDayMins
                % settings with values from the upper-level regions obj
                regionsArray(tileIdx).STC = obj.STC;
%{
                regionsArray(tileIdx).snowCoverDayMins = ...
                    obj.snowCoverDayMins;
%}
            end
        end
        function waterYear = getWaterYearForDate(obj, thisDate)
            % Parameters
            % ----------
            % thisDate: datetime.
            %
            % Return
            % ------
            % waterYear: int.
            % NB: Assumes that waterYear is always the year of the last date of the
            %   waterYear, even if the start of waterYear is in March
            % (south hemisphere).
            firstMonth = obj.getFirstMonthOfWaterYear();
            waterYear = year(thisDate);
            if month(thisDate) >= firstMonth
                waterYear = year(thisDate) + 1;
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
            modisDataStruct = struct(obj.espEnv.modisData);
            stcStruct = struct(obj.STC);
            warning('on', 'MATLAB:structOnObject');
            save(outFilename, '-append', 'espEnvStruct', 'modisDataStruct', 'stcStruct');
                fprintf("%s: Appended espEnv/modisData/STC to %s\n", ...
                    class(obj), outFilename);

        end

        function writeGeotiffs(obj, ...
            varName, waterYearDate, geotiffEPSG, varargin)
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
            % waterYearDate: waterYearDate.
            %         Dates for which stats are calculated.
            % geotiffEPSG: int. Code EPSG of the projection or geographic system.
            %   SIER_163.
            % parallelWorkersNb: int, optional. Number of parallel workers. 
            %   By default 0, which means that generation is not parallel.
            %   Beware we cannot have 2 parfor loops imbricated. 2024-03-19.

            tic;
            fprintf(['%s: Start regional geotiffs generation and writing for', ...
                ' region %s, EPSG %d, waterYear %d ...\n'], mfilename(), ...
                obj.regionName, geotiffEPSG, year(waterYearDate.thisDatetime));
            
            p = inputParser;
            addParameter(p, 'parallelWorkersNb', 0);
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            parallelWorkersNb = p.Results.parallelWorkersNb;
            
            espEnv = obj.espEnv;
            publicMosaic = PublicMosaic(obj);

            % Variables and output directory
            %-------------------------------
            % NB: Need to make dynamic (if no data for variable, don't try to generate
            % the geotiff.                                                       @todo
            availableVariables = espEnv.myConf.variableregion( ...
                strcmp(espEnv.myConf.variableregion.regionName, obj.name) & ...
                espEnv.myConf.variableregion.writeGeotiffs == 1, ...
                {'varId'});
            availableVariables = join(availableVariables, espEnv.myConf.variable, ...
                LeftKeys = 'varId', ...
                RightKeys = 'id', LeftVariables = {}, ...
                RightVariables = {'id', 'output_name', 'nodata_value', 'type'});

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
                        sprintf(['%s: varName %s not found in the ', ...
                        'list of authorized outputnames in ', ...
                        'ESPEnv.variableregion limited to the region %s\n'],  ...
                        mfilename(), varName, obj.name));
                    throw(ME)
                else
                    varIndexes = index;
                end
            end

            % Current year (for file naming)
            % ------------------------------
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
            % NB: this implies that viewable_snow_fraction must be write_geotiffs =1
            % in the configuration_of_variableregion.csv file.
            varnamesToPreLoad = intersect( ...
                availableVariables.output_name, ...
                unique(obj.thresholdsForPublicMosaics.thresholded_varname));

            % Obtain output projection/system.

            % Then we start as if we reproject, using the functions within the
            % RasterProjection package, to obtain the coordinates Xq, Yq required for
            % interpolation in the output projection or geographic system.         

            % Reprojection
            % ------------

            % Determine outCellsReference.
            outCellsReference = obj.getOutCellsReference(geotiffEPSG);
            % Determine Xq and Yq ...
            coordinates = obj.espEnv.getDataForDateAndVarName( ...
                obj.name, 'reprojectioncoordinates', '', '', ...
                ['EPSG_', num2str(geotiffEPSG)]);
            if isempty(coordinates)
                coordinates = ...
                    obj.buildModisSinuCoordinatesForReprojection(geotiffEPSG);

            end
            fprintf('%s: Got the input coordinates.\n', mfilename());

            % Generation
            % ----------
            % Start or connect to the local pool (parallelism)
            % This processing tends to be a memory hog, with each worker
            % needing as much as 70GB memory.
            % So, plan to run this system on alpine with 32 tasks in order
            % to get all the memory on the node, and then limit workers here
            % SIER_163 and SIER_333 should have solve this problem.
            espEnv.configParallelismPool(4); %length(varIndexes)); % currently 8 variables

            for dateIdx=1:length(dateRange)
                logger = Logger('geotiffDate');
                thisDate = dateRange(dateIdx);
                fprintf('%s: Starting geotiff generation for date %s.\n', ...
                    mfilename(), string(thisDate, 'yyyy-MM-dd'));
                % Check if Mosaic file is available.
                if ~isfile(espEnv.MosaicFile(obj, thisDate))
                    warning(['%s: Unavailable mosaic. No Geotiff generation for ', ...
                        '%s\n'], mfilename(), string(thisDate, 'yyyy-MM-dd'));
                    continue;
                end

                % Get the variables necessary to filter/threshold the other variables.
                % There should be only 1, snow_fraction (or viewable_snow_fraction) and
                % elevation.
                initPublicMosaicData = struct();
                for varIdx = 1:length(varnamesToPreLoad)
                    varName = varnamesToPreLoad{varIdx};
                    initPublicMosaicData = publicMosaic.getThresholdedData(varName, ...
                        thisDate, initPublicMosaicData);
                end
                fprintf('%s: Got the data for filter.\n', mfilename());
                % We handle each variable to generate a geotiff.
                parfor (varIdx=1:length(varIndexes), parallelWorkersNb), 
                    % varName info
                    % ------------
                    % get the output name and units
                    varNameInfos = availableVariables(varIndexes(varIdx), :);
                    varName = varNameInfos.('output_name'){1};
                    fprintf('%s: Handling variable %s...\n', mfilename(), varName);

                    % We only handle notprocessed variable in association to snow_fraction.
                    if length(varName) >= 12 && strcmp(varName(1:12), 'notprocessed')
                        continue;
                    end
                    fprintf('%s: Starting geotiff generation for variable %s ...\n', ...
                        mfilename(), varName);

                    % Data load
                    % ---------
                    publicMosaicData = publicMosaic.getThresholdedData(varName, ...
                        thisDate, initPublicMosaicData);
                    fprintf('%s: Public mosaic for variable %s OK.\n', ...
                        mfilename(), varName);
                    if ~ismember(varName, fieldnames(publicMosaicData))
                        warning('%s: No Geotiff generation for %s on %s\n', ...
                            mfilename(), varName, string(thisDate, 'yyyy-MM-dd'));
                    else
                        varData = publicMosaicData.(varName);
                        publicMosaicData = [];

                        % Get the data interpolated at the  coordinates of the output
                        % reference system. SIER_163.
                        %---------------------------------------------------------------
                        varData = single(varData);
                        varData(varData == varNameInfos.nodata_value) = NaN;
                        fprintf('%s: Interpolation to the output reference...\n', ...
                            mfilename());
                        varData = mapinterp(varData, ...
                                inMapCellsReference, ...
                                coordinates.Xq, coordinates.Yq, 'nearest');
                           % NB: varData and inMapCellsReference should be the same
                           % size, beware that had generated a pb for USAlaska for which
                           % we lately removed h07v03.
                        fprintf('%s: Done interpolation to the output reference.\n', ...
                            mfilename());
                        varData(isnan(varData)) = varNameInfos.nodata_value;
                        varData = cast(varData, varNameInfos.type{1});
                        fprintf('%s: Interpolated variable %s OK.\n', ...
                            mfilename(), varName);
                        % Geotiff writing
                        % ---------------

                        [outFilePath, ~, ~] = ...
                            obj.espEnv.getFilePathForDateAndVarName( ...
                            obj.name, 'VariablesGeotiff', thisDate, varName, ...
                            ['EPSG_', num2str(geotiffEPSG)]);
                        geotiffwrite(outFilePath, ...
                            varData, ...
                            outCellsReference, ...
                            'CoordRefSysCode', geotiffEPSG, ...
                            'TiffTags', struct('Compression', obj.geotiffCompression));
                        fprintf('%s: Wrote %s\n', mfilename(), outFilePath);

                        % Generation of the no-processed layer which indicates the NaNs
                        if ismember(varName, {'snow_fraction', 'snow_fraction_s'})
                            notProcessedVarName = ['notprocessed', ...
                                replace(varName, 'snow_fraction', '')];
                                % We get the extension of snow_fraction variable, either
                                % none, or '_s'.
                                % It's very dirty....                              @todo
                            notProcessedData = varData == Variables.uint8NoData;
                            varData = [];
                            outFilePath = ...
                                obj.espEnv.getFilePathForDateAndVarName( ...
                                obj.name, 'VariablesGeotiff', thisDate, ...
                                notProcessedVarName, ['EPSG_', num2str(geotiffEPSG)]);
                            geotiffwrite(outFilePath, ...
                                notProcessedData, ...
                                outCellsReference, ...
                                'CoordRefSysCode', geotiffEPSG, ...
                                'TiffTags', ...
                                struct('Compression', obj.geotiffCompression));
                            fprintf('%s: Wrote %s\n', mfilename(), ...
                                outFilePath);
                            notProcessedData = [];
                        end
                        varData = [];
                    end % end if
                end % end parfor varIdx
                logger.printDurationAndMemoryUse(dbstack);
                fprintf('%s: Ended geotiff generation for date %s.\n', ...
                    mfilename(), string(thisDate, 'yyyy-MM-dd'));
            end % end dateIdx
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
            %        for 'USAZ' in the object Regions 'State_mask'
            %        Beware, this index may not be unique.
            %        If not input, write files for all subregions.
            % varName: str, Optional
            %         name of the variable on which the stats are aggregated
            %         e.g. albedo_clean_muZ, albedo_observed_muZ, snow_fraction
            %         must be in configuration_of_variables.csv.
            %         When input, write output csv files only for varName.
            %         When not input, write csv files for all variables.
            % waterYearDate: waterYearDate.
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
            % waterYearDate: waterYearDate.
            %    Date of the run (today, or another day before if necessary)

            % Dates
            %------
            waterYear = waterYearDate.getWaterYear();
            modisBeginWaterYear = obj.espEnv.modisData.beginWaterYear;
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
                    partitionName = 'State_mask';
                case 12
                    partitionName = 'HUC2_mask';
                case 14
                    partitionName = 'HUC4_mask';
%{
                case 16
                    partitionName = 'HUC6_mask';
                case 18
                    partitionName = 'HUC8_mask';
%}
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
