classdef ESPEnv < handle
    % ESPEnv - environment for ESP data dirs and algorithms
    %   Directories with locations of various types of data needed for ESP
    %   Major cleaning for SIER_352.
    % NB: Don't use the text 'zzzzz' or '*' in filenames or name of subfolders.
    %
    % WARNING: The class uses specific environment variables (property
    %   espEnvironmentVars), which must be defined at the environment level, either
    %   with the .bashrc or using Matlab, setenv(varName, value).
    properties
        confDir         % directory with configuration files (including variable names)
        defaultArchivePath % getenv('espArchiveDir');
        defaultScratchPath % getenv('espScratchDir');
        dirWith % struct with various STC pipeline directories
        filterMyConfByVersionOfAncillary = 1; % 1: configuration is filtered by
            % versionOfAncillary, which means that only regions and subdivisions
            % having the versionOfAncillary indicated in .modisData will be available
            % through .myConf of the object. 0: versionOfAncillary filter not applied.
        mappingDir     % directory with MODIS tiles projection information   @deprecated
        modisData % MODISData Object.
        myConf         % struct(filePath = Table, filter = Table, region = Table,
            % regionlink = Table, variable = Table). Pointing to tables
            % that stores the parameters for each group: (1) ancillary data files,
            % (2) filter and ratios definition at each step
            % of the generation of data (raw, gap, stc, mosaic, geotiff, statistics
            % (3) region properties, (4) links between big region and sub-regions
            % (tiles), (5) variables, used at different steps of the process
            % Step1, Step2, etc ...
            %
            % myConf can also be updated with .setAdditionalConf() to calculate stats
            % (final steps) with (1) subdivisions and (2) subdivisionlinks, which
            % refer to the masks applied to calculate stats (masks are in
            % modis_ancillary/vx.x/landsubdivision) and to the hierarchy of
            % subdivisions.
        myConfigurationOfVariables  % Table storing the parameters for each variable
            % at different steps of the process Step1, Step2, etc ...        @deprecated
        parallelismConf   % struct with parameters for parallelism
        scratchPath % char. Path hosting all files necessary for the run of the project.
%{
        %                                                                      @obsolete
        colormapDir    % directory with color maps
        shapefileDir     % directory with MODIS tiles projection information
        extentDir      % directory with geographic extent definitions
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
%}
    end
    properties(Constant)
        additionalConfigurationFilenames = struct( ...
            landsubdivision = 'configuration_of_landsubdivisions.csv', ...
            landsubdivisionlink = 'configuration_of_landsubdivisionlinks.csv', ...
            landsubdivisionstat = 'configuration_of_landsubdivisionstats.csv', ...
            landsubdivisiontype = 'configuration_of_landsubdivisiontypes.csv', ...
            variablestat = 'configuration_of_variablesstats.csv', ...
            webname = 'configuration_of_webnames.csv');
        configurationFilenames = struct( ...
            filePath = 'configuration_of_filepaths.csv', ...
            filter = 'configuration_of_filters.csv', ...
            region = 'configuration_of_regions.csv', ...
            regionlink = 'configuration_of_regionlinks.csv', ...
            variable = 'configuration_of_variables.csv', ...
            variableregion = 'configuration_of_variablesregions.csv', ...
            versionregion = 'configuration_of_versionsregions.csv');
        defaultHostName = 'CURCScratchAlpine';
        espEnvironmentVars = {'espArchiveDir', 'espProjectDir', 'espScratchDir'};
            % List of the variables which MUST be defined at the OS environment level.
        % defaultPublicOutputPath = 'xxx/esp_public/';
    end
    methods(Static)
        function espEnv = getESPEnvForRegionNameAndVersionLabel(regionName, ...
            versionLabel, scratchPath)
        % Parameters
        % ----------
        % regionName: char. Name of the region. Should be in column name of file
        %   configuration_of_regions.csv.
        % versionLabel: char. Label of the version of data files, which will be
        %   parametered in the modisData property of espEnv. E.g. v2023.1.
        % scratchPath: char. Path of the scratch path. Let '' for default.
        %
        % Return
        % ------
        % espEnv: ESPEnv object with the correct modisData attribute associate to the
        %   version of Ancillary data linked to the region (e.g. v3.1).

         % Load configuration files (paths of ancillary data files and region conf).
         %------------------------------------------------------------------------------
            allRegionsConf = struct();
            [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
            parts = split(thisFilepath, filesep);
            thisFilepath = join(parts(1:end-1), filesep); % 1 level up
            confDir = fullfile(thisFilepath{1}, 'conf');
            confLabel = 'region';
            fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
            tmp = ...
                readtable(fullfile(confDir, ...
                ESPEnv.configurationFilenames.(confLabel)), 'Delimiter', ',');
            tmp([1],:) = []; % delete comment line
            allRegionsConf = tmp;
            thisRegionConf = allRegionsConf(strcmp( ...
                allRegionsConf.name, regionName), :);
            if isempty(thisRegionConf)
                errorStruct.identifier = ...
                    'ESPEnv_getESPEnvForRegionName:InvalidRegionName';
                errorStruct.message = sprintf( ...
                    ['%s: %s is not a valid name in the ', ...
                    'configuration_of_regions.csv file'], mfilename(), regionName);
                error(errorStruct);
            end
            modisData = MODISData(label = versionLabel, ...
                versionOfAncillary = thisRegionConf.versionOfAncillary{1});
            if isempty(scratchPath)
                espEnv = ESPEnv(modisData = modisData);
            else
                espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath);
            end
        end
        function espEnv = getESPEnvForRegionNameFromESPEnv(regionName, ...
            originalEspEnv)
        % Parameters
        % ----------
        % regionName: char. Name of the region. Should be in column name of file
        %   configuration_of_regions.csv.
        % originalEspEnv: ESPEnv. A primary ESPEnv, from which some of the properties
        %   will be copied, for instance modisData.versionOf for all except ancillary
        %   and scratchPath. This way the new espEnv object can handle different
        %   versionLabels for input files and output files.
        %
        % Return
        % ------
        % espEnv: ESPEnv object with the correct modisData attribute associate to the
        %   version of Ancillary data linked to the region (e.g. v3.1).

         % Load configuration files (paths of ancillary data files and region conf).
         %------------------------------------------------------------------------------
            allRegionsConf = struct();
            [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
            parts = split(thisFilepath, filesep);
            thisFilepath = join(parts(1:end-1), filesep); % 1 level up
            confDir = fullfile(thisFilepath{1}, 'conf');
            confLabel = 'region';
            fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
            tmp = ...
                readtable(fullfile(confDir, ...
                ESPEnv.configurationFilenames.(confLabel)), 'Delimiter', ',');
            tmp([1],:) = []; % delete comment line
            allRegionsConf = tmp;
            thisRegionConf = allRegionsConf(strcmp( ...
                allRegionsConf.name, regionName), :);
            if isempty(thisRegionConf)
                errorStruct.identifier = ...
                    'ESPEnv_getESPEnvForRegionName:InvalidRegionName';
                errorStruct.message = sprintf( ...
                    ['%s: %s is not a valid name in the ', ...
                    'configuration_of_regions.csv file'], mfilename(), regionName);
                error(errorStruct);
            end
            modisData = MODISData(label = ...
                originalEspEnv.modisData.versionOf.SubdivisionStatsDailyCsv, ...
                versionOfAncillary = thisRegionConf.versionOfAncillary{1});
                    % versionOf.SubdivisionStatsDailyCsv chosen arbitrarily.
            modisData.versionOf = originalEspEnv.modisData.versionOf;
            modisData.versionOf.ancillary = thisRegionConf.versionOfAncillary{1};
            espEnv = ESPEnv(modisData = modisData, scratchPath = ...
                    originalEspEnv.scratchPath);
        end
    end
    methods
        function obj = ESPEnv(varargin)
            % The ESPEnv constructor initializes all directory settings
            % based on locale
            %
            % Parameters
            % ----------
            % modisData: MODISData obj.
            %   NB: modisData should now be obligatory 2023/06/14                  @todo
            % scratchPath: char. Top path where ancillary and data will be got and
            %   transferred to.
            % filterMyConfByVersionOfAncillary: int. 1 (default): filter the
            %   configuration .myConf according to the versionOfAncillary of .modisData.
            %   0: filter not applied (this is used when we need to construct a file
            %   containing all region/subdivision metadata, e.g. for snow-today webapp.

            % 1. Parameters and check modisData/scratchPath.
            %---------------------------------------------------------------------------
            for espEnvironementVarIdx = 1:length(obj.espEnvironmentVars)
                if isempty(getenv(obj.espEnvironmentVars{espEnvironementVarIdx}))
                    warning(['%s: UNDEFINED environment variable %s. ', ...
                        'ESPEnv will not work correctly.\n'], mfilename(), ...
                        obj.espEnvironmentVars{espEnvironementVarIdx});
                end
            end
            obj.defaultArchivePath = getenv('espArchiveDir');
            obj.defaultScratchPath = getenv('espScratchDir');

            p = inputParser;
            addParameter(p, 'modisData', []);
                % Impossible to have parameter w/o default value?
            % User's scratch locale is default, because it is fast
            addParameter(p, 'scratchPath', obj.defaultScratchPath);
            addParameter(p, 'filterMyConfByVersionOfAncillary', ...
                obj.filterMyConfByVersionOfAncillary);

            p.KeepUnmatched = false;
            parse(p, varargin{:});
            % If-Else to prevent instantiating a default MODISData by using
            % default parameter in addParameter.

            if isempty(p.Results.modisData)
                obj.modisData = MODISData();
            else
                obj.modisData = p.Results.modisData;
            end
            obj.modisData.espEnv = obj;

            % Scratch path should exist.
            if ~isfolder(p.Results.scratchPath)
                errorStruct.identifier = ...
                    'ESPEnv:InvalidScratchPath';
                errorStruct.message = sprintf( ...
                    '%s: Scratch path is not available: %s.', ...
                    mfilename(), p.Results.scratchPath);
                error(errorStruct);
            end
            obj.scratchPath = p.Results.scratchPath;
            fprintf('%s: scratch path %s\n', mfilename(), obj.scratchPath);

            % change default filtering behavior if filterMyConfByVersionOfAncillary set
            % to 0.
            if ~isempty(p.Results.filterMyConfByVersionOfAncillary)
                obj.filterMyConfByVersionOfAncillary = ...
                    p.Results.filterMyConfByVersionOfAncillary;
            end

            % 2. Load configuration files (paths of ancillary data files,
            % thresholds / region / variable configuration data.
            %---------------------------------------------------------------------------
            [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
            parts = split(thisFilepath, filesep);
            thisFilepath = join(parts(1:end-1), filesep); % 1 level up
            obj.confDir = fullfile(thisFilepath{1}, 'conf');
            confLabels = fieldnames(obj.configurationFilenames);
            for confLabelIdx = 1:length(confLabels)
                confLabel = confLabels{confLabelIdx};
                fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
                tmp = ...
                    readtable(fullfile(obj.confDir, ...
                    obj.configurationFilenames.(confLabel)), 'Delimiter', ',');
                tmp([1],:) = []; % delete comment line

                % Convert Date string columns into datetimes.
                theseFieldNames = tmp.Properties.VariableNames;
                for fieldIdx = 1:length(theseFieldNames)
                    thisFieldName = theseFieldNames{fieldIdx};
                    if contains(thisFieldName, 'Date')
                        tmp.(thisFieldName) = arrayfun(@(x) datetime(x, ...
                            InputFormat = 'yyyy-MM-dd'), tmp.(thisFieldName));
                    end
                end
                obj.myConf.(confLabel) = tmp;
            end
            % Limit the table of file paths to the version of ancillary data.
            obj.myConf.filePath = obj.myConf.filePath(strcmp( ...
                obj.myConf.filePath.version, obj.modisData.versionOf.ancillary), :);
            % Very dirty:
            % Convert the type of subfolder 1...5 to strings if there are no data in
            % them (if nodata, matlab put the field to double type).
            % NB: a cleaner solution to indicate class of columns when
            % reading the csv file should be developed                             @todo
            for subFolderIdx = 1:6
                subFolder = ...
                    obj.myConf.filePath.(['fileSubDirectory', num2str(subFolderIdx)]);
                if strcmp(class(subFolder), 'double')
                    idx = isnan(subFolder);
                    subFolder = num2cell(subFolder);
                    subFolder(idx) = {''};
                    obj.myConf.filePath.(['fileSubDirectory', ...
                        num2str(subFolderIdx)]) = subFolder;
                end
            end
            fprintf('%s: Filtered filepath configuration.\n', mfilename());

            % Order the filter table by the order in which the filtering should be
            % processed. Redundant with precedent?                              @tocheck
            obj.myConf.filter = sortrows(obj.myConf.filter, [1, 2]);
            fprintf('%s: Sorted filter configuration.\n', mfilename());

            % Restrict region to value of modisData versionOfAncillary.
            if obj.filterMyConfByVersionOfAncillary
                obj.myConf.region = obj.myConf.region( ...
                    strcmp(obj.myConf.region.versionOfAncillary, ...
                    obj.modisData.versionOf.ancillary), :);
            end

            % Restrict region/subregion links to active (e.g. USAlaska/h08v03).
            % NB: Should also restrict to value of versionOfAncillary.             @todo
            obj.myConf.regionlink = obj.myConf.regionlink( ...
                obj.myConf.regionlink.isActive == 1, :);
            fprintf('%s: Restricted region links to isActive = 1.\n', mfilename());

            % Variables associated to regions:
            % - Determine the name of variables.
            % - Restrict the variable region to the regions of the version of ancillary
            % - and extend the variable region conf to the tiles part of the big region.
            obj.myConf.variableregion.output_name = [];
            obj.myConf.variableregion = innerjoin(obj.myConf.variableregion, ...
                obj.myConf.variable, LeftKeys = 'varId', RightKeys = 'id', ...
                RightVariables = {'output_name'});
            obj.myConf.variableregion = innerjoin(obj.myConf.variableregion, ...
                obj.myConf.region, LeftKeys = 'regionName', RightKeys = 'name', ...
                RightVariables = {});
            additionalVariableRegion = ...
                outerjoin(obj.myConf.regionlink, obj.myConf.variableregion, ...
                    LeftKeys = 'supRegionName', RightKeys = 'regionName', ...
                    LeftVariables = 'subRegionName', Type = 'left');
            additionalVariableRegion = ...
                additionalVariableRegion(~isnan(additionalVariableRegion.varId), :);
            additionalVariableRegion = renamevars( ...
                removevars(additionalVariableRegion, ...
                    {'regionName'}), {'subRegionName'}, {'regionName'});
            obj.myConf.variableregion = vertcat(obj.myConf.variableregion, ...
                additionalVariableRegion);
            fprintf('%s: Extended variable region to tiles (subregions).\n', ...
                mfilename());

            obj.myConfigurationOfVariables = obj.configurationOfVariables();
                % @deprecated. replaced by obj.myConf.variable.

            obj.mappingDir = fullfile(thisFilepath, 'mapping');
            %obj.colormapDir = fullfile(thisFilepath, 'colormaps');            @obsolete
            %obj.extentDir = fullfile(thisFilepath, 'StudyExtents');           @obsolete

            % 3. Configuration of data directories.
            %---------------------------------------------------------------------------
            % In practice, these directories will be
            % appended with labels from MODISData class
            path = fullfile(obj.scratchPath, 'modis');
            obj.dirWith = struct(...
                'MOD09Raw', fullfile(path, 'intermediary', 'mod09_raw'), ...
                'SCAGDRFSRaw', fullfile(path, 'intermediary', 'scagdrfs_raw'), ...
                'SCAGDRFSGap', fullfile(path, 'intermediary', 'scagdrfs_gap'), ...
                'SCAGDRFSSTC', fullfile(path, 'intermediary', 'scagdrfs_stc'), ...
                'VariablesMatlab', fullfile(path, 'variables', 'scagdrfs_mat'), ...
                'VariablesNetCDF', fullfile(path, 'variables', 'scagdrfs_netcdf'), ...
                'VariablesGeotiff', fullfile(path, 'variables', 'scagdrfs_geotiff'), ...
                'RegionalStatsMatlab', fullfile(path, 'regional_stats', ...
                'scagdrfs_mat'), ...
                'RegionalStatsCsv', fullfile(path, 'regional_stats', ...
                'scagdrfs_csv'));
%{
            obj.dirWith.publicFTP =  fullfile(obj.defaultPublicOutputPath, 'snow-today'));
            % For top-level stuff, paths are on PetaLibrary
            path = fullfile('x', 'x');

            %                                                              @obsolete
            obj.MODISDir = fullfile(path, 'scag', 'MODIS', 'SSN', 'v01');
            obj.viirsDir = fullfile(path, 'viirs');
            obj.watermaskDir = fullfile(path, 'landcover', 'NLCD_ucsb');
            obj.LandsatDir = fullfile(path, 'Landsat_test');
            obj.LandsatResampledDir = fullfile(path, ...
            'Landsat_test', 'Landsat8_resampled');
            obj.heightmaskDir = fullfile(path, ...
                'SierraBighorn', 'landcover', 'LandFireEVH_ucsb');
            obj.MODICEDir = fullfile(path, 'modis', 'modice');
            obj.modisWatermaskDir = fullfile(path, 'landcover');
            obj.modisForestDir = fullfile(path, 'forest_height');
            obj.modisElevationDir = fullfile(path, 'elevation');
            obj.modisTopographyDir = fullfile(path, 'topography');
            obj.shapefileDir = fullfile(path, 'shapefiles');
            obj.regionMaskDir = fullfile(path, 'region_masks', 'v3');
%}
            % Convert these from 1x1 cells to plain char arrays, (put aside read-only
            % constants).
            metaEspEnv = ?ESPEnv;
            theseProperties = metaEspEnv.PropertyList;
            for propertyIdx = 1:length(theseProperties)
                if ~theseProperties(propertyIdx).Constant & ...
                    iscell(obj.(theseProperties(propertyIdx).Name))
                    obj.(theseProperties(propertyIdx).Name) = ...
                        obj.(theseProperties(propertyIdx).Name){1};
                end
            end

            % 4. Parallelism configuration.
            %---------------------------------------------------------------------------

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
        function f = configurationOfVariables(obj)
            %                                                                @deprecated
            f = obj.myConf.variable;
        end
        function varData = getDataForDateAndVarName(obj, ...
            objectName, dataLabel, thisDate, varName, complementaryLabel)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            % thisDate: datetime. Cover the period for which we want the
            %   files. If not necessary, put ''.
            % varName: name of the variable to load (name in the file, not output_name
            %   of configuration_of_variables.csv).
            % complementaryLabel: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857. If not necessary, put ''.
            %
            % Return
            % ------
            % varData: data array or table read.
            %
            % NB: only works for dataLabel in VariablesMatlab.
            % NB: doesn't check if the variable is present in file.                @todo

            % 1. Check valid dataLabel and get file for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            [filePath, fileExists, ~] = ...
                obj.getFilePathForDateAndVarName(objectName, dataLabel, thisDate, ...
                    varName, complementaryLabel);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.

            % 2. Construction of the array of values extracted from the files.
            %---------------------------------------------------------------------------
            varData = [];
            if ~fileExists
                warning('%s: Absent file %s.\n', mfilename(), filePath);
            else
                fileExtension = Tools.getFileExtension(filePath);
                if strcmp(fileExtension, '.mat')
                    % In regular process, a proper
                    % handling of thisDate and of the generation of files (potentially
                    % with nodata/NaN-filled variables) should make all files present and
                    % the last condition useless.
                    if ~strcmp(varName, '')
                        varData = parloadMatrices(filePath, varName);
                    else
                        varData = load(filePath); % Not sure whether that works in parfor
                            % loops.
                    end
                elseif strcmp(fileExtension, '.csv')
                    varData = readtable(filePath, 'Delimiter', ',');
                    if startsWith(string(varData.(1)(1)), 'Metadata')
                        varData([1],:) = []; % delete metadata line.
                        % There might be necessary to put that in the metadata return @todo
                    end
                end
            end
        end
        function [data, mapCellsReference, metaData] = ...
            getDataForObjectNameDataLabel(obj, objectName, dataLabel)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            %   NB: for objects that are actually related to 2 objects, for instance
            %   landsubdivision, objectName can consist of two concatenated object
            %   the most important being that we find this concatenation in the fileName
            %   and that this concatenation is unique. For instance, the landsubdivision
            %   westernUS for tile h08v04 will have as object name: 'h08v04_westernUS'.
            % dataLabel: char. Label of the type of data we have to find. E.g.
            %   'elevation'.
            %
            % Return
            % ------
            % data: array( x ) or Struct or Table.
            %   E.g. of elevations for a tile or Struct of
            %   properties for a region mask or Table of stats.
            %   If file doesn't exit, empty.
            % mapCellsReference: MapCellsReference. Allows to georeference the data.
            [filePath, fileExists] = obj.getFilePathForObjectNameDataLabel( ...
                objectName, dataLabel);
            if ~fileExists
                warning('%s: Absent file %s.\n', mfilename(), filePath);
                data = [];
                mapCellsReference = [];
                metaData = struct();
            else
                fileExtension = Tools.getFileExtension(filePath);
                if strcmp(fileExtension, '.mat')
                    tmpObj = load(filePath);
                    data = tmpObj.data;
                    try
                        mapCellsReference = tmpObj.mapCellsReference;
                    catch e
                        mapCellsReference = [];
                    end
                    try
                        metaData = tmpObj.metaData;
                    catch e
                        metaData = struct();
                    end
                elseif strcmp(fileExtension, '.tif')
                    [data, mapCellsReference] = readgeoraster(filePath);
                    if ~strcmp(class(mapCellsReference), 'MapCellsReference')
                        mapCellsReference = [];
                    end
                    metaData = struct();
                elseif strcmp(fileExtension, '.csv')
                    data = readtable(filePath, 'Delimiter', ',');
                    if startsWith(string(data.(1)(1)), 'Metadata')
                        data([1],:) = []; % delete metadata line.
                        % There might be necessary to put that in the metadata return @todo
                    end
                end
            end
        end
        function varData = getDataForWaterYearDateAndVarName(obj, ...
            objectName, dataLabel, waterYearDate, varName)
            % SIER_297: replacement of modisData.loadMOD09() and loadSCAGDRFS()
            % NB: this ugly method may be improved, depending on raw data struct.  @todo
            %
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            % waterYearDate: WaterYearDate. Cover the period for which we want the
            %   files.
            % varName: name of the variable to load (name in the file, not output_name
            %   of configuration_of_variables.csv).
            %
            % Return
            % ------
            % varData: concatenated data arrays read. We hypothesize that the files
            %   have continuous dates, without gaps (you can have files filled by NaN
            %   or nodata.
            %
            % NB: only works for dataLabel in MOD09Raw or SCAGRaw. !!
            % NB: doesn't check if the variable is present in file.                @todo

            % 1. Check valid dataLabel and get list of files for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            fprintf('%s: Loading data %s, %s for %s, waterYearDate %s...\n', ...
                mfilename(), dataLabel, varName, objectName, waterYearDate.toChar());
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            varConf = obj.myConf.variable(strcmp(obj.myConf.variable.output_name, ...
                varName), :);

            [filePath, fileExists, lastDateInFile, waterYearDate] = ...
                obj.getFilePathForWaterYearDate(objectName, dataLabel, waterYearDate);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.
            filePath = filePath(fileExists == 1); % In regular process, a proper
                % handling of waterYearDate and of the generation of files (potentially
                % with nodata/NaN-filled variables) should make all files present and
                % this command useless.
            lastDateInFile = lastDateInFile(fileExists == 1);

            % 2. Construction of the array of values extracted from the files.
            %---------------------------------------------------------------------------
            varData = [];
            if strcmp(varName, filePathConf.dateFieldName{1})
                for fileIdx = 1:size(filePath, 2)
                    [varDataT] = load(filePath{fileIdx}, varName).(varName);
                    if fileIdx == 1
                        varData = varDataT{1}';
                    else
                        varData = [varData varDataT{1}'];
                    end
                end
                varData = datenum(varData);
            elseif strcmp(varName, 'RefMatrix')
                varData = load(filePath{1}, 'RefMatrix').RefMatrix;
            else
                % Initialization of loaded data array...
                % destination array has fix size (e.g. 2400x2400x92 days)
                % and not a variable size as before 2023-12-12, to speed execution.
                thisType = ...
                    Tools.valueInTableForThisField(obj.myConf.variable, 'raw_name', ...
                    varName, 'type');
                        % NB: For variable NoValues,
                        % type in raw files is actually logical, but code should work.

                if strcmp(varName, 'refl') % Reflectance has 7 bands as 3rd dimension.
                    thisSize = [obj.modisData.sensorProperties.tiling.rowPixelCount, ...
                        obj.modisData.sensorProperties.tiling.columnPixelCount, ...
                        7, sum(day(lastDateInFile))];

                    varData = intmax(thisType) * ones(thisSize, thisType);
                    lastIndex = 0;
                    for fileIdx = 1:size(filePath, 2)
                        varData(:, :, :, lastIndex + 1: ...
                            lastIndex + day(lastDateInFile(fileIdx))) = ...
                            load(filePath{fileIdx}, varName).(varName);
                        lastIndex = lastIndex + day(lastDateInFile(fileIdx));
                    end
                else % Other variables have time as 3rd dimension.
                    % NB: solar azimuth, zenith, sensor zenith are 2400x2400 in raw
                    % cubes (but 1200x1200 in modis files).
                    thisSize = [obj.modisData.sensorProperties.tiling.rowPixelCount, ...
                        obj.modisData.sensorProperties.tiling.columnPixelCount, ...
                        sum(day(lastDateInFile))];

                    varData = intmax(thisType) * ones(thisSize, thisType);
                    lastIndex = 0;
                    for fileIdx = 1:size(filePath, 2)
                        varData(:, :, lastIndex + 1: ...
                            lastIndex + day(lastDateInFile(fileIdx))) = ...
                            load(filePath{fileIdx}, varName).(varName);
                        lastIndex = lastIndex + day(lastDateInFile(fileIdx));
                    end
                end
            end
            fprintf('%s: Loaded data %s, %s for %s, waterYearDate %s.\n', ...
                mfilename(), dataLabel, varName, objectName, waterYearDate.toChar());
        end
        function [filePath, fileExists, fileLastEditDate] = ...
            getFilePathForDateAndVarName(obj, objectName, dataLabel, thisDate, ...
            varName, complementaryLabel, varargin)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   id of the landSubdivision. E.g. 26000 for 'westernUS'.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. spiresDaily.
            %   For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            % thisDate: datetime. For which we want the file.
            %   NB/trick: for the SubdivisionStatsWebCsv, this is a date which year is
            %   the ongoing waterYear.
            % varName: name of the variable. Currently only used for
            %   SubdivisionStatsWebCsv (2023-09-30), otherwise set to ''.
            % complementaryLabel: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857.
            % patternsToReplaceByJoker: cell array(char), optional.
            %   List of arguments (patterns)
            %   we don't a priori know. The filepath in that case will be found using
            %   a dir cmd (replacing some unknown patterns by the joker *).
            %
            % Return
            % ------
            % filePath: char or cellarray(char). FilePath or list of filePath when joker
            %   is used.
            %   NB: if cellarray and 2 versions of the file exists, only the file with
            %   the most recent fileLastEditDate is in the filePath list.
            % fileExists: uint8 or cellarray(uint8). 0 if file doesn't exist.
            % fileLastEditDate: datetime or cellarray(datetime).

            p = inputParser;
            addParameter(p, 'patternsToReplaceByJoker', {});
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;

            % 1. Generation and check existence of the file directory path.
            %---------------------------------------------------------------------------
            modisData = obj.modisData;

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            if isempty(filePathConf)
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForDateAndVarName:NoConfForDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in configuration_of_filepaths.csv file.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end
            if filePathConf.isAncillary(1) == 0 & ...
                ~ismember(dataLabel, fieldnames(modisData.versionOf))
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForDateAndVarName:BadDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in MODISData.versionOf fieldnames.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end
            directoryPath = fullfile(obj.scratchPath, ...
                filePathConf.topSubDirectory{1});
            for subFolderIdx = 1:8
                subFolder = ...
                    filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                if ~isempty(subFolder)
                    directoryPath = fullfile(directoryPath, subFolder);
                end
            end
            directoryPath = obj.replacePatternsInFileOrDirPaths(directoryPath, ...
                objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                patternsToReplaceByJoker = patternsToReplaceByJoker);
            if isempty(patternsToReplaceByJoker) & ~isfolder(directoryPath)
                mkdir(directoryPath);
            end

            % 2. Generation of the filename, check existence and determine last edit
            % date.
            %---------------------------------------------------------------------------
            fileName = [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}];
            fileName = obj.replacePatternsInFileOrDirPaths(fileName, ...
                objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                patternsToReplaceByJoker = patternsToReplaceByJoker);

            filePath = fullfile(directoryPath, fileName);

            tmpFiles = struct2table(dir(filePath));
            tmpFiles = tmpFiles(tmpFiles.isdir == 0, :);
            if size(tmpFiles, 1) == 0
                fileExists = 0;
                fileLastEditDate = NaT;
            else
                % Case when we use jokers to get a list of files (or just one file when
                % we lack some arguments to precisely determine the name of the file...
                tmpFiles = sortrows(tmpFiles(tmpFiles.isdir == 0, :), 'datenum', ...
                    'descend');
                filePath = table2cell(rowfun(@(x, y) fullfile(x, y), tmpFiles, ...
                    InputVariables = {'folder', 'name'}));
                fileExists = num2cell(ones(size(filePath, 1), 1));
                fileLastEditDate = table2cell(rowfun(@(x) ...
                    datetime(x, InputFormat = 'dd-MMM-yyyy HH:mm:ss'), ...
                    tmpFiles, InputVariables = {'date'}));
            end
            % De-cellification if only 1 return.
            if iscell(filePath) & length(filePath) == 1
                filePath = filePath{1};
                fileExists = fileExists{1};
                fileLastEditDate = fileLastEditDate{1};
            end
        end
        function [filePath, fileExists] = getFilePathForObjectNameDataLabel(obj, ...
            objectName, dataLabel)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   id of the landSubdivision. E.g. 26000 for 'westernUS'.
            %   If the filepath is not object dependent
            %   (column in configuration_of_filepaths.csv), objectName is unused.
            % dataLabel: char. Label (type) of data for which the file is required, as in
            %   configuration_of_filepaths: aspect,canopyheight, elevation, land,
            %   landsubdivision, region, slope, water.
            %
            % Return
            % ------
            % filePath: char.
            % existFile: uint8. 0 if file doesn't exist.
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            if isempty(filePathConf)
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForObjectNameDataLabel:NoConfForDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in configuration_of_filepaths.csv file.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end

            % Construction of the directory with the subfolders and replacement of
            % patterns (e.g. {version}) by their value, and create directory if doesn't
            % exists.
            directoryPath = fullfile(obj.scratchPath, ...
                filePathConf.topSubDirectory{1});
            for subFolderIdx = 1:8
                subFolder = ...
                    filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                if ~isempty(subFolder)
                    directoryPath = fullfile(directoryPath, subFolder);
                end
            end
            directoryPath = obj.replacePatternsInFileOrDirPaths(directoryPath, ...
                objectName, dataLabel, '', '', '');
            if ~isfolder(directoryPath)
                mkdir(directoryPath)
            end

            % Construction of the filename.
            fileName = [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}];
            fileName = obj.replacePatternsInFileOrDirPaths(fileName, ...
                objectName, dataLabel, '', '', '');
            % Temporary specific case for region masks                             @todo
            if isempty(filePathConf.fileLabel{1})
                fileName = [objectName, filePathConf.fileExtension{1}];
            end
            filePath = fullfile(directoryPath, fileName);
            fileExists = isfile(filePath);
        end
        function [filePath, fileExists, lastDateInFile, waterYearDate] = ...
            getFilePathForWaterYearDate(obj, objectName, dataLabel, waterYearDate)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   id of a landSubdivision. E.g. 26000.
            % dataLabel: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            %   For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            % waterYearDate: WaterYearDate. Cover the period for which we want the
            %   files.
            %
            % Return
            % ------
            % filePath: char or 1-D array(char) if several files (e.g. waterYearDate
            %   having a window > 1.
            % existFile: uint8 or 1-D array(uint8) if several files.
            %   0 if file doesn't exist.
            % lastDateInFile: datetime or 1-D array(datetime). Last date present in the file.
            %   NB: because of the design of raw files, which are filled up to the day
            %   before run, lastDate is similar to the number of days in file.
            %   Not to be used when existFile = 0.
            % waterYearDate: WaterYearDate. Adjusted to the last available date.
            %
            % NB: method which retakes some of the code of getFilePathForDate(). Maybe
            %   some mutualization is possible?                                    @todo

            % 1. Generation and check existence of the file directory path.
            %---------------------------------------------------------------------------
            modisData = obj.modisData;
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);

            if isempty(filePathConf)
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForWaterYearDate:NoConfForDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in configuration_of_filepaths.csv file.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end
            if filePathConf.isAncillary(1) == 0 & ...
                ~ismember(dataLabel, fieldnames(modisData.versionOf))
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForWaterYearDate:BadDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in MODISData.versionOf fieldnames.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end

            % 2. Generation of the filenames, check existence, detection of the
            % last date recorded in file and update of the waterYearDate.
            %---------------------------------------------------------------------------
            % Either each file is a montly cube or a daily file:
            if strcmp(filePathConf.dateInFileName{1}, 'yyyyMM')
                theseDates = waterYearDate.getMonthlyFirstDatetimeRange();
            else
                theseDates = waterYearDate.getDailyDatetimeRange();
            end
            filePath = {};
            fileExists = zeros([1, length(theseDates)], 'uint8');
            lastDateInFile = theseDates;

            for dateIdx = 1:length(theseDates)
                thisDate = theseDates(dateIdx);
                % Construct directoryPath, replace the patterns '{}' by their value and
                % create the directory if doesn't exist.
                directoryPath = fullfile(obj.scratchPath, ...
                    filePathConf.topSubDirectory{1});
                for subFolderIdx = 1:8
                    subFolder = ...
                        filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                    if ~isempty(subFolder)
                        directoryPath = fullfile(directoryPath, subFolder);
                    end
                end
                directoryPath = obj.replacePatternsInFileOrDirPaths(directoryPath, ...
                    objectName, dataLabel, thisDate, '');
                if ~isfolder(directoryPath)
                    mkdir(directoryPath);
                end

                % Determine filename.
                fileName = [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}];
                fileName = obj.replacePatternsInFileOrDirPaths(fileName, ...
                    objectName, dataLabel, thisDate, '');

                filePath{dateIdx} = fullfile(directoryPath, fileName);

                % Determine existence of file and last date in file (for daily file,
                % if present, the last date is automatically the date in the filename):
                if isfile(filePath{dateIdx})
                    fileExists(dateIdx) = 1;
                    if strcmp(filePathConf.dateInFileName{1}, 'yyyyMM')
                        lastDateInFile(dateIdx) = max( ...
                            load(filePath{dateIdx}, filePathConf.dateFieldName{1}).( ...
                                filePathConf.dateFieldName{1}));
                    else
                        lastDateInFile(dateIdx) = thisDate;
                    end
                end
            end
            lastDateInFileWhichExists = lastDateInFile(fileExists == 1);
            waterYearDate = WaterYearDate( ...
                 lastDateInFileWhichExists(end), ...
                 modisData.getFirstMonthOfWaterYear(objectName), ...
                 length(find(fileExists == 1)));
            waterYearDate.overlapOtherYear = 1; % Should be in constructor @todo
        end
        function [objectId, varId, thisDate, thisYear] = getMetadataFromFilePath(obj, ...
            filePath, dataLabel)
            % Roughly the reverse method of espEnv.replacePatternsInFileOrDirPaths(),
            % Parse the filepath to get the metadata.
            %
            % Parameters
            % ----------
            % dataLabel: char. Type of the file as indicated in
            %   configuration_of_filepaths.csv, for the versionOf.ancillary property of
            %   the current espEnv object.
            % filePath: char. Filepath from which all metadata will be derived.
            %   Its format must follow the patterns in configuration_of_filepaths.csv.
            %
            % Return
            % ------
            % objectId: uint16.
            % varId: uint8.
            % thisDate: datetime.
            % NB: don't work with the geotiffs.

            % Determination of the raw filePath pattern from configuration.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);

            patternDirectoryPath = fullfile(obj.scratchPath, ...
                filePathConf.topSubDirectory{1});
            for subFolderIdx = 1:8
                subFolder = ...
                    filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                if ~isempty(subFolder)
                    patternDirectoryPath = fullfile(patternDirectoryPath, subFolder);
                end
            end
            patternFilePath = fullfile(patternDirectoryPath, ...
                [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}]);

            % Determination of the fieldnames for each pattern and their value in the
            % filePath.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            findChar = replace(patternFilePath, {'\', '/', '.'}, {'\\', '\/', '\.'});

            findChar = regexprep(findChar, '{([0-9A-Za-z]*)}', ...
                '{([0-9A-Za-z\\.]*)}');

            replaceChar = replace(regexprep(num2str( ...
                1:count(patternFilePath, '{'), ' %u'), '([0-9]*)', '\$$1'), '  ', ' ');
            fieldName = split(regexprep(patternFilePath, findChar, replaceChar));

            findCell = cellfun(@(c)['{', c, '}'], fieldName, UniformOutput = false);
            replaceCell = cell(size(findCell));
            replaceCell(:) = {'([0-9A-Za-z]*)'};
            replaceCell(ismember(findCell, {'{version}', '{versionOfAncillary}'})) = ...
                {'([0-9A-Za-z\.]*)'};
                % NB: this is because versions include a dot, like v2023.0.
            replaceCell(strcmp(findCell, '{varName}')) = {'([0-9A-Za-z\_]*)'};
                % NB: this is because varNames include a _, like snow_fraction.

            findChar = replace(patternFilePath, {'\', '/', '.'}, {'\\', '\/', '\.'});
            findChar = replace(findChar, findCell, replaceCell);
            findChar = replace(findChar, ').', ')\.');
            fieldValue = split(regexprep(filePath, findChar, replaceChar));

            % Attribution of the value to each field, conversion to the correct
            % format for dates and years.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            numericFieldValue = cellfun(@str2double, fieldValue, UniformOutput = false);
            datetimeFieldValue = cell(size(fieldValue));
            datetimeFieldValue(:) = {NaT};
            for fieldIdx = 1:length(fieldName)
                evalChar = '';
                if ~isnan(numericFieldValue{fieldIdx})
                    if length(fieldValue{fieldIdx}) == 8
                        evalChar = [fieldName{fieldIdx}, ' = datetime(''', ...
                            fieldValue{fieldIdx}, ''', InputFormat = ''yyyyMMdd'');'];
                    elseif length(fieldValue{fieldIdx}) == 6
                        evalChar = [fieldName{fieldIdx}, ' = datetime(''', ...
                            fieldValue{fieldIdx}, '01'', InputFormat = ''yyyyMMdd'');'];
                    else
                        evalChar = [fieldName{fieldIdx}, ' = ', ...
                            fieldValue{fieldIdx}, ';'];
                    end
                else % fieldValue is always char.
                    evalChar = [fieldName{fieldIdx}, ' = ''', ...
                        fieldValue{fieldIdx}, ''';'];
                end
                eval(evalChar);
            end

            % Determine from the above values the return of the method.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if exist('objectName', 'var')
                objectLabel = objectName;
            elseif exist('objectId', 'var')
                objectLabel = objectId;
            end
            if exist('objectLabel', 'var')
                [objectId, objectName, objectType] = ...
                    obj.getObjectIdentification(objectLabel);
            else
                objectId = 0;
                objectName = '';
                objectType = 0;
            end
            if exist('varName', 'var')
                varLabel = varName;
            elseif exist('varId', 'var')
                varLabel = varId;
            end
            if exist('varLabel', 'var')
                [varId, varName] = obj.getVariableIdentification(varLabel);
            else
                varId = 0;
                varName = '';
            end
            if ~exist('thisDate', 'var') & ~exist('thisYear', 'var')
                thisDate = NaT;
                thisYear = year(WaterYearDate.fakeDate);
            elseif exist('thisDate', 'var') & ~exist('thisYear', 'var')
                thisYear = year(thisDate);
            elseif exist('thisYear', 'var') & ~exist('thisDate', 'var')
                thisDate = datetime(thisYear, month(WaterYearDate.fakeDate), ...
                    day(WaterYearDate.fakeDate));
            end
        end
        function objectNames = getObjectNamesForDataLabelAndDateAndVarName(obj, ...
            dataLabel, thisDate, varName, complementaryLabel)
            % Parameters
            % ----------
            % dataLabel: char. Label (type) of nrt/historic data or ancillary data
            % for which the file is required,
            %   e.g. spiresDaily or landsubdivisionlinkinjson. For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            % thisDate: datetime. For which we want the file.
            % varName: char. Variable name. Can be '' if files of the dataLabel are not
            %   split between variables.
            % complementaryLabel: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857. If not necessary, put ''.
            %
            % Return
            % ------
            % objectNames: char cell array. List of object names for which a file is
            %   available for the combination dataLabel - thisDate - varName (and
            %   either for the version of dataLabel in modisData or
            %   versionOfAncillary, + platform + version of collection if necessary.
            %
            % NB: we assume that if a file for one variable for an object has been
            %   generated, the other files for the other variables have been generated
            %   too. This can be consequential and creates bugs, improve!          @todo
            %
            % NB: we assume that the text zzzzz is not used in filenames or name of
            %   subfolders, except if it's an id of region or subdivision.
            % NB: We assume that a dataLabel has only 1 type of objectName, either the
            %   name of a region ('h08v04', 'westernUS') or the id of a landsubdivision
            %   (26001).

            % Initialize ...
            fprintf('%s: Starting to get the list of objectNames...\n', mfilename());
            fakeObjectName = num2str(intmax('uint16'));
                % arbitrary objectName = 65535, which gives objectName_1000 = 65,
                % if files organized in subfolders to avoid to be > 1000 files/folder.
                % varName is * to take any file containing the name of a variable in it.
                % We can't directly do that for objectName because of the possible
                % subfolders.

            % Get the filePath regexp to get the list of files associated to the
            % method arguments ...
            [filePath, ~, ~] = ...
                obj.getFilePathForDateAndVarName(fakeObjectName, ...
                dataLabel, thisDate, varName, complementaryLabel);
            filePath = replace(filePath, ...
                [filesep(), num2str(floor( ...
                    cast(str2num(fakeObjectName), 'single') / 1000)), filesep()], ...
                [filesep(), '*', filesep()]);
            filePath = replace(filePath, ...
                ['_', fakeObjectName, '_'], ['_*_']);
            filePath = replace(filePath, ...
                [filesep(), fakeObjectName, '_'], [filesep(), '*_']);
            filePath = replace(filePath, ...
                [filesep(), fakeObjectName, filesep()], [filesep(), '*', filesep()]);

            % Get the files:
            fprintf('%s: Getting the list of files in %s...\n', mfilename(), ...
                obj.scratchPath);
            objectNames = struct2table(dir(filePath)).name;
            fprintf('%s: Got the list of files.\n', mfilename());
            if isequal(objectNames, [])
                return;
            end
            if strcmp(class(objectNames), 'char')
                objectNames = {objectNames};
                    % this is so weird from Matlab, when 1 element only, gives a char
                    % and not a cell array!
            end
            % Get the parts of filename to remove to only have the objectName.
            fileNamePattern = split(filePath, filesep());
            fileNamePattern = fileNamePattern{end};
            fileNamePattern = split(fileNamePattern, '*');
            fileNamePattern = fileNamePattern(~strcmp(fileNamePattern, ''));
                % remove empties, otherwise replace below doesn't work.

            replaceForFun = @(x) replace(x, fileNamePattern, ...
                repelem({''}, size(fileNamePattern, 1))');
                    % Anomymous function to apply to the cell array below.
            objectNames = cellfun(replaceForFun, objectNames, 'UniformOutput', false);
                % NB: don't write @replaceForFun, since replaceForFun already equals
                % a handler.

            % Filter objectNames by the versionOfAncillary
            % (necessary for versionOfAncillary independent filePaths).
            % NB:This is a bit convoluted but required by the current dirty structure of
            % configuration_of_filepaths.csv. 2023-11-15.
            if Tools.valueInTableForThisField(obj.myConf.filePath, 'dataLabel', ...
                dataLabel, 'isAncillary') == 0
                objectNames = cell2table(objectNames);
                tempObjectNames = innerjoin(objectNames, obj.myConf.region, ...
                    LeftKeys = 'objectNames', RightKeys = 'name', RightVariables = {});
                if ~isempty(tempObjectNames)
                    objectNames = tempObjectNames;
                    fprintf(['%s: objectNames detected as region and ', ...
                        'filtered by versionOfAncillary.\n'], mfilename());
                else
                    obj.setAdditionalConf('landsubdivision');
                    if strcmp(class(objectNames.objectNames), ...
                        class(obj.myConf.landsubdivision.id))
                        tempObjectNames = innerjoin(objectNames, ...
                            obj.myConf.landsubdivision, ...
                            LeftKeys = 'objectNames', RightKeys = 'id', ...
                            RightVariables = {});
                        if ~isempty(tempObjectNames)
                            objectNames = tempObjectNames;
                            fprintf(['%s: objectNames detected as landsubdivision ', ...
                                'and filtered by versionOfAncillary.\n'], mfilename());
                        else
                            fprintf(['%s: Undetected objectName as region or ', ...
                                'landsubdivision, return empty.\n'], mfilename());
                        end
                    else
                        fprintf(['%s: Undetected objectName as region or ', ...
                                'landsubdivision, return empty.\n'], mfilename());
                    end
                end
                objectNames = table2cell(objectNames);
            end
            fprintf('%s: Determined the list of objectNames.\n', mfilename());
        end
        function [objectId, objectName, objectType] = ...
            getObjectIdentification(obj, objectLabel)
            % Parameters
            % ----------
            % objectLabel: char or uint16 or cellarray(char) or cellarray(uint16).
            %   Either objectId or objectName.
            %
            % Return
            % ------
            % objectId: uint16.
            % objectName: char. For region, name, for landsubdivision code.
            % objectType: uint8. 0: regions, 1: landsubdivisions, 255: unknown.

            % NB: there are probably cases i don't detect in the condition.     @tocheck
            % we get objectId from objectName and configuration_of_regions.csv and
            % configuration_of_landsubdivisions.csv.
            % Code below is to make certain that
            % objectId is numeric and single, I don't trust Matlab and its automatic
            % conversion which can make the division below a integer division we don't
            % want to because it will round to the closest int and not the floor int.
            objectId = 0;
            objectName = '';
            objectType = 0;
            if isequal(objectLabel, objectId) | isequal(objectLabel, objectName)
                objectType = intmax('uint8');
                return;
            end
            
            % We suppose first that objectLabel is a real name...
            if ischar(objectLabel) & ~isempty(regexp(objectLabel, '[A-Za-z]', 'once'))
                objectName = objectLabel;
                % NB: we exclude the object names containing _mask, specific to
                %   instantiation of regions (should be removed at at some point). @todo
                if isempty(regexp(objectName, '_mask', 'once'))
                    objectId = obj.myConf.region( ...
                        strcmp(obj.myConf.region.name, objectName), :).id(1);
                    % if empty: means that object is a landsubdivision and not a region:
                    obj.setAdditionalConf('landsubdivision');
                    if isempty(objectId)
                        objectId = obj.myConf.landsubdivision( ...
                            strcmp(obj.myConf.landsubdivision.code, objectName), :).id;
                        if isempty(objectId)
                            errorStruct.identifier = 'ESPEnv:InexistentObjectName';
                            errorStruct.message = sprintf( ...
                                ['%s, getObjectIdentification(): ', ...
                                'Inexistent ObjectName %s in regions or ', ...
                                'landsubdivisions conf.\n'], mfilename(), ...
                                    objectName);
                            error(errorStruct);
                        else
                            objectType = 1;
                        end
                    end
                end
            % Second, we suppose objectName is an objectId...
            elseif ~isempty(objectLabel)
                if ischar(objectLabel)
                    objectId = str2num(objectLabel);
                else
                    objectId = objectLabel;
                end
                objectName = obj.myConf.region( ...
                    obj.myConf.region.id == objectId, :).name;

                % if empty: means that object is a landsubdivision and not a region:
                obj.setAdditionalConf('landsubdivision');
                if isempty(objectName)
                    objectName = obj.myConf.landsubdivision( ...
                        obj.myConf.landsubdivision.id == objectId, :).code;
                    if isempty(objectName)
                        errorStruct.identifier = 'ESPEnv:InexistentObjectId';
                        errorStruct.message = sprintf( ...
                            ['%s, getObjectIdentification(): Inexistent ', ...
                            'ObjectId %s in regions or ', ...
                            'landsubdivisions conf.\n'], mfilename(), ...
                                num2str(objectId));
                        error(errorStruct);
                    else
                        objectType = 1;
                    end
                end
                if isempty(objectName)
                    objectName = '';
                elseif iscell(objectName)
                    objectName = objectName{1};
                end
            end
        end
        function [varId, varName] = getVariableIdentification(obj, varLabel)
            % Parameters
            % ----------
            % varLabel: char or uint8. varId or varName. Must be unique in
            %   configuration_of_variables.csv.
            %
            % Return
            % ------
            % varId: uint8.
            % varName: char. output_name (non-unique).                        @toprecise
            %
            % NB: there are probably cases i don't detect in the condition.     @tocheck
            % we get varId from varName and using configuration_of_variables.csv.
            % % NB: impacts the files sent to web-app and the stc preinterp files.
            % NB: varName should be only used for the geotiffs and we'll need to see
            %   if this can be replaced by varId                                   @todo
            %
            % NB: in conf, name_unique is looked after to find the varId, because unique
            %   but the replacement is output_name, which may not be unique.
            %   For instance, snow_fraction as output_name may refer to modis stc
            %   snow_fraction or modis spires snow_fraction!!!                  @warning

            varId = 0;
            varName = '';
            if isequal(varLabel, varId) | isequal(varLabel, varName)
                return;
            end
            % We suppose first that varLabel is a real name...
            if ischar(varLabel)
                if ~isempty(regexp(varLabel, '[A-Za-z]', 'once')) ...
                    & ~strcmp(varLabel, '')
                    varName = varLabel;
                    varId = obj.myConf.variable( ...
                        strcmp(obj.myConf.variable.name_unique, varName), :).id;
                    % if empty: means that varName is not in configuration:
                    if isempty(varId)
                        errorStruct.identifier = 'ESPEnv:InexistentVarName';
                        errorStruct.message = sprintf( ...
                            ['%s, getVariableIdentification(): Inexistent ', ...
                            'varName %s in variables conf.\n'], mfilename(), ...
                                varName);
                        error(errorStruct);
                    end
                end
            % Second, we suppose varName is an varId...
            else
                if ischar(varLabel)
                    varId = str2num(varLabel);
                else
                    varId = varLabel;
                end
                varName = ...
                    obj.myConf.variable(obj.myConf.variable.id == varId, :).output_name;
                % if empty: means that variable not in configuration:
                if isempty(varName)
                    errorStruct.identifier = 'ESPEnv:InexistentVarId';
                    errorStruct.message = sprintf( ...
                        ['%s, getVariableIdentification(): Inexistent ', ...
                        'varId %s in variables conf.\n'], mfilename(), ...
                            num2str(varId));
                    error(errorStruct);
                end
                varName = varName{1};
            end
        end
        function f = MOD09File(obj, MData, regionName, yr, mm)
            % MOD09File returns the name of a monthly MOD09 cubefile
            % if versionOf value is not empty, use underscore separator
            % Parameters
            % MData: unused SIER_352                                         @deprecated
            modisData = obj.modisData;
            if ~isempty(modisData.versionOf.MOD09Raw)
                sepChar = '_';
            else
                sepChar = '';
            end
            myDir = sprintf('%s%s%s', obj.dirWith.MOD09Raw, sepChar, ...
            modisData.versionOf.MOD09Raw);

            %TODO: make this an optional input
            platformName = 'Terra';
            yyyymm = sprintf('%04d%02d', yr, mm);

            f = fullfile(myDir, ...
                sprintf('v%03d', modisData.versionOf.MODISCollection), ...
                sprintf('%s', regionName), ...
                sprintf('%04d', yr), ...
                sprintf('RawMOD09_%s_%s_%s.mat', ...
                platformName, regionName, yyyymm));
        end
        function f = MosaicFile(obj, region, thisDatetime)
            % Provides the filename of the daily mosaic data file with
            % directory creation if dir doesn't exist
            %
            modisData = obj.modisData;
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
                sprintf('%s', region.regionName), ...
                datestr(thisDatetime, 'yyyy'));
            if ~exist(f, 'dir')
                mkdir(f);
            end
            f = fullfile(f, ...
                sprintf('%s_%s_%s%s.mat', ...
                region.regionName, platformName, ...
                datestr(thisDatetime, 'yyyymmdd'), labelName));
        end
        function projInfo = projInfoFor(obj, tileRegionName)
            % @deprecated. Unmaintained after SIER_320.                       DEPRECATED
            % Don't serve resolution 1000-m anymore.
            %
            % projInfoFor reads and returns tileID's projection information
            mapCellsReference = obj.modisData.getMapCellsReference( ...
                obj.modisData.getTilePositionIdsAndColumnRowCount(tileRegionName));
            projInfo.size_500m = mapCellsReference.RasterSize;
            projInfo.RefMatrix_500m = [[0, -mapCellsReference.CellExtentInWorldX]; ...
                [mapCellsReference.CellExtentInWorldX, 0]; ...
                [mapCellsReference.XWorldLimits(1) - ...
                    mapCellsReference.CellExtentInWorldX / 2, ...
                    mapCellsReference.YWorldLimits(2) + ...
                    mapCellsReference.CellExtentInWorldY / 2]];
            projInfo.size_1000m = mapCellsReference.RasterSize / 2;
            projInfo.RefMatrix_1000m = [[0, -mapCellsReference.CellExtentInWorldX * 2]; ...
                [mapCellsReference.CellExtentInWorldX * 2, 0]; ...
                [mapCellsReference.XWorldLimits(1) - ...
                    mapCellsReference.CellExtentInWorldX * 2 / 2, ...
                    mapCellsReference.YWorldLimits(2) + ...
                    mapCellsReference.CellExtentInWorldY * 2 / 2]];
        end
        function [files, haveDaysPerMonth, expectedDaysPerMonth] = ...
            rawFilesFor3months(obj, MData, regionName, yr, mm, monthPosition)
            % RawFilesFor3months returns MOD09/SCAGDRFS cubes surrounding
            % this month
            % Parameters
            % ----------
            % MData: unused. SIER_352                                        @deprecated
            modisData = obj.modisData;
            region = Regions(regionName, [regionName '_mask'], obj, modisData);

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
                mod09file = obj.MOD09File(modisData, regionName, thisYYYY, thisMM);
                scagfile = obj.SCAGDRFSFile(region, ...
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
        function newPath = replacePatternsInFileOrDirPaths(obj, path, objectName, ...
            dataLabel, thisDate, varName, complementaryLabel, varargin)
            % Parameters
            % ----------
            % path: char. FileName, directoryPath or filePath containing parameter
            % patterns in the form {objectName}, {varName}, etc...
            % objectName: char or int. Name of the tile or region as found in the modis
            %   files and others. E.g. 'h08v04'. Must be unique.
            %   Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            %   can also be objectId, unique id of the subdivision.
            %   In any case, objectId or objectName MUST be present in
            %   configuration_of_regions.csv or configuration_of_landsubdivisions.csv.
            %   NB: long-term goal should be only have objectIds.
            % dataLabel: char. Label (type) of data for which the file is required.
            % thisDate: datetime. Cover the period for which we want the files.
            %   Can also be '' if no argument.
            % varName: char. Name of the variable (name_unique in
            %   configuration_of_variables.csv. Alternatively can be varId, the unique
            %   id of the variable.
            %   Can also be '' if no argument.
            %   NB: long-term goal should be only have varIds.
            % complementaryLabel: char. This Label, if available may precise a
            %   characteristic of the file, e.g. the epsg code of the projection,
            %   e.g. EPSG_3857
            %   Can also be '' if no argument.
            % patternsToReplaceByJoker: cell array(char), optional. List of patterns to
            %   replace by * because we don't know the values.
            %   NB: Only tested for 'nearRealTime', 'versionNumberOfDataCollection'
            %   and 'dateOfHistoric'.
            %
            % Return
            % ------
            % newPath: char. FileName, directoryPath or filePath with the patterns
            %   replaced by values of the parameters contained in the patterns.

            p = inputParser;
            addParameter(p, 'patternsToReplaceByJoker', {});
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;

            % Replacement of patterns by the joker * for patternsToReplaceByJoker
            %(when we don't know certain parts of the file).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            newPath = path;
            for patternIdx = 1: length(patternsToReplaceByJoker)
                newPath = replace(newPath, ...
                    ['{', patternsToReplaceByJoker{patternIdx}, '}'], '*');
            end

            % Determine objectName, objModCode (only used in v2023.1) and objectId.
            % ObjectType: 0: regions, 1: landsubdivisions.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            objectLabel = objectName;
            [objectId, objectName, objectType] = ...
                obj.getObjectIdentification(objectLabel);

            % Determine varName, varId.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            varLabel = varName;
            [varId, varName] = obj.getVariableIdentification(varLabel);

            % Replacement of object and variable infos.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % NB: some replacements by joker have already been done above.
            newPath = replace(newPath, '{objectId}', num2str(objectId));
            newPath = replace(newPath, '{objectName}', objectName);
            newPath = replace(newPath, '{objectId_1000}', ...
                    string(floor(cast(objectId, 'single') / 1000)));

            % Detect near real time folders... Used for JPL files before 2023-10-01.
            if objectType == 0 & ...
                ismember(dataLabel, {'mod09ga', 'modscag', 'moddrfs'})
                if ~isNaT(obj.myConf.region.startDateForHistJplIngest)
                    if ~isNaT(obj.myConf.region.startDateForNrtJplIngest)
                        if thisDate < obj.myConf.region.startDateForNrtJplIngest
                            nearRealTime = 'historic';
                        elseif ~isNaT(obj.myConf.region.endDateForJplIngest) & ...
                            thisDate < obj.myConf.region.endDateForJplIngest
                            nearRealTime = 'NRT';
                        end
                    end
                end
                newPath = replace(newPath, '{nearRealTime}', nearRealTime);
            end

            % Detect sub-infos of subdivisions... Only used for v2023.1 map/stats files.
            if objectType == 1
                objectCode = obj.myConf.landsubdivision( ...
                            obj.myConf.landsubdivision.id == objectId, :).code{1};
                sourceRegionName = obj.myConf.landsubdivision( ...
                    obj.myConf.landsubdivision.id == objectId, :). ...
                    sourceRegionName{1};
                newPath = replace(newPath, '{objectModCode}', ...
                    replace(objectCode, '-', ''));
                newPath = replace(newPath, '{sourceRegionName}', ...
                    sourceRegionName);
            end

            newPath = replace(newPath, '{varId}', num2str(varId));
            newPath = replace(newPath, '{varName}', varName);

            % Replacement of other infos.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            newPath = replace(newPath, '{platform}', obj.modisData.versionOf.platform);
            newPath = replace(newPath, '{versionOfAncillary}', ...
                obj.modisData.versionOf.ancillary);
            newPath = replace(newPath, '{versionOfDataCollection}', ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection));

            if ~exist('complementaryLabel', 'var')
                complementaryLabel = '';
            end
            newPath = replace(newPath, '{EPSGCode}', complementaryLabel);
            newPath = replace(newPath, '{geotiffCompression}', ...
                Regions.geotiffCompression);

            % In the following, if conditions = false, the pattern is kept in place.
            % E.g. if a pattern contains '{thisYear}' and it thisDate is not a datetime,
            % the filePath will keep having the text '{thisYear}'.
            if ismember(dataLabel, fieldnames(obj.modisData.versionOf))
                newPath = replace(newPath, ...
                    '{version}', obj.modisData.versionOf.(dataLabel));
            end

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            if strcmp(class(thisDate), 'datetime')
                newPath = replace(newPath, '{thisYear}', string(thisDate, 'yyyy'));
                thisDateFormat = filePathConf.dateInFileName{1};

                if strcmp(thisDateFormat, 'yyyyJD')
                    replacement = [num2str(year(thisDate)), ...
                        sprintf('%03d', day(thisDate, 'dayofyear'))]
                else
                    replacement = string(thisDate, thisDateFormat);
                end
                newPath = replace(newPath, '{thisDate}', replacement);
            end
        end
        function setAdditionalConf(obj, confLabel)
            % Load additional configuration and add it to the .myConf property. Used to
            % add subdivisions before calculating statistics.
            % NB: this is used to avoir to have a too big ESPEnv object in steps others
            % than statistics (because we store this object as metadata in intermediary
            % data files.
            %
            % Parameters
            % ----------
            % confLabel: char. Label of the configuration, should be fieldname of the
            %   property .additionalConfigurationFilenames.

            if ~ismember(confLabel, fieldnames(obj.additionalConfigurationFilenames))
                errorStruct.identifier = ...
                    'ESPEnv_setAdditionalConf:BadConfLabel';
                errorStruct.message = sprintf(['%s: confLabel should be ', ...
                    'landsubdivision, landsubdivisionlink or landsubdivisionstat.'], ...
                    mfilename());
                error(errorStruct);
            end

            % If the conf had been added to espEnv obj before...
            if ismember(confLabel, fieldnames(obj.myConf))
                return;
            end

            [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
            parts = split(thisFilepath, filesep);
            thisFilepath = join(parts(1:end-1), filesep); % 1 level up
            obj.confDir = fullfile(thisFilepath{1}, 'conf');
            confLabels = fieldnames(obj.configurationFilenames);
            fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
            tmp = ...
                readtable(fullfile(obj.confDir, ...
                obj.additionalConfigurationFilenames.(confLabel)), 'Delimiter', ',');
            tmp([1],:) = []; % delete comment line

            % Convert Date string columns into datetimes.
            % NB: already implemented in ESPEnv(), maybe check how to synthesize through
            % a unique sub-method.                                                 @todo
            theseFieldNames = tmp.Properties.VariableNames;
            for fieldIdx = 1:length(theseFieldNames)
                thisFieldName = theseFieldNames{fieldIdx};
                if contains(thisFieldName, 'Date')
                    tmp.(thisFieldName) = arrayfun(@(x) datetime(x, ...
                        InputFormat = 'yyyy-MM-dd'), tmp.(thisFieldName));
                end
            end

            % Add the versionOfAncillary for landsubdivision.
            if strcmp(confLabel, 'landsubdivision')
                tmp = tmp(tmp.used > 0, :);
                    % Might be necessary to change to == 1 2023-11-15 @todo
                tmp = innerjoin(tmp, obj.myConf.region, ...
                    LeftKeys = 'sourceRegionName', RightKeys = 'name', ...
                    RightVariables = 'versionOfAncillary');
                tmp = tmp(~isnan(tmp.id), :);
            elseif strcmp(confLabel, 'variablestat')
                confLabel2 = 'landsubdivisionstat';
                tmp2 = ...
                    readtable(fullfile(obj.confDir, ...
                        obj.additionalConfigurationFilenames.(confLabel2)), ...
                        'Delimiter', ',');
                tmp = innerjoin(tmp, tmp2, ...
                    LeftKeys = 'landSubdivisionStatId', RightKeys = 'id', ...
                    LeftVariables = {'id', 'landSubdivisionStatId'}, ...
                    RightVariables = {'name', 'type'});
                tmp = renamevars(tmp, {'name', 'type'}, {'landSubdivisionStatName', ...
                    'landSubdivisionStatType'});
                tmp = innerjoin(tmp, obj.myConf.variable, LeftKeys = 'id', ...
                    RightKeys = 'id', LeftVariables = {'id', ...
                    'landSubdivisionStatId', 'landSubdivisionStatName', ...
                    'landSubdivisionStatType'}, RightVariables = {'output_name'});
                tmp = renamevars(tmp, 'id', 'varId');
            end
            obj.myConf.(confLabel) = tmp;
        end
        function f = SCAGDRFSFile(obj, region, ...
            fileType, thisDatetime)
            % SCAGDRFSFile returns the name of a monthly filetype
            % SCAGDRFS cube
            % fileType should be one of obj.dirWith 'SCAGDRFS*' cubes:
            %   SCAGDRFSRaw
            %   SCAGDRFSGap
            %   SCAGDRFSSTC
            %
            % Directory creation if dir doesn't exist
            modisData = obj.modisData;
            regionName = region.regionName;

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
        function f = SnowTodayGeotiffDir(obj, region, geotiffEPSG, year)
            % SIER_163 add parameter geotiffEPSG.
            myDir = sprintf('%s_%s', obj.dirWith.VariablesGeotiff, ...
                obj.modisData.versionOf.VariablesGeotiff);

            f = fullfile(myDir, ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
                sprintf('EPSG_%d', geotiffEPSG), ...
                region.geotiffCompression);
            % SIER_163 year subfolder for EPSG different from the website epsg.
            if geotiffEPSG ~= Regions.webGeotiffEPSG
                f = fullfile(f, string(year));
            end
        end
        function f = SnowTodayGeotiffFile(obj, region, outDir, platformName, ...
	    thisDatetime, varName)
            % This filename for geotiffs is expected by the front-end
            fileName = sprintf('%s_%s_%s_%s.tif', ...
                region.regionName, platformName, datestr(thisDatetime, 'yyyymmdd'), ...
                varName);                	
            f = fullfile(outDir, fileName);
        end
        function [filePath, fileExists] = Step0ModisFilename(obj, region, myDate, varName)
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
            % filePath: char. Full filepath of the daily file received from JPL for the tile and
            %   variable, accessible from the /scratch/alpine/user directory.
            % fileExists: uint8. 0 if the file has not been received or
            % doesn't exist.
            modisData = obj.modisData;
            regionName = region.regionName;
            varConf = obj.myConf.variable(find( ...
                strcmp(obj.myConf.variable.output_name, varName)), :);
            if ~strcmp(varName, 'mod09ga')
                sourceVarName = [varConf.modis_source_name{1} '.dat'];
                source = varConf.modis_source{1};
            else % hdf mod09GA files having reflectance and solar data
                sourceVarName = 'hdf';
                source = 'mod09ga';
            end
            historicFolderName = 'historic';
            if myDate > modisData.endDateOfHistoricJPLFiles
                historicFolderName = 'NRT';
            end

            directory = fullfile(obj.scratchPath, 'modis', source, historicFolderName, ...
                sprintf('v%03d', modisData.versionOf.MODISCollection), ...
                regionName, sprintf('%04d', year(myDate)));
            searchFilename = sprintf('MOD09GA.A%04d%03d.%s.*.*.%s', ...
                    year(myDate), day(myDate, 'dayofyear'), regionName, ...
                    sourceVarName);
            fileStruct = dir(fullfile(directory, searchFilename));
            if isempty(fileStruct)
                filePath = fullfile(directory, searchFilename);
                fileExists = 0;
            else
                filePath = fullfile(directory, fileStruct(end).name);
                fileExists = 1;
            end
        end
        function f = SummarySnowFile(obj, region, startYr, stopYr)
            % SummarySnowFile returns the name of statistics summary file
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsMatlab, ...
                obj.modisData.versionOf.RegionalStatsMatlab);

            f = fullfile(myDir, ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
                sprintf('%04d_to_%04d_%sby%s_Summary.mat', ...
                startYr, stopYr, region.regionName, ...
                region.maskName));
        end
        function f = SummaryCsvDir(obj, region, waterYearDate)
            % SummaryCsvDir returns the dir with csv versions of statistics summary file
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsCsv, ...
                obj.modisData.versionOf.RegionalStatsCsv);

            f = fullfile(myDir, ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
		sprintf('WY%04d', waterYearDate.getWaterYear()));
        end
        function f = SummaryCsvFile(obj, region, subRegionIdx, outDir, varName, waterYear)
	    % This filename for csv stats summary files is expected by the front-end
	    fileName = sprintf('SnowToday_%s_%s_WY%04d_yearToDate.csv', ...
                region.ShortName{subRegionIdx}, varName, waterYear);                	
            f = fullfile(outDir, fileName);
        end
%{
        function f = LandsatScagDirs(obj, platform, path, row, varargin)
            %                                                                  @obsolete
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
            %                                                                  @obsolete
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
        function f = MODICEFile(obj, version, tileID, ...
            yr, nstrikes, fileType, varargin)
            %                                                                  @obsolete
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
        function f = SnowTodayFile(obj, MData, ...
            regionName, ...
            shortName, ...
            inputDt, creationDt, labelName)
            %                                                                  @obsolete
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
        function f = geotiffFile(~, extentName, platformName, sensorName, ...
        baseName, varName, version)
            %                                                                  @obsolete
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
        %                                                                      @obsolete
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
            %                                                                  @obsolete
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
            %                                                                  @obsolete
            % heightmaskFile returns the current height mask file name

            f = dir(fullfile(obj.heightmaskDir, ...
            'Sierra_utm_LandFire_EVH_gt2.5m_mask.tif'));
        end
        function s = heightmask(obj)
            %                                                                  @obsolete
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
            %                                                                  @obsolete
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
            %                                                                  @obsolete
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
            %                                                                  @obsolete
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
            %                                                                  @obsolete
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
        function s = readShapefileFor(obj, shapeName, varargin)
            %                                                                  @obsolete
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
%}
    end
end
