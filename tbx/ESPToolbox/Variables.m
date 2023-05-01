classdef Variables
    % Handles the calculations to obtain the variables
    % e.g. snow_cover_days
    properties
        region         % Regions object, on which the calculations are done
    end

    properties(Constant)
        uint8NoData = cast(255, 'uint8');
        uint16NoData = cast(65535, 'uint16');
        albedoScale = 100.; % Factor to multiply albedo obtained from
                             % ParBal.spires_albedo
        albedoDeltavisScale = 100.; % Factor for deltavis in albedo_observed
                                    % calculations
        albedoDownscaleFactor = 0.63; % Factor for albedo_clean in albedo_observed
                                      % calculations
        albedoMinGrainSize = 1;  % Min grain size accepted to calculate albedo
                                    % spires in parBal package
        albedoMaxGrainSize = 1999;  % Max grain size accepted to calculate albedo
                                    % spires in parBal package
        dataStatus = ...
            struct(observed = 1, ...
                unavailable = 0, ...
                cloudyOrOther = 10, ...
                highSolarZenith = 20, ...
                lowValue = 30, ...
                notForGeneralPublic = 40, ...
                temporary = 255); % possible values
            % for the viewable_snow_fraction_status variable to indicate 
            % observed and reliable/unobserved/interpolated data.
        dataStatusForNoObservation = [Variables.dataStatus.unavailable, ...
            Variables.dataStatus.cloudyOrOther, ...
            Variables.dataStatus.highSolarZenith]; % Data status values that indicate no 
            % observation, used to calculate days_without_observation.
        highSolarZenith = 67.5; % solar zenith value above which the observed data is
            % considered unreliable.            
    end

    methods
        function obj = Variables(region)
            % Constructor of Variables
            %
            % Parameters
            % ----------
            % region: Regions object
            %   Region on which the variables are handled

            obj.region = region;
        end
        function calcDaysWithoutObservation(obj, waterYearDate)
            % Calculates days_without_observation from snow_fraction_status variable
            % and updates the dailty mosaic data files with the value.
            % By default days_without_observation is 0 starting from the 1st day
            % of the current waterYear and increase over time if there's no data
            % available for the pixel, the data indicate water, clouds, or noise,
            % or solar zenith was too high. days_without_observation goes back to 
            % 0 the day when there's a reliable observation.
            %
            % Called by runSnowTodayStep2.sh \ runUpdateMosaic.sh
            % 
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object, optional
            %   Date and range of days before over which calculation
            %   should be carried out

            % 0. Initialization, dates
            %    and collection of units and divisor
            %---------------------------------------------------------------------------
            tic;
            baseVarName = 'viewable_snow_fraction_status';
            aggregateVarName = 'days_without_observation';
            fprintf('%s: Start %s calculations\n', mfilename(), aggregateVarName);
            
            region = obj.region;
            espEnv = region.espEnv;
            modisData = region.modisData;

            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getDailyDatetimeRange();

            thisVarConf = espEnv.myConf.variable(find( ...
                strcmp(espEnv.myConf.variable.output_name, ...
                    aggregateVarName)), :);
            mosaicData = struct();
            mosaicData.([aggregateVarName '_units']) = thisVarConf.units_in_map{1};
            mosaicData.([aggregateVarName '_divisor']) = thisVarConf.divisor;

            % 1. Initial daysWithoutObservation.
            %---------------------------------------------------------------------------
            % Taken from the day preceding the date range (in the daily
            % modaic data file of the day before), if the date range
            % doesn't begin in the first month of the wateryear
            % else 0.
            lastDaysWithoutObservation = zeros(region.getSizeInPixels(), 'single');
            if dateRange(1) ~= waterYearDate.getFirstDatetimeOfWaterYear()
                thisDatetime = daysadd(dateRange(1) , -1); % date before.
                dataFilePath = espEnv.MosaicFile(region, thisDatetime);
                unavailableDataFlag = false;
                if ~isfile(dataFilePath)
                    unavailableDataFlag = true;
                else
                    data = load(dataFilePath, aggregateVarName);
                    fprintf('%s: Loading %s from %s\n', ...
                            mfilename(), aggregateVarName, dataFilePath);
                    if isempty(data) | ...
                        ~ismember(aggregateVarName, fieldnames(data))
                        unavailableDataFlag = true;
                    else
                        lastDaysWithoutObservation = cast(data.days_without_observation, 'single');
                            % Don't forget that in mosaics type is not single.
                        lastDaysWithoutObservation( ...
                            lastDaysWithoutObservation == thisVarConf.nodata_value) ...
                            = NaN;
                    end
                end
                if unavailableDataFlag
                    warning('%s: Missing file or no %s variable in %s\n', ...
                        mfilename(), aggregateVarName, dataFilePath);
                    lastDaysWithoutObservation = NaN(region.getSizeInPixels(), 'single');
                end
            end

            % 2. Update each daily mosaic file for the full
            % period by calculating days_without_observation from 
            % viewable_snow_fraction_status.
            %---------------------------------------------------------------------------
            for thisDateIdx=1:length(dateRange) % No parfor here.
                % 2.a. Loading of the daily mosaic file
                %-----------------------------------------------
                dataFilePath = espEnv.MosaicFile(region, dateRange(thisDateIdx));

                unavailableDataFlag = false;
                if ~isfile(dataFilePath)
                    unavailableDataFlag = true; 
                else
                    data = load(dataFilePath, baseVarName);
                    fprintf('%s: Loading %s from %s\n', ...
                            mfilename(), baseVarName, dataFilePath);                    
                    if isempty(data) | ...
                        ~ismember(baseVarName, fieldnames(data))
                        unavailableDataFlag = true;
                    end
                end
                if unavailableDataFlag
                    warning(['%s: Stop updating days_without_observation. ', ...
                        'Missing file or no %s variable in %s\n'], ... 
                        mfilename(), baseVarName, dataFilePath);
                    break;
                else
                    % 2.b. If viewable_snow_fraction_status equals certain values,
                    % the pixel doesn't have reliable observations and was interpolated.
                    % Therefore we increase the counter of days without observations
                    % otherwise we reset it to zero.
                    %-----------------------------------------------------------------------
                    isObserved = ~ismember(data.(baseVarName), ...
                        obj.dataStatusForNoObservation);
                    lastDaysWithoutObservation(isObserved) = 0;
                    lastDaysWithoutObservation(~isObserved) = ...
                        lastDaysWithoutObservation(~isObserved) + 1;
                end
                lastDaysWithoutObservation(isnan(lastDaysWithoutObservation)) = ...
                    thisVarConf.nodata_value;
                mosaicData.(aggregateVarName) = cast(lastDaysWithoutObservation, ...
                    thisVarConf.type_in_mosaics{1});
                mosaicData.data_status_for_no_observation = obj.dataStatusForNoObservation;
                save(dataFilePath, '-struct', 'mosaicData', '-append');
                fprintf('%s: Saved %s to %s\n', mfilename(), ...
                    aggregateVarName, dataFilePath);
            end
            t2 = toc;
            fprintf('%s: Finished %s update in %s seconds\n', ...
                mfilename(), aggregateVarName, ...
                num2str(roundn(t2, -2)));
        end
        function calcSnowCoverDays(obj, waterYearDate)
            % Calculates snow cover days from snow_fraction variable
            % and updates the monthly STC cube interpolation data files with the value.
            % Cover days are calculated if elevation and snow cover fraction
            % are above thresholds defined at the Region level (attribute
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
            region = obj.region;
            espEnv = region.espEnv;
            modisData = region.modisData;
            mins = region.snowCoverDayMins;

            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getMonthlyFirstDatetimeRange();
            numberOfMonths = length(dateRange);

            elevationData = region.getElevations();

            snowCoverConf = espEnv.myConf.variable(find( ...
                strcmp(espEnv.myConf.variable.output_name, 'snow_cover_days')), :);
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
                STCFile = espEnv.SCAGDRFSFile(region, ...
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
                STCFile = espEnv.SCAGDRFSFile(region, ...
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

                snowCoverFraction = STCData.snow_fraction; % type 'single' in STCCubde
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
                fprintf('%s: Saved snow_cover_days to %s\n', mfilename(), ...
                    STCFile);
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
            region = obj.region;
            espEnv = region.espEnv;
            modisData = region.modisData;

            if ~exist('waterYearDate', 'var')
                waterYearDate = WaterYearDate();
            end
            dateRange = waterYearDate.getDailyDatetimeRange();

            topo = matfile(espEnv.topographyFile(region));
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
                % If snow_fraction is 0 or NaN, set the variables
                %  to NaN to get final albedos to NaN
                % convert all variables to double (and NaN) for
                % parBal package
                % Since Mosaic files are stored as int and the ParBal functions
                % use floats as input arguments, we 
                % 1. cast the Mosaic data to the float type and 
                %    replace no_data_value by NaNs, 
                % 2. use the ParBal functions, and then
                % 3. replace the albedo NaNs by no_data_value and cast 
                %    the albedos to integers.
                %----------------------------------------------
                errorStruct = struct();
                mosaicFile = espEnv.MosaicFile(region, dateRange(dateIdx));

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
                nans = zeros(size(mosaicData.snow_fraction), 'uint8');
                for fieldIdx = 1:length(mosaicFieldnames)
                    fieldname = mosaicFieldnames{fieldIdx};
                    mosaicData.(fieldname) = cast(mosaicData.(fieldname), 'double');
                    if strcmp(fieldname, 'snow_fraction')
                        continue;
                    end                    
                    varInfos = confOfVar(find( ...
                        strcmp(confOfVar.output_name, fieldname)), :);                                        
                    nans = nans | mosaicData.(fieldname) == varInfos.nodata_value;
                    mosaicData.(fieldname)(mosaicData.(fieldname) == ...
                        varInfos.nodata_value) = NaN;
                    mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                        Variables.uint8NoData | mosaicData.snow_fraction == 0) = NaN;
                end
                % Set to NaN of snow_fraction should be done after the other variables.
                fieldname = 'snow_fraction';
                varInfos = confOfVar(find( ...
                        strcmp(confOfVar.output_name, fieldname)), :);
                nans = nans | mosaicData.(fieldname) == varInfos.nodata_value;
                mosaicData.(fieldname)(mosaicData.snow_fraction == ...
                    Variables.uint8NoData | mosaicData.snow_fraction == 0) = NaN;

                fprintf('%s: Loading snow_fraction and other vars from %s\n', ...
                        mfilename(), mosaicFile);

                % 2.c. Calculations of mu0 and muZ (cosinus of solar zenith)
                % considering a flat surface (mu0) or considering slope and
                % aspect (muZ)
                % + cap of grain size to max value accepted by parBal.spires
                % use of ParBal package: .sunslope and .spires_albedo.
                % spires_albedo needs no data values to be NaNs
                %----------------------------------------------------------- 
                mu0 = cosd(mosaicData.solar_zenith);
                mu0(nans) = NaN;

                % phi0: Normalize stored azimuths to expected azimuths
                % stored data is assumed to be -180 to 180 with 0 at North
                % expected data is assumed to be +ccw from South, -180 to 180
                phi0 = 180. - mosaicData.solar_azimuth;
                phi0(phi0 > 180) = phi0(phi0 > 180) - 360;
                phi0(nans) = NaN;

                muZ = sunslope(mu0, phi0, slope, aspect);

                grainSizeForSpires = mosaicData.grain_size;
                grainSizeForSpires(grainSizeForSpires > ...
                    obj.albedoMaxGrainSize) = obj.albedoMaxGrainSize;
                grainSizeForSpires(grainSizeForSpires < ...
                    obj.albedoMinGrainSize) = obj.albedoMinGrainSize;

                % 2.d. Calculations of clean albedos, corrections to
                % obtain observed albedos
                % sanity check min-max, replacement for nodata and
                % recast to type and save
                %---------------------------------------------------
                albedos.albedo_clean_mu0 = spires_albedo(...
                    grainSizeForSpires, mu0, ...
                    region.atmosphericProfile);
                albedos.albedo_clean_muZ = spires_albedo(...
                    grainSizeForSpires, muZ, ...
                    region.atmosphericProfile);

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
						Variables.albedoScale * albedoConf.divisor;

                    if min(albedos.(albedoName), [], 'all') < albedos.([albedoName '_min']) ...
                    || max(albedos.(albedoName), [], 'all') > albedos.([albedoName '_max'])
                        errorStruct.identifier = 'Variables:RangeError';
                        errorStruct.message = sprintf(...
                            '%s: Calculated %s %s [%.3f,%.3f] out of bounds\n',...
                            mfilename, region.regionName, ...
                            albedoName, [albedoName '_min'], [albedoName '_max']);
                        error(errorStruct);
                    end
                    albedos.(albedoName)(isnan(albedos.(albedoName))) = ...
                        albedos.([albedoName '_nodata_value']);
                    albedos.(albedoName) = cast(albedos.(albedoName), ...
                        albedos.([albedoName '_type']));
                end

                % 2.e. Save albedos and params in Mosaic Files
                %---------------------------------------------
                Tools.parforSaveFieldsOfStructInFile(mosaicFile, albedos, 'append');
                fprintf('%s: Saved albedo to %s\n', mfilename(), ...
                    mosaicFile);
            end

            t2 = toc;
            fprintf('%s: Finished albedos update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
