classdef ExporterToWebsite < handle
    % ExporterToWebsite: Allows the export of several datasets to an ingest account
    % from which the website will import the data and then display them on the
    % snow-today website.
    %
    % NB: The exporter uses scp to a distant domain, from a linux server.
    % Other methods (ftp, windows laptop, etc ...) not implemented.
    % Before using this exporter, you have
    % to generate a ssh key and copy it to the distant domain. You can use ssh-keygen
    % and ssh-copy-id, see for instance:
    % https://cloud.ibm.com/docs/ssh-keys?topic=ssh-keys-generating-and-using-ssh-keys-for-remote-host-authentication.
    %
    % NB: Before use, initialize the environment variables:
    %   - espWebExportDomain. e.g. lafrance.net
    %   - espWebExportRootDir. e.g. /montmouth/george/1778/
    %   - espWebExportSshKeyFilePath. e.g. /ssh/id_rsa_beautiful
    %   - espWebExportUser. e.g. lafayette
    %
    % NB: Folders on the webapp ingest servers can have more than 1,000 files, beware
    % on ls execution time if you check the files over there.
    % NB: This code was inspired from a former script runSnowTodayStep4.sh fully in
    % bash. Unheartily, I decided to convert it in Matlab because the new
    % version of webapp ingest needs different filenames and hierarchy from the
    % filenames and hierarchy in the backend archive/scratch.

%{
    % Use case
    % --------
    % Don't forget to use the script AncillaryOutput.m to generate updated all
    % region .json, if the configuration .csv files have changed and then sync
    % from archive to scratch [WARNING].

    label = 'v2024.0';
    versionOfAncillary = 'v3.2'; % Only for initiating the exporter.
    versionOfAncillariesToExport = {'v3.1', 'v3.2'}; % all these versions are exported.
    dataLabel = 'landsubdivisioninjson';
    thisDate = '';
    varName = '';
    complementaryLabel = '';
    scratchPath = getenv('espArchiveDir');
    setenv('espWebExportRootDir', getenv('espWebExportRootDirForIntegration'));
    modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary);
    espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath);
    exporter = ExporterToWebsite(espEnv, versionOfAncillariesToExport);
    exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
        complementaryLabel);
    exporter.generateAndExportTrigger(); % Beware this will launch ingestion, so don't
        % excute this line if web-app unready. Alternatively, parameter a filename
        % different from 'TRIGGER' in configuration_of_filepaths.csv.
        % to handle that more transparently for testing                            @todo

    % Use case 2
    % ----------
    % Export of all expected files daily. CHECK how to switch between 2 subdivision tests and 1+2 all subdivisions in prod IMPORTANT !!!  @todo
    toBeUsedFlag = 1; % By default 1.
    label = 'v2024.0';
    versionOfAncillary = 'v3.1'; % Only for initiating the exporter.
    versionOfAncillariesToExport = {'v3.1', 'v3.2'}; % all these versions are exported.
    dataLabels = {'landsubdivisioninjson', ...
        'landsubdivisionlinkinjson', 'landsubdivisionrootinjson', ...
        'landsubdivisionshapeingeojson', 'landsubdivisiontypeinjson'}; 
            % 'webvariableconfinjson' not necessary because
            % stored as a static file.  
    thisDate = '';
    varName = '';
    complementaryLabel = '';
    scratchPath = '/rc_scratch/sele7124/'; %getenv('espArchiveDir');
    setenv('espWebExportRootDir', getenv('espWebExportRootDirForIntegration'));
    %setenv('espWebExportRootDir', getenv('espWebExportRootDirForQA'));
    %setenv('espWebExportRootDir', getenv('espWebExportRootDirForProd'));
    modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary);
    espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath);
    exporter = ExporterToWebsite(espEnv, versionOfAncillariesToExport, ...
        toBeUsedFlag = toBeUsedFlag);
    for dataLabelIdx = 1:length(dataLabels)
        if dataLabelIdx == 4
            continue;
        end
        dataLabel = dataLabels{dataLabelIdx};
        exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
            complementaryLabel);
    end
    % exporter.generateAndExportTrigger(); % Beware this will launch ingestion, so don't
        % excute this line if web-app unready. Alternatively, parameter a filename
        % to handle that more transparently for testing                            @todo

    % Use case 3
    % ----------
    % Don't forget to generate the geotiffs and stats before.
    % NB: some root subdivisions share the same geotiffs (USAlaska and Western Canada).
    toBeUsedFlag = 1; % By default 1.
    label = 'v2024.0';
    versionOfAncillary = 'v3.1'; % Only for initiating the exporter.
    versionOfAncillariesToExport = {'v3.1', 'v3.2'}; % all these versions are exported.
    dataLabel = 'VariablesGeotiff';
    thisDate = ''; %datetime(2024, 2, 28);
    complementaryLabel = ['EPSG_', num2str(Regions.webGeotiffEPSG)];
    scratchPath = '/rc_scratch/sele7124/'; %getenv('espArchiveDir');
    setenv('espWebExportRootDir', getenv('espWebExportRootDirForIntegration'));
    %setenv('espWebExportRootDir', getenv('espWebExportRootDirForQA'));
    %setenv('espWebExportRootDir', getenv('espWebExportRootDirForProd'));
    modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary);
    espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath);
    espEnvWOFilter = ESPEnv(modisData = modisData, scratchPath = scratchPath, ...
        filterMyConfByVersionOfAncillary = 0);
    varNames = unique(espEnvWOFilter.myConf.variableregion( ...
        espEnvWOFilter.myConf.variableregion.writeGeotiffs == 1, :).output_name);
    %varNames = varNames(1);
    exporter = ExporterToWebsite(espEnv, versionOfAncillariesToExport, ...
        toBeUsedFlag = toBeUsedFlag);
    for varIdx = 1:length(varNames)
        varName = varNames{varIdx};
        exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
            complementaryLabel);
    end

    % If we want to supply the former v2023.1 web-app:
%{
    dataLabel = 'VariablesGeotiffv20231';
    for varIdx = 1:length(varNames)
        varName = varNames{varIdx};
        exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
            complementaryLabel);
    end
%}    
    % Export of the stat files.
    dataLabel = 'SubdivisionStatsWebJson';
    varNames = unique(espEnvWOFilter.myConf.variableregion( ...
        espEnvWOFilter.myConf.variableregion.writeStats == 1, :).output_name);
    for varIdx = 1:length(varNames)
        varName = varNames{varIdx};
        exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
            complementaryLabel);
    end

    exporter.generateAndExportTrigger(); % Beware this will launch ingestion, so don't
        % excute this line if web-app unready. Alternatively, parameter a filename
        % different from 'TRIGGER' in configuration_of_filepaths.csv.
        % to handle that more transparently for testing                            @todo
%}
    properties
        espEnv              % ESPEnv obj.
        espWebExport = struct(domain = '', rootDir = '', sshKeyFilePath = '', ...
            user = '');     % struct. Properties allowing to connect to the ingest
                            % machine and push files in the correct directory.
                            % - domain: char. Domain where to push the data to be
                            %   ingested by the website.
                            % - rootDir: char. Root directory where the folders of data
                            %   will be exported. Must end by a /.
                            % - sshKeyFilePath: char. FilePath of the ssh key, that
                            % allows to  connect the user to the ingest domain.
                            % - user: char. User/Login that allows to connect to the
                            % domain.
        versionOfAncillariesToExport % cell(char). List of versionOfAncillary data to
                            % export.
        toBeUsedFlag = 1;   % Flag in the landsubdivision confs indicating that the
                            % landsubdivision is used.
    end
    properties(Constant)
    end
    methods(Static)
        % I put here all the methods to communicate with the webapp ingest server,
        % although they could be in a dedicated System or Ssh class.
        % NB: Linux server only is implemented.
        function [status, cmdout] = system(cmd)
            % Parameters
            % ----------
            % cmd: char. Command to execute on the distant server.
            %
            % Return
            % ------
            % status: int. 0 if ok, otherwise error code.
            % cmdout: char. Result of the command.
            %
            % NB: this method exists to handle the failed status return by matlab
            %   system().
            fprintf('%s: Sending cmd %s ...\n', mfilename(), cmd);
            [status, cmdout] = system(cmd);
            if status
                errorStruct.identifier = ...
                    'ExporterToWebsite:systemCmdError';
                errorStruct.message = sprintf( ...
                    ['%s: Failed cmd, error %s: %s.\n', ...
                    'instantiation: %s'], mfilename(), string(status), cmdout);
                error(errorStruct);
            else
                fprintf(['%s: Executed cmd. Result: %s: %s.\n', ...
                    'instantiation: %s.\n'], mfilename(), string(status), cmdout);
            end
        end
    end
    methods
        function obj = ExporterToWebsite(espEnv, versionOfAncillariesToExport, ...
            varargin)
            % Parameters
            % ----------
            % espEnv: ESPEnv obj. This espEnv will be reused to generate a dedicated
            %   espEnv for each version of ancillary.
            % versionOfAncillariesToExport: cell(char). List of the version of ancillary
            %   data to export. This is used to filter regions, and also the data linked
            %   to these regions (if versionOfAncillary is v3.1, only westernUS
            %   ancillary and data will be exported.
            % toBeUsedFlag: int, optional. By default 1, but we can use another number
            %   > 1 to temporarily deactivate some subdivisions. Shouldn't be 0.
            %
            % NB: also requires environmental variables, see above.
            fprintf('%s: Instantiate exporterToWebsite ...\n', mfilename())
            obj.espEnv = espEnv;
            obj.versionOfAncillariesToExport = versionOfAncillariesToExport;
            espWebExportFieldNames = fieldnames(obj.espWebExport);
            for fieldIdx = 1:length(espWebExportFieldNames)
                thisFieldName = espWebExportFieldNames{fieldIdx};
                environmentVarName = ['espWebExport', upper(thisFieldName(1)), ...
                    thisFieldName(2:end)];
                if isempty(getenv(environmentVarName))
                    errorStruct.identifier = ...
                        'ExporterToWebsite:UnsetEnvironmentVariables';
                    errorStruct.message = sprintf( ...
                        ['%s: Environment variables should be set before ', ...
                        'instantiation: %s.\n'], mfilename(), thisFieldName);
                    error(errorStruct);
                end
                obj.espWebExport.(thisFieldName) = ...
                    getenv(environmentVarName);
            end
            
            p = inputParser;
            addParameter(p, 'toBeUsedFlag', obj.toBeUsedFlag);
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            obj.toBeUsedFlag = p.Results.toBeUsedFlag;
            
            fprintf('%s: Instantiates exporterToWebsite to %s@%s directory %s.\n', ...
                mfilename(), obj.espWebExport.user, obj.espWebExport.domain, ...
                obj.espWebExport.rootDir);
        end
        function exportFileForDataLabelDateAndVarName(obj, ...
            dataLabel, thisDate, varName, complementaryLabel)
            % Export a file to the ingest domain, for all versions of ancillary of this
            % object or for the version label of nrt/historic data of the espEnv
            % property of this object.
            %
            % Parameters
            % ----------
            % objectName: char. Name of the tile or region as found in the modis files
            %   and others. E.g. 'h08v04'. Must be unique. Alternatively, can be the
            %   name of the landSubdivisionGroup. E.g. 'westernUS' or 'USWestHUC2'.
            % dataLabel: char. Label (type) of data for which the file is required, should
            %   be a key of ESPEnv.dirWith struct, e.g. MOD09Raw.
            % thisDate: datetime. Cover the period for which we want the
            %   files.
            % varName: char. Name of the variable to load (name in the file, not
            %   obligatorily output_name of configuration_of_variables.csv). Can be ''
            %   if the file is not specific to a variable.
            % complementaryLabel: char. Only used to add EPSG code for geotiffs. E.g.
            %   EPSG_3857. If not necessary, put ''.
            %
            % NB: only works on Linux server right now (2023-10-23).

            % list of filePaths already sent during this call (don't check sent in
            % previous calls).
            exportedWebFilePaths = {''};

            % Run for each versionOfAncillary...
            for versionOfAncillaryIdx = 1:length(obj.versionOfAncillariesToExport)
                versionOfAncillary = ...
                    obj.versionOfAncillariesToExport{versionOfAncillaryIdx};
                % Initialize the local espEnv object ...
                % NB: label for the local ModisData is arbitrarily taken from the main
                % ModisData.
                thisEspEnv = ESPEnv(modisData = MODISData( ...
                    label = obj.espEnv.modisData.versionOf.SubdivisionStatsWebJson, ...
                    versionOfAncillary = versionOfAncillary), ...
                    scratchPath = obj.espEnv.scratchPath);
                    % WARNING: here we use versionOf.SubdivisionStatsWebJson while in
                    % AncillaryOutput we use versionOf.VariablesGeotiff.        @warning
                if ~isempty(varName) && ...
                    ~ismember(varName, thisEspEnv.myConf.variableregion( ...
                    thisEspEnv.myConf.variableregion.writeGeotiffs == 1, :).output_name)
                    fprintf(['%s: No handling of variable %s for version ', ...
                        '%s (writeGeotiffs = 0).\n'], mfilename(), varName, ...
                        versionOfAncillary);
                    continue;
                end

                thisParameterChar = [dataLabel, ' version: ', ...
                    thisEspEnv.modisData.versionOf.ancillary]; % used for messages.
                if strcmp(class(thisDate), 'datetime')
                    thisParameterChar = [thisParameterChar, ', date: ', ...
                        char(thisDate, 'yyyy-MM-dd')];
                end
                if ~isempty(varName) & strcmp(class(varName), 'char')
                    thisParameterChar = [thisParameterChar, ', varName: ', ...
                        varName];
                end
                fprintf('%s: Exporting %s ...\n', mfilename(), thisParameterChar);

                % Get the list of objectNames having files with this dataLabel -
                % thisDate and varName:
                patternsToReplaceByJoker = {'objectId', 'objectId_1000', 'objectName'};
                if isempty(thisDate)
                    patternsToReplaceByJoker{end + 1} = 'thisDate';
                    patternsToReplaceByJoker{end + 1} = 'thisYear';
                    patternsToReplaceByJoker{end + 1} = 'thisWaterYear';
                end
                [filePath, fileExists, ~] = ...
                    thisEspEnv.getFilePathForDateAndVarName(0, dataLabel, thisDate, ...
                    varName, complementaryLabel, ...
                    patternsToReplaceByJoker = patternsToReplaceByJoker);
                % If files were not generated previously and do not exist.
                if ~iscell(filePath) && ~fileExists
                    warning( ...
                        ['%s: No file found for pattern %s, ', ...
                        '.exportFileForDataLabelDateAndVarName().'], ...
                        mfilename(), filePath);
                    continue;
                end
                % Cellification if only 1 record.
                if ~iscell(filePath)
                    filePath = {filePath};
                end
                try
                    [objectIds, ~, ~, ~] = cellfun(@(x) ...
                        thisEspEnv.getMetadataFromFilePath(x, dataLabel), filePath, ...
                        UniformOutput = false); % UniformOutput = false, otherwise return
                            % char rather than cell if only 1 filePath.
                catch thisException % Uselessnow ?
                    fprintf('%s: No file and objects to export for %s ...\n', ...
                        mfilename(), thisParameterChar);
                    continue;
                end
                objectIds = unique(cell2mat(objectIds));
                % If the file really refers to an object, there's no objectId = 0.
                if ~ismember(dataLabel, {'landsubdivisionrootinjson', ...
                    'landsubdivisiontypeinjson'})
                    objectIds(objectIds == 0) = [];
                end
                
                % For some dataLabels get the landsubdivision conf.
                if ismember(dataLabel, {'VariablesGeotiff', 'VariablesGeotiffv20231'})
                    thisEspEnv.setAdditionalConf('landsubdivision'); 
                        % NB: already done in getMetadata ...?                  @tocheck
                    % espEnv.setAdditionalConf('landsubdivisionlink');
                    %espEnv.setAdditionalConf('landsubdivisiontype');
                end

                % For each object, get the file and send a copy to the webapp ingest ...
                % Note that this way of doing things, reasking for the filePath while
                % we already asked for it is convoluted and I don't remember exactly
                % why I'm doing like this but there might have been a reason :D @tocheck
                patternsToReplaceByJoker( ...
                    contains(patternsToReplaceByJoker, 'object')) = [];
                for objectIdx = 1:length(objectIds)
                    objectLabel = objectIds(objectIdx); % here it's an objectId.
                    [objectId, objectName, ~] = ...
                        thisEspEnv.getObjectIdentification(objectLabel);
                        % NB: objectName is initially name of region, and if geotiffs
                        % shifts to id of subdivision, see below.
                        % NB: throughout the esp code, there's a confusion between
                        % objectId and objectName, which may be hard to remember.
                        %                                                       @warning

                    % Get the filePath and check existence/already sent in this call.
                    [filePath, fileExists] = ...
                        thisEspEnv.getFilePathForDateAndVarName( ...
                        objectId, dataLabel, thisDate, varName, complementaryLabel, ...
                        patternsToReplaceByJoker = patternsToReplaceByJoker);
                        % Raises error if dataLabel not in
                        % configuration_of_filenames.csv and in modisData.versionOf.
                    if ~iscell(fileExists) && ~fileExists
                        warning(['%s: Inexistent file %s.\n'], mfilename(), filePath);
                        continue;
                    elseif iscell(filePath)
                        filePath = filePath{1}; % the first is the most recent.
                    end

                    % Get the filepath in the destination distant webapp server.
                    % For this, we occasionally need the subdivision id as destination
                    % objectName (for geotiffs only 2023-11-15).
                    webRelativeFilePaths = {};
                    if ismember(dataLabel, ...
                        {'VariablesGeotiff', 'VariablesGeotiffv20231'})
                        rootSubdivisionTable = thisEspEnv.myConf.landsubdivision( ...
                            thisEspEnv.myConf.landsubdivision.used >= ...
                            obj.toBeUsedFlag & ...
                            thisEspEnv.myConf.landsubdivision.root == 1, :);
                        subdivisionIds = Tools.valueInTableForThisField( ...
                            rootSubdivisionTable, 'sourceRegionName', ...
                            objectName, 'id');

                        for subdivisionIdx = 1:length(subdivisionIds)
                            objectId = subdivisionIds(subdivisionIdx);
                            if strcmp(dataLabel, 'VariablesGeotiffv20231')
                                objectId = objectName;
                            end % NB: temporary patch for keeping v2023.1 web-app  @todo

                            webRelativeFilePaths{subdivisionIdx} = ...
                                Tools.valueInTableForThisField( ...
                                thisEspEnv.myConf.filePath, 'dataLabel', ...
                                dataLabel, 'webRelativeFilePath');
                            webRelativeFilePaths{subdivisionIdx} = ...
                                thisEspEnv.replacePatternsInFileOrDirPaths(...
                                webRelativeFilePaths{subdivisionIdx}, objectId, ...
                                dataLabel, thisDate, varName, complementaryLabel);
                                % NB: here we transfer objectId at the place of
                                % objectName argument (a bit ambiguous).
                        end
                    else
                        webRelativeFilePaths = Tools.valueInTableForThisField( ...
                                thisEspEnv.myConf.filePath, 'dataLabel', ...
                                dataLabel, 'webRelativeFilePath');

                        webRelativeFilePaths = { ...
                            thisEspEnv.replacePatternsInFileOrDirPaths(...
                                webRelativeFilePaths, objectId, ...
                                dataLabel, thisDate, varName, complementaryLabel)};
                            % Here it must be objectId, because we have subdivisions
                            % sharing the same code (objectName).
                    end

                    % Transfer each file corresponding to each available object
                    % for the dataLabel.
                    for webRelativeFileIdx = 1:length(webRelativeFilePaths)
                        % We use a loop, but actually the loop is only useful when
                        % we send
                        % two copies of the same file under distinct target names,
                        % which is currently the case only for geotiffs 2023-11-15.

                        webRelativeFilePath = webRelativeFilePaths{webRelativeFileIdx};
                        if ismember(webRelativeFilePath, exportedWebFilePaths)
                            fprintf(['%s: Already sent file %s (normal for ', ...
                                'ancillary data not depending on version).\n'], ...
                                mfilename(), webRelativeFilePath);
                            continue;
                        end
                        [webRelativeDirPath, ~, ~] = fileparts(webRelativeFilePath);
                        % Check if the distant directory exists, otherwise create it ...
                        cmd = ['ssh -q -i ', ...
                            obj.espWebExport.sshKeyFilePath, ...
                            ' ', obj.espWebExport.user, '@', ...
                            obj.espWebExport.domain, ...
                            ' [ ! -d "', obj.espWebExport.rootDir, ...
                            webRelativeDirPath, '" ] && echo 1 || echo 0'];
                        [status, cmdout] = obj.system(cmd);
                        if str2num(cmdout(end-1:end-1)) == 1
                            % required to convert to num because cmdout contains a
                            % \n at the end.
                            % and also because blanca launch a warning at the beginning
                            % of the string,
                            % glibc_shim: Didn't find correct code to patch. 2023-11-16.
                            cmd = ['ssh -q -i ', ...
                                obj.espWebExport.sshKeyFilePath, ...
                                ' ', obj.espWebExport.user, '@', ...
                                obj.espWebExport.domain, ...
                                ' "mkdir -p ', obj.espWebExport.rootDir, ...
                                webRelativeDirPath, '"'];
                            [status, cmdout] = obj.system(cmd);
                        end

                        % Copy the file to the distant directory ...
                        cmd = ['scp -q -i ', ...
                            obj.espWebExport.sshKeyFilePath, ' ', filePath, ...
                            ' ', obj.espWebExport.user, '@', ...
                            obj.espWebExport.domain, ...
                            ':', obj.espWebExport.rootDir, webRelativeFilePath];
                        [status, cmdout] = obj.system(cmd);
                        exportedWebFilePaths{end} = webRelativeDirPath;
                    end % webRelativeFileIdx
                end % objectIdx
                if length(objectIds) == 0
                    warning('%s: Not Exported any object for %s.\n', mfilename(), ...
                        thisParameterChar);
                else
                    fprintf('%s: Exported objects for %s.\n', mfilename(), ...
                        thisParameterChar);
                end
            end % versionOfAncillaryIdx
        end
        function generateAndExportTrigger(obj)
            % Generate a trigger file and export it to the web-app ingest, so that the
            % web-app starts ingest.
            % NB: Once the trigger file is in the web-app ingest directory,
            % ExporterToWebsite can't export any more file til the trigger file is
            % removed by the web-app.
            %
            % NB: it's apparent impossible to do ssh touch to the distant webapp ingest
            % server (2023-10-25).
            dataLabel = 'webingestrigger';
            [filePath, ~] = ...
                obj.espEnv.getFilePathForDateAndVarName( ...
                        '', dataLabel, '', '', '');
            cmd = ['touch "', filePath, '"'];
            [status, cmdout] = obj.system(cmd);
            dataLabel = 'webingestrigger';
            webRelativeFilePath = Tools.valueInTableForThisField( ...
                obj.espEnv.myConf.filePath, 'dataLabel', ...
                dataLabel, 'webRelativeFilePath');
            % Copy the file to the distant directory ...
            cmd = ['scp -q -i ', ...
                obj.espWebExport.sshKeyFilePath, ' ', filePath, ...
                ' ', obj.espWebExport.user, '@', obj.espWebExport.domain, ...
                ':', obj.espWebExport.rootDir, webRelativeFilePath];
            [status, cmdout] = obj.system(cmd);
        end
    end
end
