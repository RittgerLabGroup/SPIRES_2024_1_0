%---------------------------------------------------------------------------------------
% Creation of tile ancillary data necessary for snowToday processes for a new region:
% regions masks, elevations, slopes, aspects, canopy heights, water and land masks.
% Generation for each tiles that compose the region + for the full region.
% Does not include the masks for drainage basins HUC2, HUC4.
% NB: the geotiffs are unable to store a geographic associated to sinusoidal
% projection, that contain both a WGS 84 datum and a spheroid. The ancillary data are
% then generated both in .geotiff and .mat files, with only the .mat file containing
% the crs with the correct WGS 84 datum.
%
% NB: This class doesn't generate the false positive raster tiles. For this, open QGIS
% and run the model
% qgisGetStcFalsePositiveModisTile.model3 on the land tiles produced by this script
% using an updated global false positive (=dry lakes) polygon vector file, to generate
% the raster tiles of false positives.
%
% v3.alaska
% sebastien.lenard@colorado.edu
% 04/06/2023
%---------------------------------------------------------------------------------------
classdef TileRegionAncillaryDataSetup
    properties
        % georeferencing.                                           2023-06-30 @obsolete
        espEnv % ESPEnv Obj.
        parentDirectory % char. Parent directory which store the ancillary
            % files.
        regionName % char. Name of the region.
        tileRegionNames % cell array of char. Names of the modis tiles which
            % compose the region.
        version % char. Version of the files.
    end
    properties(Constant)
        mod09ga500mGridIdx = 2; % 500-m georeferencing info location in Grid attribute
            % of mod09ga tile .hdf file.
        mod44wWaterThreshold = 0.5; % threshold above which mod44w values are considered
            % as water.
        % modisNrtMod09ga = fullfile('modis', 'mod09ga', 'NRT', 'v006'), ...
        inputSubdirectories = struct(v32 = struct( ...
            modisHistMod44w = fullfile('modis_ancillary', 'mod44w', 'historic', ...
                'v006'), ...
            modisHistMod44b = fullfile('modis_ancillary', 'mod44b', 'historic', ...
                'v061')), ...
            v33 = struct( ...
            modisHistMod44w = ...
                fullfile('modis_ancillary', 'MOD44W.061', '2022.01.01'), ...
            modisHistMod44b = fullfile('modis_ancillary', 'mod44b', 'historic', ...
                'v061'))); % subdirectories where to find tile data according version
                % of ancillary data.); % subdirectories where to find tile data according version
                % of ancillary data.
                % v3.3 temporarily used for Antarctica
        fileNamePatterns = struct(v32 = struct( ...
            modisHistMod44w = ['MOD44W.A2015001.{regionName}.006.*.hdf'], ...
            modisHistMod44b = ['MOD44B.A2022065.{regionName}.061.*.hdf']), ...
            v33 = struct( ...
            modisHistMod44w = ['MOD44W.A2022001.{regionName}.061.*.hdf'], ...
            modisHistMod44b = ['MOD44B.A2022065.{regionName}.061.*.hdf']));
        fieldNameInSource = struct(v32 = struct( ...
            modisHistMod44w = 'water_mask', ...
            modisHistMod44b = 'Percent_Tree_Cover'), ...
            v33 = struct( ...
            modisHistMod44w = 'water_mask', ...
            modisHistMod44b = 'Percent_Tree_Cover'));
    end
    methods
        function obj = TileRegionAncillaryDataSetup(varargin)
            % Constructor
            %
            % Parameters
            % ----------
            % georeferencing % struct(northwest = struct(x0 = int, y0 = int), tileInfo =
            %   struct(dx = single, dy = single, columnCount = int, rowCount = int)).
            %   Data necessary to absolutely calculate georeferencing for each tile
            %   named hyyvxx.
            % parentDirectory: char. Parent directory which store the ancillary
            %   files.
            % regionName: char. Name of the region.
            % tileRegionNames: cells(char). Names of the modis tiles which
            %   compose the region.
            % version: char. Version of the files.
            %
            % Return
            % ----------
            % obj: regionAncillaryDataSetup
            for vararginIdx = 1:length(varargin)
                if rem(vararginIdx,2) ~= 0
                    obj.(varargin{vararginIdx}) = varargin{vararginIdx + 1};
                end
            end
        end
        function generateAspectSlopeFiles(obj, elevationSourcePaths)
            % Generation of the aspect and slope files for the geographic-referenced
            % original elevation files. For each elevation file a band of 1-pixel large
            % from adjacent elevation files is included for calculations.
            %
            % Parameters
            % ----------
            % elevationSourcePaths: cells(char). Paths of source elevation files to
            %   calculate slope and aspect for each tile. They are supposed to be in a
            %   geographic
            %   reference and have the same reference and the same matrix size.
            %
            % NB: the calculation should be done directly on the original geographic
            % tiles rather than on the re-project in geographic the projected elevation
            % tiles calculated by generateTileElevationFiles().
            % NB: tiles at -180 longitude don't consider adjacent tiles at +180
            % longitude.
            outputDirectories = {fullfile(obj.parentDirectory, 'modis_ancillary', ...
                'aspect_tmp'), ...
                fullfile(obj.parentDirectory, 'modis_ancillary', 'slope_tmp')};
            for directoryIdx = 1:length(outputDirectories)
                directory = outputDirectories{directoryIdx};
                if ~isfolder(directory)
                    mkdir(directory);
                end
            end

            % Get the geographic-referenced elevation file and its surrounding pixels
            % and then calculate aspect and slopes. the bits of tile for each elevation source.
            % NB: Given live memory limits, it's better no to combine the source data
            % together in 1 matrix only.
            for elevationSourceIdx = 1:length(elevationSourcePaths)
                % We check is there are pixels surrounding this sourceIdx
                % in the other source files
                sourceGeographicCellsReference = geotiffinfo( ...
                    elevationSourcePaths{elevationSourceIdx}).SpatialRef;
                % Matrix larger than the source elevation matrix by a surrounding
                % 1-pixel band that we will fill by the data from adjacent elevation
                % files.
                latitudeLimit1 = sourceGeographicCellsReference.LatitudeLimits(1);
                latitudeLimit2 = sourceGeographicCellsReference.LatitudeLimits(2);
                longitudeLimit1 = sourceGeographicCellsReference.LongitudeLimits(1);
                longitudeLimit2 = sourceGeographicCellsReference.LongitudeLimits(2);
                sourceElevationXLimits = [1, ...
                    sourceGeographicCellsReference.RasterSize(2)];
                sourceElevationYLimits = [1, ...
                    sourceGeographicCellsReference.RasterSize(1)];
                if sourceGeographicCellsReference.LatitudeLimits(1) > -89.0
                    latitudeLimit1 = ...
                        sourceGeographicCellsReference.LatitudeLimits(1) - ...
                        sourceGeographicCellsReference.CellExtentInLatitude;
                end
                if sourceGeographicCellsReference.LatitudeLimits(2) < 89.
                    latitudeLimit2 = ...
                        sourceGeographicCellsReference.LatitudeLimits(2) + ...
                        sourceGeographicCellsReference.CellExtentInLatitude;
                    sourceElevationYLimits = sourceElevationYLimits + 1;
                end
                if sourceGeographicCellsReference.LongitudeLimits(1) > -179.
                    longitudeLimit1 = ...
                        sourceGeographicCellsReference.LongitudeLimits(1) - ...
                        sourceGeographicCellsReference.CellExtentInLongitude;
                    sourceElevationXLimits = sourceElevationXLimits + 1;
                end
                if sourceGeographicCellsReference.LongitudeLimits(2) < 179.
                    longitudeLimit2 = ...
                        sourceGeographicCellsReference.LongitudeLimits(2) + ...
                        sourceGeographicCellsReference.CellExtentInLongitude;
                end
                sourceElevationXRange = ...
                    sourceElevationXLimits(1):sourceElevationXLimits(2);
                sourceElevationYRange = ...
                    sourceElevationYLimits(1):sourceElevationYLimits(2);
                rasterSize = [cast((latitudeLimit2 - latitudeLimit1) / ...
                    sourceGeographicCellsReference.CellExtentInLatitude, 'int16'), ...
                    cast((longitudeLimit2 - longitudeLimit1) / ...
                    sourceGeographicCellsReference.CellExtentInLongitude, 'int16')];
                geographicCellsReference = georefcells(...
                    [latitudeLimit1, latitudeLimit2], ...
                    [longitudeLimit1, longitudeLimit2], ...
                    double(rasterSize));
                geographicCellsReference.GeographicCRS = ...
                    sourceGeographicCellsReference.GeographicCRS;
                elevations = zeros( ...
                    geographicCellsReference.RasterSize(1), ...
                    geographicCellsReference.RasterSize(2));

                for adjacentSourceIdx = 1:length(elevationSourcePaths)
                    if adjacentSourceIdx == elevationSourceIdx
                        continue;
                    end
                    adjacentGeographicCellsReference= geotiffinfo( ...
                        elevationSourcePaths{adjacentSourceIdx}).SpatialRef;
                    if sourceGeographicCellsReference.LatitudeLimits == ...
                        adjacentGeographicCellsReference.LatitudeLimits
                        if sourceGeographicCellsReference.LongitudeLimits(1) == ...
                            adjacentGeographicCellsReference.LongitudeLimits(2)
                            tmpElevations = readgeoraster( ...
                                elevationSourcePaths{adjacentSourceIdx});
                            elevations(sourceElevationYRange, 1) = ...
                                tmpElevations(:, end);
                        elseif sourceGeographicCellsReference.LongitudeLimits(2) == ...
                            adjacentGeographicCellsReference.LongitudeLimits(1)
                            tmpElevations = readgeoraster( ...
                                elevationSourcePaths{adjacentSourceIdx});
                            elevations(sourceElevationYRange, end) = ...
                                tmpElevations(:, 1);
                        end
                    elseif sourceGeographicCellsReference.LongitudeLimits == ...
                        adjacentGeographicCellsReference.LongitudeLimits
                        if sourceGeographicCellsReference.LatitudeLimits(1) == ...
                            adjacentGeographicCellsReference.LatitudeLimits(2)
                            tmpElevations = readgeoraster( ...
                                elevationSourcePaths{adjacentSourceIdx});
                            elevations(end, sourceElevationXRange) = ...
                                tmpElevations(1, :);
                        elseif sourceGeographicCellsReference.LatitudeLimits(2) == ...
                            adjacentGeographicCellsReference.LatitudeLimits(1)
                            tmpElevations = readgeoraster( ...
                                elevationSourcePaths{adjacentSourceIdx});
                            elevations(1, sourceElevationXRange) = ...
                                tmpElevations(end, :);
                        end
                    end
                end
                clear('tmpElevations');
                elevations(sourceElevationYRange, sourceElevationXRange) = ...
                    readgeoraster(elevationSourcePaths{elevationSourceIdx});
                fprintf('aspect and slope calculation for %s\n', ...
                    elevationSourcePaths{elevationSourceIdx});
                [aspect, slope, ~, ~] = gradientm(elevations, geographicCellsReference);
                clear('elevations');
                [~, elevationFilename, ext] = ...
                    fileparts(elevationSourcePaths{elevationSourceIdx});
                elevationFilename = [elevationFilename ext];
                outputFilename = fullfile(outputDirectories{1}, ...
                    ['aspect_' elevationFilename]);
                geotiffwrite(outputFilename, ...
                    aspect(sourceElevationYRange, sourceElevationXRange), ...
                    sourceGeographicCellsReference, ...
                    TiffTags = struct('Compression', 'LZW'));
                clear('aspect');
                outputFilename = fullfile(outputDirectories{2}, ...
                    ['slope_' elevationFilename]);
                geotiffwrite(outputFilename, ...
                    slope(sourceElevationYRange, sourceElevationXRange), ...
                    sourceGeographicCellsReference, ...
                    TiffTags = struct('Compression', 'LZW'));
                clear('slope');
            end
        end
        function generateTileCanopycoverFilesFromMod44b(obj, canopycoverLabel)
            % Generation of the canopy cover tile files.
            % From individual MOD44B.A2022065 dated back to 2022.
            %
            % NB: Probably need a varying canopy cover for v3.3, since MOD44B should be
            %   available back to 2000.                                            @todo
            %
            % Parameters
            % ----------
            % canopycoverLabel: char. Label included in output filename and indicating
            %   source of canopy height data.
            % Seb. 2024-03-03.
            modisData = obj.espEnv.modisData;
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, 'canopycover');
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            versionChar = replace(obj.version, '.', ''); % remove the . in v3.2, because
                % struct cannot accept . in their fieldnames.
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                % Georeferencing.
                mapCellsReference = modisData.getMapCellsReference( ...
                    modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
                % Find source file
                fileSearch = fullfile(obj.parentDirectory, ...
                    obj.inputSubdirectories.(versionChar). ...
                    modisHistMod44b, ...
                    replace(obj.fileNamePatterns.(versionChar). ...
                        modisHistMod44b, '{regionName}', tileRegionName));
                fileResults = dir(fileSearch);
                canopycover = hdfread( ...
                    fullfile(fileResults(1).folder, fileResults(1).name), ...
                    obj.fieldNameInSource.(versionChar).modisHistMod44b);
                    
                % Here fill value is expected to be 253, water to be 200,
                % and range 0-100.
                canopycover(canopycover > 100) = 0;
                    % NB: in theory, if fill value, we should interpolate. But, it seems
                    % that there are not that many fill values, and that they are at
                    % the edge of the world represented in modis projection. However,
                    % this needs to
                    % be checked at some point systematically.                     @todo 

                canopycover = imresize(single(canopycover), [2400 2400], 'bilinear');
                canopycover = cast(canopycover, 'uint8');
                            
                land = obj.getLand(tileRegionName);
                canopycover(land ~= 1) = 0;
                data = canopycover;
                outputFilenameWithoutExtension = fullfile(outputDirectory, ...
                    [tileRegionName, canopycoverLabel]);
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                    data, ...
                    mapCellsReference, ...
                    GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                    TiffTags = struct('Compression', 'LZW'));
            end
        end
        function generateTileCanopyFiles(obj, canopyLabel, ...
            canopyFileLabel, ...
            canopyPath)
            % Generation of the canopy height or cover tile files.
            % From global map from Simard 2011
            % Simard_Pinto_3DGlobalVeg_L3C.tif or
            % PROBAV_LC100_global_v3.0.1_2019-nrt_Tree-CoverFraction-layer_EPSG-4326.tif
            % NB: I extracted with QGis a limited geotiff from this big geotiff to
            % produce the individual canopy height tiles. Some mismatch problems occur
            % when we work on a big geotiff (unexplained).
            % The extent of the big geotiff creates warning on Matlab and
            % might create other problems. There is also the possibility that a geotiff
            % tag overrides something when reading the geotiff in Matlab.
            % NB: Simard Pinto 2011 is not the most recent dataset, but it has the
            % advantage of having a low esolution which makes all handling quicker and
            % easier.
            % NB: There is some unexplained mismatch between the result of this method
            % and current canopy height files.
            %
            % doi:10.1029/2011JG001708
            %
            % Parameters
            % ----------
            % canopyLabel: char: Label indicating the subfolder of the ancillary
            %   data, e.g. canopyheight or canopycover.
            % canopyFileLabel: char. Label included in output filename and
            % indicating source of canopy height data.
            % canopyPath: char. Path of input file.
            modisData = obj.espEnv.modisData;
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, canopyLabel);
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            [sourceCanopy sourceGeographicCellsReference] = ...
                readgeoraster(canopyPath);
            sourceCanopy(sourceCanopy > 100) = 0;
            if isempty(sourceGeographicCellsReference)
                sourceGeographicCellsReference = ...
                    geotiffinfo(canopyPath).SpatialRef;
            end
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                tileRegionMapCellsReference = modisData.getMapCellsReference( ...
                    modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
                land = obj.getLand(tileRegionName);
                tileRegionCanopy = rasterReprojection(sourceCanopy, ...
                    sourceGeographicCellsReference, 'rasterref', ...
                    tileRegionMapCellsReference, 'fillvalue', 0, ...
                    'method', 'linear');
                tileRegionCanopy(land == 0) = 0;
                tileRegionCanopy = min(tileRegionCanopy, 100);
                outputFilenameWithoutExtension = fullfile(outputDirectory, ...
                    [tileRegionName canopyFileLabel]);
                data = tileRegionCanopy;
                mapCellsReference = tileRegionMapCellsReference;
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                                        data, ...
                                        mapCellsReference, ...
                                        GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                                        TiffTags = struct('Compression', 'LZW'));
            end
        end
        function generateTileMaskFiles(obj, exampleMaskPath)
            % Generate the mask files for each tile.
            %
            % Parameters
            % ----------
            % exampleMaskPath: char. Path of the example mask on which basing the tile
            %   masks, that is it copies some attributes present in the example mask
            %   towards the new tile mask.
            modisData = obj.espEnv.modisData;
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, 'region');
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            load(exampleMaskPath);
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                geotiffCrop.xLeft = 0;
                geotiffCrop.xRight =0;
                geotiffCrop.yTop = 0;
                geotiffCrop.yBottom = 0;
                indxMosaic = NaN; % modified in call generateTileWaterAndLandFiles()
                LongName = tileRegionName;
                mapCellsReference = modisData.getMapCellsReference( ...
                    modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
                RefMatrix = obj.espEnv.projInfoFor(tileRegionName).RefMatrix_500m;
                S = NaN;
                ShortName = tileRegionName;
                tileIds = {tileRegionName};
                save(fullfile(outputDirectory, [tileRegionName '_mask.mat']), ...
                    'atmosphericProfile', 'geotiffCrop', 'indxMosaic', ...
                    'LongName', 'lowIllumination', 'percentCoverage', 'RefMatrix', ...
                    'ShortName', 'snowCoverDayMins', 'S', 'stc', 'stcStruct', ...
                    'thresholdsForMosaics', 'thresholdsForPublicMosaics', 'tileIds', ...
                    'useForSnowToday', 'mapCellsReference');
            end
        end
%{
        function generateTileProjectionInfoFiles(obj)
            %                                                       2023-06-23 @obsolete
            % Generate the v3 files containing the projection information
            % refmat (reference matrix), size, and mstruct) for each tile region.
            % @deprecated for v3.alaska.
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                'projInfo', obj.version);
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                fileSearch = fullfile(obj.parentDirectory, ...
                    obj.inputSubdirectories.(versionChar).modisNrtMod09ga, tileRegionName, '2022', ...
                    ['MOD09GA.A2022*.' tileRegionName '.061.NRT.hdf']);
                fileResults = dir(fileSearch);
                [mstruct Rmap1km Rmap500m size1km size500m] = makeSinusoidProj( ...
                    fullfile(fileResults(1).folder, fileResults(1).name));
                RefMatrix_1000m = Rmap1km;
                RefMatrix_500m = Rmap500m;
                size_1000m = size1km;
                size_500m = size500m;

                save(fullfile(outputDirectory, [tileRegionName '_projInfo.mat']), ...
                    'mstruct', 'RefMatrix_1000m', ...
                    'RefMatrix_500m', 'size_1000m', 'size_500m');
            end
        end
