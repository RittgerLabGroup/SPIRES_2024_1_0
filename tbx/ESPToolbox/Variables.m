classdef Variables
    % Handles the calculations to obtain the variables
    % e.g. snow_cover_days
    properties
        regions         % Regions object, on which the calculations are done
    end

    properties(Constant)
        albedoScale = 10000.; % Factor to multiply albedo obtained from
                             % ParBal.spires_albedo
        albedoDeltavisScale = 100.; % Factor for deltavis in albedo_observed
                                    % calculations
        albedoDownscaleFactor = 0.63; % Factor for albedo_clean in albedo_observed
                                      % calculations
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
            fprintf('%s: Start snow_cover_days calculations', mfilename());
            % 1. Initialization, elevation data, dates
            %    and collection of units and divisor for
            %    snow_cover_days
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;
            mins = regions.snowCoverDayMins;

            if ~exist('espDate', 'var')
                espDate = ESPDate();
            end
            dateRange = espDate.getMonthFirstDateRangeForCalculations();
            numberOfMonths = length(dateRange);

            elevationFile = espEnv.modisRegionElevationFile(regions);
            elevationData = load(elevationFile, 'Z');

            variables = espEnv.confOfVariables();
            snowCoverConf = variables(find( ...
                strcmp(variables.output_name, 'snow_cover_days')), :);
            snow_cover_units = snowCoverConf.units_in_map;
            snow_cover_divisor = snowCoverConf.divisor;

            snow_cover_min_elevation = mins.minElevation;
            snow_cover_min_snow_cover_fraction = mins.minSnowCoverFraction;

            % 1. Initial snowCoverDays
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            % Taken from the day preceding the date range (in the monthly
            % interp data file of the month before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0
            lastSnowCoverDays = 0;

            if month(dateRange(1)) ~= ESPDate.waterYearFirstMonth
                dateBefore = daysadd(dateRange(1) , -1);
                interpFile = espEnv.MonthlySCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateBefore);

                if isfile(interpFile)
                    interpData = load(interpFile, 'snow_cover_days');
                    fprintf('%s: Loading snow_cover_days from %s\n', ...
                            mfilename(), interpFile);
                    if ~isempty(interpData) && ...
						any(strcmp(fieldnames(interpData), 'snow_cover_days')) 
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
            for monthDayIdx=1:numberOfMonths
                % 2.a. Loading of the monthly interpolation file
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                interpFile = espEnv.MonthlySCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateRange(monthDayIdx));

                if ~isfile(interpFile)
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        interpFile);
                    continue;
                end

                interpData = load(interpFile, 'snow_fraction');
                fprintf('%s: Loading snow_fraction from %s\n', ...
                        mfilename(), interpFile);
                if isempty(interpData)
                    warning('%s: No snow_fraction variable in %s\n', ...
                        mfilename(), interpFile);
                    continue;
                end

                snowCoverFraction = interpData.snow_fraction;
                % 2.b. Below a certain elevation and fraction, the pixel is not
                % considered covered by snow
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                snowCoverFraction(snowCoverFraction < ...
					snow_cover_min_snow_cover_fraction) = 0;
                snowCoverFraction(elevationData.Z < snow_cover_min_elevation) = 0;

                % 2.c. Cumulated snow cover days calculation and save
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
				snowCoverFractionWithoutNaN = snowCoverFraction(:, :, :);
				snowCoverFractionWithoutNaN(isnan(snowCoverFraction)) = 0; 
				logicalSnowCoverFraction = cast(logical(snowCoverFractionWithoutNaN), ...
					'double');
				logicalSnowCoverFraction(isnan(snowCoverFraction)) = NaN; 
                snow_cover_days = lastSnowCoverDays + ...
                    cumsum(logicalSnowCoverFraction, 3);
                lastSnowCoverDays = snow_cover_days(:, :, end);
                save(interpFile, 'snow_cover_days', 'snow_cover_divisor', ...
                            'snow_cover_units', 'snow_cover_min_elevation', ...
                            'snow_cover_min_snow_cover_fraction', '-append');
            end
            t2 = toc;
            fprintf('%s: Finished snow cover days update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
