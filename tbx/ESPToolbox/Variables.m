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
        %
        % Calculates snow cover days from snow_fraction variable
        % and updates the mosaic data files with the value.
        % Cover days are calculated if elevation and snow cover fraction
        % are above thresholds defined at the Regions level (attribute
        % snowCoverDayMins.
        % Cover days doesn't include the days without mosaic data.
        %
        % Parameters
        % ----------
        % espDate: ESPDate object, optional
        %   Date and range of days before over which calculation
        %   should be carried out

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
            dateRange = espDate.getDateNumRangeForCalculations();
            numberOfDays = length(dateRange);

            elevationFile = espEnv.modisElevationFile(regions.regionName);
            elevationData = load(elevationFile, 'Z');

            % 2. Get a list of mosaic files for the full period and load
            % snowCoverFractions for each of them
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            snowCoverFraction = zeros(cat(2, ...
                regions.countOfRowsAndColumns, numberOfDays)); %, 'uint8');
            mosaicFiles = strings(regions.countOfRowsAndColumns);
            % Start or connect to the local pool (parallelism)            
            Parallelism.configParallelismPool(espEnv);
            tic;
            parfor d=1:numberOfDays
                % Loading of the daily mosaic
                mosaicFile = espEnv.DailyMosaicFile(regions, ...
                    dateRange(d));

                % Warning if a date is missing else adding the filename
                % to the list of mosaicFiles.
                if ~isfile(mosaicFile)
                    fprintf('%s: Missing mosaic file %s\n', mfilename(), ...
                        mosaicFile);
                    continue;
                else
                    mosaicFiles(d) = mosaicFile;
                end
                snowCoverFraction(:, :, d) = cell2mat(struct2cell(load(mosaicFile, ...
                    'snow_fraction')));
                fprintf('%s: Loading snow_fraction from %s\n', ...
                    mfilename(), mosaicFile);
            end
            t1 = toc;
            fprintf(strcat('%s: Loaded snow cover fraction for %s mosaic files up', ...
                'to %s in %s seconds\n'), ...
                mfilename(), numberOfDays, ...
                datestr(espDate.thisDatetime, 'yyyy-mm-dd'), ...
                num2str(roundn(t1, -2)));

            % 3. Initial snowCoverDays
            %%%%%%%%%%%%%%%%%%%%%%%%%%
            % Taken from the day preceding the date range, if the date range
            % doesn't begin in the first month of the wateryear
            % else 0
            snowCoverDays = zeros(regions.countOfRowsAndColumns);

            if month(dateRange(1)) ~= ESPDate.waterYearFirstMonth
                mosaicFile = espEnv.DailyMosaicFile(regions, ...
                    daysadd(dateRange(1) , -1));

                % Warning if a date is missing
                if ~isfile(mosaicFile)
                   fprintf('%s: Missing mosaic file %s\n', mfilename(), ...
                        mosaicFile);
                else
                    matrix = cell2mat(struct2cell(load(mosaicFile, ...
                        'snow_cover_days')));
                    if ~isempty(matrix)
                        snowCoverDays = matrix
                        fprintf('%s: Loading snow_fraction from %s\n', ...
                            mfilename(), mosaicFile);
                    else
                        fprintf('%s: No snow_fraction variable in %s\n', ...
                            mfilename(), mosaicFile);
                    end
                end
            end

            % 4. Below a certain elevation and fraction, the pixel is not
            % considered covered by snow
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            snowCoverFraction(snowCoverFraction < mins.minSnowCoverFraction) = 0;
            snowCoverFraction(elevationData.Z < mins.minElevation) = 0;

            % 5. Cumulated snow cover days calculation and save
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            snow_cover_units = 'days';
            snow_cover_divisor = 1;
            tic;
            for d=1:numberOfDays
                if mosaicFiles(d) ~= ""
                    snowCoverDays = snowCoverDays + ...
                        logical(snowCoverFraction(:, :, d));
                    snow_cover_days = snowCoverDays;
                    save(mosaicFiles(d), 'snow_cover_days', 'snow_cover_units', ...
                        'snow_cover_divisor', '-append');
                end
            end
            t2 = toc;
            fprintf('%s: Finished snow cover days update in %s seconds\n', ...
                mfilename(), ...
                num2str(roundn(t2, -2)));
        end
    end
end
