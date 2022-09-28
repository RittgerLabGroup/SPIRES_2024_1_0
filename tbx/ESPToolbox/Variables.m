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
            dateRange = espDate.getDatetimeMonthRangeForCalculations();
            numberOfMonths = length(dateRange);

            elevationFile = espEnv.modisRegionElevationFile(regions);
            elevationData = load(elevationFile, 'Z');

            variables = espEnv.confOfVariables();
            snowCoverConf = variables(find( ...
                strcmp(variables.output_name, 'snow_cover')), :);
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
            for d=1:numberOfMonths
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
                save(interpFile, 'snow_cover_days', 'snow_cover_divisor', ...
                            'snow_cover_units', 'snow_cover_min_elevation', ...
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
            fprintf('%s: Start albedos calculations', mfilename())

            % 1. Initialization, dates, slopes, aspects
            %    and collection of albedo types, units, divisors
            %    and min-max.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;

            if ~exist('espDate', 'var')
                espDate = ESPDate();
            end
            dateRange = espDate.getDatetimeMonthRangeForCalculations();
            numberOfMonths = length(dateRange);

            topo = matfile(espEnv.modisRegionTopographyFile(regions));
            slope = topo.S;
            aspect = topo.A;

            albedoNames = ['albedo_clean_mu0', 'albedo_clean_muZ', ...
                'albedo_observed_mu0', 'albedo_observed_muZ'];
            albedoConf = struct();
            variables = espEnv.confOfVariables();

            for i=1:len(albedoNames)
                albedoName = albedoNames(i);
                albedoConf = variables(find( ...
                    strcmp(variables.output_name, albedoName)), :);
                albedoConf.([albedo '_type']) = albedoConf.type;
                albedoConf.([albedo '_units']) = albedoConf.units_in_map;
                albedoConf.([albedo '_divisor']) = albedoConf.divisor;
                albedoConf.([albedo '_min']) = albedoConf.min * albedoConf.divisor;
                albedoConf.([albedo '_max']) = albedoConf.max * albedoConf.divisor;
            end

            % 2. Update each monthly interpolated files for the full
            % period by calculating albedos
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Start or connect to the local pool (parallelism)
            Parallelism.configParallelismPool(espEnv);

            parfor d=1:numberOfMonths
                % 2.a. Loading of the monthly interpolation file
                %      If snow_fraction is 0, set the grain_size
                %      to NaN to get final albedos to NaN
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                albedos = struct();
                albedo_clean_mu0 = 0;
                albedo_observed_mu0 = 0;
                albedo_clean_muZ = 0;
                albedo_observed_muZ = 0;
                errorStruct = struct();
                interpFile = espEnv.MonthlySCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateRange(d));

                if ~isfile(interpFile)
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        interpFile);
                    continue;
                end

                data = load(interpFile, 'deltavis', 'grain_size', ...
                    'snow_fraction', 'solar_azimuth', 'solar_zenith');

                fprintf('%s: Loading snow_fraction and other vars from %s\n', ...
                        mfilename(), interpData);
                if isempty(interpData)
                    warning('%s: No variables in %s\n', ...
                        mfilename(), interpFile);
                    continue;
                end

                % 2.b. Calculations of mu0 and muZ (cosinus of solar zenith)
                % considering a flat surface (mu0) or considering slope and
                % aspect (muZ)
                % use of ParBal package: .sunslope and .spires_albedo.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                mu0 = cosd(double(data.solar_zenith));

                % phi0: Normalize stored azimuths to expected azimuths
                % stored data is assumed to be -180 to 180 with 0 at North
                % expected data is assumed to be +ccw from South, -180 to 180
                phi0 = 180. - double(data.solar_azimuth);
                phi0(phi0 > 180) = phi0(phi0 > 180) - 360;

                muZ = sunslope(mu0, phi0, slope, aspect);

                % 2.c. Calculations of clean albedos, corrections to
                % obtain observed albedos, cast to the expected type,
                % sanity check min-max, and save
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                albedos.albedo_clean_mu0 = spires_albedo(data.grain_size, mu0, ...
                    regions.atmosphericProfile);
                albedos.albedo_clean_muZ = spires_albedo(data.grain_size, muZ, ...
                    regions.atmosphericProfile);

                albedoObservedCorrection = (data.deltavis / ...
                    Variables.albedoDeltavisScale) * ...
                    Variables.albedoDownscaleFactor;

                albedos.albedo_observed_mu0 = albedo_clean_mu0 - ...
                    albedoObservedCorrection;
                albedos.albedo_observed_muZ = albedo_clean_muZ - ...
                    albedoObservedCorrection;

                for i=1:len(albedoNames)
                    albedoName = albedoNames(i);
                    albedos.(albedoName) = cast(albedos.(albedoName) * ...
                        Variables.albedoScale, ...
                        albedoConf.([albedoName '_type']));
                    if min(albedos.(albedoName), [], 'all') < albedoConf.([albedoName '_min']) ...
                    || max(albedos.(albedoName), [], 'all') > albedoConf.([albedoName '_max'])
                        errorStruct.identifier = 'Variables:RangeError';
                        errorStruct.message = sprintf(...
                            '%s: Calculated %s %s [%.3f,%.3f] out of bounds\n',...
                            mfilename, regions.regionName, ...
                            albedoName, [albedoName '_min'], [albedoName '_max']);
                        error(errorStruct);
                    end
                end

                albedo_clean_mu0 = albedos.albedo_clean_mu0;
                albedo_observed_mu0 = albedos.albedo_observed_mu0;
                albedo_clean_muZ = albedos.albedo_clean_muZ;
                albedo_observed_muZ = albedos.albedo_observed_muZ;

                save(interpFile, 'albedo_clean_mu0', 'albedo_clean_mu0_divisor', ...
                    'albedo_clean_mu0_units', 'albedo_observed_mu0', ...
                    'albedo_observed_mu0_divisor', 'albedo_observed_mu0_units', ...
                    'albedo_clean_muZ', 'albedo_clean_muZ_divisor', ...
                    'albedo_clean_muZ_units', 'albedo_observed_muZ', ...
                    'albedo_observed_muZ_divisor', 'albedo_observed_muZ_units', ...
                    '-append');
            end

            t2 = toc;
            fprintf('%s: Finished albedos update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
