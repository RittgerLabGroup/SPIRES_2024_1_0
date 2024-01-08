classdef MODISData < handle
    %MODISData - manages our inventory of MODIS tile data
    %   This class contains functions to manage our copy of MODIS tile
    %   data, including MOD09, modscag and moddrfs
    properties      % public properties
        archiveDir    % top-level directory with tile data
                        % NB: check hownot to duplicate information with ESPEnv dirs
                        %                                                          @todo
        alternateDir  % top-level directory with tile data on scratch
        espEnv      % ESPEnv obj.
        fileNamePrefix % Struct(char).
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
        mstruct % mapping structure for MODIS sinusoidal projection
        cstruct % structure with units/fields for MOD09GA files
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
        defaultArchiveDir = '/pl/active/rittger_esp/modis';
        defaultVersionOf = struct(ancillary = 'v3.1', ...
            modisCollection = 6);        
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
        % Band values for Modis v6.
        reflectanceBandIds = struct( ...
            green = 4, ... 
            nir = 2, ...
            red = 1, ...
            swir = 6 ... % SWIR band, 6 for MODIS and L8
            );
        sensorProperties = struct(orbitHeight = 705, ...
            tiling = struct(columnCount = 36, ...
                rowCount = 18, ...
                columnPixelCount = 2400, ...
                rowPixelCount = 2400)); % constant for spires. Units?
    end
    methods         % public methods
        function obj = MODISData(varargin)
            % The MODISData constructor initializes the directory
            % for local storage of MODIS tile data

            p = inputParser;

            % The default location is PetaLibrary, so that
            % inventory paths are always set to the definitive PL
            % location; in practice, alternateDir (user's scratch)
            % will be checked and used since it is faster
            checkArchiveDir = @(x) exist(x, 'dir');
            addOptional(p, 'archiveDir', obj.defaultArchiveDir, ...
                checkArchiveDir);

            % The default versionOf label
            % For operational processing, this can be set to something
            % consistent, e.g. 'v2023.0', or the individual versionOf
            % labels can be controlled by the caller
            defaultLabel = 'test';
            checkLabel = @(x) isstring(x) | ischar(x);
            addParameter(p, 'label', defaultLabel, checkLabel);
            addParameter(p, 'versionOfAncillary', obj.defaultVersionOf.ancillary);

            p.KeepUnmatched = false;
            parse(p, varargin{:});

            label = p.Results.label;
            obj.archiveDir = p.Results.archiveDir;

            % Default location for (fast) alternate data
            obj.alternateDir = sprintf('/scratch/alpine/%s/modis', ...
                getenv('USER'));

            path = fileparts(mfilename('fullpath'));
            parts = split(path, filesep);
            path = join(parts(1:end-1), filesep);
            topPath = path{1};

            % Fetch the mstruct information for the MODIS sinusoidal map
            mstructFile = fullfile(topPath, 'mapping', ...
                'Sinusoidal_projection_structure.mat');
            m = matfile(mstructFile);
            obj.mstruct = m.mstruct;

            % Fetch the structure that describes MOD09GA fields/units
            cstructFile = fullfile(topPath, 'mapping', ...
                'MOD09GA_cstruct.mat');
            m = matfile(cstructFile);
            obj.cstruct = m.cstruct;

            % Set various versions needed to control where data
             % are located.
             % MODISCollection is major version of MOD09GA files
             % Raw/Gap/Interp cubes and Daily file version strings
             % are used for directory hierarchy and some filenames
             % Free-form string, by convention do not use '_' or
             % '.' as first characters
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
                'platform', 'Terra', ...
                'MODISCollection', obj.defaultVersionOf.modisCollection, ...
                'modscag', label, ...
                'moddrfs', label, ...
                'mod09ga', label, ...
                'MOD09Raw', label, ...
                'SCAGDRFSRaw', label, ...
                'modisspirescube', label, ...
                'modisspiresdaily', label, ...
                'SCAGDRFSGap',  label, ...
                'SCAGDRFSSTC',  label, ...
                'VariablesMatlab',  label, ...
                'VariablesNetCDF',  label, ...
                'VariablesGeotiff',  label, ...
                'VariablesGeotiffv20231',  label, ...
                'RegionalStatsMatlab',  label, ...
                'SubdivisionStatsAggregCsv',  label, ...
                'SubdivisionStatsDailyCsv', label, ...
                'SubdivisionStatsWebCsvv20231', label, ...
                'SubdivisionStatsWebJson', label, ...
                'RegionalStatsCsv',  label);
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
        function mapCellsReference = getMapCellsReference(obj, positionalData)
            % Parameters
            % ----------
            % positionalTileData: struct(horizontalId=int, verticalId=int,
            %   columnCount=int, rowCount=int).
            %   - horizontalId: horizontal id of the tile.
            %   - verticalId: vertical id of the tile.
            %   - columnCount: number of pixels along a row of the tile.
            %   - rowCount: number of pixels along a column of the tile.
            %
            % Return
            % ------
            % mapCellsReference: MapCellsReference object.
            % SIER_320.
            %
            % NB/NetCDF: Beware that before matlab 2022, the ProjectedCRS.GeographicCRS 
            %   property of the mapCellsReference object is not set.
            % To access this property, you should call geocrs(MODISData.geocrsWkt);

            theseFieldnames = fieldnames(positionalData);
            for fieldIdx = 1:length(theseFieldnames)
                positionalData.(theseFieldnames{fieldIdx}) = cast( ...
                    positionalData.(theseFieldnames{fieldIdx}), 'double');
                    % required by maprefcells.
            end
            dx = obj.georeferencing.tileInfo.dx;
            dy = obj.georeferencing.tileInfo.dy;
            northWestX =  obj.georeferencing.northwest.x0 + ...
                positionalData.horizontalId * ...
                obj.georeferencing.tileInfo.columnCount * dx;
                % don't use positionalData.columnCount here, we need the size of modis
                % elemental tiles to get the space from x0.
            northWestY = obj.georeferencing.northwest.y0 - ...
                positionalData.verticalId * ...
                obj.georeferencing.tileInfo.rowCount * dy;
            refMatrix = [[0 -dy];[dx 0];[northWestX + dx  / 2 - dx, ...
                northWestY - dy / 2 + dy]]; % Should give result same as deprecated
                                            % makerefmat()
            mapCellsReference = refmatToMapRasterReference(refMatrix,...
                    [positionalData.rowCount positionalData.columnCount]);
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
            obj, tileRegionName)
            % Parameters
            % ----------
            % tileRegionName: char. Tile region name (format h00v00).
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
            positionalData.horizontalId = str2num(tileRegionName(2:3));
            positionalData.verticalId = str2num(tileRegionName(5:6));
            positionalData.columnCount = obj.georeferencing.tileInfo.columnCount;
            positionalData.rowCount = obj.georeferencing.tileInfo.rowCount;

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
            replace = sprintf('/scratch/alpine/%s/modis', getenv('USER'));
            S.filename = regexprep(filename, expression, replace);
            S.onScratch = isfile(S.filename);
        end
        function S = readInventoryStatus(obj, whichSet, ...
                tile, imtype)

            % Load the inventory file for this set/tile/type
            fileName = fullfile(obj.archiveDir, 'archive_status', ...
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
        %{
        function S = tileSubsetCoords(...
                obj, espEnv, RefMatrix, nRows, nCols, tileID)
                                                                             % @obsolete
            %ExtractTileSubset - returns row/col coords for tileID in RefMatrix
            %% Refer to tutorial here:
            %% https://laptrinhx.com/introduction-to-spatial-referencing-3251134442/
            %%
            %% Get Big RefMatrix from Slope-Aspect file
            %%f = myEnv.topographyFile(westernUSRegions);
            %%mObj = matfile(f);
            %%[nRows, nCols] = size(mObj, 'A');
            %%RefMatrix = mObj.RefMatrix;

            try

                %% Use the large RefMatrix to make a 2d referencing object
                %% that relates x-y coordinates to row-col
                %% Converting the scales to single precision
                %% will ignore round-off issues in the tileID
                %% projection information files.
                ULx = RefMatrix(3, 1);
                ULy = RefMatrix(3, 2);
                scalex = single(RefMatrix(2, 1));
                scaley = single(RefMatrix(1, 2));
                LRx = RefMatrix(3, 1) + (nCols * scalex);
                LRy = RefMatrix(3, 2) + (nRows * scaley);

                %% Think of spans similar to indexing a matrix:
                %%
                %% Y span increases from top to bottom of image
                %%    Y span 2-element input here has to be [Ysmaller Ylarger]
                %% X span increases from left to right of image
                %% rows increase from top to bottom
                %% cols increase from left to right
                %%
                RI = imref2d([nRows nCols], [ULx LRx], [LRy ULy]);

                %% Now fetch the UL corner of the requested tileID
                projInfo = espEnv.projInfoFor(tileID);

                x = single(projInfo.RefMatrix_500m(3, 1));
                y = single(projInfo.RefMatrix_500m(3, 2));

                % And get row, col of nearest pixel to (x, y) with:
                [r, c] = worldToSubscript(RI, x, y);

                % Default image reference insists that Y needs to increase from
                % top to bottom, but that's not what sinusoidal projection does,
                % so flip the row coordinate top-to-bottom
                r = nRows - r + 1;

                S.Rows = [ r (r + obj.tileRows_500m - 1)];
                S.Cols = [ c (c + obj.tileCols_500m - 1)];

            catch e
                fprintf('%s: Error in tileSubsetCoords for %s\n', ...
                    mfilename(), tileID);
                rethrow(e);
            end
        end
%}
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
        function years = getSubDirs(folder)
            % Returns a sorted cell array of the subdirs in folder
            list = dir(folder);

            list = list([list(:).isdir]==1);
            list = list(~ismember({list(:).name},{'.','..'}));

            years = sort({list.name});
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
        function [RefMatrix, umdays, NoValues, SensZ, SolZ, SolAzimuth, ...
                refl] = loadMOD09(files)
            %loadMOD09 loads the data from a list of MOD09 Raw cubes
            %
            % Input
            %   files: cell array of filenames
            %
            % Output
            %   concatenated data arrays read from filenames
            %
            % Notes: Returned RefMatrix is from final file loaded,
            % earlier ones are loaded and then replaced.

            NoValues = [];
            SensZ = [];
            SolZ = [];
            SolAzimuth = [];
            refl = [];
            umdays = [];
            for mn=1:size(files,2)
                [NoValuesT, SensZT, SolZT, SolAzimuthT, ...
                    reflT, RefMatrix] = ...
                    parloadMatrices(files{mn}, ...
                    'NoValues', 'SensZ', 'SolZ', 'SolAzimuth', ...
                    'refl', 'RefMatrix');
                [umdaysT] = parloadDts(files{mn}, 'umdays');
                if mn == 1
                    NoValues = NoValuesT; %cat was making this a double
                    umdays = umdaysT{1}';
                else
                    NoValues = cat(3, NoValues, NoValuesT);
                    umdays = [umdays umdaysT{1}'];
                end
                SensZ = cat(3, SensZ, SensZT);
                SolZ = cat(3, SolZ, SolZT);
                SolAzimuth = cat(3, SolAzimuth, SolAzimuthT);
                refl = cat(4, refl, reflT);
            end
            umdays = datenum(umdays);
        end
        function [RefMatrix, usdays, RawSnow, RawVeg, RawRock, ...
                RawDV, RawRF, RawGS_SCAG, RawGS_DRFS, ...
                viewable_snow_fraction_status] = ...
                loadSCAGDRFS(files)
            %loadSCAGDRFS loads the data from a list of SCAGDRFS Raw cubes
            %
            % Input
            %   files: cell array of filenames
            %
            % Output
            %   concatenated data arrays read from filenames
            %
            % Notes: Returned RefMatrix is from final file loaded,
            % earlier ones are loaded and then replaced.
            % SIER_151 ugly add of viewable_snow_fraction_status

            usdays = [];
            RawSnow = [];
            RawVeg = [];
            RawRock = [];
            RawGS_SCAG = [];
            RawDV = [];
            RawRF = [];
            RawGS_DRFS = [];
            viewable_snow_fraction_status = [];
            for mn=1:size(files, 2)
                [RawSnowT, RawVegT, RawRockT, RawDVT, RawRFT, ...
                    RawGS_SCAGT, RawGS_DRFST, RefMatrix, ...
                    viewable_snow_fraction_statusT] = ...
                    parloadMatrices(files{mn}, ...
                    'RawSnow', 'RawVeg', 'RawRock', 'RawDV', 'RawRF', ...
                    'RawGS_SCAG', 'RawGS_DRFS', 'RefMatrix', ...
                    'viewable_snow_fraction_status');
                [usdaysT] = ...
                    parloadDts(files{mn}, ...
                    'usdays');
                if mn == 1
                    usdays = usdaysT{1}';
                else
                    usdays = [usdays usdaysT{1}'];
                end
                RawSnow = cat(3, RawSnow, RawSnowT);
                RawVeg = cat(3, RawVeg, RawVegT);
                RawRock = cat(3, RawRock, RawRockT);
                RawDV = cat(3, RawDV, RawDVT);
                RawRF = cat(3, RawRF, RawRFT);
                RawGS_SCAG = cat(3, RawGS_SCAG, RawGS_SCAGT);
                RawGS_DRFS = cat(3, RawGS_DRFS, RawGS_DRFST);
                viewable_snow_fraction_status = cat(3, ...
                    viewable_snow_fraction_status, viewable_snow_fraction_statusT);
            end
            usdays = datenum(usdays);
        end
        function list = matchingFiles(mod09File)
            % matchingFiles finds any scag/drfs files that
            % match this mod09ga file, including procID
            tokenNames = regexp(mod09File, ...
                ['MOD09GA.A(?<yyyy>\d{4})(?<doy>\d{3})\.' ...
                '(?<tileID>h\d{2}v\d{2})\.(?<version>\d{3})\.' ...
                '(?<procID>\w+)\.'], ...
                'names');
            [path, baseName, ~] = fileparts(mod09File);
            parts = split(path, filesep);
            procMode = parts(end-3);
            topPath = join(parts(1:end-5), filesep);

            % Look for scag files
            versionStr = sprintf('v%s', tokenNames.version);

            list = [...
                dir(fullfile(topPath{1}, 'modscag', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('%s.*.dat', baseName))); ...
                dir(fullfile(topPath{1}, 'modscag', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('%s.*.tif', baseName))); ...
                dir(fullfile(topPath{1}, 'moddrfs', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('%s.*.dat', baseName))); ...
                dir(fullfile(topPath{1}, 'moddrfs', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('%s.*.tif', baseName)))];
        end
        function [ppl, ppt, thetad] = pixelSize(R, H, p, theta_s)
            %pixelSize calculate pixel sizes in along-track and cross-track directions
            % input
            %  (first 3 inputs must be in same units)
            %  R - Earth radius
            %  H - orbit altitude
            %  p - pixel size at nadir
            %  theta_s - sensor zenith angle (degrees, can be vector of arguments)
            %
            % output (same size as vector theta_s)
            %  ppl - pixel size in along-track direction
            %  ppt - pixel size in cross-track direction
            %  thetad - nadir sensor angle, degrees
            %

            theta=asin(R*sind(theta_s)/(R+H));
            ppl=(1/H)*(cos(theta)*(R+H)-R*sqrt(1-((R+H)/R)^2*(sin(theta)).^2));
            beta=atan(p/(2*H));
            ppt=(R/p)*(asin(((R+H)/R)*sin(theta+beta))-...
                asin(((R+H)/R)*sin(theta-beta))-2*beta);
            thetad=rad2deg(theta);
            ppl=ppl*p;
            ppt=ppt*p;
        end
        function numDupes = removeMod09gaDuplicates(S)
            %removeMod09gaDuplicates removes duplicate MOD09GA files
            %
            % Input
            %   S = mod09ga inventory cell array returned from
            %       inventoryMod09ga
            %
            % Output
            %   numDupes - number of duplicates found and removed
            %
            % Notes
            %
            % Example
            %
            numDupes = 0;

            % Find duplicate MOD09GA files from input inventory
            idx = [S.num] > 1;

            subS = S(idx);

            for i=1:length(subS)
                fprintf("\n%s: multiple files found for : %s\n", ...
                    mfilename(), datestr(subS(i).dt, 'yyyy-mm-dd'));
                names = vertcat(subS(i).files.name);
                folders = vertcat(subS(i).files.folder);
                [numFiles, ~] = size(names);
                files = strings(numFiles, 1);
                for j=1:numFiles
                    files(j) = fullfile(folders(j,:), names(j,:));
                end
                files = sort(files, 'descend');

                % Delete all but the first one, sorting in descending order
                for j=1:length(files)
                    if 1 == j
                        fprintf("%s: keeping %s\n", mfilename(), files(j));
                    else
                        fprintf("%s: deleting %s...\n", ...
                            mfilename(), files(j));

                        delete(files(j));

                        % Delete any scag/drfs files found for this
                        % file also
                        list = MODISData.matchingFiles(files(j));
                        if ~isempty(list)
                            for k=1:length(list)
                                modisFile = fullfile(list(k).folder, ...
                                    list(k).name);
                                fprintf("%s: deleting %s...\n", ...
                                    mfilename(), modisFile);
                                delete(modisFile);
                            end
                        end
                        numDupes = numDupes + 1;
                    end
                end
            end
        end
        %{
        function [filenames, datevals, missingSCAG, ...
                missingDRFS] = getMODISfilenames(tile, whichSet, imtype, ...
                scagflag, drfsflag, modisDir)
            %                                                                  @obsolete
            %getMODISfilenames returns list of scag-related filenames
            %
            % Input
            %   tile - MODIS tile. Example: 'h08v05'
            %   whichSet - 'historic' or 'nrt'
            %   imtype - either 'tif' or 'dat'
            %   scagflag - vector of length 7 1s and 0s for desired files
            %      if empty, then look for all
            %   drfsflag - vector length 3 1s and 0s for desired files
            %      if empty, then look for all
            %   modisDir - directory with directory hierarchy, with
            %      mod09ga, modscag, moddrfs
            %
            % Output
            %   filenames - filenames excluding root directory where
            %      we have all files
            %   datevals - vector of corresponding datetimes
            %   missingSCAG - list of strings with missing scag/tiles
            %   missingDRFS - list of strings with missing drfs/tiles
            % Notes
            %   This routine uses the list of MOD09GA files for this tile
            %   to look for matching scag/drfs files.  It assumes that
            %   there is 1 MOD09GA file for a given date.
            %TODO: check datevals for dups and quit if they are found?
            %
            % Original version from Karl Rittger
            % NSIDC, CUB & ERI, UCSB
            % April 27, 2016

            %% MODSCAG and MODDRFS variables of interest
            scag_variables = {'snow_fraction';'vegetation_fraction';...
                'rock_fraction';'other_fraction';'grain_size'};
            %'shade_fraction';
            drfs_variables = {'forcing';'deltavis';'drfs.grnsz'};
            % Used for field names in ouptut, can't use . in Matlab
            % fieldnames
            drfs_variables2 = {'forcing';'deltavis';'drfs_grnsz'};

            %% Subset the variables specified
            if isempty(scagflag)
                scagflag = ones(size(scag_variables));
            end
            scag_variables = scag_variables(logical(scagflag));

            if isempty(drfsflag)
                drfsflag = ones(size(drfs_variables));
            end
            drfs_variables = drfs_variables(logical(drfsflag));
            drfs_variables2 = drfs_variables2(logical(drfsflag));

            %%FIXME: move this stupid junk to a single function
            switch lower(whichSet)
                case 'historic'
                    processingMode = 'historic';
                case 'nrt'
                    processingMode = 'NRT';
                otherwise
                    error('%s: unrecognized argument %s ', mfilename(), ...
                        whichSet);
            end
            reflectance_version = 6;
            versionStr = sprintf('%03d', reflectance_version);

            hdfDir = fullfile(modisDir, 'mod09ga', processingMode, ...
                ['v' versionStr], tile);
            scagDir = fullfile(modisDir, 'modscag', processingMode, ...
                ['v' versionStr], tile);
            drfsDir = fullfile(modisDir, 'moddrfs', processingMode, ...
                ['v' versionStr], tile);

            %% List the source hdf files
            hdffiles = dir(fullfile(hdfDir, '*', ...
                ['MOD09GA.A*' tile '*.hdf']));
            fprintf(['%s: %d MOD09GA files found. ' ...
                'Looking for matching %s...\n'], mfilename(), ...
                length(hdffiles), imtype);
            dts = MODISData.getMod09gaDt(string({hdffiles.name})');

            %TODO: check for dup dates and quit now if found?
            [~, ind] = unique(dts);
            if length(ind) ~= length(dts)
                fprintf(['\n\n\n%s: WARNING: duplicate ' ...
                    '%s MOD09GA files\n\n\n\n'], ...
                    mfilename(), tile);
            end

            %% Start counts
            cntgood=0;% HDF, all SCAG and all DRFS present
            cntmscag=0;% Missing some/all SCAG
            cntmdrfs=0;% Missing some/all DRFS

            %% Allocate storage for output once
            numFiles = length(dts);
            datevals = NaT(numFiles, 1);
            filenames.MOD09GA = cell(numFiles, 1);
            for i=length(scag_variables)
                filenames.(scag_variables{i}) = cell(numFiles, 1);
            end
            for i=length(drfs_variables2)
                filenames.(drfs_variables2{i}) = cell(numFiles, 1);
            end

            %% Loop for each day
            for i=1:numFiles

                thisYYYYStr = datestr(dts(i), 'yyyy');
                thisYYYYDDDStr = sprintf('%04d%03d', dts(i).Year, ...
                    day(dts(i), 'dayofyear'));

                % Path for hdf, scag, drfs files for this day
                sDir = fullfile(scagDir, thisYYYYStr);
                fDir = fullfile(drfsDir, thisYYYYStr);

                % Parse the hdf base name for this day
                [~, hdfbase, ~] = fileparts(hdffiles(i).name);

                % add SCAG filenames to structure if they exist
                % Looks for "." first, then w/o
                for n=1:length(scag_variables)
                    if exist(fullfile(sDir,...
                            [hdfbase '.' scag_variables{n} '.' imtype]),...
                            'file')==2
                        scagnames.(scag_variables{n}) = fullfile(sDir,...
                            [hdfbase '.' scag_variables{n} '.' imtype]);
                    elseif exist(fullfile(sDir,...
                            [hdfbase scag_variables{n} '.' imtype]),...
                            'file')==2
                        scagnames.(scag_variables{n}) = fullfile(sDir,...
                            [hdfbase scag_variables{n} '.' imtype]);
                    end
                end

                % add DRFS filenames to structure if they exist
                % Looks for "." first, then w/o
                for n=1:length(drfs_variables)
                    if exist(fullfile(fDir,...
                            [hdfbase '.' drfs_variables{n} '.' imtype]),...
                            'file')==2
                        drfsnames.(drfs_variables2{n}) = fullfile(fDir,...
                            [hdfbase '.' drfs_variables{n} '.' imtype]);
                    elseif exist(fullfile(fDir,...
                            [hdfbase drfs_variables{n} '.' imtype]),...
                            'file')==2
                        drfsnames.(drfs_variables2{n}) = fullfile(fDir,...
                            [hdfbase drfs_variables{n} '.' imtype]);
                    end
                end

                % Check to see if there are files for either scag or drfs
                if   exist('scagnames','var')==1 && exist('drfsnames',...
                        'var')==1
                    % Check for all fields
                    if length(fields(scagnames))==length(scag_variables)
                        svars=1;
                    else
                        svars=0;
                    end
                    if length(fields(drfsnames))==length(drfs_variables2)
                        dvars=1;
                    else
                        dvars=0;
                    end
                    % If all files, get filenames
                    if svars==1 && dvars==1

                        cntgood=cntgood+1;

                        % HDF file and datevals
                        filenames.MOD09GA{cntgood, 1} = fullfile(...
                            hdffiles(i).folder, hdffiles(i).name);
                        datevals(cntgood, 1) = dts(i);

                        % SCAG names
                        for n=1:length(scag_variables)
                            filenames.(scag_variables{n}){cntgood,1} = ...
                                scagnames.(scag_variables{n});
                        end

                        % DRFS names
                        for n=1:length(drfs_variables)
                            filenames.(drfs_variables2{n}){cntgood,1}=...
                                drfsnames.(drfs_variables2{n});
                        end

                        % Skip files if some or all scag files are missing
                    elseif svars==0 && dvars==1
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing some SCAG variables'])
                        cntmscag=cntmscag+1;
                        missingSCAG{cntmscag,1}=[tile '_' thisYYYYDDDStr];
                        % Skip files if some or all drfs files are missing
                    elseif svars==1 && dvars==0
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing some DRFS variables'])
                        cntmdrfs=cntmdrfs+1;
                        missingDRFS{cntmdrfs,1}=[tile '_' thisYYYYDDDStr];
                    end
                else
                    if ~exist('scagnames','var')
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing all SCAG variables'])
                        cntmscag=cntmscag+1;
                        missingSCAG{cntmscag,1}=[tile '_' thisYYYYDDDStr];
                    end
                    if ~exist('drfsnames','var')
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing all DRFS variables'])
                        cntmdrfs=cntmdrfs+1;
                        missingDRFS{cntmdrfs,1}=[tile '_' thisYYYYDDDStr];
                    end
                end
                clear scagnames drfsnames dvars svars
            end

            %% Delete any unused indices in output variables
            if cntgood > 0
                datevals = datevals(1:cntgood);
                fNames = fieldnames(filenames);
                for i=1:length(fNames)
                    filenames.(fNames{i}) = ...
                        filenames.(fNames{i})(1:cntgood);
                end
            elseif 0 == cntgood
                datevals = {};
                filenames = {};
            end

            %% Define any return variables if they haven't already been set
            if ~exist('missingSCAG','var')
                missingSCAG={};
            end
            if ~exist('missingDRFS','var')
                missingDRFS={};
            end
        end
        function saveMODISfilenames(saveFile, filenames, datevals, ...
                missingSCAG, missingDRFS)
            %                                                                  @obsolete
            %saveMODISfilenames - saves a MODIS file inventory to .mat file

            inventoryDate = datestr(datetime('now'));

            save(saveFile, 'inventoryDate', ...
                'filenames', 'datevals', 'missingSCAG', 'missingDRFS');
        end
        function list = tilesFor(region)
            %                                                                  @obsolete
            % tilesFor returns cell array of tileIDs for the region

            lowRegion = lower(region);
            if (strcmp(lowRegion, 'westernus'))
                list = {...
                    'h08v04'; 'h09v04'; 'h10v04'; ...
                    'h08v05'; 'h09v05'};
            elseif (strcmp(lowRegion, 'indus'))
                list = {...
                    'h23v05'; 'h24v05'; 'h25v05'};
            elseif (strcmp(lowRegion, 'hma'))
                list = {...
                    'h22v04'; 'h23v04'; 'h24v04'; ...
                    'h22v05'; 'h23v05'; 'h24v05'; 'h25v05'; 'h26v05';...
                    'h23v06'; 'h24v06'; 'h25v06'; 'h26v06'};
            elseif (strcmp(lowRegion, 'alaska'))
                list = {...
                    'h12v01'; 'h13v01';...
                    'h09v02'; 'h10v02'; 'h11v02'; 'h12v02'; 'h13v02';...
                    'h07v03'; 'h08v03'; 'h09v03'; 'h10v03'; 'h11v03'};
            elseif (regexp(lowRegion, 'h\d{2}v\d{2}'))
                list = {lowRegion};
            else
                error("%s: Unknown region=%s", ...
                    mfilename(), region);
            end

        end
        function regionName = regionNameFor(tileID)
            %                                                                  @obsolete
            % regionNameFor returns the regionName for this tileID
            switch tileID
                case MODISData.tilesFor('westernUS')
                    regionName = 'westernUS';
                case MODISData.tilesFor('Indus')
                    regionName = 'Indus';
                otherwise
                    error("%s: Unknown tileID=%s", ...
                        mfilename(), tileID);
            end

        end
        function [Rmap, lr, dims] = RmapFor(espEnv, tiles)
            %                                                                  @obsolete
            % RmapFor returns the merged referencing matrix for tiles
            % Input:
            % espEnv : environment tile projection files
            % tiles : cell array with tileIDs
            % Output:
            % Rmap : referencing matrix for the merged tiles
            % lr : lower right map coordinates (m) for each tile
            % dims : dimensions of tile mosaic [rows cols]

            resolution = 500;
            ntiles = length(tiles);
            RefMatrices = zeros(ntiles, 3, 2);
            sizes = zeros(ntiles, 2);
            lr = zeros(ntiles, 2);

            % structure fieldnames for ProjInfo files
            resolutionName = ['RefMatrix_' num2str(resolution) 'm'];
            sizeName = ['size_' num2str(resolution) 'm'];

            for t = 1:ntiles

                projInfo = espEnv.projInfoFor(tiles{t});
                RefMatrices(t, :, :) = projInfo.(resolutionName);
                sizes(t, :) = projInfo.(sizeName);
                lr(t, :) = [sizes(t, :) 1] * squeeze(RefMatrices(t, :, :));

            end

            Rmap = zeros(3, 2);
            Rmap(3, 1) = min(RefMatrices(:, 3, 1));
            Rmap(2, 1) = RefMatrices(1, 2, 1);
            Rmap(1, 2) = RefMatrices(1, 1, 2);
            Rmap(3, 2) = max(RefMatrices(:, 3, 2));

            xy = [max(lr(:, 1)) min(lr(:, 2))];
            dims = round(map2pix(Rmap, xy));
        end
        function FP = loadFP(fpFile, dims)
            %                                                                  @obsolete
            %loadFP loads a false positives mask
            %
            % Input
            %   fpFile: watermask filename
            %   dims: dimensions of expected mask
            %
            % Output
            %   If fpFile contains an FP array, use it,
            %   otherwise if it contains a watermask array, use that.
            %   if not, a mask of size dims with 0s is allocated and
            %   returned.
            %FIXME: if file exists but doesnt have FP or watermask,
            % nothing will be returned here.
            %
            % Load a false positives mask
            if isfile(fpFile)
                load(fpFile);
                if ~exist('FP', 'var')
                    FP = parloadMatrices(fpFile, 'watermask');
                    clear watermask;  %TODO: why did Karl do this?
                    fprintf('%s: Using watermask for FP from %s\n', ...
                        mfilename(), fpFile);
                else
                    fprintf('%s: using FP directly from %s\n', ...
                        mfilename(), fpFile);
                end
            else
                FP = false(dims);
                fprintf('%s: Using dummy false positives FP mask\n', ...
                    mfilename());
            end
        end
%}
    end
end
