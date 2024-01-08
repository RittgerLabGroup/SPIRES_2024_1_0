%---------------------------------------------------------------------------------------
% Creation of the ancillary data necessary for snowToday processes for a new region:
% regions masks, elevations, slopes, aspects, canopy heights, water and land masks.
% Generation for each tiles that compose the region + for the full region.
% Does not include the masks for drainage basins HUC2, HUC4.
% NB: the geotiffs are unable to store a geographic associated to sinusoidal
% projection, that contain both a WGS 84 datum and a spheroid. The ancillary data are
% then generated both in .geotiff and .mat files, with only the .mat file containing
% the crs with the correct WGS 84 datum.
%
% v3.alaska
% sebastien.lenard@colorado.edu
% 04/06/2023
%---------------------------------------------------------------------------------------
classdef RegionAncillaryDataSetup
    properties
%{
        georeferencing % struct(northwest = struct(x0 = int, y0 = int), tileInfo =
            % struct(dx = single, dy = single, columnCount = int, rowCount = int)).
            % Data necessary to absolutely calculate georeferencing for each tile named
            % hyyvxx.                                               2023-06-30 @obsolete
%}
        espEnv % ESPEnv Obj.
        parentDirectory % char. Parent directory which store the ancillary
            % files.
        regionName % char. Name of the region.
        tileRegionNames % cell array of char. Names of the modis tiles which
            % compose the region.
        version % char. Version of the files.
    end
    properties(Constant)
        modisGeoreferencing = struct(horizontalTileIdLimits = [0, 35], ...
            verticalTileIdLimits = [0 27], ...
            columnCount = 2400, rowCount = 2400); % tileDx = tileDy.  % There is a way to remove this from here @todo
    end
    methods
        function obj = RegionAncillaryDataSetup(varargin)
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
        function generateAggregatedFilesFromTileDataFiles(obj, ...
            ancillaryDataDirectories, ancillaryDataFileLabels)
            % Aggregates the data from each tile ancillary data file and save the
            % results in files for the big region, in the Modis Sinusoidal projection.
            %
            % Parameters
            % ----------
            % ancillaryDataDirectories: cells(char). List of directories having
            %   ancillary data (elevation, ... except ProjInfo and masks).
            % ancillaryDataFileLabels: cells(char). Labels for each type of ancillary
            %   data.
            modisData = obj.espEnv.modisData;
            % Georeferencing of the big region, extracted from tile infos
            mapCellsReference = obj.getMapCellsReference();

            % Extracting the ancillary data info from the tile files and setting them
            % in the big region matrix.
            for directoryIdx = 1:length(ancillaryDataDirectories)
                directory = ancillaryDataDirectories{directoryIdx};
                fileLabel = ancillaryDataFileLabels{directoryIdx};
                data = [];
                for tileRegionIdx = 1:length(obj.tileRegionNames)
                    tileRegionName = obj.tileRegionNames{tileRegionIdx};
                    positionalData = ...
                        modisData.getTilePositionIdsAndColumnRowCount(tileRegionName);
                    tileHorizontalId = positionalData.horizontalId;
                    tileVerticalId = positionalData.verticalId;
                    [tileData, tileMapCellsReference] = ...
                        readgeoraster(fullfile(directory, [tileRegionName, ...
                        fileLabel, '.tif']));
                    if tileRegionIdx == 1
                        data = zeros(mapCellsReference.RasterSize(1), ...
                            mapCellsReference.RasterSize(2), class(tileData));
                    end
                    relativePositionalData = modisData.getTileRelativePositionIds( ...
                        tileRegionName, obj.tileRegionNames);
                    westInBigRegion = relativePositionalData.horizontalId * ...
                        tileMapCellsReference.RasterSize(1) + 1;
                    northInBigRegion = relativePositionalData.verticalId * ...
                        tileMapCellsReference.RasterSize(1) + 1;
                    data(northInBigRegion: northInBigRegion + ...
                        tileMapCellsReference.RasterSize(1) - 1, ...
                        westInBigRegion: westInBigRegion + ...
                        tileMapCellsReference.RasterSize(2) - 1) = tileData;
                end
                outputFilenameWithoutExtension = fullfile(directory, ...
                    [obj.regionName fileLabel]);
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                    data, ...
                    mapCellsReference, ...
                    GeoKeyDirectoryTag = ...
                        modisData.projection. ...
                        modisSinusoidal.geoKeyDirectoryTag, ...
                    TiffTags = struct('Compression', 'LZW'));
                if contains(fileLabel, 'land')
                    % Update indMosaic in region mask.
                    indxMosaic = data;
                    outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                        obj.version, 'region');
                    save(fullfile(outputDirectory, [obj.regionName, '_mask.mat']), ...
                        'indxMosaic', '-append');
                end
            end
        end
        function generateMaskFile(obj, exampleMaskPath)
            % Generate the mask files for each tile.
            %
            % Parameters
            % ----------
            % exampleMaskPath: char. Path of the example mask on which basing the tile
            %   masks, that is it copies some attributes present in the example mask
            %   towards the new tile mask.
            outputDirectory = fullfile(obj.parentDirectory, 'modis_ancillary', ...
                obj.version, 'region');
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            load(exampleMaskPath);
            geotiffCrop.xLeft = 0;
            geotiffCrop.xRight =0;
            geotiffCrop.yTop = 0;
            geotiffCrop.yBottom = 0;
            indxMosaic = NaN; % FIND a way to modify that !                         TODO
            LongName = obj.regionName;
            mapCellsReference = obj.getMapCellsReference();
            RefMatrix = [[0, -mapCellsReference.CellExtentInWorldX]; ...
                [mapCellsReference.CellExtentInWorldX, 0]; ...
                [mapCellsReference.XWorldLimits(1) - ...
                    mapCellsReference.CellExtentInWorldX / 2, ...
                    mapCellsReference.YWorldLimits(2) + ...
                    mapCellsReference.CellExtentInWorldY / 2]]; % should have a method in Regions? @todo
            S = NaN;
            ShortName = obj.regionName;
            tileIds = obj.tileRegionNames;
            % the following is not very clever ...
            tileRegionAncillaryDataSetup = TileRegionAncillaryDataSetup( ...
                espEnv = obj.espEnv, ...
                parentDirectory = obj.parentDirectory, ...
                regionName = obj.regionName, ...
                tileRegionNames = obj.tileRegionNames, ...
                version = obj.version);
            save(fullfile(outputDirectory, [obj.regionName '_mask.mat']), ...
                'atmosphericProfile', 'geotiffCrop', 'indxMosaic', ...
                'LongName', 'lowIllumination', 'percentCoverage', 'RefMatrix', ...
                'ShortName', 'snowCoverDayMins', 'S', 'stc', 'stcStruct', ...
                'thresholdsForMosaics', 'thresholdsForPublicMosaics', 'tileIds', ...
                'useForSnowToday', 'mapCellsReference');
        end
        function mapCellsReference = getMapCellsReference(obj)
            % Parameters
            % ----------
            % regionName: char. region or tile region name.
            %
            % Return
            % ------
            % mapCellsReference: MapCellsReference object.
            % Encapsulates the MODISData getMapCellsReference. Here
            % we need to have the list of all tiles that compose the big region,
            % which we can't have if we only base on the MODISData object.
            % Copy of the Regions.getMapCellsReference()
            modisData = obj.espEnv.modisData;

            horizontalTileIds = zeros([1, length(obj.tileRegionNames)], 'uint8');
            verticalTileIds = zeros([1, length(obj.tileRegionNames)], 'uint8');
            for idx = 1:length(obj.tileRegionNames)
                positionalTileData = ...
                    modisData.getTilePositionIdsAndColumnRowCount( ...
                    obj.tileRegionNames{idx});
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

            mapCellsReference = modisData.getMapCellsReference(positionalData);
        end
