classdef ESPEnv
    % ESPEnv - environment for ESP data dirs and algorithms
    %   Directories with locations of various types of data needed for ESP
    properties
        colormapDir    % directory with color maps
        mappingDir     % directory with MODIS tiles projection information
        shapefileDir     % directory with MODIS tiles projection information
        extentDir      % directory with geographic extent definitions
        confDir         % directory with configuration files (including variable names)
        regionMaskDir  % directory with region mask ids files
        heightmaskDir  % directory heightmask for Landsat canopy corrections
        MODISDir       % directory with MODIS scag STC cubes from UCSB (.mat)
        LandsatDir     % directory with Landsat scag images
        LandsatResampledDir % directory with resample Landsat images
        viirsDir       % directory with TBD for VIIRS
        watermaskDir   % directory with water mask
        modisWatermaskDir   % directory with MODIS watermask files
        modisForestDir      % directory with MODIS canopy corrections
        modisElevationDir   % directory with MODIS DEMs
        modisTopographyDir  % directory with MODIS topography files
        MODICEDir      % directory with (annual) MODICE data
             % by tile/year (.hdr/.dat, .tif)
        dirWith % struct with various STC pipeline directories
        parallelismConf   % struct with parameters for parallelism
        myConfigurationOfVariables  % Table storing the parameters for each variable
            % at different steps of the process Step1, Step2, etc ...
    end
    methods
        function obj = ESPEnv(varargin)
            % The ESPEnv constructor initializes all directory settings
            % based on locale

            p = inputParser;

            % User's scratch locale is default, because it is fast
            defaultHostName = 'CURCScratchAlpine';
            validHostNames = {'CURC', 'CURCScratchAlpine'};
            checkHostName = @(x) any(validatestring(x, validHostNames));
            addOptional(p, 'hostName', defaultHostName, ...
            checkHostName);

            p.KeepUnmatched = false;
            parse(p, varargin{:});

            if contains(p.Results.hostName, 'CURC')
                % Default path is relative to this file, 2 levels up
                [path, ~, ~] = fileparts(mfilename('fullpath'));
                parts = split(path, filesep);

                % 1 level up
                path = join(parts(1:end-1), filesep);

                obj.colormapDir = fullfile(path, 'colormaps');
                obj.mappingDir = fullfile(path, 'mapping');
                obj.extentDir = fullfile(path, 'StudyExtents');
                obj.confDir = fullfile(path, 'conf');

                % For top-level stuff, paths are on PetaLibrary
                path = fullfile('/pl', 'active', 'rittger_esp');
                obj.MODISDir = fullfile(path, 'scag', 'MODIS', 'SSN', 'v01');

                obj.viirsDir = fullfile(path, 'viirs');
                obj.watermaskDir = fullfile(path, 'landcover', 'NLCD_ucsb');
                obj.LandsatDir = fullfile(path, 'Landsat_test');
                obj.LandsatResampledDir = fullfile(path, ...
                'Landsat_test', 'Landsat8_resampled');
                obj.heightmaskDir = fullfile(path, ...
                'SierraBighorn', 'landcover', 'LandFireEVH_ucsb');
                obj.MODICEDir = fullfile(path, 'modis', 'modice');

                % For ESP pipelines, set scratch locations
                if strcmp(p.Results.hostName, 'CURCScratchAlpine')
                    path = fullfile('/scratch', 'alpine', ...
                        getenv('USER'), 'modis_ancillary');
                end

                obj.modisWatermaskDir = fullfile(path, 'landcover');
                obj.modisForestDir = fullfile(path, 'forest_height');
                obj.modisElevationDir = fullfile(path, 'elevation');
                obj.modisTopographyDir = fullfile(path, 'topography');
                obj.shapefileDir = fullfile(path, 'shapefiles');
                obj.regionMaskDir = fullfile(path, 'region_masks', 'v3');

                % For ESP pipelines, set scratch locations
                if strcmp(p.Results.hostName, 'CURCScratchAlpine')
                    path = fullfile('/scratch', 'alpine', ...
                        getenv('USER'), 'modis');
                else
                    path = fullfile(path, 'modis');
                end

                % In practice, these directories will be
                % appended with labels from MODISData class
                obj.dirWith = struct(...
                    'MOD09Raw', fullfile(path, 'intermediary', 'mod09_raw'), ...
                    'SCAGDRFSRaw', fullfile(path, 'intermediary', 'scagdrfs_raw'), ...
                    'SCAGDRFSGap', fullfile(path, 'intermediary', 'scagdrfs_gap'), ...
                    'SCAGDRFSSTC', fullfile(path, 'intermediary', 'scagdrfs_stc'), ...
                    'VariablesMatlab', fullfile(path, 'variables', 'scagdrfs_mat'), ...
                    'VariablesGeotiff', fullfile(path, 'variables', 'scagdrfs_geotiff'), ...
                    'RegionalStatsMatlab', fullfile(path, 'regional_stats', ...
                    'scagdrfs_mat'), ...
                    'RegionalStatsCsv', fullfile(path, 'regional_stats', ...
                    'scagdrfs_csv'), ...
                    'publicFTP', ...
                    fullfile('/pl', 'active', 'rittger_esp_public', ...
                    'snow-today'));

            else
                fprintf(['%s: Unrecognized host=%s, ' ...
                    'cannot set expected paths\n'], ...
                    mfilename(), p.Results.hostName);
            end

            % Convert these from 1x1 cells to plain char arrays
            props = properties(obj);
            for i = 1:length(props)
                if iscell(obj.(props{i}))
                    obj.(props{i}) = obj.(props{i}){1};
                end
            end

            obj.parallelismConf.maxWorkers = 20;

            % Set JobStorageLocation to something that will be
            % unique for each slurm process id and put it on
            % local scratch so ~/.matlab/ doesn't grow indefinitely
	    % Normally I would expect a non-empty SLURM_SCRATCH
	    % to exist, but apparently randomly this is not the case.
            if ~isempty(getenv('SLURM_SCRATCH')) & ...
	       isfolder(getenv('SLURM_SCRATCH')) & ...
                ~isempty(getenv('SLURM_ARRAY_JOB_ID'))
                obj.parallelismConf.jobStorageLocation = ...
                    fullfile(getenv('SLURM_SCRATCH'), ...
                    getenv('SLURM_ARRAY_JOB_ID'));
                if ~isfolder(obj.parallelismConf.jobStorageLocation)
                    mkdir(obj.parallelismConf.jobStorageLocation)
                end
            % if not in a job, but still on a linux machine
            elseif ~isempty(getenv('TMPDIR'))
                obj.parallelismConf.jobStorageLocation = getenv('TMPDIR');
            % if Windows machine
            else
                obj.parallelismConf.jobStorageLocation = getenv('TMP');
            end

            obj.myConfigurationOfVariables = obj.configurationOfVariables();
        end

        function S = configParallelismPool(obj, maxWorkers)
            % Configures the pool allowing to parallelize tasks.
            %
            % Parameters
            % ----------
            % maxWorkers: max number of workers (default is 
            %   obj.parallelismConf.maxWorkers)
            %   jobStorageLocation: alternative location for job
            %    storage information, default is
            %    ~/.matlab/local_cluster_jobs/R2019b/
            %    use this to customize locations in SLURM jobs, e.g.
            %    fullfile(getenv('SLURM_SCRATCH'), getenv('SLURM_ARRAY_JOB_ID'));
            %
            % Return
            % ------
            % S: struct.
            %   info about the pool.

            if ~exist('maxWorkers', 'var') | isnan(maxWorkers)
                maxWorkers = obj.parallelismConf.maxWorkers;
            end
            jobStorageLocation = obj.parallelismConf.jobStorageLocation;

            S.pool = gcp('nocreate');

            % Use a running pool only if it doesn't use the maxWorkers, else
            % shut it down.
            if ~isempty(S.pool)
                if maxWorkers == 0
                    maxWorkers = S.pool.NumWorkers;
                elseif S.pool.NumWorkers > maxWorkers
                    delete(S.pool);
                    S.pool = gcp('nocreate');
                end
            end

            % If no pool (or previous pool shut down), create a new pool.
            if isempty(S.pool)
                S.cluster = parcluster('local');
                S.cluster.JobStorageLocation = jobStorageLocation;
                if maxWorkers == 0 | maxWorkers > S.cluster.NumWorkers
                    maxWorkers = S.cluster.NumWorkers;
                end
                S.pool = parpool(S.cluster, maxWorkers);
                S.cluster.disp();
            end
            S.pool.disp();
        end

        function f = LandsatScagDirs(obj, platform, path, row, varargin)
            % LandsatFile returns list of Landsat scag directories for platform/path/row
            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.LandsatDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            platformStr = sprintf('Landsat%1i', platform);
            pathRowStr = sprintf('p%03ir%03i', path, row);

            f = dir(fullfile(myDir, ...
                platformStr, ...
                pathRowStr, ...
                'LC*'));
        end

        function f = MODISFile(obj, varargin)
            % MODISFile returns a list of MODIS STC cube files
            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.MODISDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            f = dir(fullfile(myDir, '*_*Y*.mat'));
        end
        
        function f = MOD09File(obj, MData, regionName, yr, mm)
            % MOD09File returns the name of a monthly MOD09 cubefile
            % if versionOf value is not empty, use underscore separator
            if ~isempty(MData.versionOf.MOD09Raw)
                sepChar = '_';
            else
                sepChar = '';
            end
            myDir = sprintf('%s%s%s', obj.dirWith.MOD09Raw, sepChar, ...
            MData.versionOf.MOD09Raw);

            %TODO: make this an optional input
            platformName = 'Terra';
            yyyymm = sprintf('%04d%02d', yr, mm);

            f = fullfile(myDir, ...
                sprintf('v%03d', MData.versionOf.MODISCollection), ...
                sprintf('%s', regionName), ...
                sprintf('%04d', yr), ...
                sprintf('RawMOD09_%s_%s_%s.mat', ...
                platformName, regionName, yyyymm));
        end

        function f = MODICEFile(obj, version, tileID, ...
            yr, nstrikes, fileType, varargin)

            % MODICEFile returns the name of an annual MODICE tile
            % fileType is one of: 'hdr', 'merged.ice.tif',
            % 'modice_last_update.dat'or 'modice_persistent_ice.dat'
            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.MODICEDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            yrStr = sprintf('%04d', yr);
            vStr = sprintf('v%03.1f', version);
            strikeStr = sprintf('%1dstrike', nstrikes);

            f = fullfile(myDir, ...
                vStr, ...
                tileID, ...
                yrStr, ...
                sprintf('MODICE.%s.%s.%s.%s.%s', ...
                vStr, tileID, yrStr, strikeStr, fileType));
        end

        function f = SCAGDRFSFile(obj, regions, ...
            fileType, thisDatetime)
            % SCAGDRFSFile returns the name of a monthly filetype
            % SCAGDRFS cube
            % fileType should be one of obj.dirWith 'SCAGDRFS*' cubes:
            %   SCAGDRFSRaw
            %   SCAGDRFSGap
            %   SCAGDRFSSTC
            %
            % Directory creation if dir doesn't exist
            modisData = regions.modisData;
            regionName = regions.regionName;

            % if versionOf value is not empty, use underscore separator
            if ~isempty(modisData.versionOf.(fileType))
                sepChar = '_';
            else
                sepChar = '';
            end
            myDir = sprintf('%s%s%s', obj.dirWith.(fileType), sepChar, ...
                modisData.versionOf.(fileType));

            % use versionOf value for file labelName
            % if it is not empty, prepend a period
            labelName = modisData.versionOf.(fileType);
            if ~isempty(labelName)
                labelName = sprintf('.%s', labelName);
            end

            %TODO: make this an optional input
            platformName = 'Terra';

            prefix = struct('SCAGDRFSRaw', 'Raw', ...
                'SCAGDRFSGap', 'Gap', ...
                'SCAGDRFSSTC', 'Interp');

            f = fullfile(myDir, ...
                sprintf('v%03d', modisData.versionOf.MODISCollection), ...
                sprintf('%s', regionName), ...
                datestr(thisDatetime, 'yyyy'));
            if ~exist(f, 'dir')
                mkdir(f);
            end    

            f = fullfile(f, ...
                sprintf('%sSCAG_%s_%s_%s%s.mat', ...
                prefix.(fileType), platformName, ...
                regionName, ...
                datestr(thisDatetime, 'yyyymm'), labelName));
        end

        function f = MosaicFile(obj, regions, thisDatetime)
            % Provides the filename of the daily mosaic data file with
            % directory creation if dir doesn't exist
            % 
            modisData = regions.modisData;
            myDir = sprintf('%s_%s', obj.dirWith.VariablesMatlab, ...
                modisData.versionOf.VariablesMatlab);

            %TODO: make this an optional input
            platformName = 'Terra';

            % use versionOf value for file labelName
            % if it is not empty, prepend a period
            labelName = modisData.versionOf.VariablesMatlab;
            if ~isempty(labelName)
                labelName = sprintf('.%s', labelName);
            end

            f = fullfile(myDir, ...
                sprintf('v%03d', modisData.versionOf.MODISCollection), ...
                sprintf('%s', regions.regionName), ...
                datestr(thisDatetime, 'yyyy'));
            if ~exist(f, 'dir')
                mkdir(f);
            end
            f = fullfile(f, ...
                sprintf('%s_%s_%s%s.mat', ...
                regions.regionName, platformName, ...
                datestr(thisDatetime, 'yyyymmdd'), labelName));
        end

        function filename = Step0ModisFilename(obj, region, myDate, varName)
            % Parameters
            % ----------
            % source: char. 
            %   JPL source of the file: 'mod09ga', 'moddrfs', 'modscag'.
            % modisData: MODISData object.
            % region: Regions object. 
            %   Should be a tile region since JPL files are received only for tiles. 
            %   E.g. region of 'h08v04' tile.
            % myDate: datetime.
            % varName: char.
            %   Name of the variable. E.g. 'snow_fraction'.
            %
            % Return
            % ------
            % Full filename of the daily file received from JPL for the tile and 
            %   variable, accessible from the /scratch/alpine/user directory.
            %   If the file has not been received or doesn't exist, return ''
            modisData = region.modisData;
            regionName = region.regionName;
            varConf = obj.myConfigurationOfVariables(find( ...
                strcmp(obj.myConfigurationOfVariables.output_name, varName)), :);
            if ~strcmp(varName, 'mod09ga')
                sourceVarName = [varConf.modis_source_name{1} '.dat'];
                source = varConf.modis_source{1};
            else % hdf mod09GA files having reflectance and solar data
                sourceVarName = 'hdf';
                source = 'mod09ga';
            end
            historicFolderName = 'historic';
            if myDate >= modisData.startDatetimeWhenNrtReceived
                historicFolderName = 'NRT';
            end

            directory = fullfile(modisData.alternateDir, source, historicFolderName, ...
                sprintf('v%03d', modisData.versionOf.MODISCollection), ...
                regionName, sprintf('%04d', year(myDate)));
            searchFilename = sprintf('MOD09GA.A%04d%03d.%s.*.*.%s', ...
                    year(myDate), day(myDate, 'dayofyear'), regionName, ...
                    sourceVarName);
            fileStruct = dir(fullfile(directory, searchFilename));
            if isempty(fileStruct)
                filename = '';
            else
                filename = fullfile(directory, fileStruct(end).name);
            end                
        end

        function f = SummarySnowFile(obj, region, startYr, stopYr)
            % SummarySnowFile returns the name of statistics summary file
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsMatlab, ...
                region.modisData.versionOf.RegionalStatsMatlab);

            f = fullfile(myDir, ...
                sprintf('v%03d', region.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
                sprintf('%04d_to_%04d_%sby%s_Summary.mat', ...
                startYr, stopYr, region.regionName, ...
                region.maskName));
        end

        function f = SummaryCsvDir(obj, region, waterYearDate)
            % SummaryCsvDir returns the dir with csv versions of statistics summary file
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsCsv, ...
                region.modisData.versionOf.RegionalStatsCsv);

            f = fullfile(myDir, ...
                sprintf('v%03d', region.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
		sprintf('WY%04d', waterYearDate.getWaterYear()));
        end

        function f = SummaryCsvFile(obj, region, subRegionIdx, outDir, varName, waterYear)
	    % This filename for csv stats summary files is expected by the front-end
	    fileName = sprintf('SnowToday_%s_%s_WY%04d_yearToDate.csv', ...
                region.ShortName{subRegionIdx}, varName, waterYear);                	       
            f = fullfile(outDir, fileName);
        end

        function f = SnowTodayGeotiffDir(obj, region)

            myDir = sprintf('%s_%s', obj.dirWith.VariablesGeotiff, ...
                region.modisData.versionOf.VariablesGeotiff);

            f = fullfile(myDir, ...
                sprintf('v%03d', region.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
                sprintf('EPSG_%d', region.geotiffEPSG), ...
                region.geotiffCompression);

        end

        function f = SnowTodayGeotiffFile(obj, region, outDir, platformName, ...
	    thisDatetime, varName)
	    % This filename for geotiffs is expected by the front-end
	    fileName = sprintf('%s_%s_%s_%s.tif', ...
                region.regionName, platformName, datestr(thisDatetime, 'yyyymmdd'), ...
                varName);                	       
            f = fullfile(outDir, fileName);
        end

        function f = SnowTodayFile(obj, MData, ...
            regionName, ...
            shortName, ...
            inputDt, creationDt, labelName)
            % SnowTodayFile returns the name of a Snow Today
            % map or plot .png file -- this is really obsolete
            % maybe need to keep it for the Geotiffs?  but
            % there should be a method for the geotiffs files
            myDir = sprintf('%s_%s', obj.dirWith.VariablesMatlab, ...
                MData.versionOf.VariablesMatlab);

            f = fullfile(myDir, ...
                sprintf('v%03d', MData.versionOf.MODISCollection), ...
                sprintf('%s_SnowToday', regionName), ...
                shortName, ...
                sprintf('%sinputs_createdOn%s_%s_%s.png', ...
                datestr(inputDt, 'yyyymmdd'), ...
                datestr(creationDt, 'yyyymmdd'), ...
                shortName, ...
                labelName));
        end

        function [files, haveDaysPerMonth, expectedDaysPerMonth] = ...
            rawFilesFor3months(obj, MData, regionName, yr, mm, monthPosition)
            % RawFilesFor3months returns MOD09/SCAGDRFS cubes surrounding
            % this month

            regions = Regions(regionName, [regionName '_mask'], obj, MData);

            thisMonthDt = datetime(yr, mm, 1);

	    if strcmp(monthPosition, 'centered')

                % Look for cubes for previous and subsequent month
		priorMonthDt = thisMonthDt - calmonths(1:1);
		nextMonthDt = thisMonthDt + calmonths(1:1);
		Dts = [priorMonthDt, thisMonthDt, nextMonthDt];

	    elseif strcmp(monthPosition, 'trailing')

                % Look for cubes for 2 previous months 
		% (make thisMonth the "trailing" month)
		priorMonth2Dt = thisMonthDt - (2 * calmonths(1:1));
		priorMonth1Dt = thisMonthDt - calmonths(1:1);
		Dts = [priorMonth2Dt, priorMonth1Dt, thisMonthDt];

	    else
                errorStruct.identifier = ...
                    'rawFilesFor3months:InvalidMonthPosition';
                errorStruct.message = sprintf( ...
                    ['%s: invalid monthPosition=%s, ' ...
	             'should be centered or training.'], ...
		    mfilename(), monthPosition);
                error(errorStruct);
	    end
            fprintf('%s: %s: monthPosition=%s\n', ...
                mfilename(), datestr(thisMonthDt), monthPosition);

            nMonths = length(Dts);
            expectedDaysPerMonth = zeros(nMonths, 1);
            haveDaysPerMonth = zeros(nMonths, 1);
            files = {};
            nextIndex = 1;
            for i=1:nMonths

                thisYYYY = year(Dts(i));
                thisMM = month(Dts(i));
                yyyymm = sprintf('%04d%02d', thisYYYY, thisMM);

                % Save the expected number of days in this month
                expectedDaysPerMonth(i) = eomday(thisYYYY, thisMM);

                % Look for Raw cubes for this month
                mod09file = obj.MOD09File(MData, regionName, thisYYYY, thisMM);
                scagfile = obj.SCAGDRFSFile(regions, ...
                    'SCAGDRFSRaw', datetime(thisYYYY, thisMM, 1));

                if ~isfile(mod09file) || ~isfile(scagfile)

                    % Other months might be missing, but
                    % there must be cubes for this month to continue
                    if thisMonthDt == Dts(i)
                        errorStruct.identifier = ...
                            'rawFilesFor3months:NoDataForRequestedMonth';
                        errorStruct.message = sprintf( ...
                            '%s: %s MOD09 and/or SCAGDRFS cubes missing.', ...
                            mfilename(), yyyymm);
                        error(errorStruct);
                    else
                        fprintf(['%s: %s: No MOD09 or SCAGDRFS cubes ' ...
                        'for adjacent month %s\n'], ...
                        mfilename(), datestr(thisMonthDt), yyyymm);
                        continue;
                    end
                end

                % Get actual number of days in this month with data
                mdata = load(mod09file, 'umdays');
                sdata = load(scagfile, 'usdays');
                nMOD09days = length(mdata.umdays);
                nSCAGdays = length(sdata.usdays);
                if nMOD09days ~= nSCAGdays
                    errorStruct.identifier = ...
                        'rawFilesFor3months:ArchiveError';
                    errorStruct.message = sprintf( ...
                        '%s: %s umdays=%d ~= usdays=%d.', ...
                        mfilename(), yyyymm, nMOD09days, nSCAGdays);
                    error(errorStruct);
                end

                haveDaysPerMonth(i) = nSCAGdays;

                files.MOD09{nextIndex} = mod09file;
                files.SCAGDRFS{nextIndex} = scagfile;
                nextIndex = nextIndex + 1;
            end
        end

        function f = geotiffFile(~, extentName, platformName, sensorName, ...
        baseName, varName, version)
            % builds a geoTiff file name based on the input values

            if (regexpi(platformName, 'Landsat'))
                f = sprintf('%s.%s.%s.v%02d.tif', ...
                    extentName, ...
                    baseName, ...
                    varName, ...
                    version);
            else
                if strcmp(platformName, '')
                    switch sensorName
                        case 'MODIS'
                            platformName = 'Terra';
                        otherwise
                            error("%s: Unknown sensorName=%s", ...
                                mfilename(), sensorName);
                    end
                end

                f = sprintf('%s.%s.%s-%s.%s.v%02d.tif', ...
                    extentName, baseName, ...
                    platformName, sensorName, varName, ...
                    version);
            end
        end

        function m = colormap(obj, colormapName, varargin)
            % colormap reads and returns the color map from the given file

            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.colormapDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            f = dir(fullfile(myDir, ...
                sprintf('%s.mat', colormapName)));
            m = load(fullfile(f.folder, f.name));
        end

        function f = watermaskFile(obj, path, row, varargin)
            % watermaskFile returns a list of water mask file for the given
            % path/row

            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            % fullfile requires char vectors, not modern Strings
            optargs = {obj.watermaskDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            f = dir(fullfile(myDir, ...
                sprintf('p%03ir%03i_water.tif', path, row)));
        end

        function f = heightmaskFile(obj)
            % heightmaskFile returns the current height mask file name

            f = dir(fullfile(obj.heightmaskDir, ...
            'Sierra_utm_LandFire_EVH_gt2.5m_mask.tif'));
        end

        function s = heightmask(obj)
            % heightmask reads and returns the height mask

            f = obj.heightmaskFile();
            s.mask = readgeoraster(fullfile(f.folder, f.name));
            s.info = geotiffinfo(fullfile(f.folder, f.name));
        end

        function f = modisForestHeightFile(obj, regionName, varargin)
            % modisForestHeighFile returns forest height file for regionName

            numvarargs = length(varargin);
            if numvarargs > 1
            error('%s:TooManyInputs, ', ...
            'requires at most 1 optional inputs', mfilename());
            end

            % fullfile requires char vectors, not modern Strings
            optargs = {obj.modisForestDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            f = dir(fullfile(myDir, ...
            sprintf('%s_CanopyHeight.mat', ...
            regionName)));

            if length(f) ~= 1
                errorStruct.identifier = ...
                    'MODISData_modisForesstHeightFile:FileError';
                errorStruct.message = sprintf( ...
                    ['%s: Unexpected forest height files found ' ...
                    'for %s at %s'], ...
                    mfilename(), regionName, myDir);
                error(errorStruct);
            end

            f = fullfile(f(1).folder, f(1).name);
        end

        function f = modisWatermaskFile(obj, regionName, varargin)
            % modisWatermaskFile returns water mask file for the regionName

            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            % fullfile requires char vectors, not modern Strings
            optargs = {obj.modisWatermaskDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            %TODO: what does the 50 stand for in these filenames?
            f = dir(fullfile(myDir, ...
                sprintf('%s_MOD44_50_watermask_463m_sinusoidal.mat', ...
                regionName)));

            if length(f) ~= 1
                errorStruct.identifier = ...
                    'MODISData_modisWatermaskFile:FileError';
                errorStruct.message = sprintf( ...
                    '%s: Unexpected watermasks found for %s at %s', ...
                    mfilename(), regionName, myDir);
                error(errorStruct);
            end

            f = fullfile(f(1).folder, f(1).name);
        end

        function f = elevationFile(obj, regions)
            % returns DEM for the regions
            %
            % Parameters
            % ----------
            % regions: Region object
            regionName = regions.regionName; 
            f = dir(fullfile(obj.modisElevationDir, ...
                sprintf('%s_dem.mat', ...
                regionName)));

            if length(f) ~= 1
                errorStruct.identifier = ...
                    'ESPEnv_elevationFile:FileError';
                errorStruct.message = sprintf( ...
                    '%s: Unexpected DEMs found for %s at %s', ...
                    mfilename(), regionName, obj.modisElevationDir);
                error(errorStruct);
            end

            f = fullfile(f(1).folder, f(1).name);
        end

        function f = topographyFile(obj, regions)
            % modisTopographyFile file with regionName elevation-slope-aspect

            f = dir(fullfile(obj.modisTopographyDir, ...
                sprintf('%s_Elevation_Slope_Aspect.mat', ...
                regions.regionName)));

            if length(f) ~= 1
                errorStruct.identifier = ...
                    'ESPEnv_topographyFile:FileError';
                errorStruct.message = sprintf( ...
                    '%s: Unexpected Topographies found for %s at %s', ...
                    mfilename(), regions.regionName, obj.modisTopographyDir);
                error(errorStruct);
            end

            f = fullfile(f(1).folder, f(1).name);
        end

        function f = studyExtentFile(obj, regionName)
            % studyExtentFile returns the study extent file for the
            % given regionName

            f = dir(fullfile(obj.extentDir, ...
                sprintf('%s.mat', regionName)));
            if length(f) ~= 1
                errorStruct.identifier = ...
                    'ESPEnv_studyExtentFile:FileError';
                errorStruct.message = sprintf( ...
                    '%s: Unexpected study extentsfound for %s at %s', ...
                    mfilename(), regionName, obj.extentDir);
                error(errorStruct);
            end

            f = fullfile(f(1).folder, f(1).name);
        end

        function projInfo = projInfoFor(obj, tileID, varargin)
            % projInfoFor reads and returns tileID's projection information
            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.mappingDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            try
                projInfo = load(fullfile(myDir, ...
                    sprintf('%s_ProjInfo.mat', tileID)));
            catch e
                fprintf("%s: Error reading projInfo in %s for %s\n", ...
                    mfilename(), myDir, tileID);
                rethrow(e);
            end
        end

        function s = readShapefileFor(obj, shapeName, varargin)
            % shapefileFor - returns the request shapefile contents
            numvarargs = length(varargin);
            if numvarargs > 1
                error('%s:TooManyInputs, ', ...
                    'requires at most 1 optional inputs', mfilename());
            end

            optargs = {obj.shapefileDir};
            optargs(1:numvarargs) = varargin;
            [myDir] = optargs{:};

            try
                shapeFile = fullfile(myDir, ...
                    shapeName, ...
                    sprintf('%s.shp', shapeName));
                s = shaperead(shapeFile);
                fprintf('%s: Read shapefile from %s\n', mfilename(), ...
                    shapeFile);
            catch e
                fprintf("%s: Error reading shapefile in %s for %s\n", ...
                    mfilename(), myDir, shapeName);
                rethrow(e);
            end
        end

        function f = configurationOfVariables(obj)
            f = readtable(fullfile(obj.confDir, ...
                "configuration_of_variables.csv"), 'Delimiter', ',');
            f([1],:) = []; % delete comment line
        end
    end
end
