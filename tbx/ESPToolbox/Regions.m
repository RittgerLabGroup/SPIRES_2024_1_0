classdef Regions
%Regions - information about spatial sub-regions (states/watersheds)
%   This class contains functions to manage information about our
%   subregions by state (county) and watersheds at several levels
    properties      % public properties
        archiveDir    % top-level directory with region data
    	name          % name of region set
        ShortName     % cell array of short names for file names
        LongName      % cell array of long names for title
        S             % region geometry structures
        indxMosaic    % mask with region IDS
        percentCoverage % areal percent coverage of the region in our tiles
    end
    properties(Constant)
        % pixSize_500m = 463.31271653;
    end
    
    methods         % public methods
        
        function obj = Regions(regionName, varargin)
            % The Regions constructor initializes the directory
            % for local storage of MODIS tile data
            
            p = inputParser;

            addRequired(p, 'regionName', @ischar);

            defaultArchiveDir = '/pl/active/rittger_esp/region_masks';
            checkArchiveDir = @(x) exist(x, 'dir');
            addOptional(p, 'archiveDir', defaultArchiveDir, ...
                checkArchiveDir);

            p.KeepUnmatched = true;
            
            parse(p, regionName, varargin{:});
            
            obj.archiveDir = p.Results.archiveDir;
            obj.name = p.Results.regionName;

            % Fetch the structure with the requested region information
            regionFile = fullfile(obj.archiveDir, ...
                sprintf("%s.mat", obj.name));
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
            obj.percentCoverage = mObj.percentCoverage;
            
            
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
