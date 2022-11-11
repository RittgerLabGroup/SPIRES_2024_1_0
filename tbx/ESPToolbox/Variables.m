classdef Variables
    % Handles the calculations to obtain the variables
    % e.g. snow_cover_days
    properties
        regions         % Regions object, on which the calculations are done
    end

    properties(Constant)
        uint8NoData = cast(255, 'uint8');
        uint16NoData = cast(65535, 'uint16');
        albedoScale = 10000.; % Factor to multiply albedo obtained from
                             % ParBal.spires_albedo
        albedoDeltavisScale = 100.; % Factor for deltavis in albedo_observed
                                    % calculations
        albedoDownscaleFactor = 0.63; % Factor for albedo_clean in albedo_observed
                                      % calculations
        albedoMaxGrainSize = 1999;  % Max grain size accepted to calculate albedo
                                    % spires in parBal package
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

        function calcSnowCoverDays(obj, waterYearDate)
            % Calculates snow cover days from snow_fraction variable
            % and updates the monthly STC cube interpolation data files with the value.
            % Cover days are calculated if elevation and snow cover fraction
            % are above thresholds defined at the Regions level (attribute
            % snowCoverDayMins.
            % Cover days is NaN after the first day (included) without snow fraction data.
            %
            % Called by runSnowTodayStep1.sh \ updateRegionMonthCubes.m \
            % updateSTC_SCAGDRFSFor.m
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object, optional
            %   Date and range of days before over which calculation
            %   should be carried out

            tic;
            fprintf('%s: Start snow_cover_days calculations\n', mfilename());
            % 1. Initialization, elevation data, dates
            %    and collection of units and divisor for
            %    snow_cover_days
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;
            mins = regions.snowCoverDayMins;

            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getMonthlyFirstDatetimeRange();
            numberOfMonths = length(dateRange);

            elevationData = regions.getElevations();

            variables = espEnv.configurationOfVariables();
            snowCoverConf = variables(find( ...
                strcmp(variables.output_name, 'snow_cover_days')), :);
            snow_cover_days_units = snowCoverConf.units_in_map;
            snow_cover_days_divisor = snowCoverConf.divisor;

            snow_cover_days_min_elevation = mins.minElevation;
            snow_cover_days_min_snow_cover_fraction = mins.minSnowCoverFraction;

            % 1. Initial snowCoverDays
            %-------------------------
            % Taken from the day preceding the date range (in the monthly
            % interp data file of the month before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0
            lastSnowCoverDays = 0.;

            if month(dateRange(1)) ~= waterYearDate.waterYearFirstMonth
                dateBefore = daysadd(dateRange(1) , -1);
                STCFile = espEnv.SCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateBefore);

                if isfile(STCFile)
                    STCData = load(STCFile, 'snow_cover_days');
                    fprintf('%s: Loading snow_cover_days from %s\n', ...
                            mfilename(), STCFile);
                    if ~isempty(STCData) && ...
                        any(strcmp(fieldnames(STCData), 'snow_cover_days'))
                        lastSnowCoverDays = STCData.snow_cover_days(:, :, end);
                    else
                        warning('%s: No snow_cover_days variable in %s\n', ...
                            mfilename(), STCFile);
                        lastSnowCoverDays = NaN;
                    end
                else
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        STCFile);
                    lastSnowCoverDays = NaN;
                end
            end

            % 2. Update each monthly interpolated files for the full
            % period by calculating snow_cover_days from snow_fractions
            %----------------------------------------------------------
            for monthDayIdx=1:numberOfMonths
                % 2.a. Loading of the monthly interpolation file
                %-----------------------------------------------
                STCFile = espEnv.SCAGDRFSFile(regions, ...
                    'SCAGDRFSSTC', dateRange(monthDayIdx));

                if ~isfile(STCFile)
                    warning('%s: Missing interpolation file %s\n', mfilename(), ...
                        STCFile);
                    lastSnowCoverDays = NaN;
                    continue;
                end

                STCData = load(STCFile, 'snow_fraction');
                fprintf('%s: Loading snow_fraction from %s\n', ...
                        mfilename(), STCFile);
                if isempty(STCData)
                    warning('%s: No snow_fraction variable in %s\n', ...
                        mfilename(), STCFile);
                    lastSnowCoverDays = NaN;
                    continue;
                end

                snowCoverFraction = STCData.snow_fraction;
                % 2.b. Below a certain elevation and fraction, the pixel is not
                % considered covered by snow
                %--------------------------------------------------------------
                snowCoverFraction(...
                    snowCoverFraction < ...
                    snow_cover_days_min_snow_cover_fraction) = 0;
                snowCoverFraction(...
                    elevationData < snow_cover_days_min_elevation) = 0;

                % 2.c. Cumulated snow cover days calculation and save
                %----------------------------------------------------
                snowCoverFractionWithoutNaN = snowCoverFraction(:, :, :);
                snowCoverFractionWithoutNaN(isnan(snowCoverFraction)) = 0;
                logicalSnowCoverFraction = cast(logical(snowCoverFractionWithoutNaN), ...
                    'single');
                logicalSnowCoverFraction(isnan(snowCoverFraction)) = NaN;
                snow_cover_days = repmat( ...
                    lastSnowCoverDays, 1, 1, ...
                    size(logicalSnowCoverFraction, 3) ...
                    ) + cumsum(logicalSnowCoverFraction, 3);
                lastSnowCoverDays = snow_cover_days(:, :, end);

                save(STCFile, 'snow_cover_days', ...
                    'snow_cover_days_divisor', ...
                    'snow_cover_days_units', ...
                    'snow_cover_days_min_elevation', ...
                    'snow_cover_days_min_snow_cover_fraction', '-append');

            end
            t2 = toc;
            fprintf('%s: Finished snow cover days update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end

        function calcAlbedos(obj, waterYearDate)
            % Calculates clean and observed albedos on flat surface (mu0)
            % and on slopes (muZ) from snow_fraction, solar_zenith, solar_azimuth,
            % grain_size, deltavis, topographic slopes and aspect variables.
            % Updates the daily mosaic data files with the values.
            % Fields calculated: albedo_clean_mu0, albedo_observed_mu0,
            % albedo_clean_muZ, albedo_observed_muZ.
            % Albedos are NaN when snow_fraction or grain_size are NaN.
            %
            % Parameters
            % ----------
            % waterYearDate: WaterYearDate object, optional
            %   Date and range of days before over which calculation
            %   should be carried out

            tic;
            fprintf('%s: Start albedos calculations\n', mfilename())

            % 1. Initialization, dates, slopes, aspects
            %------------------------------------------
            regions = obj.regions;
            espEnv = regions.espEnv;
            modisData = regions.modisData;

            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getDailyDatetimeRange();

            topo = matfile(espEnv.topographyFile(regions));
            slope = topo.S;
            aspect = topo.A;

            albedoNames = {'albedo_clean_mu0'; 'albedo_clean_muZ'; ...
                'albedo_observed_mu0'; 'albedo_observed_muZ'};
            confOfVar = espEnv.configurationOfVariables();                        

            % 2. Update each daily mosaic files for the full
            % period by calculating albedos
            %-----------------------------------------------

            % Start or connect to the local pool (parallelism)
            espEnv.configParallelismPool();

            parfor dateIdx=1:length(dateRange)

                % 2.a collection of albedo types, units, divisors
                %    and min-max.
                %------------------------------------------------
                % NB: could have been set outside loop, but since we use a struct
                % within a parloop, it should stay her so as to not trigger transparency
                % error.

                albedos = struct();
                for albedoIdx=1:length(albedoNames)
                    albedoName = albedoNames{albedoIdx};
                    albedoConf = confOfVar(find( ...
                        strcmp(confOfVar.output_name, albedoName)), :);
                    albedos.([albedoName '_type']) = albedoConf.type{1};
                    albedos.([albedoName '_units']) = albedoConf.units_in_map{1};
                    albedos.([albedoName '_divisor']) = albedoConf.divisor;
                    albedos.([albedoName '_min']) = albedoConf.min * albedoConf.divisor;
                    albedos.([albedoName '_max']) = albedoConf.max * albedoConf.divisor;
                    albedos.([albedoName '_nodata_value']) = albedoConf.nodata_value;
                end

                % 2.b. Loading the daily file
                %      If snow_fraction is 0, set the grain_size
                %      to NaN to get final albedos to NaN
                %-----------------------------------------------
                errorStruct = struct();
                mosaicFile = espEnv.MosaicFile(regions, dateRange(dateIdx));

                if ~isfile(mosaicFile)
                    warning('%s: Missing mosaic file %s\n', mfilename(), ...
                        mosaicFile);
                    continue;
                end

                mosaicData = load(mosaicFile, 'deltavis', 'grain_size', ...
                    'snow_fraction', 'solar_azimuth', 'solar_zenith');
                if isempty(mosaicData)
                    warning('%s: No variables in %s\n', ...
                        mfilename(), mosaicFile);
                    continue;
                end

                mosaicFieldnames = fieldnames(mosaicData);
                for fieldIdx = 1:length(mosaicFieldnames)
                    fieldname = mosaicFieldnames{fieldIdx};
                    if strcmp(fieldname, 'snow_fraction')
                        continue;
                    end
                    mosaicData.(fieldname) = cast(mosaicData.(fieldname), 'double');
                    mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                        Variables.uint8NoData) = NaN;
                end
                fieldname = 'snow_fraction';
                mosaicData.(fieldname) = cast(mosaicData.(fieldname), 'double');
                mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                    Variables.uint8NoData) = NaN;
                    
                fprintf('%s: Loading snow_fraction and other vars from %s\n', ...
                        mfilename(), mosaicFile);

                % 2.c. Calculations of mu0 and muZ (cosinus of solar zenith)
                % considering a flat surface (mu0) or considering slope and
                % aspect (muZ)
                % + cap of grain size to max value accepted by parBal.spires
                % use of ParBal package: .sunslope and .spires_albedo.
                %-----------------------------------------------------------                    
                mu0 = cosd(mosaicData.solar_zenith);

                % phi0: Normalize stored azimuths to expected azimuths
                % stored data is assumed to be -180 to 180 with 0 at North
                % expected data is assumed to be +ccw from South, -180 to 180 
                phi0 = 180. - mosaicData.solar_azimuth;
                phi0(phi0 > 180) = phi0(phi0 > 180) - 360;

                muZ = sunslope(mu0, phi0, slope, aspect);

                grainSizeForSpires = mosaicData.grain_size;
                grainSizeForSpires(grainSizeForSpires > ...
                    obj.albedoMaxGrainSize) = obj.albedoMaxGrainSize;

                % 2.d. Calculations of clean albedos, corrections to
                % obtain observed albedos
                % sanity check min-max, replacement for nodata and
                % recast to type and save
                %---------------------------------------------------
                albedos.albedo_clean_mu0 = spires_albedo(grainSizeForSpires, mu0, ...
                    regions.atmosphericProfile);
                albedos.albedo_clean_muZ = spires_albedo(grainSizeForSpires, muZ, ...
                    regions.atmosphericProfile);

                albedoObservedCorrection = (cast(mosaicData.deltavis, 'double') / ...
                    Variables.albedoDeltavisScale) * ...
                    Variables.albedoDownscaleFactor;

                albedos.albedo_observed_mu0 = albedos.albedo_clean_mu0 - ...
                    albedoObservedCorrection;
                albedos.albedo_observed_muZ = albedos.albedo_clean_muZ - ...
                    albedoObservedCorrection;

                for albedoIdx=1:length(albedoNames)
                    albedoName = albedoNames{albedoIdx};
					albedos.(albedoName) = albedos.(albedoName) * ...
						Variables.albedoScale;
                    albedos.(albedoName)(isnan(mosaicData.grain_size)) = 0;
					albedos.(albedoName) = cast(albedos.(albedoName), ...
                        albedos.([albedoName '_type']));

                    if min(albedos.(albedoName), [], 'all') < albedos.([albedoName '_min']) ...
                    || max(albedos.(albedoName), [], 'all') > albedos.([albedoName '_max'])
                        errorStruct.identifier = 'Variables:RangeError';
                        errorStruct.message = sprintf(...
                            '%s: Calculated %s %s [%.3f,%.3f] out of bounds\n',...
                            mfilename, regions.regionName, ...
                            albedoName, [albedoName '_min'], [albedoName '_max']);
                        error(errorStruct);
                    end
                    albedos.(albedoName)(isnan(mosaicData.grain_size)) = ...
                        albedos.([albedoName '_nodata_value']);
                end

                % 2.e. Save albedos and params in Mosaic Files
                %---------------------------------------------
                Tools.parforSaveFieldsOfStructInFile(mosaicFile, albedos, 'append');
            end

            t2 = toc;
            fprintf('%s: Finished albedos update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
