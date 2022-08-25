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
        useForSnowToday % logical cell array indicating we are using it
        lowIllumination % logical cell array for Northern areas
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

            defaultArchiveDir = '/pl/active/rittger_esp/region_masks/v3';
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
            obj.useForSnowToday = mObj.useForSnowToday;
            obj.lowIllumination = mObj.lowIllumination;
            
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
        
        function writeStats(obj, espEnv, historicalStats, ...
                currentStats, regionNum, statsType)
            % writes the year-to-date statsType for regionNum to public FTP
			% statsType: albedo_clean_muZ, albedo_observed_muZ,
			% radiative_forcing, must be in field_and_stats_names.csv
			
			% Statstype info
			% --------------
			% Check if the statsType is ok and get the abbreviation (used as
			% a suffix or prefix of fields in the historicalStats and
			% currentStats files) and label and units (for the header)
			fields = espEnv.field_names_and_descriptions();
			if isempty(fields(strcmp(fields.name, statsType), :))
				ME = MException('%s: statsType %s not found in the ', ...
					'list of authorized statsType',  mfilename(), statsType);
				throw(ME)
			end
			statsTypeLine = fields(strcmp(fields.name, statsType), :);
			abbreviation = statsTypeLine.('calc_suffix_n_prefix'){1};
			label = statsTypeLine.('label'){1};
			units = statsTypeLine.('units'){1};
			
			% Current year
			% ------------
            todayDt = datetime;
            waterYr = year(todayDt);
            thisMonth = month(todayDt);
            if thisMonth >= 10
                waterYr = waterYr + 1;
            end
			
			% File
			% ----
            fileName = sprintf('SnowToday_%s_%s_WY%4d_yearToDate.csv', ...
                obj.ShortName{regionNum}, statsType, waterYr);
            fileName = fullfile(espEnv.dirWith.publicFTP, ...
                sprintf('WY%04d', waterYr), ...
                'linePlotsToDate', ...
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
                datestr(todayDt, 'yyyy-mm-dd'));
            fprintf(fileID, 'Units : %s\n', units);
            fprintf(fileID, 'Water Year : %04d\n', ...
                waterYr);
            fprintf(fileID, 'Water Year Begins : %04d-10-01\n', ...
                waterYr - 1);
            fprintf(fileID, 'RegionName : %s\n', ...
                historicalStats.LongName{regionNum});
            fprintf(fileID, 'RegionID : %s\n', ...
                historicalStats.ShortName{regionNum});
            [~, nyears] = size(historicalStats.yrs);
            fprintf(fileID, 'Historical Years : %04d-%04d\n', ...
                historicalStats.yrs(1), ...
                historicalStats.yrs(nyears));
            fprintf(fileID, 'Lowest Snow Year : %04d\n', ...
                historicalStats.yr_min(regionNum));
            fprintf(fileID, 'Highest Snow Year : %04d\n', ...
                historicalStats.yr_max(regionNum));
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
                historicalStats.yrs == historicalStats.yr_min(regionNum));
            yr_max_indx = find(...
                historicalStats.yrs == historicalStats.yr_max(regionNum));
                            
			min = historicalStats.(abbreviation + "_yr")(yr_min_indx, :, regionNum)';
			max = historicalStats.(abbreviation + "_yr")(yr_max_indx, :, regionNum)';
			prc25 = historicalStats.("prc25_" + abbreviation)(1, :, regionNum)';
			median = historicalStats.("median_" + abbreviation)(1, :, regionNum)';
			prc75 = historicalStats.("prc75_" + abbreviation)(1, :, regionNum)';
			
			year_to_date = ...
				currentStats.(abbreviation + "_yr")(1, :, regionNum)';
            
			dlmwrite(fileName, [day_of_water_year min max prc25 median ...
				prc75 max year_to_date], '-append');
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
