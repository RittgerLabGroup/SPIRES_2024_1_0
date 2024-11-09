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
        archivePath % char. Path where are archived the files. Only used to pull input
            % files or push output files.
        confDir         % directory with configuration files (including variable names)
        defaultArchivePath % getenv('espArchiveDir');
        defaultScratchPath % getenv('espScratchDir');
        dirWith % struct with various STC pipeline directories
        espWebExportConfId = 0; % int. 0: generation for prod web-app. 1: for
          % integration web-app, 2: for QA web-app.
        filterMyConfByVersionOfAncillary = 1; % 1: configuration is filtered by
            % versionOfAncillary, which means that only regions and subdivisions
            % having the versionOfAncillary indicated in .modisData will be available
            % through .myConf of the object. 0: versionOfAncillary filter not applied.
        lastCallToGetFilePathForWaterYearDate = struct(); % Struct containing the list
            % of the
            % last call to getFilePathForWaterYearDate(). Mostly to avoid reconstruct
            % the list at each call.
            % struct(objectName = int/char, dataLabel = char, waterYearDate=
            % WaterYearDate, filePath = cell(char), lastDateInFile = array(datetime),
            % newWaterYearDate = WaterYearDate, metaData = struct()).
            % NB: exclude files wich dont exist.
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
        slurmEndDate  % datetime. When running on slurm, indicates when the job will
            % a kill signal [cancel].
        slurmFullJobId % char. When running on slurm, id of the job (jobId_taskId).
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
            datalabellink = 'configuration_of_datalabellinks.csv', ...
            filePath = 'configuration_of_filepaths.csv', ...
            filter = 'configuration_of_filters.csv', ...
            region = 'configuration_of_regions.csv', ...
            regionlink = 'configuration_of_regionlinks.csv', ...
            variable = 'configuration_of_variables.csv', ...
            variablelink = 'configuration_of_variableslinks.csv', ...
            variableregion = 'configuration_of_variablesregions.csv', ...
            versionregion = 'configuration_of_versionsregions.csv', ...
            versionvariable = 'configuration_of_versionsvariables.csv');
        defaultHostName = 'CURCScratchAlpine';
        espEnvironmentVars = {'espArchiveDir', 'espProjectDir', 'espScratchDir'};
            % List of the variables which MUST be defined at the OS environment level.
        % defaultPublicOutputPath = 'xxx/esp_public/';
        patternsInFilePath = table({ ...
            'EPSGCode', 'columnStartId', 'columnEndId', ...
            'inputProduct', 'deviceUC', 'processLevelUC', ...
            'inputProductVersion', 'collection', 'collectionCategoryUC', ...
            'geotiffCompression', 'monthWindow', 'nearRealTime', ...
            ...
            'objectId', 'objectName', 'objectId_1000', ...
            'platform', 'processDate', ...
            'rowStartId', 'rowEndId', ...
            'shortObjectName', 'slurmFullJobId', ...
            'timestampAndNrt', 'thisDate', ...
            ...
            'thisIndex', 'thisIndex_1M', 'thisIndex_1000', ...
            'thisWaterYear', 'thisYear', ...
            'varId', 'varName', 'version', 'versionOfAncillary', ...
            'versionOfDataCollection'}', { ...
            ...
            'EPSG_[0-9]+', '[0-9]+', '[0-9]+', ...
            '[a-zA-Z0-9\.]+', '[A-Z0-9]+', '[A-Z0-9]+', ...
            '[0-9t\.]+', '[0-9]+', '[0-9T]+', ...
            '[a-zA-Z]+', '[0-9]{1,2}', '[a-zA-Z]+', ...
            ...
            '[0-9]+', '[a-zA-Z0-9]*', '[0-9]{1,3}', ...
            '[a-zA-Z]', '[0-9\.]+', ...
            '[0-9]+', '[0-9]+', ...
            '[a-zA-Z0-9]*', '[0-9]+\_[0-9]+', ...
            '[0-9\.NRT]*', '[0-9\.]+', ...
            ...
            '[0-9]+', '[0-9]{1}', '[0-9]{1,3}', ...
            '2[0-9]{3}', '2[0-9]{3}', ...
            '[0-9]{1,3}', '[a-zA-Z_]+[0-9]?', 'v[0-9\.a-z]+', 'v[0-9\.]+', ...
            'v[0-9]{3}'}', ...
            VariableNames = {'toReplace', 'replacingRegexp'});
            % NB: timestampAndNrt can also be a process date of the format yyyyMMdd.
        rsyncAlias = '/bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s';
        slurmSafetySecondsBeforeKill = 3 * 60; % in seconds.
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
            [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
            parts = split(thisFilepath, filesep);
            thisFilepath = join(parts(1:end-1), filesep); % 1 level up
            confDir = fullfile(thisFilepath{1}, 'conf');
            confLabel = 'region';
            fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
            allRegionsConf = ...
                readtable(fullfile(confDir, ...
                ESPEnv.configurationFilenames.(confLabel)), 'Delimiter', ',');
            allRegionsConf(1,:) = []; % delete comment line
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
            originalEspEnv, varargin)
        % Parameters
        % ----------
        % regionName: char. Name of the region. Should be in column name of file
        %   configuration_of_regions.csv.
        % originalEspEnv: ESPEnv. A primary ESPEnv, from which some of the properties
        %   will be copied, for instance modisData.versionOf for all except ancillary
        %   and scratchPath. This way the new espEnv object can handle different
        %   versionLabels for input files and output files.
        % version: char, optional. Label of version, if different from originalEspEnv.
        %   E.g. v2024.0f
        % versionOfAncillary: char, optional. Version of ancillary if different from
        %   regionName conf. E.g. v3.2.
        %
        % Return
        % ------
        % espEnv: ESPEnv object with the correct modisData attribute associate to the
        %   version of Ancillary data linked to the region (e.g. v3.1).

        % Load configuration files (paths of ancillary data files and region conf).
        %------------------------------------------------------------------------------
            p = inputParser;
            addParameter(p, 'version', '');
            addParameter(p, 'versionOfAncillary', '');
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            version = p.Results.version;
            versionOfAncillary = p.Results.versionOfAncillary;
            
            if isempty(versionOfAncillary)
                [thisFilepath, ~, ~] = fileparts(mfilename('fullpath'));
                parts = split(thisFilepath, filesep);
                thisFilepath = join(parts(1:end-1), filesep); % 1 level up
                confDir = fullfile(thisFilepath{1}, 'conf');
                confLabel = 'region';
                fprintf('%s: Load %s configuration\n', mfilename(), confLabel);
                allRegionsConf = ...
                    readtable(fullfile(confDir, ...
                    ESPEnv.configurationFilenames.(confLabel)), 'Delimiter', ',');
                allRegionsConf(1,:) = []; % delete comment line
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
                versionOfAncillary = thisRegionConf.versionOfAncillary{1};
            end
            if isempty(version)
                version = originalEspEnv.modisData.versionOf.SubdivisionStatsDailyCsv;
            end
                
            modisData = MODISData(label = version, ...
                versionOfAncillary = versionOfAncillary, ...
                inputProduct = originalEspEnv.modisData.inputProduct, ...
                inputProductVersion = originalEspEnv.modisData.inputProductVersion);
                    % versionOf.SubdivisionStatsDailyCsv chosen arbitrarily.
            espEnv = ESPEnv(modisData = modisData, ...
                archivePath = originalEspEnv.defaultArchivePath, ...
                espWebExportConfId = originalEspEnv.espWebExportConfId, ...
                scratchPath = originalEspEnv.scratchPath, ...
                filterMyConfByVersionOfAncillary = ...
                    originalEspEnv.filterMyConfByVersionOfAncillary);
        end
    end
    methods
        function obj = ESPEnv(varargin)
            % The ESPEnv constructor initializes all directory settings
            % based on locale
            %
            % Parameters
            % ----------
            % espWebExportConfId % int, optional. Flag indicating which web-app is
            %   targeted for export. Only used at the last step of the pipeline, during
            %   export to the web-app. 0: default, generation for prod web-app. 1: for
            %   integration web-app, 2: for QA web-app.
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
            addParameter(p, 'espWebExportConfId', 0);
            addParameter(p, 'modisData', []);
                % Impossible to have parameter w/o default value?
            addParameter(p, 'archivePath', obj.defaultArchivePath);
            % User's scratch locale is default, because it is fast
            addParameter(p, 'scratchPath', obj.defaultScratchPath);
            addParameter(p, 'filterMyConfByVersionOfAncillary', ...
                obj.filterMyConfByVersionOfAncillary);

            p.KeepUnmatched = false;
            parse(p, varargin{:});
            % If-Else to prevent instantiating a default MODISData by using
            % default parameter in addParameter.
            obj.espWebExportConfId = p.Results.espWebExportConfId;

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
            obj.archivePath = p.Results.archivePath;
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
                tmp(1,:) = []; % delete comment line

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
                if isa(subFolder, 'double')
                    idx = isnan(subFolder);
                    subFolder = num2cell(subFolder);
                    subFolder(idx) = {''};
                    obj.myConf.filePath.(['fileSubDirectory', ...
                        num2str(subFolderIdx)]) = subFolder;
                end
            end
            fprintf('%s: Filtered filepath configuration.\n', mfilename());

            % Restrict dataLabel links.
            % NB: Not sure if we need to keep it.                                  @todo
            obj.myConf.datalabellink = ...
                obj.myConf.datalabellink(obj.myConf.datalabellink.used >= 1, :);
            obj.myConf.datalabellink.used = [];

            % Associate list of variables by dataLabel and version to dataLabel
            % input/output links and restrict the variables by dataLabel and version
            % only to the versions associated to the modisData of this object.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            obj.myConf.versionvariable = ...
                obj.myConf.versionvariable(obj.myConf.versionvariable.used >= 1, :);
            obj.myConf.versionvariable.used = [];

            thisDataLabel = fieldnames(obj.modisData.versionOf);
            thisVersion = struct2cell(obj.modisData.versionOf);
            theseVersionsDataLabels = table(thisDataLabel, thisVersion);

            obj.myConf.versionvariable = innerjoin(obj.myConf.versionvariable, ...
                theseVersionsDataLabels, LeftKeys = 'outputDataLabel', ...
                RightKeys = 'thisDataLabel');
            obj.myConf.versionvariable = obj.myConf.versionvariable( ...
                strcmp(obj.myConf.versionvariable.outputVersion, ...
                obj.myConf.versionvariable.thisVersion), :);
            obj.myConf.versionvariable.thisVersion = [];
            obj.myConf.versionvariable = outerjoin(obj.myConf.versionvariable, ...
                theseVersionsDataLabels, LeftKeys = 'inputDataLabel', ...
                RightKeys = 'thisDataLabel', Type = 'left');
                % outerjoin left to keep dataLabels without any specific
                % input dataLabels.
            obj.myConf.versionvariable = obj.myConf.versionvariable( ...
                strcmp(obj.myConf.versionvariable.inputVersion, ...
                obj.myConf.versionvariable.thisVersion), :);
            obj.myConf.versionvariable.thisVersion = [];
            isNameWithinFileEmpty = isempty(obj.myConf.versionvariable.nameWithinFile);
            obj.myConf.versionvariable.nameWithinFile(isNameWithinFileEmpty) = ...
                obj.myConf.versionvariable.name(isNameWithinFileEmpty);

            % Order the filter table by the order in which the filtering should be
            % processed. Redundant with precedent?                              @tocheck
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

            obj.setAdditionalConf('landsubdivision', confFieldNames = {'name', 'id', ...
                'code', 'sourceRegionId', 'sourceRegionName', ...
                'firstMonthOfWaterYear', 'versionForProd', 'versionForIntegration', ...
                'versionOfAncillary'});

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
            if ~isempty(getenv('SLURM_SCRATCH')) && ...
                isfolder(getenv('SLURM_SCRATCH')) && ...
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

            % Initialize lastCall properties.
            %---------------------------------------------------------------------------
            obj.lastCallToGetFilePathForWaterYearDate.objectName = '';
            
            % Default now + 24 h for slurmEndDate, if espEnv used outside of slurm.
            obj.slurmEndDate = datetime('now') + 1;
            obj.slurmFullJobId = '';
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

            if ~exist('maxWorkers', 'var') || isnan(maxWorkers)
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
                if maxWorkers == 0 || maxWorkers > S.cluster.NumWorkers
                    maxWorkers = S.cluster.NumWorkers;
                end
                S.pool = parpool(S.cluster, maxWorkers, IdleTimeout = 60 * 24); % 2024-07-14 no automatic shutdown of a pool before a day (spiresFill constraints)
                S.cluster.disp();
            end
            S.pool.disp();
        end
        function f = configurationOfVariables(obj)
            %                                                                @deprecated
            f = obj.myConf.variable;
        end
        function checkSlurmJobStatus(obj)
            % Check whether the slurm job has been cancelled and if yes launch an error.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.checkSlurmJobStatus';
            objectName = '';
            dataLabel = 'espjobforscancel';
            
        end
        function [varData, conversionMask] = getAndSaveData(obj, objectName, inputDataLabel, ...
            outputDataLabel, varargin)
            % Extract the data from a file of type inputDataLabel, convert to the type,
            %   nodata, min, max, fill missings, and resample them if necessary with
            %   resamplingFactor, create a bit mask of the data which have been changed
            %   (cap min max, fill missings), save varData in the file of type
            %   outputDataLabel and return it.
            % Parameters
            % ----------
            % objectName: char. Unique name of the object, either region (type 0) or
            %   subdivision (type 1). Configuration in espEnv.myConf.region and
            %   espEnv.myConf.landsubdivision. Necessary to get the number of days
            %   of a waterYear.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw. Configuration
            %   in espEnv.myConf.variableversion.
            % theseDate: datetime or array(datetime) [firstDate, lastDate], optional.
            %   Cover the period for which we want the data instantiated. Configuration
            %   in espEnv.myConf.filePath, field period and dimensionInfo. Default:
            %   today.
            % varName: char, optional. Necessary to know if there's resampling (is
            %   this variable in 1200x1200 (resamplingFactor 2) or 2400x2400 (factor 1).
            %   Default: 'defaultVarName' (resamplingFactor 1).
            % complementaryLabel: char, optional. Only used to add EPSG code for
            %   geotiffs. E.g. EPSG_3857.
            % monthWindow: int, optional. MonthWindow of the data within the file.
            % timestampAndNrt: char, optional. Only for mod09ga files.
            % patternsToReplaceByJoker: cell array(char), optional.
            %   List of arguments (patterns)
            %   we don't a priori know. The filepath in that case will be found using
            %   a dir cmd (replacing some unknown patterns by the joker *).
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, minMaxCut), optional. Used to
            %   override varName configuration.
            %   outputDataLabel: char. We expect the data the format given by the
            %       outputDataLabel. Can be overriden by the values of other fields of
            %       force.
            %   divisor: float. The data extracted are divided by this value.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   resamplingMethod: char. Method of resampling used for imresize. If
            %       not given, use default Matlab method.
            %   fillMissing: struct. Only accept fillMissing = {'inpaint_nans', n}.
            %       If set, indicates that the missing values (noData) are filled with
            %       the function inpaint_nans() and argument 4 (method).
            %   minMaxCut: 0-2. Default: 0, no cut. 1: if varData below min, or above
            %       max, correct value to be min, or max, respectively, without taking
            %       into account nodata_value. 2: the values below min and above max
            %       are set to nodata.
            %       NB: even if minMaxCut = 0 or 2, a conversion to a type (uint8 e.g.)
            %       can cut the values.                                         @warnin
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metaData recorded in output file,
            %       doesnt update any data ( = skip). 1: if input filename and its
            %       modification date (lastEditDate) are identic to metaData recorded in
            %       output file, doesnt update the data directly extracted from the
            %       input (i.e. using espEnv.getAndSaveData(), but update the data
            %       calculated. 10: update everything in any case ( = redo).
            %       IMPORTANT: right now only saves if force = 10.                 @todo
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % varData: array(int or float). 1 to 3 D array of data potentially of type
            %   converted or values capped to min max.
            % conversionMask: array(uint8). Bit array indicating the pixels that have
            %   changed under the fillmissing and cut of min/max. Pos 1: no data.
            %   2: value below range. 3: value above range.
            %
            % NB: Right now this method saves in only 1 file. This is why we call
            %   getFilePathForDateAndVarName, and we supply only 1 date.
            %
            % RMQ: getAndSaveData() handle the type/divisor/nodata from inputLabel and
            % outputLabel, based on what is in espEnv.myConf.versionvariable and
            % variable. It replaces nan by nodata and conversely when necessary.
            % RMQ: We dont check if data were already got/updated and we directly
            %   replace them. The existence of data previously saved should be checked
            %   at a higher level.
            % NB: For mod09ga to modspires, angles and state are saved at resolution
            %   1200x1200.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.getAndSaveData';
            p = inputParser;
            force = struct();
            defaultOptim = struct(force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'theseDate', datetime('today'));
            addParameter(p, 'varName', 'defaultVarName');
            addParameter(p, 'complementaryLabel', '');
            addParameter(p, 'patternsToReplaceByJoker', {});
            addParameter(p, 'monthWindow', WaterYearDate.yearMonthWindow);
            addParameter(p, 'timestampAndNrt', '');

            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;

            theseDate = p.Results.theseDate;
            varName = p.Results.varName;
            if size(theseDate, 2) == 1
                theseDate = [theseDate, theseDate];
            end % to get a start and end.
            complementaryLabel = p.Results.complementaryLabel;
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;
            monthWindow = p.Results.monthWindow;
            timestampAndNrt = p.Results.timestampAndNrt;

            dataLabel = inputDataLabel;
            thisDate = theseDate(1);
            force.outputDataLabel = outputDataLabel;
            [varData, conversionMask] = obj.getDataForDateAndVarName(...
                objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                force = force, optim = optim, ...
                patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                monthWindow = monthWindow, timestampAndNrt = timestampAndNrt);
            % if optim.force == 10
                dataLabel = outputDataLabel;
                % Since the data have been already converted in
                % getDataForDateAndVarName(), we don't convert them again in saveData()
                % and set force = nothing.
                force = struct();
                obj.saveData(varData, objectName, dataLabel, theseDate = theseDate, ...
                    varName = varName, force = force, optim = optim);
                fprintf(['%s: Saved , object: %s, thisDate: %s, ', ...
                    ' varName: %s, inputDataLabel: %s, outputDataLabel, %s, ' ...
                    'cellIdx: [%s], countOfCellPerDimension: [%s], ', ...
                    'force: %d, logLevel: %d, ', ...
                    'parallelWorkersNd: %d...\n'], thisFunction, objectName, ...
                    char(thisDate, 'yyyy-MM-dd'), varName, inputDataLabel, ...
                    outputDataLabel, join(num2str(optim.cellIdx), ', '), ...
                    join(num2str(optim.countOfCellPerDimension), ', '), ...
                    optim.force, optim.logLevel, optim.parallelWorkersNb);
            % end
            % NB: I didnt develop yet the cases when we have to check
            %   the metaData metaData.day.inputFileName{dayInWaterYear}) and
            %   metaData.day.inputFileLastEditDate{dayInWaterYear} and compare them to
            %   the input file and see if we effectively save or not. 
            % This should be handled at a higher level now.                        @todo
        end
        function [varData, conversionMask] = getDataForDateAndVarName(obj, ...
            objectName, dataLabel, thisDate, varName, complementaryLabel, varargin)
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
            % monthWindow: int, optional. MonthWindow of the data within the file.
            % timestampAndNrt: char, optional. Only for mod09ga files.
            % patternsToReplaceByJoker: cell array(char), optional.
            %   List of arguments (patterns)
            %   we don't a priori know. The filepath in that case will be found using
            %   a dir cmd (replacing some unknown patterns by the joker *).
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, fillMissing, minMaxCut), optional. Used to
            %   override varName configuration.
            %   outputDataLabel: char. We expect the data the format given by the
            %       outputDataLabel. Can be overriden by the values of other fields of
            %       force.
            %   divisor: float. The data extracted are divided by this value.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   resamplingMethod: char. Resampling method: default bicubic, but can be
            %       nearest, bilinear (see matlab doc).
            %   fillMissing: struct. Only accept fillMissing = {'inpaint_nans', n}.
            %       If set, indicates that the missing values (noData) are filled with
            %       the function inpaint_nans() and argument 4 (method).
            %   minMaxCut: 0-2. Default: 0, no cut. 1: if varData below min, or above
            %       max, correct value to be min, or max, respectively, without taking
            %       into account nodata_value. 2: the values below min and above max
            %       are set to nodata.
            %       NB: even if minMaxCut = 0 or 2, a conversion to a type (uint8 e.g.)
            %       can cut the values.                                         @warnin
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %       IMPORTANT: irrelevant here.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            %   NB: Allow concatenation of files only for .csv (stats).         @warning

            %
            % Return
            % ------
            % varData: data array or table read. NB: when optional
            %   patternsToReplaceByJoker yields a list of files, if .mat extension,
            %   only the data of the first file are returned, if .csv the data of all
            %   files are contenated. NB: if the .csv files have distinct headers,
            %   matlab raises an error.
            % conversionMask: array(uint8). Bit array indicating the pixels that have
            %   changed under the fillmissing and cut of min/max. Pos 1: no data.
            %   2: value below range. 3: value above range.
            %
            % NB: only works for dataLabel in VariablesMatlab.
            % NB: doesn't check if the variable is present in file.                @todo
            % NB: For .h5 files, gets only the 2400x2400 raster data corresponding to
            % 1 date (not the full dataset or full year). The date in the file should be
            % formatted yyyyJD (2001275 e.g.). Designed to extract spires waterYear
            % output
            % to build mosaic daily files, to plug to the Subdivision/Region.geotiff/
            % exportWebsite pipeline more easily (2024-01-22).                  @warning
            % NB: Multiple files are only available for .csv files right now
            % (2024-01-22).                                                     @warning
            % NB: For some files, the variable retrieved has its name distinct from
            % varName, associated with varNameWithinFile in conf_of_filepaths.csv,
            % with links a certain field in conf_of_variables.csv.
            % NB: The method can provide a reshaped varData, with new nodata, or have
            %   missing filled, divided, or changed of type. Same specs as in
            %   .getAndSaveData().

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.getDataForDateAndVarName';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], ...
                force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            % Mustn't add countOfPixelPerDimension in default.                  @warning
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'patternsToReplaceByJoker', {});
            addParameter(p, 'monthWindow', WaterYearDate.yearMonthWindow);
            addParameter(p, 'timestampAndNrt', '');

            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;
            monthWindow = p.Results.monthWindow;
            timestampAndNrt = p.Results.timestampAndNrt;
            fprintf(['%s: Starting, region: %s, dataLabel: %s, thisDate: %s, ', ...
                'varName: %s, ', ...
                'cellIdx: [%s], countOfCellPerDimension: [%s], logLevel: %d, ', ...
                'parallelWorkersNb: %d, monthWindow: %d, timestampAndNrt: %s...\n'], ...
                thisFunction, objectName, dataLabel, char(thisDate, 'yy-MM-dd'), ...
                varName, ...
                join(string(optim.cellIdx), ', '), ...
                join(string(optim.countOfCellPerDimension), ', '), ...
                optim.logLevel, optim.parallelWorkersNb, monthWindow, timestampAndNrt);

            aggregateCells = ismember('rowStartId', patternsToReplaceByJoker);
                % This induces that data are split into cell files which are aggregated
                % to form a tile. 2024-02-28.
                % RowStartId should be replaced by something like dim1StartId...   @todo

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Check valid dataLabel and get file for which the variable is
            % to be loaded.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [filePath, fileExists, ~, metaData] = ...
                obj.getFilePathForDateAndVarName(objectName, dataLabel, thisDate, ...
                    varName, complementaryLabel, ...
                    patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                    monthWindow = monthWindow, timestampAndNrt = timestampAndNrt, ...
                    optim = optim);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.
                % NB: metaData is information yielded by getObjectIdentification() and
                % getVariableIdentification() through the call to
                % replacePatternByValue(). These metadata are currently not updated when
                % objectName or varName were jokerized to yield all files of a certain
                % type, whatever the variables or objects.                      @warning
            varId = metaData.varId;
            varName = metaData.varName;
            objectId = metaData.objectId;
            objectName = metaData.objectName;
            objectType = metaData.objectType;

            % Detection of extension and multiple files.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            varData = [];
            conversionMask = [];
            if ~iscell(fileExists)
                fileExists = num2cell(fileExists);
            end
            if ~sum(cell2mat(fileExists))
                warning('%s: Absent file(s) %s.\n', mfilename(), filePath);
                return;
            end

            if size(filePath, 1) > 1
                fileExtension = Tools.getFileExtension(filePath{1});
            else
                fileExtension = Tools.getFileExtension(filePath);
            end
            if size(filePath, 1) > 1 & ...
                ismember(fileExtension, {'.hdf', '.h5', '.mat'}) ...
                & ~aggregateCells
                % We take the most recent file only.                            @warning
                filePath = filePath{1};
                warning(['%s: Only the data of the first file, %s, ', ...
                    'will be retrieved, because the method doesn''t ', ...
                    'currently concatenate multiple .mat or .h5 files.\n'], ...
                    mfilename(), filePath);
            elseif size(filePath, 1) == 1 & ismember(fileExtension, {'.csv'})
               filePath = cellstr(filePath);
            end

            % Configuration of file and object (region or subdivision).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            inputFileConf = obj.myConf.filePath( ...
                strcmp(obj.myConf.filePath.dataLabel, dataLabel), :);
            if metaData.objectType == 0
                objectConf = obj.myConf.region(obj.myConf.region.id == objectId, :);
            else
                objectConf = obj.myConf.landsubdivision( ...
                  obj.myConf.landsubdivision.id == objectId, :);
            end

            % Determine the time dimension and get all indices.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [startIdx, endIdx, thisSize] = obj.getIndicesForCellForDataLabel( ...
                objectName, dataLabel, theseDate = thisDate, varName = varName, ...
                force = force, optim = optim);

            % Configuration of input (from file) and output (what we want).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Here, inputDataLabel = dataLabel argument of the method,
            % and outputDataLabel = force.outputDataLabel argument, if defined.
            varName = metaData.varName; % varName argument can be varId, we take the
                % info from the getObjectIdentification() present in getFilePath()
                % through a call to replacePatternByValue().
            [inputVariables, ~] = obj.getVariable(dataLabel);
              % Here, we are not smart, because it forces to have a input/output set
              % of variables in versionvariable with inputLabel=outpuLabel and of the
              % same version, with duplication of confs... To improve!             @todo
            inputVariable = inputVariables( ...
                strcmp(inputVariables.name, varName), :);
            outputVariable = [];
            outputFileConf = inputFileConf;
            if ismember('outputDataLabel', fieldnames(force))
                [outputVariables, ~] = ...
                        obj.getVariable(force.outputDataLabel);
                outputVariable = outputVariables( ...
                    strcmp(outputVariables.name, varName), :);
                outputFileConf = obj.myConf.filePath( ...
                    strcmp(obj.myConf.filePath.dataLabel, ...
                    force.outputDataLabel), :);
            end

            % Get the varName within the file, which might be distinct from varName.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            varNameWithinFile = varName;
            if ~isempty(varName) && ischar(varName)
                if ~isempty(inputFileConf.fieldForVarNameWithinFile{1})
                    varConf = obj.myConf.variable( ...
                        strcmp(obj.myConf.variable.output_name, varName), :);
                    varNameWithinFile = ...
                        varConf.(inputFileConf.fieldForVarNameWithinFile{1}){1};
                elseif ~isempty(inputVariable.nameWithinFile{1})
                    varNameWithinFile = inputVariable.nameWithinFile{1};
                end
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % .hdf files.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Currently restricted to mod09ga 1 day file.
            % NB: We only get the values for a specific date (no a series of days) and
            % variable. We suppose that each file has only 1 date.
            % We take the most recent file only, see transformation of filePath
            % 30 lines above.
            % No retrieval of metadata.
            if strcmp(fileExtension, '.hdf')
                if ~(~isempty(thisDate) && ~isempty(varName) && ...
                    ~strcmp(varName, 'metaData') && ...
                    inputFileConf.dimensionInfo == 20 && inputFileConf.period == 1)
                    error( ...
                       ['%s: No handling of empty date, ', ...
                       'empty varName, "metaData" varName, ', ...
                       'inputFileConf.dimensionInfo different from 20, ', ...
                       'inputFileConf.period different from 1.\n'], thisFunction);
                end
                varData = hdfread(filePath, varNameWithinFile, ...
                    Index = {double([startIdx(1), startIdx(2)]), ...
                    double([1, 1]), double([thisSize(1), thisSize(2)])});
                    % "Index": starts, slices, lengths.
                    % matlab requires indices of type double.

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % .h5 files.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Currently restricted to .h5 spires v20231027 and v2024.0/0a wateryear
            % files.
            % We get the values for 1 specific date or a slice of dates.
            % If several files, each of them should be a cell rowxcolumnxtime of the
            % dataset, with all cells aggregated in dim1 x dim2 forming the tile
            % (this is used in spires v2024.0a for spiressmoothbycell files.
            % We check whether the first date of the file is the 1st date of the water
            % year and assume that the rest of the record is for a continuous series of
            % 365/366 days.                                                     @warning
            elseif strcmp(fileExtension, '.h5')
                if isempty(thisDate) || isempty(varName) || ...
                    strcmp(varName, 'metaData') || ...
                    (~(inputFileConf.dimensionInfo == 30 && ...
                        inputFileConf.period == 5) && ...
                    ~(inputFileConf.dimensionInfo == 20 && ...
                        inputFileConf.period == 1))
                    error( ...
                       ['%s: No handling of empty date, ', ...
                       'empty varName, "metaData" varName, ', ...
                       'inputFileConf.dimensionInfo different from 30 (20), ', ...
                       'inputFileConf.period different from 5 (1).\n'], thisFunction);
                end
                % WARNING: special case for using smoothSPIREScube dataLabel
                % spiressmoothbycell when getting data of one sub-file only handled by
                % the condition
                % && ...
                % (length(optim.countOfPixelPerDimension) ~= 3 || ...
                % optim.countOfPixelPerDimension(3) ~= 1)
                % very dirty!                                                   @warning

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % a. Case with a classic file consisting in 1 cell only, =full modis
                %   tile with time as depth dimension, as in spires v20231027.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ischar(filePath)
%{
                    thisFileInfo = h5info(filePath);
                    theseDates = h5readatt(filePath, ...
                        inputFileConf.dateAttributePath{1}, inputFileConf.dateFieldName{1});
                    countOfDayInWaterYear = countOfDayInWaterYear(thisDate, ...
                         objectConf.firstMonthOfWaterYear)

                    % Check the number of days in file. Unfortunately, can't do this
                    % as such since the smoothspires files are built for less than 365
                    % days for current waterYear.                                  @todo
                    if numel(theseDates) ~= countOfDayInWaterYear(thisDate, ...
                         objectConf.firstMonthOfWaterYear)
                         error( ...
                            ['%s: Bad count of days in file %s: %d vs %d expected', ...
                            ' for waterYear %d.\'], thisFunction, file, ...
                            numel(theseDates), countOfDayInWaterYear, waterYear);
                    end
%}
%{
                    % Previous implementation before 2024-04-2.
                    thisJDDate = year(thisDate) * 1000 + day(thisDate, 'dayofyear');
                        % NB: We suppose that dates are numeric in the file.    @warning
                    dateIdx = find(theseDates == thisJDDate);
                    if isempty(dateIdx)
                        errorStruct.identifier = 'ESPEnv:getDataForDateAndVarName';
                        warning( ...
                           ['%s: Missing date %d in %s.\n'], mfilename(), ...
                           thisJDDate, filePath);
                    else
%}
                    if inputFileConf.period == 1
                        varData = h5read(filePath, ...
                            [inputFileConf.datasetGroupPath{1}, ...
                            varNameWithinFile], ...
                            double([startIdx(1), startIdx(2)]), ...
                            double([thisSize(1), thisSize(2)]), double([1, 1]));
                            % Arguments: start, count, stride.
                    elseif inputFileConf.period == 5
                        varData = h5read(filePath, ...
                            [inputFileConf.datasetGroupPath{1}, ...
                            varNameWithinFile], ...
                            double([startIdx(1), startIdx(2), startIdx(3)]), ...
                            double([thisSize(1), thisSize(2), thisSize(3)]), ...
                            double([1, 1, 1]));
                            % Arguments: start, count, stride.
                    end

                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % b. Case with a set of cell-split files to combine to form a tile,
                %   as in spires v2024.0a.
                %   NB: Works only for 1 day and full tile. Very specific to v2024.0a.
                %       and doesnt raise error otherwise...                     @warning
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                %                                                            @deprecated
                elseif iscell(filePath) & size(filePath, 1) > 1
                    % NB: there should be here another requirement on the number of
                    % files expected.
                    for fileIdx = 1:size(filePath)
                        thisFilePath = filePath{fileIdx};
%{
                        theseDates = h5readatt(thisFilePath, ...
                            inputFileConf.dateAttributePath{1}, ...
                            inputFileConf.dateFieldName{1});
                        countOfDayInWaterYear = ...
                            WaterYearDate.getCountOfDayInWaterYear(thisDate, ...
                            objectConf.firstMonthOfWaterYear);

                    % Check the number of days in file. Unfortunately, can't do this
                    % as such since the smoothspires files are built for less than 365
                    % days for current waterYear.                                  @todo
                    if numel(theseDates) ~= countOfDayInWaterYear(thisDate, ...
                         objectConf.firstMonthOfWaterYear)
                         error( ...
                            ['%s: Bad count of days in file %s: %d vs %d expected', ...
                            ' for waterYear %d.\'], thisFunction, file, ...
                            numel(theseDates), countOfDayInWaterYear, waterYear);
                    end
%}
%{
                    % Previous implementation before 2024-04-2.
                        thisJDDate = year(thisDate) * 1000 + day(thisDate, 'dayofyear');
                            % NB: We suppose that dates are numeric in the file.@warning
                        dateIdx = find(theseDates == thisJDDate);
                        if isempty(dateIdx)
                            errorStruct.identifier = 'ESPEnv:getDataForDateAndVarName';
                            warning( ...
                               ['%s: Missing date %d in %s.\n'], mfilename(), ...
                               thisJDDate, thisFilePath);
                    % NB: now dateIdx = startIdx(3)         @warning
%}
                        [~, ~, ~, ~, ~, metaData] = ...
                            obj.getMetadataFromFilePath(thisFilePath, dataLabel);
                        if fileIdx == 1
                            oneData = h5read(thisFilePath, ...
                                [inputFileConf.datasetGroupPath{1}, ...
                                    varNameWithinFile], [1, 1, 1], [2, 1, 1]);
                            varData = ...
                                ones(obj.modisData.sensorProperties.tiling. ...
                                    rowPixelCount, ...
                                    obj.modisData.sensorProperties.tiling. ...
                                    columnPixelCount, 1, class(oneData));
                            if isinteger(oneData)
                                varData = intmax(class(oneData)) * varData;
                            else
                                varData = NaN * varData;
                            end
                        end
                        % Occasionally, smoothSpires miss the last day and the
                        % dataset has a lower size (in days) than expected.
                        thatVarInfoInFile = h5info(thisFilePath, ...
                            [inputFileConf.datasetGroupPath{1}, ...
                                varNameWithinFile]);
                        if startIdx(3) > thatVarInfoInFile.Dataspace.Size(3)
                            warning(['Impossible to read %s in %s, ', ...
                                ' 3rd dim called position %d but size %d in ', ...
                                'file.\n'], ...
                                [inputFileConf.datasetGroupPath{1}, ...
                                varNameWithinFile], thisFilePath, ...
                                startIdx(3), ...
                                thatVarInfoInFile.Dataspace.Size(3));
                            varData = [];
                            return;
                        end   
                        try
                            varData(metaData.rowStartId:metaData.rowEndId, ...
                                metaData.columnStartId:metaData.columnEndId) = ...
                                h5read(thisFilePath, ...
                                [inputFileConf.datasetGroupPath{1}, ...
                                    varNameWithinFile], ...
                                double([1, 1, startIdx(3)]), ...
                                double([metaData.rowEndId - metaData.rowStartId + 1, ...
                                metaData.columnEndId - metaData.columnStartId + 1, 1]));
                                % Matlab requires double precision indices for h5read.
                        catch thisException
                            warning(['Impossible to read %s in %s, called position', ...
                                ' [%d, %d, %d], size [%d, %d, %d].\n'], ...
                                [inputFileConf.datasetGroupPath{1}, ...
                                varNameWithinFile], thisFilePath, ...
                                1, 1, startIdx(3), ...
                                metaData.rowEndId - metaData.rowStartId + 1, ...
                                metaData.columnEndId - metaData.columnStartId + 1, ...
                                1);
                            rethrow(thisException);
                        end
                    end
                end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % .mat files.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Handling and get of the metadata in the .mat file. Not done for other
            % extensions.
            elseif strcmp(fileExtension, '.mat')
                % In regular process, a proper
                % handling of thisDate and of the generation of files (potentially
                % with nodata/NaN-filled variables) should make all files present &
                % the last condition useless.
                if ~strcmp(varNameWithinFile, '')
                    % varData = parloadMatrices(filePath, varNameWithinFile); 2024-03-25
                    fileObj = matfile(filePath);
                    if strcmp(varNameWithinFile, 'metaData')
                        try
                            varData = fileObj.(varNameWithinFile);
                        catch thisException
                            warning('%s: %s, %s.\n', thisFunction, ...
                                thisException.identifier, thisException.message);
                        end
                    else
                        switch inputFileConf.dimensionInfo
                            case 11
                                % 11: 1 dim column: row*column (reshaped matrix with on
                                % column with each pixel correspond to a row).
                                varData = fileObj.(varNameWithinFile)( ...
                                    starIdx(1):endIdx(1));
                            case {20, 21}
                                % 20: 2 dim: pixel row x pixel column (only one day
                                % here).
                                % 21: 2 dim: day x row*column (reshaped matrix with
                                % each pixel correspond to a column of days).
                                varData = fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), startIdx(2):endIdx(2));
                            case 30
                                % 30: pixel row x pixel column x day
                                varData = fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), startIdx(2):endIdx(2), ...
                                    startIdx(3):endIdx(3));
                        end
                    end
                else
                    varData = load(filePath); % Not sure whether that works in
                        % parfor loops.
                end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % .csv files.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Csv files are contenated over row dimension.
            % No selection of subset of dates or cells here.                    @warning
            elseif strcmp(fileExtension, '.csv')
                varData = table();
                for fileIdx = 1:size(filePath, 1)
                    tmpData = readtable(filePath{fileIdx}, 'Delimiter', ',');
                    fprintf('%s: Reading %s...\n', mfilename(), filePath{fileIdx});
                    if startsWith(string(tmpData.(1)(1)), 'Metadata')
                        tmpData(1,:) = []; % delete metadata line.
                        % Might be necessary to put that in metadata return    @todo
                    end
                    varData = [varData; tmpData];
                end
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Reshape, conversion, fillmissing (NaN), resampling, min/max, divisor,
            % type, nodata.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ismember(fileExtension, {'.hdf', '.h5', '.mat', '.tif'}) & ...
                ~strcmp(varName, 'metaData') & isnumeric(varData) & ~isempty(varData)

                % Reshaping.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if outputFileConf.dimensionInfo ~= inputFileConf.dimensionInfo
                    if outputFileConf.dimensionInfo == 21
                        if inputFileConf.dimensionInfo == 20
                            varData = reshape(varData, ...
                                [1, thisSize(1) * thisSize(2)]);
                        end
                        if inputFileConf.dimensionInfo == 30
                            varData = reshape(varData, ...
                                [thisSize(3), thisSize(1) * thisSize(2)]);
                                    % Matrix of column vectors.
                        end
                    elseif (outputFileConf.dimensionInfo == 11 && ...
                        inputFileConf.dimensionInfo == 20)
                        varData = reshape(varData, ...
                            [1, thisSize(1) * thisSize(2)]); % row vector.
                    elseif (outputFileConf.dimensionInfo == 30 && ...
                        inputFileConf.dimensionInfo == 20)
                        % No reshaping.
                    else
                        error(['%s: Impossible reshaping. Reshaping allowed ', ...
                            ' for dimensions 20 or 30 towards 21 or dimension', ...
                            ' 20 towards 10.'], thisFunction);
                    end
                    % 11: 1 dim column: row*column (reshaped matrix with on column with
                    % each pixel correspond to a row). 20: 2 dim: pixel row x
                    % column (only one day here). 21: 2 dim: pixel row*column x day
                    % (reshaped matrix with each pixel corresponding to a column of
                    % days), 30: pixel row x pixel column x day.
                end

                % Resampling.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                outputResamplingFactor = inputVariable.resamplingFactor(1);
                if ismember('resamplingFactor', fieldnames(force))
                    outputResamplingFactor = force.resamplingFactor;
                elseif ismember('outputDataLabel', fieldnames(force))
                    outputResamplingFactor = outputVariable.resamplingFactor(1);
                end
                actualResamplingFactor = inputVariable.resamplingFactor(1) / ...
                    outputResamplingFactor; % e.g. input 2 (1 km) / output 1 (500 m)
                if actualResamplingFactor ~= 1
                     if ~ismember(class(varData), {'single', 'double'})
                        varData = single(varData);
                        varData(varData == inputVariable.nodata_value(1)) = NaN;
                    end
                    if ismember('resamplingMethod', fieldnames(force))
                        varData = imresize( ...
                            varData, actualResamplingFactor, force.resamplingMethod);
                            % nearest for logical, bicubic for others.
                            % We may have chosen nearest because we only resize the angles
                            % and they
                            % are probably similar from pixel to pixel. However for other
                            %   values, may not be ok. Was bicubic in v20231027.    @warning
                    else
                        varData = imresize(varData, actualResamplingFactor);
                            % nearest for logical, bicubic for others.
                            % We may have chosen nearest because we only resize the angles
                            % and they
                            % are probably similar from pixel to pixel. However for other
                            %   values, may not be ok. Was bicubic in v20231027.    @warning
                    end
                end

                % Nodata and preparing casting to output type.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % conversionMask: array(uint8). Bit array indicating the pixels that
                %   have changed under the fillmissing and cut of min/max.
                % Mask of cells which have been modified.
                conversionMask = zeros(size(varData), 'uint8');
                    % Bits. Pos 1: no data. 2: value below range. 3: value above range.

                outputType = inputVariable.type{1};
                if ismember('type', fieldnames(force))
                    outputType = force.type;
                elseif ismember('outputDataLabel', fieldnames(force))
                    outputType = outputVariable.type{1};
                end

                if ~ismember('fillMissing', fieldnames(force))
                  outputNoDataValue = inputVariable.nodata_value(1);
                  if ismember('nodata_value', fieldnames(force))
                      outputNoDataValue = force.nodata_value;
                  elseif ismember('outputDataLabel', fieldnames(force))
                      outputNoDataValue = outputVariable.nodata_value(1);
                  end
                  if ismember(outputType, {'single', 'double'})
                      outputNoDataValue = NaN;
                  end
                end

                if ismember(inputVariable.type{1}, {'single', 'double'}) | ...
                    ismember(class(varData), {'single', 'double'})
                    conversionMask = bitset(conversionMask, 1, isnan(varData));
                else
                    conversionMask = bitset(conversionMask, 1, ...
                        varData == inputVariable.nodata_value(1));
                end
                isNoData = bitget(conversionMask, 1);

                % Divisor.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                outputDivisor = inputVariable.divisor(1);
                if ismember('divisor', fieldnames(force))
                    outputDivisor = force.divisor;
                elseif ismember('outputDataLabel', fieldnames(force))
                    outputDivisor = outputVariable.divisor(1);
                end
                actualDivisor = inputVariable.divisor(1) / outputDivisor;
                if actualDivisor ~= 1
                    if ~ismember(class(varData), {'single', 'double'})
                        varData = single(varData);
                        varData(varData == inputVariable.nodata_value(1)) = NaN;
                    end
                    varData = varData / actualDivisor;
                end

                % Cut.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ismember('minMaxCut', fieldnames(force)) && ...
                  ismember(force.minMaxCut, [1, 2]) && ...
                  ismember('outputDataLabel', fieldnames(force))
                  if outputVariable.min(1) ~= outputVariable.nodata_value(1)
                      conversionMask = bitset(conversionMask, 2, ...
                          (~isNoData & ...
                              varData < outputVariable.min(1)));
                  end
                  if outputVariable.max(1) ~= outputVariable.nodata_value(1)
                      conversionMask = bitset(conversionMask, 3, ...
                          (~isNoData & ...
                              varData > outputVariable.max(1)));
                  end
                  thisMin = outputVariable.min(1);
                  thisMax = outputVariable.max(1);
                  if force.minMaxCut == 2
                    thisMin = inputVariable.nodata_value(1);
                    thisMax = inputVariable.nodata_value(1);
                    % We take nodata_value from input because it is the one considered
                    % for fillmissing and later it'll be converted into nodata_value
                    % of outputVariable.
                    isNoData = (conversionMask ~= 0);
                  end
                  varData(logical(bitget(conversionMask, 2))) = thisMin;
                  varData(logical(bitget(conversionMask, 3))) = thisMax;
                end

                % Fillmissing.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % If spatial interpolation (inpaint_nans), must be done before
                % reshaping.
                if ismember('fillMissing', fieldnames(force)) && ...
                    sum(logical(bitget(conversionMask, 1)), 'all') > 0
                      % if there is at least one nodata pixel.
                    if strcmp(force.fillMissing{1}, 'inpaint_nans')
                        if ~ismember(inputVariable.type{1}, {'single', 'double'})
                            isNoData = (varData == inputVariable.nodata_value(1));
                            varData = double(varData);
                            varData(isNoData) = NaN;
                        end
                        varData = inpaint_nans(varData, force.fillMissing{2});
                          % inpaint_nans only accepts double, and remove all nodata.
                        varData = cast(varData, inputVariable.type{1});
                        isNoData(:) = uint8(0);
                    end
                end

                % Nodata (if fillmissing not done) and casting to output type.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                varData = cast(varData, outputType);
                if ~ismember('fillMissing', fieldnames(force))
                  varData(logical(isNoData)) = outputNoDataValue;
                end
            else
                warning(['%s: No conversion for extension %s or ', ...
                    'varName metaData or non numeric data.\n'], ...
                    thisFunction, fileExtension);
            end
        end
        function [data, mapCellsReference, metaData] = ...
            getDataForObjectNameDataLabel(obj, objectName, dataLabel, varargin)
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
            %   NB: specific handling for spiresModel, depending on modis/viirs and Ned
            %   filter conf or not.
            %
            % Return
            % ------
            % data: array( x ) or Struct or Table.
            %   E.g. of elevations for a tile or Struct of
            %   properties for a region mask or Table of stats.
            %   If file doesn't exit, empty.
            % mapCellsReference: MapCellsReference. Allows to georeference the data.
            thisFunction = 'ESPEnv.getDataForObjectNameDataLabel';

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
                    tmpObj = matfile(filePath);
                    data = tmpObj.data;
                    % Specific to v3.1. elevation, slope, aspect, canopy. 2024-03-23.
                    if ismember(class(data), {'single', 'double'})
                        data(isnan(data)) = 0;
                    end
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
                    if ~isa(mapCellsReference, 'MapCellsReference')
                        mapCellsReference = [];
                    end
                    metaData = struct();
                elseif strcmp(fileExtension, '.csv')
                    data = readtable(filePath, 'Delimiter', ',');
                    if startsWith(string(data.(1)(1)), 'Metadata')
                        data(1,:) = []; % delete metadata line.
                        % There might be necessary to put that in the metadata return
                        %                                                          @todo
                    end
                end
            end
        end
        function [varData, waterYearDate] = getDataForWaterYearDateAndVarName(obj, ...
            objectName, dataLabel, waterYearDate, varName, varargin)
            % SIER_297: replacement of modisData.loadMOD09() and loadSCAGDRFS()
            % NB: this ugly method may be improved, depending on raw data struct.  @todo
            %
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            %   NB: not int right now.                                          @warning
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            % waterYearDate: WaterYearDate. Cover the period for which we want the
            %   files.
            % varName: name of the variable to load (name in the file, not output_name
            %   of configuration_of_variables.csv).
            % force: struct(dimensionInfo), optional. Used to
            %   override varName configuration.
            %   dimensionInfo: 11: 1 dim row: row*column*depth (reshaped matrix with on
            %       row with each pixel correspond to a column).
            %   divisor: float. The data extracted are divided by this value.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx, depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % varData: concatenated data arrays read. We hypothesize that the files
            %   have continuous dates, without gaps (you can have files filled by NaN
            %   or nodata.
            % waterYearDate: WaterYearDate. Cover the period for which there are present
            %   files.
            %
            % NB: only works for dataLabel in MOD09Raw or SCAGRaw. !!
            % NB: doesn't check if the variable is present in file.                @todo
            %
            % NB: This function is slow when files are daily and cover a full waterYear.
            %                                                                      @todo
            %
            % NB: only works with .mat files right now. 2024-03-25.                @todo

            % 1. Check valid dataLabel and get list of files for which the variable is
            % to be loaded.
            %---------------------------------------------------------------------------
            thisFunction = 'ESPEnv.getDataForWaterYearDateAndVarName';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            % Mustn't add countOfPixelPerDimension in default.                  @warning
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'patternsToReplaceByJoker', {});
            addParameter(p, 'monthWindow', WaterYearDate.yearMonthWindow);
            addParameter(p, 'timestampAndNrt', '');

            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;
            monthWindow = p.Results.monthWindow;
            timestampAndNrt = p.Results.timestampAndNrt;
            fprintf(['%s: Starting, region: %s, dataLabel: %s, waterYearDate: %s, ', ...
                'varName: %s, ', ...
                'cellIdx: [%s], countOfCellPerDimension: [%s], logLevel: %d, ', ...
                'parallelWorkersNb: %d, monthWindow: %d, timestampAndNrt: %s...\n'], ...
                thisFunction, objectName, dataLabel, waterYearDate.toChar(), ...
                varName, join(string(optim.cellIdx), ', '), ...
                join(string(optim.countOfCellPerDimension), ', '), ...
                optim.logLevel, optim.parallelWorkersNb, monthWindow, timestampAndNrt);

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            varConf = obj.myConf.variable(strcmp(obj.myConf.variable.output_name, ...
                varName), :);

            [filePath, fileExists, lastDateInFile, waterYearDate] = ...
                obj.getFilePathForWaterYearDate(objectName, dataLabel, ...
                    waterYearDate, optim = optim);
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.
            filePath = filePath(fileExists == 1); % In regular process, a proper
                % handling of waterYearDate and of the generation of files (potentially
                % with nodata/NaN-filled variables) should make all files present and
                % this command useless.
            lastDateInFile = lastDateInFile(fileExists == 1);

            % Determine the time dimension and get all indices.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [startIdx, endIdx, thisSize] = obj.getIndicesForCellForDataLabel( ...
                objectName, dataLabel, theseDate = waterYearDate.getDailyDatetimeRange(), ...
                varName = varName, force = force, optim = optim);
                % thisSize is incorrect for the date dimension since we only supply
                % one date. See how to improve the code clarity.                   @todo

            % 2. Construction of the array of values extracted from the files.
            %---------------------------------------------------------------------------
            varData = [];
            if strcmp(varName, filePathConf.dateFieldName{1})
                % WARNING: only works for .mat files, not for .h5 files.        @warning
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
                % Get the varName within the file, which might be distinct from varName.
                fileConf = obj.myConf.filePath( ...
                    strcmp(obj.myConf.filePath.dataLabel, dataLabel), :);

                % Get the varName within the file, which might be distinct from varName.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                varLabel = varName;
                [varId, varName] = obj.getVariableIdentification(varLabel);
                [variable, ~, ~] = obj.getVariable(dataLabel);
                if ~isempty(variable)
                    % New way to get infos 2024-05-17, in versionvariable, rather than
                    % in filepath and variable configuration.
                    varNameWithinFile = variable(variable.id == varId, :).name{1};
                    thisType = variable(variable.id == varId, :).type{1};
                    datasetGroupPath = ...
                        variable(variable.id == varId, :).datasetGroupPath{1};
                        % For .h5 files.
                else
                    % deprecated way, only for .mat.
                    varNameWithinFile = varName;
                    if ~isempty(varName) && ischar(varName) && ...
                        ~isempty(fileConf.fieldForVarNameWithinFile{1})
                        varConf = obj.myConf.variable( ...
                            strcmp(obj.myConf.variable.output_name, varName), :);
                        varNameWithinFile = ...
                            varConf.(fileConf.fieldForVarNameWithinFile{1}){1};
                    end
                    thisType = ...
                        Tools.valueInTableForThisField(obj.myConf.variable, ...
                        'output_name', varName, fileConf.fieldForVarTypeWithinFile{1});
                        % NB: For variable NoValues,
                        % type in raw files is actually logical, but code should work.
                end

                % Initialization of loaded data array...
                % destination array has fix size (e.g. 2400x2400x92 days)
                % and not a variable size as before 2023-12-12, to speed execution.

                fileExtension = Tools.getFileExtension(filePath{end});
                countOfDaysInFile = ones(size(lastDateInFile));
                sizeInThirdDimension = 1;
                if ismember(fileConf.dateInFileName{1}, {'yyyyJD', 'yyyyMMdd'})
                    sizeInThirdDimension = numel(lastDateInFile);
                elseif ismember(fileConf.dateInFileName{1}, {'yyyyMM'})
                    countOfDaysInFile = day(lastDateInFile);
                    sizeInThirdDimension = sum(countOfDaysInFile);
                elseif ismember(fileConf.dateInFileName{1}, {'yyyy'})
                    % water yearly.
                    % NB: Beware, cannot work on files for julian years.        @warning
                    countOfDaysInFile = daysact( ...
                        waterYearDate.getFirstDatetimeOfWaterYear(), lastDateInFile) ...
                        + 1;
                    sizeInThirdDimension = countOfDaysInFile;
                end

                if strcmp(varName, 'refl') % Reflectance has 7 bands as 3rd dimension.
                    thisSize = [thisSize(1), ...
                        thisSize(2), ...
                        7, sizeInThirdDimension];
                    if ismember(thisType, {'single', 'double'})
                        varData = NaN(thisSize, thisType);
                    elseif strcmp(thisType, 'logical')
                        varData = zeros(thisSize, thisType);
                    else
                        varData = intmax(thisType) * ones(thisSize, thisType);
                    end
                    lastIndex = 0;
                    for fileIdx = 1:size(filePath, 2)
                        fileObj = matfile(filePath{fileIdx});
                        if ismember(fileConf.dateInFileName{1}, {'yyyyJD', 'yyyyMMdd'})
                            varData(:, :, :, lastIndex + 1: ...
                                lastIndex + countOfDaysInFile(fileIdx)) = ...
                                fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), ...
                                    startIdx(2):endIdx(2), :);
                        else
                            varData(:, :, :, lastIndex + 1: ...
                                lastIndex + countOfDaysInFile(fileIdx)) = ...
                                fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), ...
                                    startIdx(2):endIdx(2), :, :);
                        end
                        lastIndex = lastIndex + countOfDaysInFile(fileIdx);
                    end
                else % Other variables have time as 3rd dimension.
                    % NB: solar azimuth, zenith, sensor zenith are 2400x2400 in raw
                    % cubes (but 1200x1200 in modis files).
                    thisSize = [thisSize(1), ...
                        thisSize(2), ...
                        sizeInThirdDimension];
                    if ismember(thisType, {'single', 'double'})
                        varData = NaN(thisSize, thisType);
                    elseif strcmp(thisType, 'logical')
                        varData = zeros(thisSize, thisType);
                    else
                        varData = intmax(thisType) * ones(thisSize, thisType);
                    end
                    
                    if ismember(fileConf.dateInFileName{1}, {'yyyyJD', 'yyyyMMdd'})
                        % Only one day per file, simple case.
                        parfor fileIdx = 1:size(filePath, 2)
                            %fprintf('%s: Loading %s, %s...\n', mfilename(), ...
                            %    filePath{fileIdx}, varNameWithinFile);
                            if strcmp(fileExtension, '.h5')
                                try
                                    varData(:, :, fileIdx) = h5read( ...
                                        filePath{fileIdx}, ...
                                        [datasetGroupPath, varNameWithinFile], ...
                                        double([startIdx(1), startIdx(2)]), ...
                                        double([thisSize(1), thisSize(2)]), ...
                                            double([1, 1]));
                                catch thisException
                                    warning('Impossible to read %s in %s.\n', ...
                                        varNameWithinFile, filePath{fileIdx});
                                    rethrow(thisException);
                                end
                            else
                                fileObj = matfile(filePath{fileIdx});
                                varData(:, :, fileIdx) = ...
                                    fileObj.(varNameWithinFile)( ...
                                        startIdx(1):endIdx(1), ...
                                        startIdx(2):endIdx(2));
                            end % default .mat.
                        end
                    else
                        % several days per file.
                        lastIndex = 0;
                        for fileIdx = 1:size(filePath, 2)
                            if strcmp(fileExtension, '.h5')
                                % WARNING: only works if there's only one file only.
                                % very specific to modisspiressmoothbycell.
                                %                                               @warning
                                try
                                    varData(:, :, lastIndex + 1: ...
                                        lastIndex + countOfDaysInFile(fileIdx)) = ...
                                        h5read(filePath{fileIdx}, ...
                                            [datasetGroupPath, varNameWithinFile], ...
                                        double([startIdx(1), startIdx(2), ...
                                            startIdx(3)]), ...
                                        double([thisSize(1), thisSize(2), ...
                                            thisSize(3)]), ...
                                        double([1, 1, 1]));
                                catch thisException
                                    warning('Impossible to read %s in %s.\n', ...
                                        varNameWithinFile, filePath{fileIdx});
                                    rethrow(thisException);
                                end
                            else
                                fileObj = matfile(filePath{fileIdx});
                                varData(:, :, lastIndex + 1: ...
                                    lastIndex + countOfDaysInFile(fileIdx)) = ...
                                    fileObj.(varNameWithinFile)( ...
                                        startIdx(1):endIdx(1), ...
                                        startIdx(2):endIdx(2), :);
                            end % default .mat.
                            lastIndex = lastIndex + countOfDaysInFile(fileIdx);
                        end
                    end
                end
            end

            % Reshape/convert/divisor the data.
            % (like in getDataForDateAndVarName(), in a minimal way. The 2 methods are
            % close...

            % Get variable info.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Here, inputDataLabel = dataLabel argument of the method,
            % and outputDataLabel = force.outputDataLabel argument, if defined.
            [inputVariables, ~] = obj.getVariable(dataLabel);
            inputVariable = inputVariables( ...
                strcmp(inputVariables.name, varName), :);

            % Reshape.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Only tested for modisspiresdaily for smoothing.
            if ismember('dimensionInfo', fieldnames(force)) && ...
                force.dimensionInfo == 21 && fileConf.dimensionInfo == 20
                varData = reshape(varData, ...
                  [thisSize(1) * thisSize(2), sizeInThirdDimension])';
            end

            % Nodata and preparing casting to output type.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            outputType = inputVariable.type{1};
            if ismember('type', fieldnames(force))
                outputType = force.type;
            end
            outputNoDataValue = inputVariable.nodata_value(1);
            if ismember('nodata_value', fieldnames(force))
                outputNoDataValue = force.nodata_value;
            end
            if ismember(outputType, {'single', 'double'})
                outputNoDataValue = NaN;
            end

            if ismember(inputVariable.type{1}, {'single', 'double'})
                isNoData = isnan(varData);
            else
                isNoData = varData == inputVariable.nodata_value(1);
            end
            
            % Resampling.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            outputResamplingFactor = inputVariable.resamplingFactor(1);
            if ismember('resamplingFactor', fieldnames(force))
                outputResamplingFactor = force.resamplingFactor;
            elseif ismember('outputDataLabel', fieldnames(force))
                outputResamplingFactor = outputVariable.resamplingFactor(1);
            end
            actualResamplingFactor = inputVariable.resamplingFactor(1) / ...
                outputResamplingFactor; % e.g. input 2 (1 km) / output 1 (500 m)
            if actualResamplingFactor ~= 1
                if ~ismember(class(varData), {'single', 'double'})
                    varData = single(varData);
                    varData(varData == inputVariable.nodata_value(1)) = NaN;
                end
                if ismember('resamplingMethod', fieldnames(force))
                    varData = imresize( ...
                        varData, actualResamplingFactor, force.resamplingMethod);
                        % nearest for logical, bicubic for others.
                        % We may have chosen nearest because we only resize the angles
                        % and they
                        % are probably similar from pixel to pixel. However for other
                        %   values, may not be ok. Was bicubic in v20231027.    @warning
                else
                    varData = imresize(varData, actualResamplingFactor);
                        % nearest for logical, bicubic for others.
                        % We may have chosen nearest because we only resize the angles
                        % and they
                        % are probably similar from pixel to pixel. However for other
                        %   values, may not be ok. Was bicubic in v20231027.    @warning
                end
                isNoData = isnan(varData);
            end

            % Divisor.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            outputDivisor = inputVariable.divisor(1);
            if ismember('divisor', fieldnames(force))
                outputDivisor = force.divisor;
            end
            actualDivisor = inputVariable.divisor(1) / outputDivisor;
            if actualDivisor ~= 1
                if ~ismember(class(varData), {'single', 'double'})
                    varData = single(varData);
                    varData(varData == inputVariable.nodata_value(1)) = NaN;
                end
                varData = varData / actualDivisor;
            end

            % Nodata and casting to output type.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            varData = cast(varData, outputType);
            varData(logical(isNoData)) = outputNoDataValue;

            fprintf('%s: Loaded data %s, %s for %s, waterYearDate %s.\n', ...
                mfilename(), dataLabel, varName, objectName, waterYearDate.toChar());
        end
        function [filePath, fileExists, fileLastEditDate, metaData, thisDate] = ...
            getFilePath(obj, objectName, dataLabel, varargin)
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files,
            %   pathrow for landsat swaths and others. E.g. 'h08v04', 'p042r034'.
            %   Must be unique. Alternatively, can be the
            %   id of the landSubdivision. E.g. 26000 for 'westernUS'.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. spiresDaily.
            %   For nrt/historic data,
            %   the version of dataLabel must be in obj.modisData.versionOf.(dataLabel).
            %
            % Optional parameters
            % -------------------
            % NB: all these parameters can be a string with a globbing wild card as *.
            %   Other wild cards are currently not implemented. In particular
            %   {b*,c*,*est*} mustnt be used since the file patterns start and end by
            %   {}.
            %   The bash command used to get file lists is ls (linux). NB: not tested
            %   on windows.
            %   https://tldp.org/LDP/abs/html/globbingref.html
            % 
            % complementaryLabel: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857. Default: ''.
            % monthWindow: int. MonthWindow of the data within the file. Default: 12.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            % patternsToReplaceByJoker: cell array(char).
            %   List of arguments (patterns)
            %   we don't a priori know. The filepath in that case will be found using
            %   a dir cmd (replacing some unknown patterns by the joker *). Default {}.
            % thisDate: datetime. For which we want the file. Default: today.
            %   NB/trick: for the SubdivisionStatsWebCsv, this is a date which year is
            %   the ongoing waterYear.
            % thisIndex: int. Index of the pixel for files containing only 1
            %   pixel, e.g. modisspiresyeartmp. Default: 1.
            % thisYear: int. Year for which we want the files. Incompatible with
            %   thisDate and thisWaterYear. Default: 0.
            % thisWaterYear: int. Water Year for which we want the files. Incompatible
            %   with thisDate and thisYear.Default: 0.
            % timestampAndNrt: char. Only for input files (mod09ga, vnp09ga,
            %   lc08.l2sp.02.t1, etc...). Can be a timestamp or a process date yyyymmdd.
            %   Default: ''.
            % varName: char. name of the variable. Default: ''.
            %
            % Return
            % ------
            % filePath: char or cellarray(char). FilePath or list of filePath when joker
            %   is used.
            %   NB: if cellarray and 2 versions of the file exists, only the file with
            %   the most recent fileLastEditDate is in the filePath list.
            % fileExists: logical or array(logical). 0 if file doesn't exist.
            %   NB: is cellarray() in other getFileXxx() methods.
            % fileLastEditDate: datetime or array(datetime).
            %   NB: is celldatetime() in other getFileXxx() methods.
            % metaData: struct(objectId, objectName, objectType, varId, varName).
            %   information yielded by getObjectIdentification() and
            %   getVariableIdentification() through the call to replacePatternByValue().
            %   These metadata are currently not updated when objectName or varName
            %   were jokerized to yield all files of a certain type, whatever the
            %   variables or objects.                                           @warning
            % thisDate: datetime or array of datetimes. Date of the data included in the
            %   file.
            %   NB: only case of 1 file = 1 day handled currently 20241020.     @warning
            
            thisFunction = 'ESPEnv.getFilePath';
            
            % Optional parameters.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 %{
            complementaryLabel = '';
            monthWindow = WaterYearDate.yearMonthWindow;
            optim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            % Mustn't add countOfPixelPerDimension in default optim.            @warning
            patternsToReplaceByJoker = {};
            thisDate = WaterYearDate.getDateForToday();
            thisIndex = 1;
            thisYear = 0;
            thisWaterYear = 0;
            timestampAndNrt = '';
            varName = '';
 %}           
            optionalParameters = struct();
            optionalParameters.complementaryLabel = '*';
            optionalParameters.monthWindow = WaterYearDate.yearMonthWindow;
            optionalParameters.optim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            optionalParameters.patternsToReplaceByJoker = {};
            optionalParameters.thisDate = NaT;
            optionalParameters.thisIndex = 1;
            optionalParameters.thisYear = '*';
            optionalParameters.thisWaterYear = '*';
            optionalParameters.timestampAndNrt = '*';
            optionalParameters.varName = '*';
            % Mustn't add countOfPixelPerDimension in default optim.            @warning

            % Optional parameter parsing.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            p = inputParser;
            optionalParameterNames = fieldnames(optionalParameters);
            for optionalParameterIdx = 1:length(optionalParameterNames);
                optionalParameterName = optionalParameterNames{optionalParameterIdx};
              addParameter(p, ...
                  optionalParameterName, ...
                  optionalParameters.(optionalParameterName));
            end
%{         
            addParameter(p, 'complementaryLabel', complementaryLabel);
            addParameter(p, 'monthWindow', monthWindow);
            addParameter(p, 'optim', optim);
            addParameter(p, 'patternsToReplaceByJoker', patternsToReplaceByJoker);
            addParameter(p, 'thisDate', thisDate);
            addParameter(p, 'thisIndex', thisIndex);
            addParameter(p, 'thisYear', thisYear);
            addParameter(p, 'thisWaterYear', thisWaterYear);
            addParameter(p, 'timestampAndNrt', timestampAndNrt);
            addParameter(p, 'varName', varName);
%}
            p.StructExpand = false;
            parse(p, varargin{:});
            for optionalParameterIdx = 1:length(optionalParameterNames)
                optionalParameterName = optionalParameterNames{optionalParameterIdx};
                if ~isequal(p.Results.(optionalParameterName), ...
                    optionalParameters.(optionalParameterName))
                    if strcmp(optionalParameterName, 'optim')
                        optim = p.Results.optim;
                        optimFieldNames = fieldnames(optionalParameters.optim);
                        for fieldIdx = 1:length(optimFieldNames)
                            thisFieldName = optimFieldNames{fieldIdx};
                            if ~ismember(thisFieldName, fieldnames(optim))
                                optim.(thisFieldName) = ...
                                    optionalParameters.optim.(thisFieldName);
                            end
                        end % fieldIx.
                        optionalParameters.optim = optim;
                    else
                        optionalParameters.(optionalParameterName) = ...
                            p.Results.(optionalParameterName);
                    end
                end
            end
            if ~isempty(optionalParameters.patternsToReplaceByJoker)
                for optionalParameterIdx = 1:length(optionalParameterNames)
                    optionalParameterName = ...
                        optionalParameterNames{optionalParameterIdx};
                    if strcmp('*', ...
                        optionalParameters.(optionalParameterName))
                        optionalParameters.(optionalParameterName) = '';
                    end
                end
            end
                % NB: we can't use at the same time wild cards in parameters and having
                % patternsToReplaceByJoker not empty.
                % Currently no check if parameters contain wild cards.          @warning
            complementaryLabel = optionalParameters.complementaryLabel;
            monthWindow = optionalParameters.monthWindow;
            optim = optionalParameters.optim;
            patternsToReplaceByJoker = optionalParameters.patternsToReplaceByJoker;
            if isnat(optionalParameters.thisDate)
              thisDate = '*';
            else
              thisDate = optionalParameters.thisDate;
            end
            thisIndex = optionalParameters.thisIndex;
            thisYear = optionalParameters.thisYear;
            thisWaterYear = optionalParameters.thisWaterYear;
            timestampAndNrt = optionalParameters.timestampAndNrt;
            varName = optionalParameters.varName;
                % NB: use of eval doesnt work in this context, when variables were not
                % declared first.
       
 %{
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;
            monthWindow = p.Results.monthWindow;
            timestampAndNrt = p.Results.timestampAndNrt;
            thisIndex = p.Results.thisIndex;
            thisDate, ...
            varName, complementaryLabel, 
 %}
            % 1. Generation and check existence of the file directory path.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            modisData = obj.modisData;

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            if isempty(filePathConf)
                errorStruct.identifier = ...
                    ['ESPEnv:getFilePath:NoConfForDataLabel'];
                errorStruct.message = sprintf( ...
                    ['%s: invalid dataLabel=%s, ' ...
                     'should be in configuration_of_filepaths.csv file.'], ...
                    thisFunction, dataLabel);
                error(errorStruct);
            end
            % if filePathConf.isAncillary(1) == 0 && ...
            if ~ismember(dataLabel, fieldnames(modisData.versionOf)) && ...
                filePathConf.isAncillary == 0
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

            filePath = fullfile(directoryPath, ...
                [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}]);
            filePathWithPatterns = filePath;

            [filePath, regexpPattern, metaData] = ...
                obj.replacePatternsInFileOrDirPaths(filePath, ...
                objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                monthWindow = monthWindow, timestampAndNrt = timestampAndNrt, ...
                thisIndex = thisIndex, optim = optim, thisYear = thisYear, ...
                thisWaterYear = thisWaterYear);
                % If there are jokers in pattern to replace, this list can yield
                % multiple results. However, the metaData are not specifically updated
                % to the correct list of objectName or varName right now.          @todo

            [directoryPath, ~, ~] = fileparts(filePath);
            if isempty(patternsToReplaceByJoker) && ~isfolder(directoryPath)
                mkdir(directoryPath);
            end

            % 2. Generation of the filename, check existence of filenames and determine
            % last edit date.
            %---------------------------------------------------------------------------
            tmpFiles = struct2table(dir(filePath));
            tmpFiles = sortrows(tmpFiles(tmpFiles.isdir == 0, :), 'datenum', ...
                'descend');
             
            if ~isempty(tmpFiles)
                filePath = table2cell(rowfun(@(x, y) fullfile(x, y), tmpFiles, ...
                    InputVariables = {'folder', 'name'}));

                % Specific root path alias. Filepaths root can return with an alias.
                filePath = replace(filePath, getenv('espScratchDirAlias'), ...
                    obj.scratchPath);

                % Case when we use jokers to get a list of files (or just one file when
                % we lack some arguments to precisely determine the name of the file...
                if ~isempty(patternsToReplaceByJoker)
                  regexpIndices = regexp(filePath, regexpPattern, 'start');
                  notEmptyIndices  = ~cellfun('isempty', regexpIndices);
                  filePath = filePath(notEmptyIndices);
                  tmpFiles = tmpFiles(notEmptyIndices, :); % to get the last edit date
                    % below.
                end

                if size(filePath, 1) == 0
                    fileExists = 0;
                    fileLastEditDate = NaT;
                    thisDate = NaT;
                else
                    fileExists = ones([size(filePath, 1), 1], 'uint8'); 
                        % NB: is cell array in other getFileXxx() methods. num2cell().
                    fileLastEditDate = table2array(rowfun(@(x) ...
                        datetime(x, InputFormat = 'dd-MMM-yyyy HH:mm:ss'), ...
                        tmpFiles, InputVariables = {'date'}));
                        % NB: is cell array in other getFileXxx() methods. table2cell().
                    [~, thisFileName, ~] = fileparts(filePath);
                    theseMetadata = split(thisFileName, {'_', '.'});
                        [~, thisFileName, ~] = fileparts(filePathWithPatterns);
                    if iscolumn(theseMetadata)
                        % Case only one file in tmpFiles correspond to the call.
                        theseMetadata = theseMetadata';
                    end
                    theseMetadataNames = replace(split(thisFileName, {'_', '.'}), ...
                        {'{', '}'}, {'', ''});
                    if ischar(thisDate) && isequal(thisDate, '*') && ...
                      ~filePathConf.isAncillary(1) && ...
                      ~isempty(filePathConf.dateInFileName{1})
                        metadataIdx = find(strcmp(theseMetadataNames, 'thisDate'));
                        thisDate = datetime(theseMetadata(:, metadataIdx), ...
                            InputFormat = filePathConf.dateInFileName{1});
                    elseif ~isdatetime(thisDate)
                        thisDate = NaT;
                    end
                      % NB: We update thisDate only when the return is a list of files
                      % corresponding to several dates.
                    if ischar(timestampAndNrt) && isequal(timestampAndNrt, '*') && ...
                      ~filePathConf.isAncillary(1) && ...
                      contains(filePathConf.fileLabel{1}, '{timestampAndNrt}')
                      metadataIdx = find(strcmp(theseMetadataNames, 'timestampAndNrt'));
                      metaData.timestampAndNrt = theseMetadata{:, metadataIdx};
                    else
                      metaData.timestampAndNrt = '';
                    end
                      % NB: beware that metaData.timestampAndNrt is only filled when
                      % there is one file only.                                 @warning
                end
                % De-cellification if only 1 return.
                if iscell(filePath) & length(filePath) == 1
                    filePath = filePath{1};
                    fileExists = fileExists(1);
                    fileLastEditDate = fileLastEditDate(1);
                    thisDate = thisDate(1);
                end
                % Here I think we need to get the varName and objectName if they were
                % in wild cards *.                                                 @todo
            else
                % Remove the part with wild cards *.
                % NB: remove all the part at the first folder with wild card until last
                % character of filePath.
                % NB: this can induce a lot of delay due to rsync full folders. @warning
                % NB: Don't handle other globbing wild cards as ? [] ^ {} ,
                thatFilePath = regexprep(filePath, '/[^/]*\*[^@]*$', '/');
                % Copy the file from the archive if present in archive ...
                archiveFilePath = strrep( ...
                    thatFilePath, obj.scratchPath, obj.archivePath);
                cmd = [obj.rsyncAlias, ' ', archiveFilePath, ' ', thatFilePath];
                fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
                [status, cmdout] = system(cmd);
                tmpFiles = struct2table(dir(filePath));
                % if files present in archive and copied we recall the method.
                if ~isempty(tmpFiles)
                    [filePath, fileExists, fileLastEditDate, metaData, thisDate] = ...
                      obj.getFilePath(objectName, dataLabel, ...
                      complementaryLabel = complementaryLabel, ...
                      monthWindow = monthWindow, optim = optim, ...
                      patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                      thisDate = thisDate, thisIndex = thisIndex, ...
                      thisYear = thisYear, thisWaterYear = thisWaterYear, ...
                      timestampAndNrt = timestampAndNrt, varName = varName);
                else
                    fileExists = 0;
                    fileLastEditDate = NaT;
                    thisDate = NaT;
                end
            end
            fileExists = logical(fileExists);
        end
        function [filePath, fileExists, fileLastEditDate, metaData] = ...
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
            % monthWindow: int, optional. MonthWindow of the data within the file.
            % timestampAndNrt: char, optional. Only for mod09ga files.
            % thisIndex: int, optional. Index of the pixel for files containing only 1
            %   pixel, e.g. modisspiresyeartmp.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % filePath: char or cellarray(char). FilePath or list of filePath when joker
            %   is used.
            %   NB: if cellarray and 2 versions of the file exists, only the file with
            %   the most recent fileLastEditDate is in the filePath list.
            % fileExists: uint8 or cellarray(uint8). 0 if file doesn't exist.
            % fileLastEditDate: datetime or cellarray(datetime).
            % metaData: struct(objectId, objectName, objectType, varId, varName).
            %   information yielded by getObjectIdentification() and
            %   getVariableIdentification() through the call to replacePatternByValue().
            %   These metadata are currently not updated when objectName or varName
            %   were jokerized to yield all files of a certain type, whatever the
            %   variables or objects.                                           @warning
            thisFunction = 'ESPEnv.getFilePathForDateAndVarName';
            p = inputParser;
            addParameter(p, 'patternsToReplaceByJoker', {});
            addParameter(p, 'monthWindow', WaterYearDate.yearMonthWindow);
            addParameter(p, 'timestampAndNrt', '');
            addParameter(p, 'thisIndex', 1);

            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            % Mustn't add countOfPixelPerDimension in default.                  @warning
            addParameter(p, 'optim', struct());

            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            patternsToReplaceByJoker = p.Results.patternsToReplaceByJoker;
            monthWindow = p.Results.monthWindow;
            timestampAndNrt = p.Results.timestampAndNrt;
            thisIndex = p.Results.thisIndex;

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
            if filePathConf.isAncillary(1) == 0 && ...
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

            filePath = fullfile(directoryPath, ...
                [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}]);

            [filePath, regexpPattern, metaData] = ...
                obj.replacePatternsInFileOrDirPaths(filePath, ...
                objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                monthWindow = monthWindow, timestampAndNrt = timestampAndNrt, ...
                thisIndex = thisIndex, optim = optim);
                % If there are jokers in pattern to replace, this list can yield
                % multiple results. However, the metaData are not specifically updated
                % to the correct list of objectName or varName right now.          @todo

            [directoryPath, ~, ~] = fileparts(filePath);
            if isempty(patternsToReplaceByJoker) && ~isfolder(directoryPath)
                mkdir(directoryPath);
            end

            % 2. Generation of the filename, check existence of filenames and determine
            % last edit date.
            %---------------------------------------------------------------------------
            tmpFiles = struct2table(dir(filePath));
            tmpFiles = sortrows(tmpFiles(tmpFiles.isdir == 0, :), 'datenum', ...
                'descend');
             
            if ~isempty(tmpFiles)
                filePath = table2cell(rowfun(@(x, y) fullfile(x, y), tmpFiles, ...
                    InputVariables = {'folder', 'name'}));

                % Specific Alpine. To implement cleaner!!!!!!!                     @todo
                filePath = replace(filePath, '/gpfs/alpine1/scratch/', '/scratch/alpine/');

                % Case when we use jokers to get a list of files (or just one file when
                % we lack some arguments to precisely determine the name of the file...
                regexpIndices = regexp(filePath, regexpPattern, 'start');
                notEmptyIndices  = ~cellfun('isempty', regexpIndices);
                filePath = filePath(notEmptyIndices);
                tmpFiles = tmpFiles(notEmptyIndices, :); % to get the last edit date
                    % below.

                if size(filePath, 1) == 0
                    fileExists = 0;
                    fileLastEditDate = NaT;
                else
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
                % Here I think we need to get the varName and objectName if they were
                % in jokers.                                                       @todo
            else
                % Remove the part with jokers *.
                % NB: this can induce a lot of delay due to rsync full folders. @warning
                thatFilePath = regexprep(filePath, '/[^/]*\*[^@]*$', '/');
                % Copy the file from the archive if present in archive ...
                archiveFilePath = strrep( ...
                    thatFilePath, obj.scratchPath, obj.archivePath);
                cmd = [obj.rsyncAlias, ' ', archiveFilePath, ' ', thatFilePath];
                fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
                [status, cmdout] = system(cmd);
                tmpFiles = struct2table(dir(filePath));
                % if files present in archive and copied we recall the method.
                if ~isempty(tmpFiles)
                    [filePath, fileExists, fileLastEditDate, metaData] = ...
                      obj.getFilePathForDateAndVarName(objectName, dataLabel, ...
                      thisDate, varName, complementaryLabel, ...
                      patternsToReplaceByJoker = patternsToReplaceByJoker, ...
                      monthWindow = monthWindow, timestampAndNrt = timestampAndNrt, ...
                      thisIndex = thisIndex, optim = optim);
                else
                    fileExists = 0;
                    fileLastEditDate = NaT;
                end
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
            %   NB: specific handling for spiresModel, depending on modis/viirs and Ned
            %   filter conf or not.
            %
            % Return
            % ------
            % filePath: char.
            % existFile: uint8. 0 if file doesn't exist.
            
            % Handling of dataLabel spiresmodel depending on inputProduct and spires
            % conf associated to object.
            if ismember(dataLabel, {'backgroundreflectance', 'spiresmodel'})
                switch obj.modisData.inputProduct
                    case 'mod09ga'
                        thatConfId = obj.myConf.region(strcmp( ...
                            obj.myConf.region.name, objectName), :).spiresConfId(1);
                        thatConf = ...
                            obj.myConf.filter(obj.myConf.filter.id == thatConfId, :);
                        switch dataLabel
                            case 'backgroundreflectance'
                                parameterName = ...
                                    'spiresBackgroundReflectanceSourceForModis'; 
                                valueForThatParameter = ...
                                    Tools.valueInTableForThisField(thatConf, ...
                                    'lineName', parameterName, 'minValue');
                                if valueForThatParameter == 1
                                    dataLabel = 'backgroundreflectanceformodisned';
                                else
                                    dataLabel = [dataLabel, 'formodis'];
                                end
                            case 'spiresmodel'
                                parameterName = 'spiresModelForModis'; 
                                valueForThatParameter = ...
                                    Tools.valueInTableForThisField(thatConf, ...
                                    'lineName', parameterName, 'minValue');
                                if valueForThatParameter == 1
                                    dataLabel = 'spiresmodelformodisned';
                                else
                                    dataLabel = [dataLabel, 'formodis'];
                                end
                        end
                    case 'vnp09ga'
                        dataLabel = [dataLabel, 'forviirs'];
                end
                fprintf('%s: updated dataLabel to: %s.\n', mfilename(), dataLabel);
            end
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
            if ~fileExists && ~ismember(dataLabel, {'espjobforscancel'})
                % Copy the file from the archive if present in archive ...
                archiveFilePath = strrep(filePath, obj.scratchPath, obj.archivePath);
                cmd = [obj.rsyncAlias, ' ', archiveFilePath, ' ', filePath];
                fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
                [status, cmdout] = system(cmd);
                fileExists = isfile(filePath);
            end
        end
        function [filePath, fileExists, lastDateInFile, waterYearDate, metaData] = ...
            getFilePathForWaterYearDate(obj, objectName, dataLabel, waterYearDate, ...
            varargin)
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
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx, depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
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
            % metaData: struct(objectId, objectName, objectType, varId, varName).
            %   information yielded by getObjectIdentification() and
            %   getVariableIdentification() through the call to replacePatternByValue().
            %   These metadata are currently not updated when objectName or varName
            %   were jokerized to yield all files of a certain type, whatever the
            %   variables or objects.                                           @warning
            %
            % NB: method which retakes some of the code of getFilePathForDate(). Maybe
            %   some mutualization is possible?                                    @todo
            %
            % NB: the method is way too long to get all mosaic files of a wateryear.
            %   Shortcuts using regexp needs                                       @todo
            %
            % NB: if the list of files has been requested in last call, we returned that
            %   list (stored in property .lastCallToGetFilePathForWaterYearDate.

            % 1. Generation and check existence of the file directory path.
            %---------------------------------------------------------------------------
            varName = '';
            complementaryLabel = '';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            % Mustn't add countOfPixelPerDimension in default.                  @warning
            addParameter(p, 'optim', struct());

            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.

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

            % Check if we didn't already ask the list of files. If yes we return
            % that list.
            if ~isempty(obj.lastCallToGetFilePathForWaterYearDate.objectName) && ...
                strcmp(obj.lastCallToGetFilePathForWaterYearDate.objectName, ...
                    objectName) && ...
                strcmp(obj.lastCallToGetFilePathForWaterYearDate.dataLabel, ...
                    dataLabel) && ...
                isequal(obj.lastCallToGetFilePathForWaterYearDate.waterYearDate, ...
                    waterYearDate)
                filePath = obj.lastCallToGetFilePathForWaterYearDate.filePath;
                lastDateInFile = ...
                    obj.lastCallToGetFilePathForWaterYearDate.lastDateInFile;
                fileExists = ones([1, length(lastDateInFile)], 'uint8');
                waterYearDate = ...
                    obj.lastCallToGetFilePathForWaterYearDate.newWaterYearDate;
                metaData = obj.lastCallToGetFilePathForWaterYearDate.metaData;
                return;
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
            metaData = struct();
            if filePathConf.period == 5
                % If file cover 1 waterYear...
                % NB: strcmp(filePathConf.dateInFileName{1}, 'yyyy') can be calendar
                % year or wateryear, unfortunately right now.
                % WARNING: right now, we don't handle waterYearDate covering several
                % waterYears, so here there's 1 file only.                      @warning

                thisDate = theseDates(end);
                [thatFilePath, thatFileExists, ~, metaData] = ...
                    obj.getFilePathForDateAndVarName(objectName, dataLabel, ...
                        thisDate, varName, complementaryLabel, optim = optim);
                filePath = {thatFilePath};
                fileExists = [thatFileExists];
                if ~fileExists
                    lastDateInFile = [NaT];
                    waterYearDate = [];
                else
                    fileExtension = Tools.getFileExtension(thatFilePath);
                    if strcmp(fileExtension, '.h5')
                        % NB: ugly. Should be handled in a function.               @todo
                        % this case is only for [xx]spiressmoothbycell dataLabel in .h5
                        % WARNING: Assumes that dates are written as attributes in
                        % location dateAttributePath.                           @warning
                        thisLastDateInFile = h5readatt(thatFilePath, ...
                            filePathConf.dateAttributePath{1}, ...
                            filePathConf.dateFieldName{1});
                    else
                        % default .mat file. Others will raise error.
                        thisLastDateInFile = load(thatFilePath, ...
                            filePathConf.dateFieldName{1}).( ...
                            filePathConf.dateFieldName{1});
                    end
                    thisLastDateInFile = thisLastDateInFile(end);
                    if isnumeric(thisLastDateInFile)
                        thisLastDateInFile = num2str(thisLastDateInFile);
                    end
                    if strcmp(filePathConf.dateFieldType{1}, 'datenum')
                        thisLastDateInFile = datetime(thisLastDateInFile, ...
                            ConvertFrom = filePathConf.dateFieldType{1});
                    elseif strcmp(filePathConf.dateFieldType{1}, 'yyyyJD')
                        thisLastDateInFile = datetime(char(thisLastDateInFile), ...
                            InputFormat = 'uuuuDDD');
                            % datetime expects ISO year uuuu and not gregorian yyyy.
                    elseif strcmp(filePathConf.dateFieldType{1}, 'yyyyMMdd')
                        thisLastDateInFile = datetime(thisLastDateInFile, ...
                            InputFormat = 'yyyyMMdd');
                    end % default: datetime.
                    thisLastDateInFile = datetime(year(thisLastDateInFile), ...
                        month(thisLastDateInFile), day(thisLastDateInFile), ...
                        waterYearDate.dayStartTime.HH, ...
                        waterYearDate.dayStartTime.MIN, ...
                        waterYearDate.dayStartTime.SS);
                        % Because dates are stored without time in spiressmoothbycell.
                    lastDateInFile = [thisLastDateInFile];
                    if ~isequal(thisLastDateInFile, theseDates(end))
                        waterYearDate = ...
                            waterYearDate.shortenToDate(thisLastDateInFile);
                    end
                end
                return;
            end
            % File cover less than a waterYear.
            % WARNING: No handling of calendar year right now.                  @warning
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
                filePath{dateIdx} = fullfile(directoryPath, ...
                    [filePathConf.fileLabel{1}, filePathConf.fileExtension{1}]);

                [filePath{dateIdx}, ~, thatMetaData] = ...
                    obj.replacePatternsInFileOrDirPaths(filePath{dateIdx}, ...
                    objectName, dataLabel, thisDate, varName, complementaryLabel, ...
                    optim = optim);
                    % If there are jokers in pattern to replace, this list can yield
                    % multiple results. However, the metaData are not specifically
                    % updated to the correct list of objectName or varName right now.
                    %                                                              @todo
                [directoryPath, ~, ~] = fileparts(filePath{dateIdx});
                if ~isfolder(directoryPath)
                    mkdir(directoryPath);
                end

                if dateIdx == 1
                    metaData = thatMetaData;
                end

                % Determine existence of file and last date in file (for daily file,
                % if present, the last date is automatically the date in the filename):
                % We first make sure the file was copied from archive.
                if ~isfile(filePath{dateIdx})
                    % Copy the file from the archive if present in archive ...
                    archiveFilePath = strrep(filePath{dateIdx}, obj.scratchPath, ...
                        obj.archivePath);
                    cmd = [obj.rsyncAlias, ' ', archiveFilePath, ' ', ...
                        filePath{dateIdx}];
                    fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
                    [status, cmdout] = system(cmd);
                end   
                if isfile(filePath{dateIdx})
                    fileExists(dateIdx) = 1;
                    if strcmp(filePathConf.dateInFileName{1}, 'yyyyMM')
                        thisLastDateInFile = max( ...
                            load(filePath{dateIdx}, filePathConf.dateFieldName{1}).( ...
                                filePathConf.dateFieldName{1}));
                        if strcmp(filePathConf.dateFieldType{1}, 'datenum')
                            lastDateInFile(dateIdx) = datetime(thisLastDateInFile, ...
                                ConvertFrom = filePathConf.dateFieldType{1});
                        else
                            lastDateInFile(dateIdx) = thisLastDateInFile;
                        end
                    else
                        lastDateInFile(dateIdx) = thisDate;
                    end
                end
            end
            obj.lastCallToGetFilePathForWaterYearDate = struct();
            obj.lastCallToGetFilePathForWaterYearDate.objectName = objectName;
            obj.lastCallToGetFilePathForWaterYearDate.dataLabel = dataLabel;
            obj.lastCallToGetFilePathForWaterYearDate.waterYearDate = waterYearDate;
            obj.lastCallToGetFilePathForWaterYearDate.filePath = ...
              filePath(fileExists == 1);
            obj.lastCallToGetFilePathForWaterYearDate.lastDateInFile = ...
              lastDateInFile(fileExists == 1);


            lastDateInFileWhichExists = lastDateInFile(fileExists == 1);
            if ~isempty(lastDateInFileWhichExists) && ...
                lastDateInFileWhichExists(end) ~= lastDateInFile(end)
                waterYearDate = ...
                  waterYearDate.shortenToDate(lastDateInFileWhichExists(end));
                % waterYearDate.overlapOtherYear = 1;
                % Should be in constructor                                     @todo
                    % Not sure this is adapted for Spires Interpolator ...
            end

            obj.lastCallToGetFilePathForWaterYearDate.newWaterYearDate = waterYearDate;
            obj.lastCallToGetFilePathForWaterYearDate.metaData = metaData;
        end
        function [startIdx, endIdx, thisSize] = getIndicesForCell(obj, ...
            cellIdx, countOfCellPerDimension, countOfPixelPerDimension)
            % Calculates the row and colum indices for a cell if we divide a matrix by
            % cells to improve parallelization of computations.
            %
            % Parameters
            % ----------
            % cellIdx:  int or array(int). [rowCellIdx, columnCellIdx, depthCellIdx].
            %   Indices of the cell part of a tile. Row indices are counted from
            %   top to bottom, column indices from left to right. The array can extend
            %   to a number of dimensions higher than 3. Default [1, 1].
            % countOfCellPerDimension: int or array(int).
            %   [rowCellCount, columnCellCount, depthCellCount].
            %   Number of cells dividing the set of rows and same for columns, depths.
            %   E.g. if we want to divide a 2400x2400 tile in 9 cells,
            %   countOfCellPerDimension = [3, 3]. Default [1, 1]. MUST have same
            %   number of elements as cellIdx.
            % countOfPixelPerDimension: int or array(int), optional.
            %   [rowCount, columnCount, depthCount].
            %   Number of pixels in a row and same in a column and in depth
            %   (3rd dimension). MUST have same number of elements as cellIdx.
            %
            % Return
            % ------
            % startIdx: array(uint32). List of starting index for each dimension, e.g.
            %   [starting row idx, starting column idx, starting depth idx].
            %   (range 1-4294967295).
            % endIdx: array(uint32). List of end index for each dimension, e.g.
            %   [ending row idx, ending column idx, ending depth idx].
            % thisSize: array(uint32). List of size per dimension.
            thisFunction = 'MODISData.getIndicesForCell';
            cellIdx = single(cellIdx);
            countOfCellPerDimension = single(countOfCellPerDimension);
            % NB: All calculations should be done at least in single, otherwise,
            % if int, doesnt work because of the division.
            countOfPixelPerDimension = single(countOfPixelPerDimension);
            countOfPixelInCellPerDimension = ...
                floor(countOfPixelPerDimension ./ countOfCellPerDimension);
            for idx = 1:length(cellIdx)
                if cellIdx(idx) > countOfCellPerDimension(idx)
                    error(['%s: cellIdx %d > countOfCellPerDimension %d.'], ...
                        thisFunction, cellIdx(idx), countOfCellPerDimension(idx));
                end
            end

            startIdx = countOfPixelInCellPerDimension .* (cellIdx - 1) + 1;
            endIdx = startIdx + countOfPixelInCellPerDimension - 1;
            % Correction of size of last cell, if number of cells x size doesnt fit.
            for idx = 1:length(cellIdx)
                if cellIdx(idx) == countOfCellPerDimension(idx)
                    endIdx(idx) = countOfPixelPerDimension(idx);
                end
            end

            startIdx = uint32(startIdx);
            endIdx = uint32(endIdx);
            thisSize = endIdx - startIdx + 1;
        end
        function [startIdx, endIdx, thisSize] = getIndicesForCellForDataLabel(obj, ...
            objectName, dataLabel, varargin)
            % Yield cell indices and dimensions for a dataLabel, list of dates and cell
            %   configuration. Takes into account which dimension is time, and correct
            %   indices in the time dimension to fit the dates.
            % Parameters
            % ----------
            % objectName: char. Unique name of the object, either region (type 0) or
            %   subdivision (type 1). Configuration in espEnv.myConf.region and
            %   espEnv.myConf.landsubdivision. Necessary to get the number of days
            %   of a waterYear.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw. Configuration
            %   in espEnv.myConf.variableversion.
            % theseDate: datetime or array(datetime) [firstDate, lastDate], optional.
            %   Cover the period for which we want the data instantiated. Configuration
            %   in espEnv.myConf.filePath, field period and dimensionInfo. Default:
            %   today.
            % varName: char, optional. Necessary to know if there's resampling (is
            %   this variable in 1200x1200 (resamplingFactor 2) or 2400x2400 (factor 1).
            %   Default: 'defaultVarName' (resamplingFactor 1).
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, minMaxCut), optional. Used to
            %   override varName configuration.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   other fields not used in the method, in particular dimensionInfo.
            %                                                                   @warning
            %   save: 1 or 0. 1: indicates that force parameters are used for input,
            %       for instance in the context of saving data. By default 0.
            %   instantiate: 1 or 0: indicates force parameters are used to instantiate
            %       the data with the correct size. By default 0.
            % mode: int, optional. 0: default, Indices for data. 1: indices for 
            %       replacement in filepath pattern (e.g. for dataLabel
            %       modisspiressmoothbycell).
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % startIdx: array(uint32). List of starting index for each dimension, e.g.
            %   [starting row idx, starting column idx, starting depth idx].
            %   (range 1-4294967295).
            % endIdx: array(uint32). List of end index for each dimension, e.g.
            %   [ending row idx, ending column idx, ending depth idx].
            % thisSize: array(uint32). List of size per dimension.
            %
            % NB: We don't handle the case when optim.countOfCellPerDimension = 1200 and
            % resampling factor 1/2.
            % That is when resamplingFactor 1 in file but outputResamplingFactor 2.
            %                                                                   @warning
            %
            % NB: this method is really complicated and would deserve refactoring/
            % clarification.                                                       @todo

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.getIndicesForCellForDataLabel';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], ...
                force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
                % Dont add here countOfPixelPerDimension = [1, 1, 1], ... because when
                % not given as argument, it is calculated from espEnv.myConf.filePath.
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'mode', 0);
            addParameter(p, 'theseDate', datetime('today'));
            addParameter(p, 'varName', 'defaultVarName');
            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;
            mode = p.Results.mode;

            theseDate = p.Results.theseDate;
            varName = p.Results.varName;
            if isempty(varName)
              varName = 'defaultVarName';
                % Not very clear, because the signature of replacePatternByValue()
                % includes an obligatory varName argument set to ''.               @todo
            end
            if ~strcmp(varName, 'defaultVarName')
              varLabel = varName;
              [varId, ~] = obj.getVariableIdentification(varLabel);
            end
            if size(theseDate, 2) == 1
                theseDate = [theseDate, theseDate];
            end % to get a start and end.

            % Resampling management.
            % Count of pixels per row/column, depending on resamplingFactor.
            defaultColumnCountOfPixel = ...
                obj.modisData.sensorProperties.tiling.columnPixelCount;
                % count for resamplingFactor = 1.
                % half of this for resamplingFactor = 2.
                % Sorry it's afterthought, convoluted implementation....        @warning
            defaultRowCountOfPixel = ...
                obj.modisData.sensorProperties.tiling.rowPixelCount;
            startIdx = 1;
            endIdx = 1;
            thisSize = 1;
            
            if ismember(dataLabel, {'espjobforscancel'})
              return;
            end

            thisFile = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
                
            % If files split in cell files, the start and end indices should be
            % rectified accordingly for data (but not for patterns in filepath).
            % NB: this may be ugly....                                          @warning
            if mode == 0 && (thisFile.countOfFilesPerDim1 > 1 || ...
                thisFile.countOfFilesPerDim2 > 1)
                optim.cellIdx = [1, 1, 1];
            end

            inputResamplingFactor = 1;
            outputResamplingFactor = 1;
            % a. Get data scenario. We get the indices for the input file. optim
            % contains here the indices
            % of the output we desire and force the resampling factor of the output.
            if ~strcmp(varName, 'defaultVarName')
                [theseVariable, ~] = obj.getVariable(dataLabel);
                if ~isempty(theseVariable)
                    thisVariable = theseVariable(theseVariable.id == varId, :);
                    if ~isempty(thisVariable)
                        % thisVariable can be empty only when variable.writegeotiff
                        % is different than variableversion.used. This behavior needs
                        % to be simpler.                                       @todo
                        inputResamplingFactor = thisVariable.resamplingFactor(1);
                    end
                end
            end
            if ismember('resamplingFactor', fieldnames(force))
                outputResamplingFactor = force.resamplingFactor;
            end

            % b. Save data scenario.
            % we get the indices for the output save file. optim contains here the
            % indices from the input to save and force the resampling factor of
            % the input.
            if ismember('save', fieldnames(force))
                inputResamplingFactorTmp = inputResamplingFactor;
                inputResamplingFactor = outputResamplingFactor;
                outputResamplingFactor = inputResamplingFactorTmp;
                inputResamplingFactorTmp = [];

                columnCountOfPixel = ...
                    defaultColumnCountOfPixel / outputResamplingFactor;
                rowCountOfPixel = ...
                    defaultRowCountOfPixel / outputResamplingFactor;
            elseif ismember('instantiate', fieldnames(force))
                if ismember('resamplingFactor', fieldnames(force))
                    columnCountOfPixel = ...
                        defaultColumnCountOfPixel / outputResamplingFactor;
                    rowCountOfPixel = ...
                        defaultRowCountOfPixel / outputResamplingFactor;
                else
                    columnCountOfPixel = ...
                        defaultColumnCountOfPixel / inputResamplingFactor;
                    rowCountOfPixel = ...
                        defaultRowCountOfPixel / inputResamplingFactor;
                end
            else
                % Update count of pixels in the get scenarios.
                columnCountOfPixel = ...
                    defaultColumnCountOfPixel / inputResamplingFactor;
                rowCountOfPixel = ...
                    defaultRowCountOfPixel / inputResamplingFactor;
            end

            resamplingFactor = inputResamplingFactor / outputResamplingFactor;

            % Determine the time dimension and related indices.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % NB: Time dimension can be absent or present in any dimension, knowing that
            %   the file can contain 1 day, 1 month, one 3-month,
            %   one year, or one wateryear (starting for northern hemisphere 10/1 of the
            %   previous year.
            if isa(theseDate, 'datetime')
                switch thisFile.period
                    case 1
                        % 1 day only. It can be a specific day or 1 representative day with
                        % an average of data. Means no time dimension.
                        timeStartIdx = 1;
                        timeEndIdx = 1;
                        % countOfCellPerTime = 1;
                    case 2
                        % 1 month. It contains a varying number of days, 28, 29, 30, 31.
                        if year(theseDate(1)) ~= year(theseDate(end)) && ...
                            month(theseDate(1)) ~= month(theseDate(end))
                            error( ...
                           ['%s: Dates %s and %d don''t have same year/same month but ', ...
                           'dataLabel %s requires it.'], thisFunction, ...
                           char(theseDate(1), 'yyyy-MM-dd'), ...
                           char(theseDate(end), 'yyyy-MM-dd'), dataLabel);
                        end
                        timeStartIdx = day(theseDate(1));
                        timeEndIdx = day(theseDate(end));
                        % countOfCellPerTime = eom(year(thisDate(1)), month(thisDate(1)));
                    case 3
                        % 3 months. It contains a varying number of days, up to 92.
                        error(['%s: No handling of 3-month cubes right now.\n'], ...
                            thisFunction);
                    case 4
                        % 1 calendar year, from Jan 1st to Dec 31, contains 365 or 366 days.
                        if year(theseDate(1)) ~= year(theseDate(end))
                            error( ...
                           ['%s: Dates %s and %d don''t have same year but ', ...
                           'dataLabel %s requires it.'], thisFunction, ...
                           char(theseDate(1), 'yyyy-MM-dd'), ...
                           char(theseDate(end), 'yyyy-MM-dd'), dataLabel);
                        end
                        timeStartIdx = day(theseDate(1), 'dayofyear');
                        timeEndIdx = day(theseDate(end), 'dayofyear');
                        % countOfCellPerTime = yeardays(year(thisDate));
                    case 5
                        % 1 waterYear, for northern hemisphere, from 10/1 to 9/30, for
                        % southern hemisphere, from 4/1 to 3/31 or others, contains 365 or
                        % 366 days.
                        [objectId, ~, objectType] = obj.getObjectIdentification(objectName);
                        if objectType == 0
                            thisObject = obj.myConf.region( ...
                                obj.myConf.region.id == objectId, :);
                        else
                            thisObject = obj.myConf.landsubdivision( ...
                                obj.myConf.landsubdivision.id == objectId, :);
                        end

                        if WaterYearDate.getWaterYearFromDate(theseDate(1), ...
                            thisObject.firstMonthOfWaterYear) ~= ...
                            WaterYearDate.getWaterYearFromDate(theseDate(end), ...
                            thisObject.firstMonthOfWaterYear)
                             error( ...
                           ['%s: Dates %s and %d don''t have same water year but ', ...
                           'dataLabel %s requires it.'], thisFunction, ...
                           char(theseDate(1), 'yyyy-MM-dd'), ...
                           char(theseDate(end), 'yyyy-MM-dd'), dataLabel);
                        end
                        timeStartIdx = WaterYearDate.getDayInWaterYear(theseDate(1), ...
                            thisObject.firstMonthOfWaterYear);
                        timeEndIdx = WaterYearDate.getDayInWaterYear(theseDate(end), ...
                            thisObject.firstMonthOfWaterYear);
                        % countOfCellPerTime = getCountOfDayInWaterYear(theseDate(1), ...
                        %    thisObject.firstMonthOfWaterYear);
                end
            else
                % theseDate is '', because we are looking for a group of files and
                % and theseDate is replace by a wildcard.
                timeStartIdx = 1;
                timeEndIdx = 1;
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Determination of the number of dimensions for cellIdx
            % slice indices of the time dimension as a function of thisDate.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % This overrides the optim.cellIdx and optim.countOfCells, after first
            % getting the indices from them, when it's necessary depending on file
            % data dimension configuration and time dimension.
            %
            % NB: the case when we call only a pixel or set of pixels is handled only
            % for thisFile.dimensionInfo = 20 and 30.
            %                                                                   @warning
            switch thisFile.dimensionInfo
                case 11
                    % 11: 1 dim column: row*column (reshaped matrix in one row with
                    % each pixel correspond to a column).
                    if ~ismember('countOfPixelPerDimension', fieldnames(optim))
                        optim.countOfPixelPerDimension= [1, ...
                            columnCountOfPixel * rowCountOfPixel];
                    end
                    [startIdx, endIdx, thisSize] = obj.getIndicesForCell( ...
                        optim.cellIdx(1:2), optim.countOfCellPerDimension(1:2), ...
                        optim.countOfPixelPerDimension(1:2));
                case 20
                    % 20: 2 dim: pixel row x pixel column (only one day here).
                    % Here, there's no time dimension.
                    if ~ismember('countOfPixelPerDimension', fieldnames(optim))
                        optim.countOfPixelPerDimension = ...
                            [rowCountOfPixel, columnCountOfPixel];
                        if optim.countOfCellPerDimension(1) == ...
                            defaultRowCountOfPixel ...
                            && optim.countOfCellPerDimension(2) == ...
                            defaultColumnCountOfPixel && resamplingFactor == 2
                            optim.cellIdx(1:2) = ...
                                floor((optim.cellIdx(1:2) - 1) / 2 + 1);
                        end
                    end
                    [startIdx, endIdx, thisSize] = obj.getIndicesForCell( ...
                        optim.cellIdx(1:2), optim.countOfCellPerDimension(1:2), ...
                        optim.countOfPixelPerDimension(1:2));
                case 21
                    % 21: 2 dim: day x row*column (reshaped matrix with each pixel
                    % corresponding to a column of days)
                    if ~ismember('countOfPixelPerDimension', fieldnames(optim))
                        optim.countOfPixelPerDimension = ...
                            [1, rowCountOfPixel * columnCountOfPixel];
                            % Dim 1 will be overriden.
                    end
                    [startIdx, endIdx, thisSize] = obj.getIndicesForCell( ...
                        optim.cellIdx(1:2), optim.countOfCellPerDimension(1:2), ...
                        optim.countOfPixelPerDimension(1:2));
                    startIdx(1) = timeStartIdx;
                    endIdx(1) = timeEndIdx;
                    thisSize(1) = timeEndIdx - timeStartIdx + 1;
                case 30
                    % 30: pixel row x pixel column x day.
                    if ~ismember('countOfPixelPerDimension', fieldnames(optim))
                        optim.countOfPixelPerDimension = ...
                            [rowCountOfPixel, ...
                            columnCountOfPixel, 1];
                            % Dim 3 will be overriden.
                        if optim.countOfCellPerDimension(1) == ...
                            defaultRowCountOfPixel ...
                            && optim.countOfCellPerDimension(2) == ...
                            defaultColumnCountOfPixel && resamplingFactor == 2
                            optim.cellIdx(1:2) = ...
                                floor((optim.cellIdx(1:2) - 1) / 2 + 1);
                        end
                    end
                    [startIdx, endIdx, thisSize] = obj.getIndicesForCell( ...
                        optim.cellIdx(1:3), optim.countOfCellPerDimension(1:3), ...
                        optim.countOfPixelPerDimension(1:3));
                    startIdx(3) = timeStartIdx;
                    endIdx(3) = timeEndIdx;
                    thisSize(3) = timeEndIdx - timeStartIdx + 1;
            end
        end
        function [objectId, varId, thisDate, thisYear, monthWindow, ...
            metaData] = ...
            getMetadataFromFilePath(obj, filePath, dataLabel)
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
            % thisYear: int.
            % monthWindow: int.
            % metaData: struct. Having complementary metadata: rowStartId, rowEndId,
            %   columnStartId, columnEndId, timestampAndNrt.
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
            % NB: Requires at least a changing field in the pattern indicated by
            % the text ['{', fieldName, '}'].
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ismember('{', patternFilePath)
                findChar = replace(patternFilePath, ...
                    {'\', '/', '.'}, {'\\', '\/', '\.'});

                findChar = regexprep(findChar, '{([0-9A-Za-z_]*)}', ...
                    '{([0-9A-Za-z_]*)}');

                replaceChar = replace(regexprep(num2str( ...
                    1:count(patternFilePath, '{'), ' %u'), ...
                    '([0-9]*)', '\$$1'), '  ', ' ');
                fieldName = split(regexprep(patternFilePath, findChar, replaceChar));

                findCell = cellfun(@(c)['{', c, '}'], fieldName, UniformOutput = false);
                replaceCell = cell(size(findCell));
                replaceCell(:) = {'([0-9A-Za-z]*)'};
                replaceCell(ismember(findCell, {'{version}', ...
                    '{versionOfAncillary}'})) = {'([0-9A-Za-z\.]*)'};
                    % NB: this is because versions include a dot, like v2023.0.
                replaceCell(ismember(findCell, ...
                    {'{EPSGCode}', '{varName}', '{varNameWithinFile}'})) = ...
                    {'([0-9A-Za-z\_]*)'};
                    % NB: this is because varNamesand EPSGCode include a _,
                    % like snow_fraction.

                findChar = replace(patternFilePath, {'\', '/', '.'}, ...
                    {'\\', '\/', '\.'});
                findChar = replace(findChar, findCell, replaceCell);
                findChar = replace(findChar, ').', ')\.');
                fieldValue = split(regexprep(filePath, findChar, replaceChar));

                % Attribution of the value to each field, conversion to the correct
                % format for dates and years.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                numericFieldValue = cellfun(@str2double, fieldValue, ...
                    UniformOutput = false);
                datetimeFieldValue = cell(size(fieldValue));
                datetimeFieldValue(:) = {NaT};
                for fieldIdx = 1:length(fieldName)
                    evalChar = '';
                    if ~isnan(numericFieldValue{fieldIdx})
                        if length(fieldValue{fieldIdx}) == 8
                            evalChar = [fieldName{fieldIdx}, ' = datetime(''', ...
                                fieldValue{fieldIdx}, ...
                                ''', InputFormat = ''yyyyMMdd'');'];
                        elseif length(fieldValue{fieldIdx}) == 6
                            evalChar = [fieldName{fieldIdx}, ' = datetime(''', ...
                                fieldValue{fieldIdx}, ...
                                '01'', InputFormat = ''yyyyMMdd'');'];
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
            else
                warning('%s: No changing field in file pattern %s', mfilename(), ...
                    patternFilePath);
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
            if ~exist('thisDate', 'var') && ~exist('thisYear', 'var')
                thisDate = NaT;
                thisYear = year(WaterYearDate.fakeDate);
            elseif exist('thisDate', 'var') && ~exist('thisYear', 'var')
                thisYear = year(thisDate);
            elseif exist('thisYear', 'var') && ~exist('thisDate', 'var')
                thisDate = datetime(thisYear, month(WaterYearDate.fakeDate), ...
                    day(WaterYearDate.fakeDate));
            end
            if ~exist('monthWindow', 'var')
                monthWindow = 0;
            end
            metaData = struct();
            metaDataNames= {'rowStartId', 'rowEndId', 'columnStartId', ...
                'columnEndId', 'timestampAndNrt'};
            for metaDataIdx = 1:length(metaDataNames)
                metaDataName = metaDataNames{metaDataIdx};
                if exist(metaDataName, 'var')
                    metaData.(metaDataName) = eval(metaDataName);
                end
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
                    cast(str2double(fakeObjectName), 'single') / 1000)), filesep()], ...
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
            if isa(objectNames, 'char')
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
        function [objectId, objectName, objectType, shortObjectName] = ...
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
            % shortObjectName: char. For region, shortName, for landsubdivision ''.

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
            shortObjectName = '';
            if isequal(objectLabel, objectId) || isequal(objectLabel, objectName)
                objectType = intmax('uint8');
                return;
            end

            % We suppose first that objectLabel is a real name...
            if ischar(objectLabel) && ~isempty(regexp(objectLabel, '[A-Za-z]', 'once'))
                objectName = objectLabel;
                % NB: we exclude the object names containing _mask, specific to
                %   instantiation of regions (should be removed at at some point). @todo
                if isempty(regexp(objectName, '_mask', 'once'))
                    objectId = obj.myConf.region( ...
                        strcmp(obj.myConf.region.name, objectName), :).id;
                    % if empty: means that object is a landsubdivision and not a region:
                    obj.setAdditionalConf('landsubdivision');
                    if isempty(objectId)
                        objectId = obj.myConf.landsubdivision( ...
                            strcmp(obj.myConf.landsubdivision.code, objectName), :).id;
                        if isempty(objectId)
                            warning(['%s, getObjectIdentification(): ', ...
                                'Inexistent ObjectName %s in regions or ', ...
                                'landsubdivisions conf of version %s.\n'], ...
                                mfilename(), ...
                                    objectLabel, obj.modisData.versionOf.ancillary);
                            objectId = 0;
                            objectName = '';
                            objectType = intmax('uint8');
                        else
                            objectType = 1;
                        end
                    else
                        objectId = objectId(1); % by precaution if 2 regions have
                            % same name...
                        shortObjectName = obj.myConf.region( ...
                            strcmp(obj.myConf.region.name, objectName), :).shortName{1};
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
                shortObjectName = obj.myConf.region( ...
                    obj.myConf.region.id == objectId, :).shortName;

                % if empty: means that object is a landsubdivision and not a region:
                obj.setAdditionalConf('landsubdivision');
                if isempty(objectName)
                    objectName = obj.myConf.landsubdivision( ...
                        obj.myConf.landsubdivision.id == objectId, :).code;
                    if isempty(objectName)
                        warning(['%s, getObjectIdentification(): ', ...
                            'Inexistent ObjectId %s in regions or ', ...
                            'landsubdivisions conf of version %s.\n'], ...
                            mfilename(), ...
                            num2str(objectId), obj.modisData.versionOf.ancillary);
                        objectId = 0;
                        objectName = '';
                        objectType = intmax('uint8');
                    else
                        objectType = 1;
                    end
                end
                if isempty(objectName)
                    objectName = '';
                elseif iscell(objectName)
                    objectName = objectName{1};
                    if objectType == 0
                        shortObjectName = shortObjectName{1};
                    else
                        shortObjectName = objectName;
                    end
                end
            end
        end
        function [variable, variableLink, inputVariable] = getVariable(obj, ...
            outputDataLabel, varargin)
            % Yields the variable, the configuration table of the variables written
            % in the output file of the specific outputDataLabel, and variableLinks,
            % listing for each output variable the input variables necessary for
            % calculations.
            %
            % Parameters
            % ----------
            % outputDataLabel: char. DataLabel of the variable output, e.g.
            %   'VariablesMatlab'.
            % inputDataLabel: char, optional. DataLabel of the variable input,
            %   if several input dataLabels are possible. By default = '' and
            %   filter not applied.
            % outputMeasurementTypeId: array(int). Ids of the type of measurement,
            %   to filter to variables of only 1 type. E.g. 75 filters all
            %   days_since_last_observation of all sensors/platforms/method. By default
            %   [] and filter not applied.
            %
            % Return
            % ------
            % variable: table(id: int, name: char, divisor: float,
            %   nodata_value: int or float, type: char, unit: char). List attributes of
            %   all output variables.
            % variableLink: table(outputVarId, inputVarId). Yields the list of input
            %   variables for each output variables.
            % inputVariable: table(id: int, name: char, divisor: float,
            %   nodata_value: int or float, type: char, unit: char). List attributes of
            %   all input variables.
            p = inputParser;
            addParameter(p, 'inputDataLabel', '');
            addParameter(p, 'outputMeasurementTypeId', []);
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            inputDataLabel = p.Results.inputDataLabel;
            outputMeasurementTypeId = p.Results.outputMeasurementTypeId;

            requiredFieldNames = {'name', 'nameWithinFile', 'datasetGroupPath', ...
                    'divisor', ...
                    'max', 'min', 'nodata_value', 'type', 'unit', 'resamplingFactor'};
            variable = innerjoin( ...
                obj.myConf.versionvariable( ...
                    (isempty(inputDataLabel) | ...
                    strcmp(obj.myConf.versionvariable.inputDataLabel, ...
                        inputDataLabel)) ...
                    & strcmp(obj.myConf.versionvariable.outputDataLabel, ...
                    outputDataLabel), :), ...
                obj.myConf.variable(isempty(outputMeasurementTypeId) | ...
                    ismember(obj.myConf.variable.measurementTypeId, ...
                    outputMeasurementTypeId), :), ...
                LeftKeys = 'varId', RightKeys = 'id', ...
                LeftVariables = requiredFieldNames, ...
                RightVariables = {'id', 'measurementTypeId', ...
                    'multiplicator_for_mosaics'});
            variable(isnan(variable.measurementTypeId), 'measurementTypeId') = {0};
              % direct affectation = 0 doesnt work for tables.
            variable = unique(variable);
              % unique doesnt work for nan, considered all distinct in matlab.
            variableLink = innerjoin(variable, ...
                obj.myConf.variablelink, ...
                LeftKeys = 'id', RightKeys = 'outputVarId', ...
                LeftVariables = {}, ...
                RightVariables = {'outputVarId', 'inputVarId'});
            inputVariable = unique(innerjoin(variableLink, ...
                obj.myConf.versionvariable( ...
                    strcmp(obj.myConf.versionvariable.inputDataLabel, ...
                        outputDataLabel), :), ...
                LeftKeys = 'inputVarId', RightKeys = 'varId', ...
                LeftVariables = {}, ...
                RightVariables = [{'varId'}, requiredFieldNames]));
            inputVariable.id = inputVariable.varId;
            inputVariable.varId = [];
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
            if isequal(varLabel, varId) || isequal(varLabel, varName)
                return;
            end
            % We suppose first that varLabel is a real name...
            if ischar(varLabel)
                if ~isempty(regexp(varLabel, '[A-Za-z]', 'once')) ...
                    && ~strcmp(varLabel, '')
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
        function varData = instantiateAndSaveData(obj, objectName, dataLabel, ...
            varargin)
            % Extract the data from a file of type dataLabel, convert to the type,
            %   nodata, min, max, fill missings, and resample them if necessary with
            %   resamplingFactor, create a bit mask of the data which have been changed
            %   (cap min max, fill missings), save varData in the file of type
            %   outputDataLabel and return it.
            % Parameters
            % ----------
            % objectName: char. Unique name of the object, either region (type 0) or
            %   subdivision (type 1). Configuration in espEnv.myConf.region and
            %   espEnv.myConf.landsubdivision.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw. Configuration
            %   in espEnv.myConf.variableversion.
            % theseDate: datetime or array(datetime) [firstDate, lastDate], optional.
            %   Cover the period for which we want the data instantiated. Configuration
            %   in espEnv.myConf.filePath, field period and dimensionInfo. Default:
            %   today.
            % varName: char, optional. Uniqe name of the variable. Configuration in
            %   espEnv.myConf.variable, espEnv.myConf.versionvariable.
            %   Default: 'defaultVarName'.
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, minMaxCut), optional. Used to
            %   override varName configuration.
            %   outputDataLabel: char. We expect the data the format given by the
            %       outputDataLabel. Can be overriden by the values of other fields of
            %       force. Not used here.
            %   divisor: float. The data extracted are divided by this value. Not used
            %       here.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   fillMissing: struct. Only accept fillMissing = {'inpaint_nans', n}.
            %       If set, indicates that the missing values (noData) are filled with
            %       the function inpaint_nans() and argument 4 (method). Not used here.
            %   minMaxCut: 1 or 0. if varData below min, or above max, correct value to
            %       be min, or max, respectively, without taking into account
            %       nodata_value. Default: 1: the cut is done. 0: cut not done.
            %       NB: even if minMaxCut =0, a conversion to a type (uint8 e.g.) can
            %       cut the values.                                             @warning
            %       Not used here.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % varData: data array of NoData.
            %
            % NB: Erase all previous data of this varName in the file.          @warning
            % Nb: doesnt work for file extension .csv and varName = 'metaData'.
            % NB: Right now this method saves in only 1 file.
            %
            % RMQ: We dont check if data were already got/updated and we directly
            %   replace them. The existence of data previously saved should be checked
            %   at a higher level.
            % NB: For mod09ga to modspires, angles and state are saved at resolution
            %   1200x1200.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.instantiateAndSaveData';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], ...
                    force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'theseDate', datetime('today'));
            addParameter(p, 'varName', 'defaultVarName');
            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;

            theseDate = p.Results.theseDate;
            varName = p.Results.varName;
            if size(theseDate, 2) == 1
                theseDate = [theseDate, theseDate];
            end % to get a start and end.

            varData = obj.instantiateData( ...
                objectName, dataLabel, ...
                theseDate = theseDate, varName = varName, force = force, optim = optim);
            obj.saveData(varData, objectName, dataLabel, theseDate = theseDate, ...
                varName = varName, force = force, optim = optim);

            fprintf(['%s: Saved instantiated data, object: %s, ', ...
                'theseDate: %s - %s, ', ...
                ' varName: %s, dataLabel, %s, ' ...
                'cellIdx: [%s], countOfCellPerDimension: [%s], ', ...
                'force: %d, logLevel: %d, ', ...
                'parallelWorkersNd: %d...\n'], thisFunction, objectName, ...
                char(theseDate(1), 'yyyy-MM-dd'), ...
                char(theseDate(2), 'yyyy-MM-dd'), varName, dataLabel, ...
                join(num2str(optim.cellIdx), ', '), ...
                join(num2str(optim.countOfCellPerDimension), ', '), ...
                optim.force, optim.logLevel, optim.parallelWorkersNb);
        end
        function varData = instantiateData(obj, objectName, dataLabel, varargin)
            % Parameters
            % ----------
            % objectName: char. Unique name of the object, either region (type 0) or
            %   subdivision (type 1). Configuration in espEnv.myConf.region and
            %   espEnv.myConf.landsubdivision.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw. Configuration
            %   in espEnv.myConf.variableversion.
            % theseDate: datetime or array(datetime) [firstDate, lastDate], optional.
            %   Cover the period for which we want the data instantiated. Configuration
            %   in espEnv.myConf.filePath, field period and dimensionInfo. Default:
            %   today.
            % varName: char, optional. Uniqe name of the variable. Configuration in
            %   espEnv.myConf.variable, espEnv.myConf.versionvariable.
            %   Default: 'defaultVarName'.
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, minMaxCut), optional. Used to
            %   override varName configuration.
            %   outputDataLabel: char. We expect the data the format given by the
            %       outputDataLabel. Can be overriden by the values of other fields of
            %       force. Not used here.
            %   divisor: float. The data extracted are divided by this value. Not used
            %       here.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   fillMissing: struct. Only accept fillMissing = {'inpaint_nans', n}.
            %       If set, indicates that the missing values (noData) are filled with
            %       the function inpaint_nans() and argument 4 (method). Not used here.
            %   minMaxCut: 1 or 0. if varData below min, or above max, correct value to
            %       be min, or max, respectively, without taking into account
            %       nodata_value. Default: 1: the cut is done. 0: cut not done.
            %       NB: even if minMaxCut =0, a conversion to a type (uint8 e.g.) can
            %       cut the values.                                             @warning
            %       Not used here.
            %   save: 1 or 0. 1: indicates that force parameters are used for input,
            %       for instance in the context of saving data. By default 0.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % varData: data array of NoData.
            %
            % Nb: doesnt work for file extension .csv and varName = 'metaData'.

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.instantiateData';
            p = inputParser;
            defaultOptim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            addParameter(p, 'optim', struct());
            addParameter(p, 'force', struct());
            addParameter(p, 'theseDate', datetime('today'));
            addParameter(p, 'varName', 'defaultVarName');
            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;
            theseDate = p.Results.theseDate;
            varName = p.Results.varName;
            force.instantiate = 1;
            [~, ~, thisSize] = obj.getIndicesForCellForDataLabel( ...
                objectName, dataLabel, theseDate = theseDate, varName = varName, ...
                force = force, optim = optim);

            [theseVariable, ~] = obj.getVariable(dataLabel);
            thisVariable = theseVariable(strcmp(theseVariable.name, varName), :);
            thisType = thisVariable.type{1};
            thisNoDataValue = thisVariable.nodata_value;
            if ismember('type', fieldnames(force))
                thisType = force.type;
            end
            if ismember('nodata_value', fieldnames(force))
                thisNoDataValue = force.nodata_value;
            end
            if ismember(thisType, {'single', 'double'})
                thisNoDataValue = NaN;
            end
            varData = repmat(cast(thisNoDataValue, thisType), thisSize);
            % NB: this repmat is to avoid this error: MTIMES (*) is not fully supported
            % for integer classes. At least one argument must be scalar. when we do
            % cast(thisNoDataValue, thisType) .* ones(thisSize, thisType)
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
        function [newPath, regexpPattern, metaData] = ...
            replacePatternsInFileOrDirPaths(obj, filePath, objectName, ...
            dataLabel, thisDate, varName, complementaryLabel, varargin)
            % Parameters
            % ----------
            % filePath: char. FileName, directoryPath or filePath containing parameter
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
            %
            % Optional parameters
            % -------------------
            % NB: all these parameters can be a string with a globbing wild card as *.
            %   Other wild cards are currently not implemented. In particular
            %   {b*,c*,*est*} mustnt be used since the file patterns start and end by
            %   {}.
            %   The bash command used to get file lists is ls (linux). NB: not tested
            %   on windows.
            %   https://tldp.org/LDP/abs/html/globbingref.html
            % 
            % monthWindow: int. MonthWindow of the data within the file. Default: 12.
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            % patternsToReplaceByJoker: cell array(char).
            %   List of arguments (patterns)
            %   we don't a priori know. The filepath in that case will be found using
            %   a dir cmd (replacing some unknown patterns by the joker *). Default {}.
            % thisIndex: int. Index of the pixel for files containing only 1
            %   pixel, e.g. modisspiresyeartmp. Default: 1.
            % thisYear: int. Year for which we want the files. Incompatible with
            %   thisDate and thisWaterYear. Default: 0.
            % thisWaterYear: int. Water Year for which we want the files. Incompatible
            %   with thisDate and thisYear.Default: 0.
            % timestampAndNrt: char. Only for input files (mod09ga, vnp09ga,
            %   lc08.l2sp.02.t1, etc...). Can be a timestamp or a process date yyyymmdd.
            %   Default: ''.
            %
            % Return
            % ------
            % newPath: char. FileName, directoryPath or filePath with the patterns
            %   replaced by values of the parameters contained in the patterns.
            % regexpPattern: char. Pattern used to filter the results of a dir on
            %   newPath, necessary because we have filenames with variables with "_"
            %   in their definition.                                            @warning
            % fileLastEditDate: datetime or cellarray(datetime).
            % metaData: struct(objectId, objectName, objectType, varId, varName).
            %   information yielded by getObjectIdentification() and
            %   getVariableIdentification().
            thisFunction = 'ESPEnv.replacePatternsInFileOrDirPaths';
            
            % Optional parameters.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            optionalParameters = struct();
            optionalParameters.monthWindow = WaterYearDate.yearMonthWindow;
            optionalParameters.optim = struct(cellIdx = [1, 1, 1], ...
                countOfCellPerDimension = [1, 1, 1], ...
                countOfPixelPerDimension = ...
                    [obj.modisData.sensorProperties.tiling.rowPixelCount, ...
                    obj.modisData.sensorProperties.tiling.columnPixelCount, 1], ...
                force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            optionalParameters.patternsToReplaceByJoker = {};
            optionalParameters.thisIndex = 1;
            optionalParameters.thisYear = '*';
            optionalParameters.thisWaterYear = '*';
            optionalParameters.timestampAndNrt = '*';
                % Mustn't add countOfPixelPerDimension in default optim.        @warning
                % Default suppose that layers are always 2400 x 2400 pixels for that
                % method.                                                       @warning
                % We put countOfPixelPerDimension here in default because we need its
                % when rowStartId, rowEndId, columnStartId, columnEndId are in the
                % filename, as for smoothSPIREScube2024xx.m scripts, dataLabel:
                % spiressmoothbycell., ...

            % Optional parameter parsing.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            p = inputParser;
            optionalParameterNames = fieldnames(optionalParameters);
            for optionalParameterIdx = 1:length(optionalParameterNames);
                optionalParameterName = optionalParameterNames{optionalParameterIdx};
              addParameter(p, ...
                  optionalParameterName, ...
                  optionalParameters.(optionalParameterName));
            end

            p.StructExpand = false;
            parse(p, varargin{:});
            for optionalParameterIdx = 1:length(optionalParameterNames);
                optionalParameterName = optionalParameterNames{optionalParameterIdx};
                if ~isequal(p.Results.(optionalParameterName), ...
                    optionalParameters.(optionalParameterName))
                    if strcmp(optionalParameterName, 'optim')
                        optim = p.Results.optim;
                        optimFieldNames = fieldnames(optionalParameters.optim);
                        for fieldIdx = 1:length(optimFieldNames)
                            thisFieldName = optimFieldNames{fieldIdx};
                            if ~ismember(thisFieldName, fieldnames(optim))
                                optim.(thisFieldName) = ...
                                    optionalParameters.optim.(thisFieldName);
                            end
                        end % fieldIx.
                        optionalParameters.optim = optim;
                    else
                        optionalParameters.(optionalParameterName) = ...
                            p.Results.(optionalParameterName);
                    end
                end
            end
            monthWindow = optionalParameters.monthWindow;
            optim = optionalParameters.optim;
            patternsToReplaceByJoker = optionalParameters.patternsToReplaceByJoker;
            thisIndex = optionalParameters.thisIndex;
            thisYear = optionalParameters.thisYear;
            thisWaterYear = optionalParameters.thisWaterYear;
            timestampAndNrt = optionalParameters.timestampAndNrt;
                % NB: use of eval doesnt work in this context, when variables were not
                % declared first.

            % Determine the time dimension and get all indices.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            force = struct();
            
            startIdx = 1;
            endIdx = 1;
            if ismember(obj.modisData.inputProduct, {'mod09ga', 'vnp09ga'}) && ...
                ~isnumeric(thisYear) && ~isnumeric(thisWaterYear)
                [startIdx, endIdx, ~] = obj.getIndicesForCellForDataLabel( ...
                    objectName, dataLabel, theseDate = thisDate, varName = varName, ...
                    force = force, optim = optim, mode = 1);
            end % Only used for spiressmooth.
            % NB: Division by cell not yet implemented for landsat tiles.          @todo

            if ~ismember(patternsToReplaceByJoker, obj.patternsInFilePath.toReplace)
                errorStruct.identifier = ...
                    'ESPEnv_replacePatterns:Object';
                errorStruct.message = sprintf( ...
                    ['%s.replacePatternsInFileOrDirPaths()', ...
                    ': some patterns indicated ', ...
                    'are not implemented as pattern to replace.'], ...
                    mfilename());
                error(errorStruct);
            end
            if ischar(monthWindow)
                monthWindow = str2num(monthWindow);
            end

            % Determine objectName, objModCode (only used in v2023.1) and objectId.
            % ObjectType: 0: regions, 1: landsubdivisions
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            objectLabel = objectName;
            [objectId, objectName, objectType, shortObjectName] = ...
                obj.getObjectIdentification(objectLabel);
            metaData = struct();
            metaData.objectId = objectId;
            metaData.objectName = objectName;
            metaData.objectType = objectType;
            metaData.shortObjectName = shortObjectName;

            % Determine varName, varId.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%&%%%%%%%%%%%%%%%%%%%
            if isnumeric(varName) || ~ismember(varName, {'*', ''})
                varLabel = varName;
                [varId, varName] = obj.getVariableIdentification(varLabel);
                [thoseVariable, ~] = obj.getVariable(dataLabel);
                variable = thoseVariable(thoseVariable.id == varId, :);
                if isempty(variable) || isempty(variable.nameWithinFile{1})
                    % empty variable can occur for the handling of geotiff during web
                    % export.
                    varNameWithinFile = varName;
                else
                    varNameWithinFile = variable.nameWithinFile{1};
                end
            else
                varId = varName;
                varNameWithinFile = '*';
            end
            metaData.varId = varId;
            metaData.varName = varName;

            % Replacement of object and variable infos.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            newPath = filePath;

            function filePath = replacePatternByValue(filePath, patternCharCells, ...
                valueCells, patternsToReplaceByJoker)
                % Parameters
                % ----------
                % filePath: char. FilePath for which patterns are replaced by values.
                % patternCharCells: cellArray(char). List of patterns to replace.
                % valueCells: cellArray(char). List of replacing values.
                % patternsToReplaceByJoker: cellArray(char). List of patterns authorized
                %   to be replaced of this filePath.
                %
                % Return
                % ------
                % filePath: char. Updated filePath.
                for cellIdx = 1:length(patternCharCells)
                    patternChar = patternCharCells{cellIdx};
                    if ~ismember(patternChar, patternsToReplaceByJoker)
                       filePath = replace(filePath, ['{', patternChar, '}'], ...
                        valueCells{cellIdx});
                    end
                end
            end
            if objectType ~= intmax('uint8')
                newPath = replacePatternByValue(newPath, ...
                    {'objectId', 'objectName', 'objectId_1000', 'shortObjectName'}, ...
                    {num2str(objectId), objectName, ...
                        string(floor(cast(objectId, 'single') / 1000)), ...
                        shortObjectName}, ...
                    patternsToReplaceByJoker);
            end
            % Detect near real time folders... Used for JPL files before 2023-10-01.
            if objectType == 0 && ...
                ismember(dataLabel, {'mod09gaFromJPL', 'modScagDatFromJPL', ...
                    'modDrfsDatFromJPL'})
                if ~isNaT(obj.myConf.region.startDateForHistJplIngest)
                    if ~isNaT(obj.myConf.region.startDateForNrtJplIngest)
                        if thisDate < obj.myConf.region.startDateForNrtJplIngest
                            nearRealTime = 'historic';
                        elseif ~isNaT(obj.myConf.region.endDateForJplIngest) && ...
                            thisDate < obj.myConf.region.endDateForJplIngest
                            nearRealTime = 'NRT';
                        end
                    end
                end
                newPath = replacePatternByValue(newPath, {'nearRealTime'}, ...
                    {nearRealTime}, patternsToReplaceByJoker);
            end

            % Detect sub-infos of subdivisions... Only used for v2023.1 map/stats files.
            sourceRegionName = '';
            if objectType == 1
                objectCode = obj.myConf.landsubdivision( ...
                            obj.myConf.landsubdivision.id == objectId, :).code{1};
                sourceRegionName = obj.myConf.landsubdivision( ...
                    obj.myConf.landsubdivision.id == objectId, :). ...
                    sourceRegionName{1};
                newPath = replacePatternByValue(newPath, ...
                    {'objectModCode', 'sourceRegionName'}, ...
                    {replace(objectCode, '-', ''), sourceRegionName}, ...
                    patternsToReplaceByJoker);
            end

            newPath = replacePatternByValue(newPath, ...
                {'varId', 'varName', 'varNameWithinFile'}, ...
                {num2str(varId), varName, varNameWithinFile}, ...
                patternsToReplaceByJoker);
                % NB: nameWithinFile only valid for new file labels which varWithinFile
                % names are not linked to the field varNameWithinFile in the
                % conf_of_filepaths.csv!                                        @warning

            % Replacement of other infos.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if length(startIdx) == 1
              startIdx = [startIdx(1), startIdx(1)];
              endIdx =  [endIdx(1), endIdx(1)];
            end
            deviceUC = upper(regexprep(obj.modisData.inputProduct, ...
                '([^\.]+)\.[^\.]+', '$1'));
            processLevelUC = upper(regexprep(obj.modisData.inputProduct, ...
                '[^\.]+\.([^\.]+)', '$1'));
            collection = upper(regexprep(obj.modisData.inputProductVersion, ...
                '([^\.]+)\.[^\.]+', '$1'));
            collectionCategory = upper(regexprep(obj.modisData.inputProductVersion, ...
                '[^\.]+\.([^\.]+)', '$1'));
            newPath = replacePatternByValue(newPath, ...
                {'platform', 'versionOfAncillary', 'versionOfDataCollection', ...
                    'inputProduct', ...
                    'deviceUC', 'processLevelUC', ...
                    'inputProductVersion', ...
                    'collection', 'collectionCategoryUC', ...
                    'columnStartId', 'columnEndId', 'rowStartId', 'rowEndId', ...
                    'thisIndex', ...
                    'thisIndex_1M', ...
                    'thisIndex_1000'}, ...
                {obj.modisData.versionOf.platform, ...
                    obj.modisData.versionOf.ancillary, ...
                    sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                    obj.modisData.inputProduct, ...
                    deviceUC, processLevelUC, ...
                    obj.modisData.inputProductVersion, ...
                    collection, collectionCategory, ...
                    num2str(startIdx(2)), num2str(endIdx(2)), ...
                    num2str(startIdx(1)), num2str(endIdx(1)), ...
                    num2str(thisIndex), ...
                    string(floor(cast(thisIndex, 'single') / 1e6)), ...
                    string(floor(cast(thisIndex, 'single') / 1000))}, ...
                patternsToReplaceByJoker);

            if ~exist('complementaryLabel', 'var')
                complementaryLabel = '';
            end
            newPath = replacePatternByValue(newPath, ...
                {'EPSGCode', 'geotiffCompression', 'monthWindow', ...
                    'timestampAndNrt', 'slurmFullJobId'}, ...
                {complementaryLabel, Regions.geotiffCompression, ...
                    num2str(monthWindow), timestampAndNrt, obj.slurmFullJobId}, ...
                patternsToReplaceByJoker);

            % In the following, if conditions = false, the pattern is kept in place.
            % E.g. if a pattern contains '{thisYear}' and it thisDate is not a datetime,
            % the filePath will keep having the text '{thisYear}'.
            if ismember(dataLabel, fieldnames(obj.modisData.versionOf))
                newPath = replacePatternByValue(newPath, ...
                    {'version'}, ...
                    {obj.modisData.versionOf.(dataLabel)}, ...
                    patternsToReplaceByJoker);
            end

            filePathConf = obj.myConf.filePath(strcmp(obj.myConf.filePath.dataLabel, ...
                dataLabel), :);
            thisDateFormat = filePathConf.dateInFileName{1};
            if isa(thisDate, 'datetime')
                if strcmp(thisDateFormat, 'yyyyJD')
                    replacement = [num2str(year(thisDate)), ...
                        sprintf('%03d', day(thisDate, 'dayofyear'))];
                else
                    replacement = char(thisDate, thisDateFormat);
                end
                newPath = replacePatternByValue(newPath, ...
                    {'thisYear', 'thisDate'}, ...
                    {char(thisDate, 'yyyy'), replacement}, ...
                    patternsToReplaceByJoker);
                if contains(newPath, '{thisWaterYear}')
                    if objectType == 0 % region.
                        regionName = objectName;
                    else % 1 subdivision.
                        regionName = sourceRegionName;
                    end
                    region = ...
                        Regions(regionName, ...
                            [regionName, '_mask'], obj, obj.modisData);
                    replacement = num2str(region.getWaterYearForDate(thisDate));
                    newPath = replacePatternByValue(newPath, ...
                        {'thisWaterYear', }, {replacement}, ...
                        patternsToReplaceByJoker);
                    newPath = replace(newPath, '{thisWaterYear}', replacement);
                end
            elseif isnumeric(thisYear)
                if strcmp(thisDateFormat(1:4), 'yyyy')
                    replacement = [num2str(thisYear), '*'];
                else
                    replacement = '*';
                end
                newPath = replacePatternByValue(newPath, ...
                    {'thisYear', 'thisDate', 'thisWaterYear'}, ...
                    {num2str(thisYear), replacement, thisWaterYear}, ...
                    patternsToReplaceByJoker);
                    % NB: thisWaterYear pattern incompatible with thisYear set.
                    % Requires to know before hand if a type of file is by water year
                    % or by julian year...                                      @warning
            elseif isnumeric(thisWaterYear)
                replacement = '*'; 
                % NB: We get here all the files associated to the waterYear. Beware
                % maybe not what is wanted...                                   @warning
                newPath = replacePatternByValue(newPath, ...
                    {'thisYear', 'thisDate', 'thisWaterYear'}, ...
                    {replacement, replacement, thisWaterYear}, ...
                    patternsToReplaceByJoker);
                    % NB: thisWaterYear pattern incompatible with thisYear set.
                    % Requires to know before hand if a type of file is by water year
                    % or by julian year...                                      @warning
            end   

            % Replacement of patterns by the joker * for patternsToReplaceByJoker
            %(when we don't know certain parts of the file), and construction of the
            % regexp.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            regexpPattern = regexprep(newPath, '([\[\]{}()=''.(),;:%%{%}!@])', '\\$1');

            for patternIdx = 1: length(patternsToReplaceByJoker)
                replacingRegexp = obj.patternsInFilePath.replacingRegexp(...
                        strcmp(patternsToReplaceByJoker{patternIdx}, ...
                        obj.patternsInFilePath.toReplace));
                regexpPattern = replace(regexpPattern, ...
                    ['\{', patternsToReplaceByJoker{patternIdx}, '\}'], ...
                    replacingRegexp{1});
                newPath = replace(newPath, ...
                    ['{', patternsToReplaceByJoker{patternIdx}, '}'], '*');
            end
        end
        function [varData, conversionMask] = saveData(obj, varData, objectName, ...
          dataLabel, varargin)
            % Save data in the correct format.
            % Parameters
            % ----------
            % varData: array(int or float). 1 to 3 D array of data.
            % objectName: char. Unique name of the object, either region (type 0) or
            %   subdivision (type 1). Configuration in espEnv.myConf.region and
            %   espEnv.myConf.landsubdivision. Necessary to get the number of days
            %   of a waterYear.
            % dataLabel: char. Label (type) of data for which the file is required,
            %   should be a key of ESPEnv.dirWith struct, e.g. MOD09Raw. Configuration
            %   in espEnv.myConf.variableversion.
            % theseDate: datetime or array(datetime) [firstDate, lastDate], optional.
            %   Cover the period for which we want the data saved. Configuration
            %   in espEnv.myConf.filePath, field period and dimensionInfo. Default:
            %   today. Incompatible with waterYearDate option.
            %   NB: theseDate consist of consecutive dates.
            % thisIndex: int, optional. Index of the pixel for files containing only 1
            %   pixel, e.g. modisspiresyeartmp.
            % varName: char, optional. Necessary to know if there's resampling (is
            %   this variable in 1200x1200 (resamplingFactor 2) or 2400x2400 (factor 1).
            %   Default: 'defaultVarName' (resamplingFactor 1).
            % waterYearDate: WaterYearDate, optional. Cover the period for which we want
            %   the data saved. Incompatible with theseDate option. waterYearDate
            %   overrules theseDate.
            % force: struct(outputDataLabel, divisor, type, nodata_value,
            %   resamplingFactor, minMaxCut), optional. Used to
            %       override varName configuration.
            %   dimensionInfo: int. DimensionInfo of varData, which helps to reshape
            %       the varData from their input shape to the shape required in the
            %       file.
            %       11: 1 dim column: row*column (reshaped matrix with on column with
            %       each pixel correspond to a row). 20: 2 dim: pixel row x column
            %       (only one day here). 21: 2 dim: pixel row*column x day (reshaped
            %       matrix with each pixel corresponding to a column of days), 30: pixel
            %       row x column x day.
            %   period: int. Period of varData, which helps to insert the data at the
            %       correct location (date) in the file.
            %       1: 1 day only. It can be a specific day or 1 representative day with
            %       an average of data. 2: 1 month. It contains a varying number of
            %       days, 28, 29, 30, 31. 3: 3 months. It contains a varying number of
            %       days, up to 92. 4: 1 calendar year, from Jan 1st to Dec 31, contains
            %       365 or 366 days. 5: 1 waterYear, for northern hemisphere, from 10/1
            %       to 9/30, for southern hemisphere, from 4/1 to 3/31 or others,
            %       contains 365 or 366 days.
            %   outputDataLabel: char. We expect the data the format given by the
            %       outputDataLabel. Can be overriden by the values of other fields of
            %       force.
            %   divisor: float. The data extracted are divided by this value.
            %   type: char. The data are converted to this type.
            %   nodata_value: int or NaN. The nodata are set to this value.
            %   resamplingFactor: int. The data are resampled with this factor (if
            %       resamplingFactor 2, the number of pixels is increased by 2).
            %   fillMissing: struct. Only accept fillMissing = {'inpaint_nans', n}.
            %       If set, indicates that the missing values (noData) are filled with
            %       the function inpaint_nans() and argument 4 (method).
            %   minMaxCut: 0-2. Default: 0, no cut. 1: if varData below min, or above
            %       max, correct value to be min, or max, respectively, without taking
            %       into account nodata_value. 2: the values below min and above max
            %       are set to nodata.
            %       NB: even if minMaxCut = 0 or 2, a conversion to a type (uint8 e.g.)
            %       can cut the values.                                         @warning
            % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
            %       parallelWorkersNb).
            %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx,
            %       depthCellIdx].
            %       Indices of the cell part of a tile. Row indices are counted from
            %       top to bottom, column indices from left to right. Default [1, 1].
            %   countOfCellPerDimension: array(int), optional.
            %       [rowCellCount, columnCellCount, depthCellCount].
            %       Number of cells dividing the set of
            %       rows and same for columns. E.g. if we want to divide a 2400x2400
            %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
            %   countOfPixelPerDimension: array(int), optional. [rowCount, columnCount,
            %       depthCount].
            %       Number of pixels in a row and same in a column and in depth
            %       (3rd dimension). MUST have same number of elements as cellIdx.
            %   force: int, optional. Default 0: if input filename and its modification
            %       date (lastEditDate) are identic to metadata recorded in output file,
            %       doesnt update data. 1: update data in any case.
            %   logLevel: int, optional. Indicate the density of logs.
            %       Default 0, all logs. The higher the less logs.
            %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
            %
            % Return
            % ------
            % varData: array(int or float). 1 to 3 D array of data potentially of type
            %   converted or values capped to min max.
            % conversionMask: array(uint8). Bit array indicating the pixels that have
            %   changed under the fillmissing and cut of min/max. Pos 1: no data.
            %   2: value below range. 3: value above range.
            % NB: Right now this method saves in only 1 file. This is why we call
            %   getFilePathForDateAndVarName, and we supply only 1 date.
            %
            % NB: can't save partial data which are in dim 1200x1200 and must be
            % resampled in 2400x2400.
            % We don't handle the case when optim.cellIdx = x,
            % optim.countOfCellPerDimension = 1200 and
            % resampling factor 1/2.
            % That is when resamplingFactor 1 in file but outputResamplingFactor 2.
            %                                                                   @warning

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Initialize...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisFunction = 'ESPEnv.saveData';
            p = inputParser;
            defaultOptim = struct( ...
                    force = 0, logLevel = 0, ...
                parallelWorkersNb = 0);
            addParameter(p, 'force', struct());
            addParameter(p, 'optim', struct());
            defaultDate = datetime('today');
            addParameter(p, 'theseDate', datetime('today'));
            addParameter(p, 'thisIndex', 1);
            defaultWaterYearDate = WaterYearDate(datetime('today'), 1, 0);
            addParameter(p, 'waterYearDate', defaultWaterYearDate);
            addParameter(p, 'varName', 'metaData');
            p.StructExpand = false;
            parse(p, varargin{:});
            optim = p.Results.optim;
            optimFieldNames = fieldnames(defaultOptim);
            for fieldIdx = 1:length(optimFieldNames)
                thisFieldName = optimFieldNames{fieldIdx};
                if ~ismember(thisFieldName, fieldnames(optim))
                    optim.(thisFieldName) = defaultOptim.(thisFieldName);
                end
            end % fieldIx.
            force = p.Results.force;

            theseDate = p.Results.theseDate;
            waterYearDate = p.Results.waterYearDate;
            if ~isequal(waterYearDate, defaultWaterYearDate)
              theseDate = waterYearDate.getDailyDatetimeRange();
            end
            thisIndex = p.Results.thisIndex;
            varName = p.Results.varName;
            if size(theseDate, 2) == 1
                theseDate = [theseDate, theseDate];
            end % to get a start and end.
            complementaryLabel = '';
            
            if obj.slurmEndDate <= ...
                datetime('now') + seconds(obj.slurmSafetySecondsBeforeKill)
                error('ESPEnv:TimeLimit', 'Error, Job has reached its time limit.');
            end
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Get file where the data need to be saved.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % NB: Below a lot of code is the same as getData... maybe need to mutualize.
            %                                                                      @todo
            % NB: use waterYearDate only when there are several files, not only one
            % file (e.g. 1 file for the full waterYear).                        @warning
            if ~isequal(waterYearDate, defaultWaterYearDate)
                [filePath, fileExists, ~, ~, metaData] = ...
                    obj.getFilePathForWaterYearDate(objectName, dataLabel, ...
                    waterYearDate);
            else
                [filePath, fileExists, ~, metaData] = ...
                    obj.getFilePathForDateAndVarName(objectName, dataLabel, ...
                    theseDate(1), varName, complementaryLabel, optim = optim, ...
                    thisIndex = thisIndex);
            end
                % Raises error if dataLabel not in configuration_of_filenames.csv and
                % in modisData.versionOf.
                % NB: metaData is information yielded by getObjectIdentification() and
                % getVariableIdentification() through the call to
                % replacePatternByValue().

            objectId = metaData.objectId;
            objectName = metaData.objectName;
            objectType = metaData.objectType;
            varLabel = varName;
            [varId, varName] = obj.getVariableIdentification(varLabel);

            % Detection of extension and multiple files.
            % Check limited to a save to 1 date only, doesnt apply to waterYearDate.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if ~ischar(filePath) && isequal(waterYearDate, defaultWaterYearDate)
                error(['%: Several files may correspond to the target save file.', ...
                    ' Check espEnv.myConf.filePath to verify unicity for dataLabel', ...
                    ' %s.'], thisFunction, dataLabel);
            end

            % Configuration of file and object (region or subdivision).
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            fileConf = obj.myConf.filePath( ...
                strcmp(obj.myConf.filePath.dataLabel, dataLabel), :);
            fileExtension = fileConf.fileExtension{1};
            if metaData.objectType == 0
                objectConf = obj.myConf.region(obj.myConf.region.id == objectId, :);
            else
                objectConf = obj.myConf.landsubdivision(obj.myConf.landsubdivision ...
                    == objectId, :);
            end
            metaData = [];