%}
        function generateTileTopographicFiles(obj, topographicCastType, ...
            topographicFileLabel, topographicSourcePaths, topographicSubDir)
            % Generate the topographic: elevation, aspect, and slope for each tile.
            %
            % NB: to make it work requires twirking the
            % RasterReprojection\util\interpolateRaster.m L. 55, by replacing error by
            % fprintf so as to access NaN matrices (if the tile is
            % beyond the extent of the source topographic data).
            %
            % Parameters
            % ----------
            % topographicCastType: char. Type in which topographic data should be
            %   stored.
            % topographicFileLabel: char. Label included in output filename and
            %   indicating type and source of topographic data ()
            % topographicSourcePaths: cells(char). Paths of input  topographic files to
            %   extract elevation for each tile. They are supposed to be in a geographic
            %   reference and have the same reference and the same matrix size.
            % topographicSubDir: char. Either aspect, elevation, or slope
            modisData = obj.espEnv.modisData;
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, topographicSubDir);
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            nodataValue = intmax(topographicCastType);
            % Get all the bits of tile for each elevation source.
            % NB: Given live memory limits, it's better no to combine the source data
            % together in 1 matrix only.
            for topographicSourceIdx = 1:length(topographicSourcePaths)
                fprintf('Reading %s...\n', ...
                    topographicSourcePaths{topographicSourceIdx});
                [sourceTopographics, sourceGeographicCellsReference] = ...
                    readgeoraster(topographicSourcePaths{topographicSourceIdx});
                sourceTopographics(isnan(sourceTopographics) | ...
                    sourceTopographics == nodataValue | ...
                    sourceTopographics == -nodataValue) = 0;
                sourceTopographics = cast(sourceTopographics, topographicCastType);
                for tileRegionIdx = 1:length(obj.tileRegionNames)
                    tileRegionName = obj.tileRegionNames{tileRegionIdx};
                    tileMapCellsReference = modisData.getMapCellsReference( ...
                        modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
                    tileTopographics = rasterReprojection(sourceTopographics, ...
                        sourceGeographicCellsReference, 'rasterref', ...
                        tileMapCellsReference, 'fillvalue', nodataValue, ...
                        'method', 'linear');
                    eval([tileRegionName '_topographics_' num2str(topographicSourceIdx) ...
                        ' = tileTopographics;']);
                end
            end

            % Gather topographic data and generate topographic file for
            % each tile region.
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                fprintf('Generation for %s\n', tileRegionName);
                tileRegionMapCellsReference = modisData.getMapCellsReference( ...
                    modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
                topographics = eval([tileRegionName '_topographics_1']);
                for topographicSourceIdx = 2:length(topographicSourcePaths)
                    tmpTopographics = ...
                        eval([tileRegionName '_topographics_' ...
                            num2str(topographicSourceIdx)]);
                    topographics(topographics == nodataValue) = ...
                        tmpTopographics(topographics == nodataValue);
                end
                topographics(topographics == nodataValue) = 0;
                outputFilenameWithoutExtension = fullfile(outputDirectory, ...
                    [tileRegionName topographicFileLabel]);
                data = topographics;
                mapCellsReference = tileRegionMapCellsReference;
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                                        data, ...
                                        tileRegionMapCellsReference, ...
                                        GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                                        TiffTags = struct('Compression', 'LZW'));
            end
        end
        function generateTileWaterAndLandFiles(obj)
            % Generate the water and land mask geotiffs with Modis Sinusoidal projection
            % for each tile.
            % Based on the nasa mod44w v006 hdf tiles (product with process ended
            % in 2015).
            % Georeferencing calculated absolutely as a function of tile name.
            % NB: initially, georeferencing inspired by makeSinusoidProj.m and extracted
            % from the mod09ga hdf tiles. But some tiles don't have correct
            % georeferencing (ex. MOD09GA.A2022001.h09v02.061.NRT.hdf).
            % NB: georeferencing: referencing matrix shifting left and up half a
            % pixel from edge. The files say "center" for upper left and lower right,
            % but this is incorrect, and the
            % webpage is correct:
            % https://lpdaac.usgs.gov/products/modis_overview
            %
            % NB: For v3.2, this was carried out on mod44w v6.0 2015 tiles. We need an
            %   update
            %   to v6.1 for v3.3, should we include a water/land tile per year?    @todo
            %
            % NB: This code put water even in place without data.               @warning
            modisData = obj.espEnv.modisData;
            outputDirectories = {fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, 'land'), ...
                fullfile(obj.parentDirectory, 'modis_ancillary', obj.version, 'water')};
            for directoryIdx = 1:length(outputDirectories)
                directory = outputDirectories{directoryIdx};
                if ~isfolder(directory)
                    mkdir(directory);
                end
            end
            versionChar = replace(obj.version, '.', ''); % remove the . in v3.2, because
                % struct cannot accept . in their fieldnames.
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};
                % Georeferencing.
