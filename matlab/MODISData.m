classdef MODISData < handle
    %MODISData - manages our inventory of MODIS tile data
    %   This class contains functions to manage our copy of MODIS tile
    %   data, including MOD09, modscag and moddrfs
    %
    % WARNING: Called MODISData but should be renamed Sensor or something like that.
    %   also used for viirs (controlled by inputProduct properties)             @warning
    %
    properties      % public properties
        algorithm = 'spires'; % spires (default) or stc.
        archiveDir    % top-level directory with tile data
                        % NB: check hownot to duplicate information with ESPEnv dirs
                        %                                                          @todo
        % alternateDir  % top-level directory with tile data on scratch        @obsolete
        espEnv      % ESPEnv obj.
        fileNamePrefix % Struct(char).
        firstMonthOfWaterYear = 10; % Int. First month of water year for the run.
            % North hemisphere: 10, south: 4. Determined from
            % configuration_of_regions.csv.
        inputProduct  % char. Input product currently the name of lpdaac products
            % (sensor, platform), for instance mod09ga or vnp09ga. For Landsat Oli,
            % concatenation of sensor/satellite and processing correction level:
            % lc08.l2sp, lc09.l2sp.
        inputProductVersion % char. Version (= Collection) of the input product, for
            % instance 061 for
            % mod09ga spires (v6.1). Patterns corresponds to the version code inserted
            % in the filename of the lpdaac product. For Landsat Oli, concatenation of
            % collection number and collection category: 02.t1 (t1 for Tier 1).

        georeferencing = struct(northwest = struct(x0 = - pi * 6.371007181e+06, ...
            y0 = pi * 6.371007181e+06 / 2), tileInfo = struct( ...
                dx = 2 * pi * 6.371007181e+06 / 36 / 2400, ...
                dy = 2 * pi * 6.371007181e+06 / 36 / 2400, ...
                columnCount = 2400, rowCount = 2400)); % Inspired from Jeff Dozier's
                                                       % RasterReprojection package.