%{
            % WARNING: unused car saving files by parts produce corrupted files in
            % parallel computing.                                               @warning
            % Determine the time dimension and get all indices.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            [startIdx, endIdx, thisSize] = obj.getIndicesForCellForDataLabel( ...
                objectName, dataLabel, theseDate = theseDate, varName = varName, ...
                force = force, optim = optim);
                % NB: here if force has dimensionInfo attribute, it is not taken into
                % account.                                                      @warning
%}

            % Get the varName within the file, which might be distinct from varName.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % varName argument can be varId, we take the
                % info from the getObjectIdentification() present in getFilePath()
                % through a call to replacePatternByValue().
            varNameWithinFile = varName;
            if ~isempty(varName) && ischar(varName) && ...
                ~isempty(fileConf.fieldForVarNameWithinFile{1})
                varConf = obj.myConf.variable( ...
                    strcmp(obj.myConf.variable.output_name, varName), :);
                varNameWithinFile = varConf.(fileConf.fieldForVarNameWithinFile{1}){1};
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Reshaping, conversion, fillmissing (NaN), resampling, min/max, divisor,
            % type, nodata.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Here, we copy a bit the code of getDataForDateAndVarName().
            % Would need mutualization...                                          @todo

            if ismember(fileExtension, {'.hdf', '.h5', '.mat', '.tif'}) & ...
                ~strcmp(varName, 'metaData') & isnumeric(varData)
                % Configuration of output (what we want).
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                outputDataLabel = dataLabel;
                [outputVariables, ~] = obj.getVariable(outputDataLabel);
                outputVariable = outputVariables( ...
                    strcmp(outputVariables.name, varName), :);

                % Reshaping.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ismember('dimensionInfo', fieldnames(force)) && ...
                    fileConf.dimensionInfo ~= force.dimensionInfo
                    if (fileConf.dimensionInfo == 21 && ...
                        ismember(force.dimensionInfo, [20, 30])) || ...
                       (fileConf.dimensionInfo == 11 && ...
                        force.dimensionInfo == 20)
                        varData = reshape(varData, ...
                            [thisSize(1),  thisSize(2)]);
                    elseif fileConf.dimensionInfo == 20 && ...
                        force.dimensionInfo == 21 && fileConf.period == 1
                        varData = reshape(varData, ...
                            [thisSize(1),  thisSize(2), length(theseDate)]);
                        % NB: very specific case used for saving the output of 1 pixel
                        % for modisspiresdaily. Not tested for other cases !!!!
                        %                                                       @warning
                    else
                        error(['%s: Impossible reshaping. Reshaping allowed ', ...
                            ' for dimensions 20 or 30 towards 21 or dimension', ...
                            ' 20 towards 11, and for 21 to 20 for files with', ...
                            ' 1 day only.\n'], thisFunction);
                    end
                    % 11: 1 dim column: row*column (reshaped matrix with on column with
                    % each pixel correspond to a row). 20: 2 dim: pixel row x
                    % column (only one day here). 21: 2 dim: pixel row*column x day
                    % (reshaped matrix with each pixel corresponding to a column of
                    % days), 30: pixel row x pixel column x day.
                end

                % NB: there's also the information of force.period to insert correctly
                %   the date. Have to see where to insert it.                      @todo

                % Resampling.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                inputResamplingFactor = outputVariable.resamplingFactor(1);
                if ismember('resamplingFactor', fieldnames(force))
                    inputResamplingFactor = force.resamplingFactor;
                end
                actualResamplingFactor = outputVariable.resamplingFactor(1) / ...
                    inputResamplingFactor;
                if actualResamplingFactor ~= 1
                    if ~ismember(class(varData), {'single', 'double'})
                        varData = single(varData);
                        varData(varData == outputVariable.nodata_value(1)) = NaN;
                    end
                    varData = imresize(varData, actualResamplingFactor);
                        % nearest for logical, bicubic for others.
                        % We may have chosen 'nearest' because we only resize the angles
                        % and they
                        % are probably similar from pixel to pixel. However for other
                        %   values, may not be ok. Was bicubic in v20231027.    @warning
                end

                % Nodata and preparing casting to output type.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                % conversionMask: array(uint8). Bit array indicating the pixels that
                %   have changed under the fillmissing and cut of min/max.
                % Mask of cells which have been modified.
                conversionMask = zeros(size(varData), 'uint8');
                    % Bits. Pos 1: no data. 2: value below range. 3: value above range.

                inputType = class(varData);

                outputNoDataValue = outputVariable.nodata_value(1);
                if ismember(outputVariable.type{1}, {'single', 'double'})
                    outputNoDataValue = NaN;
                end
                inputNoDataValue = outputNoDataValue;
                if ismember('nodata_value', fieldnames(force))
                    inputNoDataValue = force.nodata_value;
                end
                if ismember(inputType, {'single', 'double'})
                    inputNoDataValue = NaN;
                    isNoData = isnan(varData);
                else
                    isNoData = varData == inputNoDataValue;
                end
                conversionMask = bitset(conversionMask, 1, isNoData);

                % Divisor.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                inputDivisor = outputVariable.divisor(1);
                if ismember('divisor', fieldnames(force))
                    inputDivisor = force.divisor;
                end
                actualDivisor = inputDivisor / outputVariable.divisor(1);
                if actualDivisor ~= 1
                    if ~ismember(class(varData), {'single', 'double'})
                        varData = single(varData);
                        varData(varData == inputNoDataValue) = NaN;
                    end
                    varData(~isNoData) = varData(~isNoData) / actualDivisor;
                end

                % Cut.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ismember('minMaxCut', fieldnames(force)) && ...
                  ismember(force.minMaxCut, [1, 2])
                  if outputVariable.min(1) ~= outputVariable.nodata_value(1)
                      conversionMask = bitset(conversionMask, 2, ...
                          (~isNoData & ...
                              varData < outputVariable.min(1)));
                  end
                  if outputVariable.max(1) ~= outputVariable.nodata_value(1)
                      conversionMask = bitset(conversionMask, 3, ...
                          (~isNoData & ...
                              varData > outputVariable.max(1)));
                  end
                  thisMin = outputVariable.min(1);
                  thisMax = outputVariable.max(1);
                  if force.minMaxCut == 2
                    thisMin = outputVariable.nodata_value(1);
                    thisMax = outputVariable.nodata_value(1);
                    isNoData = (conversionMask ~= 0);
                  end
                  varData(logical(bitget(conversionMask, 2))) = thisMin;
                  varData(logical(bitget(conversionMask, 3))) = thisMax;
                end

                % Nodata and casting to output type.
                %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                if ~strcmp(outputVariable.type{1}, class(varData))
                    varData = cast(varData, outputVariable.type{1});
                end
                if inputNoDataValue ~= outputNoDataValue % & ...~isnan(inputNoDataValue) % Not sure why it was here .... @toinvestigate
                    varData(logical(isNoData)) = outputNoDataValue;
                end
            else
                warning(['%s: No conversion for extension %s or', ...
                    'varName metaData or non numeric data.\n'], ...
                    thisFunction, fileExtension);
            end

            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % .mat file save.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            % Handling and get of the metadata in the .mat file. Not done for other
            % extensions. Only 1 file.
            if ~strcmp(fileExtension, '.mat')
                error(['%s: No save possible in other files than .mat right ', ...
                    'now, %s.'], thisFunction, filePath);
            elseif strcmp(varNameWithinFile, '')
                error(['%s: No variable varName.'], thisFunction);
            end
            if ~isequal(waterYearDate, defaultWaterYearDate)
                parfor fileIdx = 1:size(filePath, 2)
                    % length(filePath) must be = length(theseDate)
                    if strcmp(varNameWithinFile, 'metaData')
                        appendFlag = 'append';
                        if ~fileExists(fileIdx)
                            appendFlag = 'new_file';
                        end
                        Tools.parforSaveAsFieldInFile(filePath, varNameWithinFile, ...
                            varData, appendFlag);
                    else
                        fileObj = matfile(filePath{fileIdx}, Writable = true);
                        switch fileConf.dimensionInfo
                            case 11
                                % 11: 1 dim column: row*column (reshaped matrix with on
                                % column with each pixel correspond to a row).
                                fileObj.(varNameWithinFile) = ...
                                    varData; % NB: not tested.                  @warning
                            case {20, 21}
                                % 20: 2 dim: pixel row x pixel column (only one day
                                % here).
                                fileObj.(varNameWithinFile) = ...
                                      varData(:, :, fileIdx);
                            case 30
                                % 30: pixel row x pixel column x day
                                fileObj.(varNameWithinFile) = varData;
                                              % NB: not tested.                 @warning
                        end
