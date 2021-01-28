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

            defaultArchiveDir = '/pl/active/rittger_esp/region_masks/v2';
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

            todayDt = datetime;
            waterYr = year(todayDt);
            thisMonth = month(todayDt);
            if thisMonth >= 10
                waterYr = waterYr + 1;
            end
            fileName = sprintf('SnowToday_%s_%s_WY%4d_yearToDate.txt', ...
                obj.ShortName{regionNum}, statsType, waterYr);
            fileName = fullfile(espEnv.publicDir, ...
                sprintf('WY%04d', waterYr), ...
                'linePlotsToDate', ...
                fileName);
            [path, ~, ~] = fileparts(fileName);
            if ~isfolder(path)
                mkdir(path);
            end
            
            day_of_water_year = (1:366)';
            
            yr_min_indx = find(...
                historicalStats.yrs == historicalStats.yr_min(regionNum));
            yr_max_indx = find(...
                historicalStats.yrs == historicalStats.yr_max(regionNum));
            
            if strcmp(statsType, 'SCF')
                label = 'Total Snow Cover Area';
                units = 'square kilometers';
                
                min_sca_area_km2 = ...
                    historicalStats.sca_area_km2_yr(yr_min_indx, :, regionNum)';
                max_sca_area_km2 = ...
                    historicalStats.sca_area_km2_yr(yr_max_indx, :, regionNum)';
                prc25_sca_area_km2 = ...
                    historicalStats.prc25_sca_area_km2(1, :, regionNum)';
                median_sca_area_km2 = ...
                    historicalStats.median_sca_area_km2(1, :, regionNum)';
                prc75_sca_area_km2 = ...
                    historicalStats.prc75_sca_area_km2(1, :, regionNum)';
                year_to_date_sca_area_km2 = ...
                    currentStats.sca_area_km2_yr(1, :, regionNum)';
                
                T = table(day_of_water_year, ...
                    min_sca_area_km2, ...
                    prc25_sca_area_km2, ...
                    median_sca_area_km2, ...
                    prc75_sca_area_km2, ...
                    max_sca_area_km2, ...
                    year_to_date_sca_area_km2);
                
                
                writetable(T, fileName);
                
                % Append metadata to end of file
                fileID = fopen(fileName, 'a');
                fprintf(fileID, '\n');
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
                fprintf(fileID, 'Lowest Year : %04d\n', ...
                    historicalStats.yr_min(regionNum));
                fprintf(fileID, 'Highest Year : %04d\n', ...
                    historicalStats.yr_max(regionNum));
                
            else
                label = 'Snow Cover Days';
                units = 'days';
                
                min_scd = ...
                    historicalStats.scd_sum_yr(yr_min_indx, :, regionNum)';
                max_scd = ...
                    historicalStats.scd_sum_yr(yr_max_indx, :, regionNum)';
                prc25_scd = ...
                    historicalStats.prc25_scd_sum(1, :, regionNum)';
                median_scd = ...
                    historicalStats.median_scd_sum(1, :, regionNum)';
                prc75_scd = ...
                    historicalStats.prc75_scd_sum(1, :, regionNum)';
                year_to_date_scd = ...
                    currentStats.scd_sum_yr(1, :, regionNum)';
                
                T = table(day_of_water_year, ...
                    min_scd, ...
                    prc25_scd, ...
                    median_scd, ...
                    prc75_scd, ...
                    max_scd, ...
                    year_to_date_scd);
                
                writetable(T, fileName);
                
                % Append metadata to end of file
                fileID = fopen(fileName, 'a');
                fprintf(fileID, '\n');
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
                fprintf(fileID, 'Lowest Year : %04d\n', ...
                    historicalStats.yr_min(regionNum));
                fprintf(fileID, 'Highest Year : %04d\n', ...
                    historicalStats.yr_max(regionNum));
            end
            
            fclose(fileID);
            
            fprintf('%s: Wrote %s\n', mfilename(), fileName);
            
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