%{
                @obsolete implementation 2023-06-30.
                [horizontalId verticalId] = obj.getTilePositionIds( ...
                    tileRegionName);
                columnCount = obj.georeferencing.tileInfo.columnCount;
                rowCount = obj.georeferencing.tileInfo.rowCount;
                dx = obj.georeferencing.tileInfo.dx;
                dy = obj.georeferencing.tileInfo.dy;
                northWestX =  obj.georeferencing.northwest.x0 + horizontalId * ...
                    columnCount * dx;
                northWestY = obj.georeferencing.northwest.y0 - verticalId * ...
                    rowCount * dy;
%}
                mapCellsReference = modisData.getMapCellsReference( ...
                    modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
%{
Deprecated implementation
                fileSearch = fullfile(obj.parentDirectory, ...
                    obj.inputSubdirectories.(versionChar).modisNrtMod09ga, tileRegionName, '2022', ...
                    ['MOD09GA.A2022*.' tileRegionName '.061.NRT.hdf']);
                fileResults = dir(fileSearch);
                geoInfo = hdfinfo(fullfile(fileResults(1).folder, ...
                    fileResults(1).name), 'eos');

                columnCount = geoInfo.Grid(obj.mod09ga500mGridIdx).Columns;
                rowCount = geoInfo.Grid(obj.mod09ga500mGridIdx).Rows;
                xExtent = geoInfo.Grid(obj.mod09ga500mGridIdx).UpperLeft(2) - ...
                    geoInfo.Grid(obj.mod09ga500mGridIdx).LowerRight(2);
                dx = xExtent / columnCount; % there is some error for tile h09v02 below.
                mapCellsReference1 = maprefcells([ ...
                    geoInfo.Grid(obj.mod09ga500mGridIdx).UpperLeft(1), ...
                    geoInfo.Grid(obj.mod09ga500mGridIdx).UpperLeft(1) + dx ...
                        * columnCount], ...
                    [geoInfo.Grid(obj.mod09ga500mGridIdx).UpperLeft(2) - dx ...
                        * rowCount, ...
                    geoInfo.Grid(obj.mod09ga500mGridIdx).UpperLeft(2)], ...
                    dx, dx, 'ColumnsStartFrom','north');
%}
%{
The following is useful to check identicity of mapRasterReferences
                mapCellsReference2 = ...
                    refmatToMapRasterReference(load(['c:\Tor\Dev\' tileRegionName ...
                    '_projInfo.mat']).RefMatrix_500m, [2400 2400]);

                mapCellsReference.ProjectedCRS = ...
                    projcrs(obj.projection.modisSinusoidal.wkt);
%}
                % Water and Land.
                fileSearch = fullfile(obj.parentDirectory, ...
                    obj.inputSubdirectories.(versionChar).modisHistMod44w, ...
                    replace(obj.fileNamePatterns.(versionChar).modisHistMod44w, ...
                        '{regionName}', tileRegionName));
                fileResults = dir(fileSearch);
                water = hdfread( ...
                    fullfile(fileResults(1).folder, fileResults(1).name), ...
                    'water_mask');
                waterpercent = imresize(single(water), [2400 2400], 'bilinear');
                water = false(size(waterpercent));
                water(waterpercent > obj.mod44wWaterThreshold) = 1;

                data = water;
                outputFilenameWithoutExtension = fullfile(outputDirectories{2}, ...
                    [tileRegionName '_water_mod44_' ...
                    num2str(obj.mod44wWaterThreshold * 100)]);
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                    data, ...
                    mapCellsReference, ...
                    GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                    TiffTags = struct('Compression', 'LZW'));

                data = ~water;
                outputFilenameWithoutExtension = fullfile(outputDirectories{1}, ...
                    [tileRegionName '_land_mod44_' ...
                    num2str(obj.mod44wWaterThreshold * 100)]);
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                    data, ...
                    mapCellsReference, ...
                    GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                    TiffTags = struct('Compression', 'LZW'));
                % Update indMosaic in region mask.
                indxMosaic = data;
                outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                    obj.version, 'region');
                save(fullfile(outputDirectory, [tileRegionName '_mask.mat']), ...
                    'indxMosaic', '-append');
            end
        end