%{
                    % WARNING: following produce corrupted files in parallel computing
                    %                                                           @warning
                        switch fileConf.dimensionInfo
                            case 11
                                % 11: 1 dim column: row*column (reshaped matrix with on
                                % column with each pixel correspond to a row).
                                fileObj.(varNameWithinFile)(starIdx(1):endIdx(1)) = ...
                                    varData; % NB: not tested.                  @warning
                            case {20, 21}
                                % 20: 2 dim: pixel row x pixel column (only one day
                                % here).
                                fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), startIdx(2):endIdx(2)) = ...
                                      varData(:, :, fileIdx);
                            case 30
                                % 30: pixel row x pixel column x day
                                fileObj.(varNameWithinFile)( ...
                                    startIdx(1):endIdx(1), startIdx(2):endIdx(2), ...
                                    startIdx(3):endIdx(3)) = ...
                                    varData;  % NB: not tested.                 @warning
                        end
%}
                    end
                end
            else
                if strcmp(varNameWithinFile, 'metaData')
                    metaData = varData;
                    saveLabel = '-append';
                    if ~fileExists
                        saveLabel = '-v7.3';
                    end
                    save(filePath, varNameWithinFile, saveLabel);
                else
                    fileObj = matfile(filePath, Writable = true);
                    fileObj.(varNameWithinFile) = varData;