%{
% Before 2023-06-19:
        georeferencing = struct(northwest = struct(x0 = -2.001534101036227e+07, ...
            y0 = 1.000778633335726e+07), tileInfo = struct(dx = 4.633127165279165e+02, ... %4.633127165279169e+02, ...
            dy = 4.633127165279165e+02, columnCount = 2400, rowCount = 2400));
%}
        pixSize_500m = 2 * pi * 6.371007181e+06 / 36 / 2400; %4.633127165279165e+02; %463.31271653; % @deprecated.
        mstruct % mapping structure for MODIS sinusoidal projection. STC.
        cstruct % structure with units/fields for MOD09GA files. STC.
        endDateOfHistoricJPLFiles = datetime(2018, 12, 29);
            % Date of the last historic files available at JPL. At this date + 1, only available
            % nrt files. Determine where Step0 Modis files are stored
            % either under historic folder or nrt folder.
        versionOf % version structure for various stages of processing
    end
    properties(Constant)
        beginWaterYear = 2001;
        bitValues = 0:15; % Values of bits in state_1km_1 and QC_500m bit variables of
            % mod09ga files.
        % defaultArchiveDir = '/pl/active/rittger_esp/modis';                 % obsolete
        defaultVersionOf = struct(ancillary = 'v3.1');
        projection = struct(modisSinusoidal = struct( ...
            ... % GeoKeyDirectoryTag to generate the geotiffs in sinusoidal projection.
            ... % Tag documentation: http://geotiff.maptools.org/spec/geotiff6.html
            ... % or https://svn.osgeo.org/metacrs/geotiff/trunk/geotiff/html/usgs_geotiff.html
            geoKeyDirectoryTag = struct( ...
                GTModelTypeGeoKey = 1, ... % projected.
                GTRasterTypeGeoKey = 1, ... % cells (areas).
                ProjectedCSTypeGeoKey = 32767, ... % user-defined projection.
                PCSCitationGeoKey = 'MODIS Sinusoidal', ...
                ProjectionGeoKey = 32767, ... % user-defined projection.
                ProjCoordTransGeoKey = 24, ... % CT_Sinusoidal
                ProjLinearUnitsGeoKey = 9001, ... % linear_meter
                ProjFalseEastingGeoKey = 0.0, ...
                ProjFalseNorthingGeoKey = 0.0, ...
                GeographicTypeGeoKey = 32767, ... % World Geodetic Survey 1984
                GeogCitationGeoKey = 'User with datum World Geodetic Survey 1984', ... % World Geodetic Survey 1984. GeogGeodeticDatumGeoKey = 4326 don't yield the correct tags in the geotiff.
                GeogAngularUnitsGeoKey = 9102, ... % Angular_Degree
                GeogEllipsoidGeoKey = 32767, ... % user-defined ellipsoid.
                GeogSemiMajorAxisGeoKey = 6.371007181000000e+06, ... % Semi-major axis
                GeogSemiMinorAxisGeoKey = 6.371007181000000e+06), ... % Semi-minor axis
            ... % Well-known text to generate the projection crs. Necessary because
            ... % there is no EPSG code for sinusoidal, and Matlab don't accept code
            ... % other than from EPSG.
            proj4 = '+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs +nadgrids=@null +wktext', ...
            wkt = "PROJCS[""MODIS Sinusoidal"",BASEGEOGCRS[""User"",DATUM[""World Geodetic Survey 1984"",SPHEROID[""Authalic_Spheroid"",6371007.181,0.0]],PRIMEM[""Greenwich"",0.0],UNIT[""Degree"",0.0174532925199433]],PROJECTION[""Sinusoidal""],PARAMETER[""False_Easting"",0.0],PARAMETER[""False_Northing"",0.0],PARAMETER[""Central_Meridian"",0.0],UNIT[""Meter"",1.0]]", ...
            wkt2 = 'PROJCS["MODIS Sinusoidal",GEOGCS["User with datum World Geodetic Survey 1984",DATUM["unnamed",SPHEROID["unnamed",6371007.181,0]],PRIMEM["Greenwich",0],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]]],PROJECTION["Sinusoidal"],PARAMETER["longitude_of_center",0],PARAMETER["false_easting",0],PARAMETER["false_northing",0],UNIT["metre",1,AUTHORITY["EPSG","9001"]],AXIS["Easting",EAST],AXIS["Northing",NORTH]]', ...
            geocrsWkt = 'GEOGCRS["User",DATUM["World Geodetic Survey 1984",ELLIPSOID["Authalic_Spheroid",6371007.181,0,LENGTHUNIT["metre",1,ID["EPSG",9001]]]],PRIMEM["Greenwich",0,ANGLEUNIT["Degree",0.0174532925199433]],CS[ellipsoidal,2],AXIS["longitude",east,ORDER[1],ANGLEUNIT["Degree",0.0174532925199433]],AXIS["latitude",north,ORDER[2],ANGLEUNIT["Degree",0.0174532925199433]]]' ...
            ));
        %tileRows_500m = 2400;
        %tileCols_500m = 2400;
        %pixSize_1000m = pixSize_500m * 2;
        %tileRows_1000m = 1200;
        %tileCols_1000m = 1200;
        % Band values for Modis v6 and viirs.
        reflectanceBandIds = struct( ...
            green = 4, ...
            nir = 2, ...
            red = 1, ...
            redspires = 3, ...
            swir = 6 ... % SWIR band, 6 for MODIS and L8
            ), ...
            ;
        sensorProperties = struct(orbitHeight = 705, ...
            tiling = struct(columnCount = 36, ...
                rowCount = 18, ...
                columnPixelCount = 2400, ...
                rowPixelCount = 2400)); % constant for spires. Units?
                % this is for modis and viirs resolution 463 m.
                % Beware for viirs, reflectance bands are mostly on resolution 926 m.
    end
    methods         % public methods
        function obj = MODISData(varargin)
            % The MODISData constructor initializes the directory
            % for local storage of MODIS tile data

            p = inputParser;

            % The default versionOf label
            % For operational processing, this can be set to something
            % consistent, e.g. 'v2023.0', or the individual versionOf
            % labels can be controlled by the caller
            defaultLabel = 'test';
            checkLabel = @(x) isstring(x) | ischar(x);
            addParameter(p, 'algorithm', 'spires');
            addParameter(p, 'inputProduct', 'mod09ga');
            addParameter(p, 'inputProductVersion', '061');
            addParameter(p, 'label', defaultLabel, checkLabel);
            addParameter(p, 'versionOfAncillary', obj.defaultVersionOf.ancillary);
            addParameter(p, 'firstMonthOfWaterYear', ...
                WaterYearDate.defaultFirstMonthForNorthTiles);

            p.KeepUnmatched = false;
            parse(p, varargin{:});

            label = p.Results.label;
            obj.algorithm = p.Results.algorithm;
            obj.archiveDir = getenv('espArchiveDir');                      % @deprecated
            obj.inputProduct = p.Results.inputProduct;

            obj.inputProductVersion = p.Results.inputProductVersion;
            obj.firstMonthOfWaterYear = p.Results.firstMonthOfWaterYear;

            % Set various versions needed to control where data
             % are located.

             % MODISCollection is major version of MOD09GA files
             % Raw/Gap/Interp cubes and Daily file version strings
             % are used for directory hierarchy and some filenames
             % Free-form string, by convention do not use '_' or
             % '.' as first characters.                                        @obsolete

             % Directories:
             % If non-empty, these strings will be appended to the directory
             % names in ESPEnv as '<dir>_<versionOf.(dataType)>'
             % If empty, these strings will not be appended
             % Filenames:
             % If non-empty, these strings will be appended to
             % filenames as 'file.<versionOf.(dataType)>.ext'
             % If empty, these strings will not be used in filenames
            obj.fileNamePrefix = struct( ...
                MOD09Raw = 'RawMOD09', ...
                SCAGDRFSRaw = 'RawSCAG', ...
                SCAGDRFSGap = 'GapSCAG', ...
                SCAGDRFSSTC = 'InterpSCAG');
            obj.versionOf = struct(...
                'ancillary', p.Results.versionOfAncillary, ...
                'backgroundreflectanceformodisforwateryear', label, ...
                'backgroundreflectanceforviirsforwateryear', label, ...
                'platform', 'Terra', ...
                'mod09gaInDaac', label, ...
                'scagDrfsUnMaskedTifInDaac', label, ...
                'mod09gaFromJPL', label, ...
                'modScagDatFromJPL', label, ...
                'modDrfsDatFromJPL', label, ...
                'modscagdrfs', label, ...
                'MOD09Raw', label, ...
                'SCAGDRFSRaw', label, ...
                'mod09ga', label, ...
                'vnp09ga', label, ...
                'lc08_l2sp', label, ...
                'lc08_l2sptxt', label, ...
                'lc08_l2spjson', label, ...
                'lc09_l2sp', label, ...
                'lc09_l2sptxt', label, ...
                'lc09_l2spjson', label, ...
                'scagdailybip', label, ...
                'scagdailybipmeta', label, ...
                'scagdailytif', label, ...
                'mod09gasqueezed', label, ...
                'modisspiresfill', label, ...
                'modspiresdaily', label, ...
                'modspirestime', label, ...
                'modspirestimebycell', label, ...
                'modspiresyeartmp', label, ...
                'modisspiressmooth', label, ...
                'modisspiressmoothbycell', label, ...
                'SCAGDRFSGap',  label, ...
                'SCAGDRFSSTC',  label, ...
                'spiresdailytifsinu', label, ...
                'spiresdailymetadatajson', label, ...
                'modspiresdailytifsinu', label, ...
                'modspiresdailymetadatajson', label, ...
                'vnpspiresdailytifsinu', label, ...
                'vnpspiresdailymetadatajson', label, ...
                'VariablesMatlab',  label, ...
                'variablesmatlab2', label, ...
                'daacnetcdfv20220', label, ...
                'daacnetcdfv202301', label, ...
                'outputnetcdf', label, ...
                'spiresdailynetcdf', label, ...
                'spiresfill', label, ...
                'spiressmoothbycell', label, ...
                'VariablesNetCDF',  label, ...
                'spiresdailytifproj', label, ...
                'VariablesGeotiff',  label, ...
                'VariablesGeotiffv20231',  label, ...
                'RegionalStatsMatlab',  label, ...
                'SubdivisionStatsAggregCsv',  label, ...
                'SubdivisionStatsDailyCsv', label, ...
                'SubdivisionStatsWebCsvv20231', label, ...
                'SubdivisionStatsWebJson', label, ...
                'RegionalStatsCsv',  label, ...
                'vnpspiresdaily', label, ...
                'vnpspirestime', label, ...
                'vnpspirestimebycell', label, ...
                'vnpspiresyeartmp', label);

            obj.versionOf.MODISCollection = 6;                             % @deprecated
            % kept for obsolete scripts
        end
        function [varData, bitData] = getDataForDateAndVarName(obj, ...
            objectName, dataLabel, thisDate, varName, varData)
            % Get mod09ga/modisspiresdaily data for a certain date and variable name.
            %
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw, .
            % thisDate: datetime. Cover the day for which we want the
            %   files.
            % varName: name of the variable to load. Should be the output name
            %   (see configuration_of_variables.csv).
            % varData: 2D or 3D array(single). Value of the variable stored in the
            %   original file if previously
            %   obtained by the same method (avoid reloading the data). Only used if the
            %   variable required is a bit-part of the variable stored in the file, for
            %   instance cloud from state_1km_1. Otherwise, can be set to [].
            %
            % Return
            % ------
            % varData: 2D or 3D array(single or uint16/32) read from the variable
            %   stored in the file
            %   (e.g. a 3D array of the 7 reflectance bands, a 2D array of solar zenith
            %   scaled to the 500m resolution, or state_1km_1).
            %   If absent file, return an array of NaN
            % bitData: 2D array(uint8). Filled if the variable is a bit part of a
            %   variable stored in the original file, for instance cloud from the
            %   variable state_1km_1.
            %   Void otherwise (e.g. for reflectance or solar zenith).
            %   If file absent, return an array of intmax('uint8').
            %
            % NB: only works for dataLabel in mod09ga.
            % NB: doesn't check if the variable is present in file.                @todo
            % NB: I put this method here rather than ESPEnv
            % because it's really dependent on the source,
            % modis or viirs and what the source contain as data. I'm not sure this
            % method should or shouldn't be extended to other type of files
            %  (intermediary for instance).

            % 1. Check valid dataLabel and get list of files for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            if ~ismember(dataLabel, {'mod09ga', 'modisspiresdaily'})
                errorStruct.identifier = ...
                    'modisData:getDataForDateAndVarName:BadDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be mod09ga.'], mfilename(), dataLabel);
                error(errorStruct);
            end

            % Configuration of the variable.
            varConf = obj.espEnv.myConf.variable(strcmp( ...
                obj.espEnv.myConf.variable.output_name, varName), :);

            % 2. Construction of varData, the array of values extracted from the file.
            %---------------------------------------------------------------------------
            if isempty(varData)
                % Configuration of the source variable, different only if the variable
                % is a bit part of a variable stored in the file.
                originalVarConf = obj.espEnv.myConf.variable(ismember( ...
                    obj.espEnv.myConf.variable.([dataLabel, '_name']), ...
                    varConf.([dataLabel, '_name'])) & ...
                    obj.espEnv.myConf.variable.([dataLabel, '_bitPosition']) == 255, :);

                region = Regions(objectName, [objectName, '_mask'], obj.espEnv, obj);
                [filePath, fileExists] = ...
                    obj.espEnv.Step0ModisFilename(region, thisDate, dataLabel);
                    % call should be modified when method is extended to other source
                    % files                                                        @todo
                if fileExists == 1
                    varData = hdfread(filePath, ...
                        originalVarConf.([dataLabel, '_name']){1});
                    varDataIsNotNoData = 1;
                else
                    varData = NaN(size(varData, 1), size(varData, 2));
                    warning('%s: Absent file %s. Data filled by NaN.\n', ...
                        mfilename(), filePath);
                end
                    % 2D array.

                % If variable is reflectance, construct a 3D array to assemble the
                % 7 bands.
                if size(originalVarConf, 1) > 1
                    tmpVarData = NaN(size(varData, 1), size(varData, 2), ...
                        size(originalVarConf, 1));
                    tmpVarData(:, :, 1) = varData;
                    varData = tmpVarData;
                    if fileExists == 1
                        for sourceIdx = 2:size(originalVarConf, 1)
                            varData(:, :, sourceIdx) = hdfread(filePath, ...
                                originalVarConf.([dataLabel, '_name']){sourceIdx});
                        end
                    end
                end
                % check the min/max and no data only for non bit-composed variable
                % otherwise there might be a problem of precision ...
                % we suppose that the scale for these bit-variable is always 1.
                if varConf.([dataLabel, '_bitPosition'])(1) == 255
                    varData = single(varData);
                    varData(varData == ...
                        originalVarConf.([dataLabel, '_nodata_value'])(1) ...
                        | varData < originalVarConf.([dataLabel, '_min'])(1) | ...
                        varData > originalVarConf.([dataLabel, '_max'])(1)) = NaN;
                    varData = varData * ...
                        originalVarConf.([dataLabel, '_scale'])(1);
                end
                varData = imresize(varData, ...
                        originalVarConf.([dataLabel, '_resamplingFactor'])(1), ...
                        'nearest');
            else
                varDataIsNotNoData = 1;
            end

            % 3. Construction of bitData, the bit-value of the variable required.
            %---------------------------------------------------------------------------
            bitData = [];
            if varConf.([dataLabel, '_bitPosition'])(1) ~= 255
                if varDataIsNotNoData == 1
                    bitData = cast(bitand(bitshift(varData, ...
                        -varConf.([dataLabel, '_bitPosition'])(1)), ...
                        2^varConf.([dataLabel, '_bitCount'])(1) - 1), 'uint8');
                else
                    bitData = intmax('uint8') * ones(size(varData,1), ...
                    size(varData, 2), 'uint8');
                end
            end
        end
        function firstMonth = getFirstMonthOfWaterYear(obj, tileRegionName)
            %                                                                @deprecated
            % Parameters
            % ----------
            % tileRegionName: char. Tile region name (format h00v00).
            %
            % Return
            % ------
            % firstMonth: int. First month of the waterYear on which stats will be
            %   calculated for the tile region, depends on location of the region.
            positionalData = obj.getTilePositionIdsAndColumnRowCount(tileRegionName);
            if positionalData.verticalId <= 8 % North Hemisphere
                firstMonth = WaterYearDate.defaultFirstMonthForNorthTiles;
            else % South Hemisphere
                firstMonth = WaterYearDate.defaultFirstMonthForSouthTiles;
            end
        end
        function mapCellsReference = getMapCellsReference(obj, positionalData, varargin)
            % Parameters
            % ----------
            % positionalTileData: struct(horizontalId=int, verticalId=int,
            %   columnCount=int, rowCount=int).
            %   - horizontalId: horizontal id of the tile.
            %   - verticalId: vertical id of the tile.
            %   - columnCount: number of pixels along a row of the tile.
            %   - rowCount: number of pixels along a column of the tile.
            % resamplingFactor: int, optional. By default 1, if "native resolution"
            %   used, for modis/viirs 2400x2400 with pixel size 4.633127165279165e+02.
            %   Put 2 for tiles of 1200x1200.
            %
            % Return
            % ------
            % mapCellsReference: MapCellsReference object.
            % SIER_320.
            %
            % NB/NetCDF: Beware that before matlab 2022, the ProjectedCRS.GeographicCRS
            %   property of the mapCellsReference object is not set.
            % To access this property, you should call geocrs(MODISData.geocrsWkt);
            p = inputParser;
            addParameter(p, 'resamplingFactor', 1);
            p.StructExpand = false;
            parse(p, varargin{:});
            resamplingFactor = p.Results.resamplingFactor;
            if ~ismember(resamplingFactor, [1, 2])
              error('BadResamplingFactor', ['MODISData:getMapCellsReference(): ', ...
                'only resamplingFactor of 1 (default) or 2 allowed']);
            end

            theseFieldnames = fieldnames(positionalData);
            for fieldIdx = 1:length(theseFieldnames)
                positionalData.(theseFieldnames{fieldIdx}) = cast( ...
                    positionalData.(theseFieldnames{fieldIdx}), 'double');
                    % required by maprefcells.
            end
            dx = obj.georeferencing.tileInfo.dx * resamplingFactor;
            dy = obj.georeferencing.tileInfo.dy * resamplingFactor;
            northWestX =  obj.georeferencing.northwest.x0 + ...
                positionalData.horizontalId * ...
                obj.georeferencing.tileInfo.columnCount / resamplingFactor * dx;
                % don't use positionalData.columnCount here, we need the size of modis
                % elemental tiles to get the space from x0.
            northWestY = obj.georeferencing.northwest.y0 - ...
                positionalData.verticalId * ...
                obj.georeferencing.tileInfo.rowCount / resamplingFactor * dy;
            refMatrix = [[0 -dy];[dx 0];[northWestX + dx  / 2 - dx, ...
                northWestY - dy / 2 + dy]]; % Should give result same as deprecated
                                            % makerefmat()
            mapCellsReference = refmatToMapRasterReference(refMatrix,...
                    [positionalData.rowCount positionalData.columnCount] ...
                      / resamplingFactor);
