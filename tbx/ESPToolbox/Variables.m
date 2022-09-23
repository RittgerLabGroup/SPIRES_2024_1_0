classdef Variables
    % Handles the calculations to obtain the variables
    % e.g. snow_cover_days
    properties
        regions         % Regions object, on which the calculations are done
    end

    methods
        function obj = Variables(regions)
            % Constructor of Variables
            %
            % Parameters
            % ----------
            % regions: Regions object
            %   Regions on which the variables are handled

            obj.regions = regions;
        end

        function calcSnowCoverDays(obj, espDate)
            % Calculates snow cover days from snow_fraction variable
            % and updates the interpolation data files with the value.
            % Cover days are calculated if elevation and snow cover fraction
            % are above thresholds defined at the Regions level (attribute
            % snowCoverDayMins.
            % Cover days doesn't include the days without snow fraction data.
            %
            % Parameters
            % ----------
            % espDate: ESPDate object, optional
            %   Date and range of days before over which calculation
            %   should be carried out

            tic;
            % 1. Initialization, elevation data, dates
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;
            regionName = regions.regionName;
            mins = regions.snowCoverDayMins;

            if ~exist('espDate', 'var')
                espDate = ESPDate();
            end
            dateRange = espDate.getDatetimeMonthRangeForCalculations();
            numberOfMonths = length(dateRange);

            elevationFile = espEnv.modisElevationFile(regions.regionName);
            elevationData = load(elevationFile, 'Z');            
            
            % 1. Initial snowCoverDays
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            % Taken from the day preceding the date range (in the monthly
            % interp data file of the month before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0
            lastSnowCoverDays = 0;

            if month(dateRange(1)) ~= ESPDate.waterYearFirstMonth
                dateBefore = daysadd(dateRange(1) , -1));
                interpFile = = espEnv.MonthlySCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateBefore);

                if isfile(interpFile)
                    interpData = load(interpFile, 'snow_cover_days');
                    fprintf('%s: Loading snow_cover_days from %s\n', ...
                            mfilename(), interpData);
                    if ~isempty(interpData)
                        lastSnowCoverDays = interpData.snow_cover_days(:, :, end);                        
                    else
                        warning('%s: No snow_cover_days variable in %s\n', ...
                            mfilename(), interpFile);
                    end
                else
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        interpFile);
                end
            end

            % 2. Update each monthly interpolated files for the full
            % period by calculating snow_cover_days from snow_fractions
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            
            % Start or connect to the local pool (parallelism) : IMPOSSIBLE here          
            % Parallelism.configParallelismPool(espEnv);
            snow_cover_units = 'days';
            snow_cover_divisor = 1;
            snow_cover_min_elevation = mins.minElevation;
            snow_cover_min_snow_cover_fraction = mins.minSnowCoverFraction;
   
            for d=1:numberOfMonths % parfor impossible here
                                
                % 2.a. Loading of the monthly interpolation file
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                interpFile = espEnv.MonthlySCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateRange(d));

                if ~isfile(interpFile)
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        interpFile);
                    continue;
                end

                interpData = load(interpFile, 'snow_fraction');
                fprintf('%s: Loading snow_fraction from %s\n', ...
                        mfilename(), interpData);
                if isempty(interpData)
                    warning('%s: No snow_fraction variable in %s\n', ...
                        mfilename(), interpFile);
                    continue;
                end
                
                snowCoverFraction = interpData.snow_fraction; 
                % 2.b. Below a certain elevation and fraction, the pixel is not
                % considered covered by snow
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                snowCoverFraction(snowCoverFraction < snow_cover_min_snow_cover_fraction) = 0;
                snowCoverFraction(elevationData.Z < snow_cover_min_elevation) = 0;
                
                % 2.c. Cumulated snow cover days calculation and save
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                snow_cover_days = lastSnowCoverDays + ...
                    logical(snowCoverFraction, 3, 'omitnan');
                lastSnowCoverDays = snowCoverDays(:, :, end); 
                save(interpFile, 'snow_cover_days', 'snow_cover_units', ...
                            'snow_cover_divisor', 'snow_cover_min_elevation', ...
                            'snow_cover_min_snow_cover_fraction', '-append');
            end
            t2 = toc;
            fprintf('%s: Finished snow cover days update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
        
        function calcAlbedos(obj, espDate)
            % Calculates clean and observed albedos on flat surface (mu0)
            % and on slopes (muZ) from snow_fraction, solar_zenith, solar_azimuth,
            % grain_size, deltavis, topographic slopes and aspect variables.
            % Updates the interpolation data files with the values.
            % Fields calculated: albedo_clean_mu0, albedo_observed_mu0,
            % albedo_clean_muZ, albedo_observed_muZ.
            % Albedos are NaN when snow_fraction or grain_size are NaN.
            %
            % Parameters
            % ----------
            % espDate: ESPDate object, optional
            %   Date and range of days before over which calculation
            %   should be carried out

            tic;
            % 1. Initialization, dates, slopes, aspects
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;
            regionName = regions.regionName;
            regions.atmosphericProfile;

            if ~exist('espDate', 'var')
                espDate = ESPDate();
            end
            dateRange = espDate.getDatetimeMonthRangeForCalculations();
            numberOfMonths = length(dateRange);

            topo = matfile(espEnv.modisRegionTopographyFile(regions));
            slope = topo.S;
            aspect = topo.A;
            
            
            
            t2 = toc;
            fprintf('%s: Finished albedos update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