%{
                    % WARNING: following produce corrupted files in parallel computing
                    %                                                           @warning
                    switch fileConf.dimensionInfo
                        case 11
                            % 11: 1 dim column: row*column (reshaped matrix with on
                            % column with each pixel correspond to a row).
                            fileObj.(varNameWithinFile)(starIdx(1):endIdx(1)) = varData;
                        case {20, 21}
                            % 20: 2 dim: pixel row x pixel column (only one day
                            % here).
                            fileObj.(varNameWithinFile)( ...
                                startIdx(1):endIdx(1), startIdx(2):endIdx(2)) = varData;
                        case 30
                            % 30: pixel row x pixel column x day
                            fileObj.(varNameWithinFile)( ...
                                startIdx(1):endIdx(1), startIdx(2):endIdx(2), ...
                                startIdx(3):endIdx(3)) = varData;
                    end
%}
                end
            end
        end
        function setAdditionalConf(obj, confLabel, varargin)
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
            % confFieldNames: cell(char). List of fields in the conf (allow to remove
            %   unused fields). Default, empty, all fields are included.
            thisFunction = 'ESPEnv.setAdditionalConf';
            p = inputParser;
            addParameter(p, 'confFieldNames', {});
            p.StructExpand = false;
            parse(p, varargin{:});
            confFieldNames = p.Results.confFieldNames;

            if ~ismember(confLabel, fieldnames(obj.additionalConfigurationFilenames))
                errorStruct.identifier = ...
                    'ESPEnv_setAdditionalConf:BadConfLabel';
                errorStruct.message = sprintf(['%s: confLabel should be ', ...
                    'landsubdivision, landsubdivisionlink or landsubdivisionstat.'], ...
                    thisFunction);
                error(errorStruct);
            end

            % If the conf had been added to espEnv obj before but with the same
            % fields...
            if ismember(confLabel, fieldnames(obj.myConf)) & isempty(confFieldNames)
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
            tmp(1,:) = []; % delete comment line

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

            % Add the versionOfAncillary and firstMonthOfWaterYear and version of
            % data (e.g. v2024.0f) for landsubdivision.
            if strcmp(confLabel, 'landsubdivision')
                   
                tmp = tmp(tmp.used > 0, :);
                    % Might be necessary to change to == 1 2023-11-15 @todo
                tmp = innerjoin(tmp, obj.myConf.region, ...
                    LeftKeys = 'sourceRegionName', RightKeys = 'name', ...
                    RightVariables = {'versionOfAncillary', 'firstMonthOfWaterYear'});
                % version = version of data, i.e. geotiffs and stats.
                if ismember('version', confFieldNames)
                  if ismember(obj.espWebExportConfId, [1, 2])
                      tmp = renamevars(tmp, 'versionForIntegration', 'version');
                      tmp = removevars(tmp, 'versionForProd');
                  else
                      tmp = renamevars(tmp, 'versionForProd', 'version');
                      tmp = removevars(tmp, 'versionForIntegration');
                  end
                end      
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
            if ~isempty(confFieldNames)
                theseFieldNames = tmp.Properties.VariableNames;
                for fieldIdx = 1:length(theseFieldNames)
                    thisFieldName = theseFieldNames{fieldIdx};
                    if ~ismember(thisFieldName, confFieldNames)
                        tmp.(thisFieldName) = [];
                    end
                end
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
%{
        function f = SummarySnowFile(obj, region, startYr, stopYr)
            % SummarySnowFile returns the name of statistics summary file      @obsolete
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsMatlab, ...
                obj.modisData.versionOf.RegionalStatsMatlab);

            f = fullfile(myDir, ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
                sprintf('%04d_to_%04d_%sby%s_Summary.mat', ...
                startYr, stopYr, region.regionName, ...
                region.maskName));
        end
        function f = SummaryCsvDir(obj, region, waterYearDate)                 @obsolete
            % SummaryCsvDir returns the dir with csv versions of statistics summary file
            myDir = sprintf('%s_%s', obj.dirWith.RegionalStatsCsv, ...
                obj.modisData.versionOf.RegionalStatsCsv);

            f = fullfile(myDir, ...
                sprintf('v%03d', obj.modisData.versionOf.MODISCollection), ...
                region.regionName, ...
		sprintf('WY%04d', waterYearDate.getWaterYear()));
        end
        function f = SummaryCsvFile(obj, region, subRegionIdx, outDir, varName, waterYear)
	    % This filename for csv stats summary files is expected by the front-end @obsolete
	    fileName = sprintf('SnowToday_%s_%s_WY%04d_yearToDate.csv', ...
                region.ShortName{subRegionIdx}, varName, waterYear);                	
            f = fullfile(outDir, fileName);
        end

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