%{
% Version before 2023-06-19. Doesn't work for some tiles and didn't figure out why.
            mapCellsReference = maprefcells([ ...
                northWestX + dx / 2, ...
                northWestX - dx / 2 + dx * positionalData.columnCount], ...
                [northWestY + dy / 2 - dy * positionalData.rowCount, ...
                northWestY - dy / 2], ...
                dx, dy, 'ColumnsStartFrom','north');
%}
            mapCellsReference.ProjectedCRS = ...
                    projcrs(obj.projection.modisSinusoidal.wkt);
            % Patch for matlab 2021, to remove when transitioned to matlab 2022:   @todo
            %mapCellsReference.ProjectedCRS.GeographicCRS = geocrs(obj.geocrsWkt);

        end
        function positionalData = getTilePositionIdsAndColumnRowCount( ...
            obj, tileRegionName, varargin)
            % Parameters
            % ----------
            % tileRegionName: char. Tile region name (format h00v00).
            % resamplingFactor: int, optional. By default 1, if "native resolution"
            %   used, for modis/viirs 2400x2400 with pixel size 4.633127165279165e+02.
            %   Put 2 for tiles of 1200x1200.
            %
            % Return
            % ------
            % positionalData: struct(horizontalId=int, verticalId=int,
            %   columnCount=int, rowCount=int).
            %   - horizontalId: horizontal id of the tile.
            %   - verticalId: vertical id of the tile.
            %   - columnCount: number of pixels along a row of the tile.
            %   - rowCount: number of pixels along a column of the tile.
            % SIER_320.
            p = inputParser;
            addParameter(p, 'resamplingFactor', 1);
            p.StructExpand = false;
            parse(p, varargin{:});
            resamplingFactor = p.Results.resamplingFactor;
            if ~ismember(resamplingFactor, [1, 2])
              error('BadResamplingFactor', ...
                ['MODISData:getTilePositionIdsAndColumnRowCount(): ', ...
                'only resamplingFactor of 1 (default) or 2 allowed']);
            end

            positionalData.horizontalId = str2num(tileRegionName(2:3));
            positionalData.verticalId = str2num(tileRegionName(5:6));
            positionalData.columnCount = ...
              obj.georeferencing.tileInfo.columnCount / resamplingFactor;
            positionalData.rowCount = ...
              obj.georeferencing.tileInfo.rowCount / resamplingFactor;

            % Bypass the MockRegionDataset tiles, which don't have this
            % nomenclature. We want to be at lat/lon similar to h08v04.
            % @todo. this is quick and dirty.                           TODO
            if isempty(positionalData.horizontalId)
                positionalData.horizontalId = str2num(tileRegionName(9:9)) - 1;
                positionalData.verticalId = 0;
            end
        end
        function relativePositionalData = getTileRelativePositionIds( ...
            obj, tileRegionName, arrayOfTileRegionNames)
            % Used to generate ancillary data for new Regions. BEWARE!!!!!!
            %
            % Parameters
            % ----------
            % tileRegionName: char. Tile region name (format h00v00).
            % arrayOfTileRegionNames: cells(char). Cell list of tile regionNames, which
            %   should include tileRegionName.
            %
            % Return
            % ------
            % positionalData: struct(horizontalId=int, verticalId=int).
            %   - horizontalId: relative horizontal id of the tile.
            %   - verticalId: relative vertical id of the tile.
            % Alaska, with SIER_365.

            for tileIdx = 1:length(arrayOfTileRegionNames)
                thatTileRegionName = arrayOfTileRegionNames{tileIdx};
                thatPositionalData = obj.getTilePositionIdsAndColumnRowCount( ...
                    thatTileRegionName);
                if tileIdx == 1
                    thatHorizontalId = thatPositionalData.horizontalId;
                    thatVerticalId = thatPositionalData.verticalId;
                else
                    thatHorizontalId = min(thatHorizontalId, ...
                        thatPositionalData.horizontalId);
                    thatVerticalId = min(thatVerticalId, thatPositionalData.verticalId);
                end
            end
            thisPositionalData = obj.getTilePositionIdsAndColumnRowCount( ...
                    tileRegionName);
            relativePositionalData = struct();
            relativePositionalData.horizontalId = ...
                thisPositionalData.horizontalId - thatHorizontalId;
            relativePositionalData.verticalId = ...
                thisPositionalData.verticalId - thatVerticalId;
        end
        function S = inventoryMod09ga(obj, ...
                folder, whichSet, tileID, varargin)
            %inventoryJPLmod09ga creates an inventory of MOD09GA files for
            %tileID
            %
            % Input
            %   folder - string top directory with MODIS data
            %   whichSet - string. Either 'historic' or 'NRT'
            %   tileID - tile to inventory
            %
            % Optional Input
            %   beginDate - datetime date to begin looking for files
            %      default is first date in the mod09ga directory for tileID
            %   endDate = datetime date to stop looking for files
            %      default is last date in the mod09ga directory for tileID
            %
            % Output
            %   Cell array with row for each date in beginDate:endDate
            %
            %
            % Notes
            %
            % Example
            %
            % This example will ...
            %
            %

            %% Parse inputs
            p = inputParser;

            addRequired(p, 'folder', @ischar);

            validWhichSet = {'historic' 'nrt'};
            checkWhichSet = @(x) any(strcmp(x, validWhichSet));
            addRequired(p, 'whichSet', checkWhichSet);

            addRequired(p, 'tileID', @ischar);
            addParameter(p, 'beginDate', NaT, @isdatetime);
            addParameter(p, 'endDate', NaT, @isdatetime);

            p.KeepUnmatched = true;
            parse(p, folder, whichSet, tileID, varargin{:});

            if isnat(p.Results.beginDate)
                beginDateStr = 'from input';
            else
                beginDateStr = datestr(p.Results.beginDate);
            end
            if isnat(p.Results.endDate)
                endDateStr = 'from input';
            else
                endDateStr = datestr(p.Results.endDate);
            end

            beginDate = p.Results.beginDate;
            endDate = p.Results.endDate;

            fprintf("%s: inventory for: %s, %s, %s, dates: %s - %s...\n", ...
                mfilename(), p.Results.folder, p.Results.whichSet, ...
                p.Results.tileID, beginDateStr, endDateStr);

            %% TODO version should be optional argument
            reflectance_version = 6;

            %% TODO Local folders this junk should be moved to functions with
            % specifics of our file system
            % note that mod09ga levels don't have the year at the end
            switch lower(whichSet)
                case 'historic'
                    processingMode = 'historic';
                case 'nrt'
                    processingMode = 'NRT';
                otherwise
                    error('%s: unrecognized argument %s ', mfilename(), ...
                        whichSet);
            end
            versionStr = sprintf('%03d', reflectance_version);
            mod09Folder = fullfile(folder, 'mod09ga', processingMode, ...
                ['v' versionStr], tileID);

            %% Handle defaults for begin/end date
            % If using input for begin or end date, get a list of all
            % files in the directory and pull dates from first/last
            % filenames. Handle nominal case the first time any data
            % this tile is being pulled
            yrDirs = MODISData.getSubDirs(mod09Folder);
            if isnat(beginDate)
                if strcmp(whichSet, 'historic')
                    beginDate = obj.endDateOfHistoricJPLFiles - 1;
                else
                    beginDate = today('datetime') - 1;
                end
                if 0 < length(yrDirs)
                    list = dir(fullfile(mod09Folder, yrDirs{1}, ...
                        sprintf('MOD09GA.A*%s.*%d*hdf', ...
                        tileID, reflectance_version)));
                    if 0 < length(list)
                        beginDate = MODISData.getMod09gaDt(...
                            {list(1).name});
                    end
                end
            end

            if isnat(endDate)
                if strcmp(whichSet, 'historic')
                    endDate = obj.endDateOfHistoricJPLFiles;
                else
                    endDate = today('datetime');
                end
                if 0 < length(yrDirs)
                    list = dir(fullfile(mod09Folder, yrDirs{end}, ...
                        sprintf('MOD09GA.A*%s.*%d*hdf', ...
                        tileID, reflectance_version)));
                    if 0 < length(list)
                        endDate = MODISData.getMod09gaDt({list(end).name});
                    end
                end
            end

            %% Allocate space for dates
            % Make a struct array with 1 record for each date
            ndays = days(endDate - beginDate) + 1;
            S = repmat(struct('dt', NaT, 'num', 0, 'files', []), ndays, 1);

            %% Loop for each date
            recNum = 1;
            for dt = beginDate:endDate
                S(recNum).dt = dt;
                S(recNum).num = 0;

                yyyyddd  = sprintf('%04d%03d', dt.Year, day(dt, 'dayofyear'));

                % Find all MOD09GA files for this date
                list = dir(fullfile(mod09Folder, '*', ...
                    sprintf('MOD09GA.A%s.%s.*%d*hdf', ...
                    yyyyddd, tileID, reflectance_version)));
                if ~isempty(list)
                    S(recNum).num = length(list);
                    S(recNum).files = list;
                end

                recNum = recNum + 1;
            end
        end
        function S = isFileOnScratch(obj, filename)
            %isFileOnScratch looks for this filename on user's scratch space
            %
            % Input
            %   filename - any filename of form /*/modis/*/file.ext
            %
            % Output
            %   struct with
            %   .filename - the temporary file expected on user's tmp
            %   .exists - true or false (if tmp file exists)

            expression = '^/.*/modis';
            replace = sprintf('%smodis', obj.espEnv.scratchPath);
            S.filename = regexprep(filename, expression, replace);
            S.onScratch = isfile(S.filename);
        end
        function S = readInventoryStatus(obj, whichSet, ...
                tile, imtype)

            % Load the inventory file for this set/tile/type
            fileName = fullfile(obj.espEnv.defaultArchivePath, 'archive_status', ...
                sprintf("%s.%s.%s-inventory.mat", whichSet, tile, imtype));
            try
                S = load(fileName);
            catch e
                fprintf("%s: Error reading inventory file %s\n", ...
                    mfilename(), fileName);
                rethrow(e);
            end

            % Only return historic/nrt data before/after cutoff Dt
            if strcmp(whichSet, 'historic')
                idx = S.datevals <= obj.endDateOfHistoricJPLFiles;
            else
                idx = S.datevals > obj.endDateOfHistoricJPLFiles;
            end

            if any(idx)
                S.datevals = S.datevals(idx);
                nameFields = fields(S.filenames);
                for i=1:length(nameFields)
                    S.filenames.(nameFields{i}) = ...
                        S.filenames.(nameFields{i})(idx);
                end
            end
        end
        function setModisSensorConfForSTC(obj)
            % Fetch Modis sensor conf (for STC).
            confLabels = fieldnames(ESPEnv.modisSensorConfigurationFileNames);
            for confLabelIdx = 1:length(confLabels)
                confLabel = confLabels{confLabelIdx};
                confFilePath = ESPEnv.getESPConfFilePath(confLabel);
                fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
                m = matfile(confFilePath);
                obj.(confLabel) = m.(confLabel);
            end
        end
    end
    methods(Static)  % static methods can be called for the class
        function doy = doy(Dt)
            % Returns the day of year of the input datetime Dt
            % TODO: Make this work on an array of Dts
            % TODO: Move this to a date utility object
            jan1Dt = datetime(sprintf("%04d0101", year(Dt)), ...
                'InputFormat', 'yyyyMMdd');
            doy = days(Dt - jan1Dt + 1);

        end
        function dt = getMod09gaDt(fileNames)
            %getMod09gaDate parses the MOD09GA-like filename for datetime
            % Input
            %   fileNames = cell array with MOD09GA filenames, of form
            %   MOD09GA.Ayyyyddd.*
            %
            % Optional Input n/a
            %
            % Output
            %   dt = datetime extracted from yyyyddd field in filename
            %

            % This uses a nice trick that converts to datetime as an
            % offset from Jan 1

            try

                tokenNames = cellfun(@(x)regexp(x, ...
                    'MOD09GA\.A(?<yyyy>\d{4})(?<doy>\d{3})\.', 'names'), ...
                    fileNames, 'uniformOutput', false);
                dt = cellfun(@(x)datetime(str2num(x.yyyy), 1, ...
                    str2num(x.doy)), ...
                    tokenNames);

            catch

                errorStruct.identifier = 'MODISData:FileError';
                errorStruct.message = sprintf(...
                    '%s: Error Unable to parse dates from %s\n', ...
                    mfilename(), strjoin(fileNames));
                error(errorStruct);
            end
        end
        function idx = indexForYYYYMM(yr, mn, Dts)
            %indexForYYYYMM finds indices to Dts array for yr, mn
            %
            % Input
            %  yr: 4-digit year
            %  mn: integer month
            %  Dts: array of datetimes
            %
            % Output
            %  idx: array of indices into Dts for requested yr, mn
            %
            % Notes
            % Returns an empty array if no dates in Dts match yr, mn
            %

            superset = datenum(Dts);
            subset = datenum(yr, mn, 1):datenum(yr, mn, eomday(yr, mn));
            idx = datefind(subset, superset);
        end
        function [ppl, ppt, thetad] = pixelSize(R, H, p, theta_s)
            % Calculates pixel sizes in along-track and cross-track directions.
            %  Parameters
            %  ----------
            %  (first 3 inputs must be in same units)
            %  R - Earth radius
            %  H - orbit altitude
            %  p - pixel size at nadir, scalar or vector [height width]
            %  theta_s - sensor zenith angle (degrees, can be vector of arguments)
            %
            %  Return
            %  ------output (same size as vector theta_s)
            %  ppl - pixel size in along-track direction
            %  ppt - pixel size in cross-track direction
            %  thetad - nadir sensor angle, degrees
            %
            % source: Dozier, J., T. H. Painter, K. Rittger, and J. E. Frew (2008),
            % Time-space continuity of daily maps of fractional snow cover and albedo
            % from MODIS, Advances in Water Resources, 31, 1515-1526, doi:
            % 10.1016/j.advwatres.2008.08.011, equations (3)-(6).
            
            % cross- and along-track pixel sizes
            if isscalar(p)
                alongTrack = p;
                crossTrack = p;
            else
                assert(length(p)==2,...
                    'if not scalar, pixel size must be vector of length 2')
                alongTrack = p(1);
                crossTrack = p(2);
            end

            % Calculate the angle theta based on R, theta_s, and H
            theta = asin(R * sind(theta_s) / (R + H)); 

            % Calculate along-track distance (ppl)
            ppl = (1/H) * (cos(theta) * (R + H) - R * sqrt(1 - ((R + H) / R)^2 * (sin(theta)).^2));
            ppl = ppl * alongTrack;

            % Calculate the angle beta based on crossTrack and H
            beta = atan(crossTrack / (2 * H)); 

            % Calculate cross-track distance (ppt)
            ppt = (R / crossTrack) * (asin(((R + H) / R) * sin(theta + beta)) - ...
                    asin(((R + H) / R) * sin(theta - beta)) - 2 * beta);
            ppt = ppt * crossTrack;

            % Convert theta from radians to degrees
            thetad = radtodeg(theta);

            ppl = ppl * alongTrack;
            ppt = ppt * crossTrack;
        end
    end
end