%{
        function mapCellsReference = getMapCellsReference(obj, regionName)
            %                                                       2023-06-30 @obsolete
            % Parameters
            % ----------
            % regionName: char. region or tile region name.
            %
            % Return
            % ------
            % mapCellsReference: MapCellsReference object.
            mapCellsReference = geotiffinfo(fullfile(obj.parentDirectory, ...
                'modis_ancillary', 'land', obj.version, ...
                [regionName '_land_mod44_' ...
                    num2str(obj.mod44wWaterThreshold * 100) '.tif'])).SpatialRef;
            mapCellsReference.ProjectedCRS = ...
                    projcrs(obj.projection.modisSinusoidal.wkt); % NB: the geotiffs are
                        % unable to store a geographic associated to sinusoidal
                        % projection, that contain both a WGS 84 datum and a spheroid.
                        % We then update the crs here so that it can be taken into
                        % account when saving .mat files.
        end
%}
        function land = getLand(obj, regionName)
            % Parameters
            % ----------
            % regionName: char. region or tile region name.
            %
            % Return
            % ------
            % land: array(logical x 2). Indicates land.
            [land ~] = readgeoraster(fullfile(obj.parentDirectory, ...
                'modis_ancillary', obj.version, 'land', ...
                [regionName '_land_mod44_' ...
                    num2str(obj.mod44wWaterThreshold * 100) '.tif']));
        end
    end
%{
    methods(Static)
        function [tileHorizontalId tileVerticalId] = ...
            getTilePositionIds(tileRegionName)
            %                                                       2023-06-30 @obsolete
            % Parameters
            % ----------
            % tileRegionName: char. Tile region name (format h00v00).
            %
            % Return
            % ------
            % tileHorizontalId: int. Id number from west.
            % tileVerticalId: int. Id number from north.
            tileHorizontalId = str2num(tileRegionName(2:3));
            tileVerticalId = str2num(tileRegionName(5:6));
        end
    end
%}
end
