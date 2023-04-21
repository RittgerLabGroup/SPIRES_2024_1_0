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
        georeferencing % struct(northwest = struct(x0 = int, y0 = int), tileInfo = 
            % struct(dx = single, dy = single, columnCount = int, rowCount = int)). 
            % Data necessary to absolutely calculate georeferencing for each tile named
            % hyyvxx.
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
            tileDx = 2400); % tileDx = tileDy.
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
                        
            % Georeferencing of the big region, extracted from tile infos
            [horizontalIdLimits verticalIdLimits] = obj.getTilePositionIdLimits();
            columnCount = ...
                obj.georeferencing.tileInfo.columnCount;
            rowCount = obj.georeferencing.tileInfo.rowCount;
            dx = obj.georeferencing.tileInfo.dx;
            dy = obj.georeferencing.tileInfo.dy;  
            
            northWestX =  obj.georeferencing.northwest.x0 ...
                + horizontalIdLimits(1) * columnCount * dx;
            northWestY = obj.georeferencing.northwest.y0 ...
                - verticalIdLimits(1) * rowCount * dy;
            mapCellsReference = maprefcells([ ...
                northWestX + dx / 2, ...
                northWestX - dx / 2 + dx * columnCount * ...
                (horizontalIdLimits(2) - horizontalIdLimits(1) + 1)], ...
                [northWestY - dy / 2 - dy * rowCount * ...
                (verticalIdLimits(2) - verticalIdLimits(1) + 1), ...
                northWestY - dy / 2], ...
                dx, dy, 'ColumnsStartFrom','north');
            mapCellsReference.ProjectedCRS = ...
                projcrs( ... 
                TileRegionAncillaryDataSetup.projection.modisSinusoidal.wkt);

            % Extracting the ancillary data info from the tile files and setting them
            % in the big region matrix.
            for directoryIdx = 1:length(ancillaryDataDirectories)
                directory = ancillaryDataDirectories{directoryIdx};
                fileLabel = ancillaryDataFileLabels{directoryIdx};
                data = [];
                for tileRegionIdx = 1:length(obj.tileRegionNames)
                    tileRegionName = obj.tileRegionNames{tileRegionIdx};   
                    [tileHorizontalId tileVerticalId] = ...
                        TileRegionAncillaryDataSetup.getTilePositionIds( ...
                        tileRegionName);
                    [tileData, tileMapCellsReference] = ...
                        readgeoraster(fullfile(directory, [tileRegionName, ...
                        fileLabel, '.tif']));
                    if tileRegionIdx == 1
                        data = zeros(mapCellsReference.RasterSize(1), ...
                            mapCellsReference.RasterSize(2), class(tileData));
                    end
                    westIdInBigMatrix = (tileHorizontalId - horizontalIdLimits(1)) ...
                        * columnCount + 1;
                    northIdInBigMatrix = (tileVerticalId - verticalIdLimits(1)) ...
                        * rowCount + 1;
                    data(northIdInBigMatrix:northIdInBigMatrix ...
                        + tileMapCellsReference.RasterSize(1) - 1, ...
                        westIdInBigMatrix:westIdInBigMatrix ...
                        + tileMapCellsReference.RasterSize(2) - 1) = tileData;
                end
                outputFilenameWithoutExtension = fullfile(directory, ...
                    [obj.regionName fileLabel]);
                save([outputFilenameWithoutExtension '.mat'], ...
                    'data', 'mapCellsReference');
                geotiffwrite([outputFilenameWithoutExtension '.tif'], ...
                    data, ...
                    mapCellsReference, ...
                    GeoKeyDirectoryTag = ...
                        TileRegionAncillaryDataSetup.projection. ...
                        modisSinusoidal.geoKeyDirectoryTag, ...
                    TiffTags = struct('Compression', 'LZW'));
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
                'region', obj.version);            
            if ~isfolder(outputDirectory)
                mkdir(outputDirectory);
            end
            load(exampleMaskPath);
            geotiffCrop.xLeft = 0;
            geotiffCrop.xRight =0;
            geotiffCrop.yTop = 0;
            geotiffCrop.yBottom = 0;
            LongName = obj.regionName;
            ShortName = obj.regionName;
            tileIds = obj.tileRegionNames;
            % the following is not very clever ...
            tileRegionAncillaryDataSetup = TileRegionAncillaryDataSetup( ...
                georeferencing = obj.georeferencing, ...
                parentDirectory = obj.parentDirectory, ...
                regionName = obj.regionName, ...
                tileRegionNames = obj.tileRegionNames, ...    
                version = obj.version);
            mapCellsReference = ...
                obj.getMapCellsReference();
            save(fullfile(outputDirectory, [obj.regionName '_mask.mat']), ...
                'atmosphericProfile', 'geotiffCrop', ...
                'LongName', 'lowIllumination', 'percentCoverage', ...
                'ShortName', 'snowCoverDayMins', 'stc', ...
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
            mapCellsReference = geotiffinfo(fullfile(obj.parentDirectory, ...
                'modis_ancillary', 'land', obj.version, ...
                [obj.regionName '_land_mod44_' ...
                    num2str(TileRegionAncillaryDataSetup.mod44wWaterThreshold ...
                        * 100) '.tif'])).SpatialRef;
            mapCellsReference.ProjectedCRS = ...
                    projcrs(TileRegionAncillaryDataSetup.projection.modisSinusoidal.wkt); % NB: the geotiffs are
                        % unable to store a geographic associated to sinusoidal 
                        % projection, that contain both a WGS 84 datum and a spheroid.
                        % We then update the crs here so that it can be taken into
                        % account when saving .mat files.
        end
                
        function [horizontalIdLimits, verticalIdLimits] = ...
            getTilePositionIdLimits(obj)
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
    end
end