%{
        function [horizontalIdLimits, verticalIdLimits] = ...
            getTilePositionIdLimits(obj)
            %                                                                  @obsolete
            % Return
            % ------
            % tileHorizontalIdLimits: array(int). Tile id limits at west and east.
            % tileVerticalIdLimits: int. Tile id limits at north and south.
            horizontalIdLimits = [obj.modisGeoreferencing.horizontalTileIdLimits(2), ...
                obj.modisGeoreferencing.horizontalTileIdLimits(1)];
            verticalIdLimits = [obj.modisGeoreferencing.verticalTileIdLimits(2), ...
                obj.modisGeoreferencing.verticalTileIdLimits(1)];
            for tileRegionIdx = 1:length(obj.tileRegionNames)
                tileRegionName = obj.tileRegionNames{tileRegionIdx};

                [tileHorizontalId tileVerticalId] = ...
                    TileRegionAncillaryDataSetup.getTilePositionIds(tileRegionName);
                horizontalIdLimits(1) = min(tileHorizontalId, horizontalIdLimits(1));
                horizontalIdLimits(2) = max(tileHorizontalId, horizontalIdLimits(2));
                verticalIdLimits(1) = min(tileVerticalId, verticalIdLimits(1));
                verticalIdLimits(2) = max(tileVerticalId, verticalIdLimits(2));
            end
        end
%}
    end
end
