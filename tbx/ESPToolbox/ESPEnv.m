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
            landsubdivisiontype = 'configuration_of_landsubdivisiontypes.csv');
        configurationFilenames = struct( ...
            filePath = 'configuration_of_filepaths.csv', ...
            filter = 'configuration_of_filters.csv', ...
            region = 'configuration_of_regions.csv', ...
            regionlink = 'configuration_of_regionlinks.csv', ...
            variable = 'configuration_of_variables.csv', ...
            variableregion = 'configuration_of_variablesregions.csv');
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
    end
    methods
        function obj = ESPEnv(varargin)
            % The ESPEnv constructor initializes all directory settings
            % based on locale
            %
            % Parameters
            % modisData: MODISData obj.
            %   NB: modisData should now be obligatory 2023/06/14                  @todo
            % scratchPath: char. Top path where ancillary and data will be got and
            %   transferred to.

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

            % Order the filter table by the order in which the filtering should be
            % processed. Redundant with precedent?                              @tocheck
            obj.myConf.filter = sortrows(obj.myConf.filter, [1, 2]);

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
            objectName, dataLabel, thisDate, varName)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            % thisDate: datetime. Cover the period for which we want the
            %   files.
            % varName: name of the variable to load (name in the file, not output_name
            %   of configuration_of_variables.csv).
            %
            % Return
            % ------
            % varData: data array read.
            %
            % NB: only works for dataLabel in VariablesMatlab.
            % NB: doesn't check if the variable is present in file.                @todo

            % 1. Check valid dataLabel and get file for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            [filePath, fileExists, ~] = ...
                obj.getFilePathForDateAndVarName(objectName, dataLabel, thisDate, ...
                    varName);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.

            % 2. Construction of the array of values extracted from the files.
            %---------------------------------------------------------------------------
            varData = [];
            if fileExists == 1
                % In regular process, a proper
                % handling of thisDate and of the generation of files (potentially
                % with nodata/NaN-filled variables) should make all files present and
                % the last condition useless.
                varData = parloadMatrices(filePath, varName);
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
            % NB: only works for dataLabel in MOD09Raw or SCAGRaw.
            % NB: doesn't check if the variable is present in file.                @todo

            % 1. Check valid dataLabel and get list of files for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            varConf = obj.myConf.variable(strcmp(obj.myConf.variable.output_name, ...
                varName), :);

            [filePath, fileExists, ~, ~] = ...
                obj.getFilePathForWaterYearDate(objectName, dataLabel, waterYearDate);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.
            filePath = filePath(fileExists == 1); % In regular process, a proper
                % handling of waterYearDate and of the generation of files (potentially
                % with nodata/NaN-filled variables) should make all files present and
                % this command useless.

            % 2. Construction of the array of values extracted from the files.
            %---------------------------------------------------------------------------
            varData = [];
            if strcmp(varName, filePathConf.dateFieldName{1})
                for fileIdx = 1:size(filePath, 2)
                    [varDataT] = parloadDts(filePath{fileIdx}, varName);
                    if fileIdx == 1
                        varData = varDataT{1}';
                    else
                        varData = [varData varDataT{1}'];
                    end
                end
                varData = datenum(varData);
            elseif strcmp(varName, 'RefMatrix')
                varData = parloadMatrices(filePath{1}, 'RefMatrix');
            else
                for fileIdx = 1:size(filePath, 2)
                    varDataT = parloadMatrices(filePath{fileIdx}, varName);
                    if strcmp(varName, 'NoValues') && fileIdx == 1
                        varData = varDataT;
                    elseif strcmp(varName, 'refl')
                        varData = cat(4, varData, varDataT);
                    else
                        varData = cat(3, varData, varDataT);
                    end
                end
            end
        end
        function [filePath, fileExists, lastDateInFile] = ...
            getFilePathForDateAndVarName(obj, objectName, dataLabel, thisDate, varName)
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
            %
            % Return
            % ------
            % filePath: char.
            % existFile: uint8. 0 if file doesn't exist.
            % lastDateInFile: datetime. Provided for .mat extension only.

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
            for subFolderIdx = 1:6
                subFolder = ...
                    filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                if ~isempty(subFolder)
                    directoryPath = fullfile(directoryPath, subFolder);
                end
            end
            directoryPath = obj.replacePatternsInFileOrDirPaths(directoryPath, ...
                objectName, dataLabel, thisDate, varName);
            if ~isfolder(directoryPath)
                mkdir(directoryPath);
            end

            % 2. Generation of the filename, check existence and determine last date
            %   in file.
            %---------------------------------------------------------------------------
            fileName = [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}];
            fileName = obj.replacePatternsInFileOrDirPaths(fileName, ...
                objectName, dataLabel, thisDate, varName);

            filePath = fullfile(directoryPath, fileName);
            fileExists = isfile(filePath);
            lastDateInFile = [];
            if fileExists == 1 & strcmp(filePathConf.fileExtension{1}, '.mat') & ...
                length(filePathConf.dateFieldName{1}) > 0
                lastDateInFile = max( ...
                        load(filePath, filePathConf.dateFieldName{1}).( ...
                            filePathConf.dateFieldName{1}));
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
            for subFolderIdx = 1:6
                subFolder = ...
                    filePathConf.(['fileSubDirectory', num2str(subFolderIdx)]){1};
                if ~isempty(subFolder)
                    directoryPath = fullfile(directoryPath, subFolder);
                end
            end
            directoryPath = obj.replacePatternsInFileOrDirPaths(directoryPath, ...
                objectName, dataLabel, '', '');
            if ~isfolder(directoryPath)
                mkdir(directoryPath)
            end

            % Construction of the filename.
            fileName = [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}];
            fileName = obj.replacePatternsInFileOrDirPaths(fileName, ...
                objectName, dataLabel, '', '');
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
                for subFolderIdx = 1:6
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
        function objectNames = getObjectNamesForDataLabelAndDateAndVarName(obj, ...
            dataLabel, thisDate, varName)
            % Parameters
            % ----------
            % dataLabel: char. Label (type) of nrt/historic data or ancillary data
            % for which the file is required,
            %   e.g. spiresDaily or landsubdivisionlinkinjson. For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            % thisDate: datetime. For which we want the file.
            % varName: char. Variable name. Can be '' if files of the dataLabel are not
            %   split between variables.
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

            % Initialize ...
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
                dataLabel, thisDate, varName);
            filePath = replace(filePath, ...
                [filesep(), num2str(floor( ...
                    cast(str2num(fakeObjectName), 'single') / 1000)), filesep()], ...
                [filesep(), '*', filesep()]);
            filePath = replace(filePath, ...
                ['_', fakeObjectName, '_'], ['_*_']);
            filePath = replace(filePath, ...
                [filesep(), fakeObjectName, '_'], [filesep(), '*_']);

            % Get the files:
            objectNames = struct2table(dir(filePath)).name;
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
            fileNamePattern = fileNamePattern(end);
            fileNamePattern = split(fileNamePattern, '*');
            fileNamePattern = fileNamePattern(~strcmp(fileNamePattern, ''));
                % remove empties, otherwise replace below doesn't work.

            replaceForFun = @(x) replace(x, fileNamePattern, ...
                repelem({''}, size(fileNamePattern, 1))');
                    % Anomymous function to apply to the cell array below.
            objectNames = cellfun(replaceForFun, objectNames, 'UniformOutput', false);
                % NB: don't write @replaceForFun, since replaceForFun already equals
                % a handler.
        end
        function webRelativeFilePath = getRelativeFilePathForWebIngest(obj, ...
            objectName, dataLabel, thisDate, varName)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'. TO CHECK IF COMMENT STILL VALID @tocheck
            % label: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. spiresDaily.
            % thisDate: datetime. For which we want the file.
            %   NB/trick: for the SubdivisionStatsWebCsv, this is a date which year is
            %   the ongoing waterYear.
            % varName: name of the variable. Currently only used for
            %   SubdivisionStatsWebCsv (2023-09-30), otherwise set to ''.
            %
            % Return
            % ------
            % filePath: char. Relative filePath on the web ingest domain.

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            if isempty(filePathConf)
                errorStruct.identifier = ...
                    'ESPEnv:getFilePathForDate:NoConfForDataLabel';
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in configuration_of_filepaths.csv file.'], ...
                    mfilename(), dataLabel);
                error(errorStruct);
            end
            webRelativeFilePath = [filePathConf.webDirectory{1}, ...
                filePathConf.webFileLabel{1}, filePathConf.fileExtension{1}];
            webRelativeFilePath = obj.replacePatternsInFileOrDirPaths( ...
                webRelativeFilePath, objectName, dataLabel, thisDate, varName);
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
            dataLabel, thisDate, varName, complementaryLabel)
            % Parameters
            % ----------
            % path: char. FileName, directoryPath or filePath containing parameter
            % patterns in the form {objectName}, {varName}, etc...
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required.
            % thisDate: datetime. Cover the period for which we want the files.
            % varName: char. Name of the variable (output_name in
            %   configuration_of_variables.csv.
            % complementaryLabel: char. This Label, if available may precise a 
            %   characteristic of the file, e.g. the epsg code of the projection, 
            %   e.g. EPSG_3857
            %
            % Return
            % ------
            % newPath: char. FileName, directoryPath or filePath with the patterns
            %   replaced by values of the parameters contained in the patterns.
            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);

            newPath = replace(path, '{versionOfAncillary}', ...
                obj.modisData.versionOf.ancillary);
            newPath = replace(newPath, '{versionOfDataCollection}', ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection));
            if isnumeric(objectName)
                objectName = num2str(objectName);
            end
            newPath = replace(newPath, '{objectName}', objectName);
            newPath = replace(newPath, '{platform}', obj.modisData.versionOf.platform);
            if isnumeric(varName)
                varName = num2str(varName);                
            end
            newPath = replace(newPath, '{varId}', varName); 
                % Here we don't follow the logic when objectId is objectName in the
                % patterns and we have varId and varName in the patterns. Check what
                % we can do to be cleaner.   @todo
            newPath = replace(newPath, '{varName}', varName);
            if ~exist('complementaryLabel', 'var')
                complementaryLabel = '';
            end
            newPath = replace(newPath, '{ESPGCode}', complementaryLabel);
            newPath = replace(newPath, '{geotiffCompression}', ...
                Regions.geotiffCompression);            

            % In the following, if conditions = false, the pattern is kept in place.
            % E.g. if a pattern contains '{thisYear}' and it thisDate is not a datetime,
            % the filePath will keep having the text '{thisYear}'.
            if ismember(dataLabel, fieldnames(obj.modisData.versionOf))
                newPath = replace(newPath, ...
                    '{version}', obj.modisData.versionOf.(dataLabel));
            end
            objectId = [];
            % we get objectId from objectName. Code below is to make certain that
            % objectId is numeric and single, I don't trust Matlab and its automatic
            % conversion which can make the division below a integer division we don't
            % want to because it will round to the closest int and not the floor int.
            if strcmp(class(objectName), 'char')
                objectId = str2num(objectName);
            elseif isnumeric(objectName)
                objectId = objectName;
            end
            if ~isempty(objectId)
                objectId = cast(objectId, 'single');
                newPath = replace(newPath, '{objectName_1000}', ...
                    string(floor(objectId / 1000)));
            end
            if strcmp(class(thisDate), 'datetime')
                newPath = replace(newPath, '{thisYear}', string(thisDate, 'yyyy'));
                newPath = replace(newPath, '{thisDate}', string(thisDate, ...
                    filePathConf.dateInFileName{1}));
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

            directory = fullfile(modisData.alternateDir, source, historicFolderName, ...
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
