classdef AncillaryOutput < handle
    % Generation of all metadata and ancillary files for the web-app, in format .json.
    %
    
%{
    % Use case
    % --------
    toBeUsedFlag = 1; % We temporarily use this value of 2 to limit the number of
    % subdivisions, but for launch and having all subdivisions, we have to update
    % configuration_of_landsubdivisions.csv and
    % configuration_of_landsubdivisionlinks.csv to 1 and update toBeUsedFlag to 1 too.
    uncondensedJson = 1;
    includeSubdivisionTypeInJson = 0; 
    versionLabel = 'v2024.0d'; % Not used, but necessary to instantiate espEnv
    versionOfAncillary = 'v3.1'; % This is not used to save each subdivision shapefile,
        % another espEnv with the versionOfAncillary of the source region is used.
    scratchPath = '/rc_scratch/sele7124/'; %getenv('espScratchDir');
    
    modisData = MODISData(label = versionLabel, versionOfAncillary = versionOfAncillary);
    espEnvWOFilter = ESPEnv(modisData = modisData, scratchPath = scratchPath, ...
        filterMyConfByVersionOfAncillary = 0);

    % Get the subdivision names and source regions (to get ancillary version) and
    % the hierarchy from the configuration.
    espEnvWOFilter.setAdditionalConf('landsubdivision', ...
      confFieldNames = {'name', 'id', 'code', 'subdivisionType', 'sourceRegionId', ...
      'sourceRegionName', 'used', 'root', 'CRS', 'firstMonthOfWaterYear', ...
      'versionOfAncillary'});
    espEnvWOFilter.setAdditionalConf('landsubdivisionlink');
    espEnvWOFilter.setAdditionalConf('landsubdivisiontype');
    espEnvWOFilter.setAdditionalConf('webname');
    
    % Temporary for integration albedo/radiative_forcing.
    espEnvWOFilter.myConf.variableregion( ...
      strcmp(espEnvWOFilter.myConf.variableregion.regionName, ...
      'westernUS') & ...
      ismember(espEnvWOFilter.myConf.variableregion.varId, [62, 63]), 'webIsPresent') = {1};
    
    ancillaryOutput = AncillaryOutput(espEnvWOFilter, ...
        includeSubdivisionTypeInJson = includeSubdivisionTypeInJson, ...
        toBeUsedFlag = toBeUsedFlag, uncondensedJson = uncondensedJson);
    
    ancillaryOutput.writeSubdivisionTypes();
    % ancillaryOutput.writeVariables(); % NB: is stored as static, should change only
    % very rarely.
    ancillaryOutput.writeRootSubdivisions();
    subdivisionTable = ancillaryOutput.writeSubdivisionLinks();
    ancillaryOutput.writeSubdivisionMetadata(subdivisionTable);
%}
    properties
        espEnvWOFilter  % ESPEnv object, local environment variables (paths...)
                        % and methods. Include the modisData property.
        includeSubdivisionTypeInJson = 0; % if 1, include the subdivision type in root
            % and region json files.
        toBeUsedFlag = 1;   % Flag in the landsubdivision conf indicating that the
                            % landsubdivision is used. 1 by default.
        uncondensedJson = 0;
    end
    properties(Constant)
        
    end
    methods(Static)
                
    end
    methods
        function obj = AncillaryOutput(espEnvWOFilter, varargin)
            % Parameters
            % ----------
            % espEnvWOFilter: ESPEnv object. Which includes local environment variables.
            %   Shouldn't be filtered by versions of ancillary so as to get the full
            %   spectrum of ancillary data, obtained by:
            %   espEnvWOFilter = ESPEnv(modisData = modisData, ...
            %       scratchPath = scratchPath, filterMyConfByVersionOfAncillary = 0);
            % includeSubdivisionTypeInJson: int, optional. By default 0. If 1, include
            %   the subdivision type in root and region json files.
            % toBeUsedFlag: int, optional. By default 1, but we can use another number
            %   > 1 to temporarily deactivate some subdivisions. Shouldn't be 0.
            % uncondensedJson: int, optional. If 0 (default), condense the jsn
            %   files by removing new lines/spaces, if 1 keep the new lines/spaces.

            obj.espEnvWOFilter = espEnvWOFilter;
            p = inputParser;
            addParameter(p, 'includeSubdivisionTypeInJson', ...
                obj.includeSubdivisionTypeInJson);
            addParameter(p, 'toBeUsedFlag', obj.toBeUsedFlag);
            addParameter(p, 'uncondensedJson', obj.uncondensedJson);
            p.KeepUnmatched = false;
            parse(p, varargin{:});
            
            obj.includeSubdivisionTypeInJson = p.Results.includeSubdivisionTypeInJson;
            obj.toBeUsedFlag = p.Results.toBeUsedFlag;
            obj.uncondensedJson = p.Results.uncondensedJson;
        end
        function text = getAndWriteJsonFromStruct(obj, thisStruct, dataLabel, ...
            outFilePath)
            % Generate, format and write the json version of a struct object, based
            % on the format expected by the snow-today webapp.
            %
            % Parameters
            % ----------
            % thisStruct: struct. Represent the tree of specific ancillary data that
            %   we want into the json.
            % dataLabel: char. Label (type) of data for which the file is required,
            %    e.g. landsubdivisionrootinjson (in conf of filepaths.csv).
            % outFilePath: char: filePath to write the json.
            
            % Json generating and 1st formatting/replacement of values.
            originalValuesInText = {'web_', '%', 'sensor_text', '"false"', ...
                '"true"'};
            newValuesInText = {'', '%%', 'source', 'false', ...
                'true'};
            text = replace(regexprep(jsonencode(thisStruct, ...
                PrettyPrint = logical(obj.uncondensedJson)), ...
                '"t([0-9])+":', '"$1":'), originalValuesInText, newValuesInText);
                % - id pattern was initially '"t([0-9])+":'
                % to make keys actual integers, but matlab can't read integer keys (in
                % the improbable case we have to read the .json files. So I came back to
                % string keys. We reverse to the numeric id by removing the t.
                % -Matlab: We escape the % special character, otherwise the text will be
                % written uncomplete in the file.
            
            % 2st formatting/replacement of values using the conf file webname.csv.
            replaceValuesBy = obj.espEnvWOFilter.myConf.webname( ...
                strcmp(obj.espEnvWOFilter.myConf.webname.dataLabel, ...
                dataLabel), :);
            backendNames = cellfun(@(x) ['"',x, '"'], replaceValuesBy.backendName, ...
                UniformOutput = false);
            webNames = cellfun(@(x) ['"',x, '"'], replaceValuesBy.webName, ...
                UniformOutput = false);
            text = replace(text, backendNames, webNames);
            
            fileResource = fopen(outFilePath, 'w');
            fprintf(fileResource, text);
            fclose(fileResource);
        end
        function rootSubdivisionTable = writeRootSubdivisions(obj)
            % Generate the root subdivision conf file (1 file only), listing metadata
            % for root regions and the available variables.
            % NB: subdivision is called region in the web-app.
            % The website will use this to quickly display the list of root regions.
            % NB: This file should be updated every day with the variable value range.
            %                                                                      @todo
            % NB: A root region is not displayed if there's no geotiff.
            %
            % Return
            % ------
            % rootSubdivisionTable: table. List of root subdivisions which should be
            %     exported to the web-app.
            %   
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            dataLabel = 'landsubdivisionrootinjson';
            outFilePath = obj.espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
                '', dataLabel);
                % NB: no version in the path, see configuration_of_filepaths.csv.
            fprintf('%s: Start generating subdivision root file %s...\n', ...
                mfilename(), outFilePath);
                
            myConfWOFilter = obj.espEnvWOFilter.myConf;
            rootSubdivisionTable = myConfWOFilter.landsubdivision( ...
                myConfWOFilter.landsubdivision.used >= obj.toBeUsedFlag & ...
                myConfWOFilter.landsubdivision.root == 1 & ...
                ~strcmp(myConfWOFilter.landsubdivision.version, {''}) & ...
                ~strcmp(myConfWOFilter.landsubdivision.versionOfAncillary, {''}), ...
                {'id', 'name', 'code', 'subdivisionType', 'sourceRegionName', ...
                'sourceRegionId', 'root', 'CRS', 'version', 'versionOfAncillary', ...
                'firstMonthOfWaterYear'});
                % NB: strcmp is used because isequal or isempty dont work here, dont
                % know why...
            rootSubdivisionTable = sortrows(rootSubdivisionTable, 'name');
            subdivisionList = struct();
            relativePathDataLabels = {'landsubdivisioninjson', ...
                'landsubdivisionlinkinjson', 'landsubdivisionshapeingeojson'};
            relativePathFieldNames = {'subdivisionListAndMetadataRelativePath', ...
                'subdivisionHierarchyRelativePath', 'shapefileRelativePath'};
            fieldList = {'name', 'code', 'CRS'};
            if obj.includeSubdivisionTypeInJson
                fieldList = {'name', 'code', 'subdivisionType', 'CRS'};
            end  % this is for debug only, the schema doesn't accept subdivisionType.

            rootIdxToRemoveFromRootSubdivisionTable = [];
                % List of root ids that are to be excluded because they don't have
                % variables and data.
                
            for rootIdx = 1:size(rootSubdivisionTable, 1)
                rootId = rootSubdivisionTable.id(rootIdx);
                rootIdWithT = strcat('t', num2str(rootId));
                    % Format the id with a t because struct fieldnames used below can't
                    % be numeric.
                    
                % Get the available variables for the root subdivision and if none
                % available, don't
                % include this root subdivision in the .json file ...    
                regionVarConf = myConfWOFilter.variableregion( ...
                    strcmp(myConfWOFilter.variableregion.regionName, ...
                    rootSubdivisionTable.sourceRegionName{rootIdx}) & ...
                    (myConfWOFilter.variableregion.writeGeotiffs == 1 & ...
                    myConfWOFilter.variableregion.webIsPresent == 1), ...
                    {'varId', 'isDefault'});
                    % Initially included  & ...
                    %  myConfWOFilter.variableregion.writeStats == 1
                    % but we don't calculate stats for not_processed, which still 
                 
                % Here check if variables have actually geotiffs and stats data    @todo
                % IMPORTANT TODO!!!!!!!!!!
                
                if isempty(regionVarConf)
                    rootIdxToRemoveFromRootSubdivisionTable(end + 1) = rootIdx;
                    continue;
                end
                
                % Filling metadata of the root subdivision.
                thatSubdivisionInfo = ...
                    table2struct(rootSubdivisionTable(rootIdx, fieldList)); 
                
                % Water Year info.
                regionName = ''; % rootSubdivisionTable.sourceRegionName{rootIdx};
                originalEspEnv = obj.espEnvWOFilter;
                version = rootSubdivisionTable.version{rootIdx};
                versionOfAncillary = rootSubdivisionTable.versionOfAncillary{rootIdx};
                
                thisEspEnv = ESPEnv.getESPEnvForRegionNameFromESPEnv(regionName, ...
                    originalEspEnv, version = version, ...
                    versionOfAncillary = versionOfAncillary);
                    % NB: In that case, regionName is not used by
                    % getESPEnvForRegionNameFromESPEnv(). Modify the method?       @todo
                
                objectName = rootSubdivisionTable.sourceRegionName{rootIdx};
                % TEMPORARY dataLabel til v2024.0d for website prod deprecated. 20241210.
                if ismember(thisEspEnv.modisData.versionOf.VariablesGeotiff, ...
                    {'v2024.0d'})
                    dataLabel = 'VariablesGeotiff';
                else
                    dataLabel = 'spiresdailytifproj';
                end
                    % NB: Actually both are required, geotiff + stats.             @todo
                
                % Get the variables and build the array of sensor sources for the
                % root subdivision.
                regionVarConf = join(regionVarConf, thisEspEnv.myConf.variable, ...
                    LeftKeys = 'varId', ...
                    RightKeys = 'id', LeftVariables = {'isDefault'}, ...
                    RightVariables = {'id', 'output_name', 'nodata_value', ...
                    'web_longname', ...
                    'web_colormap_value_min', 'web_colormap_value_max', ...
                    'web_colormap_is_dynamic', 'web_sensor_text'});
                regionVarConf = sortrows(regionVarConf, ...
                {'web_sensor_text', 'web_longname'});
                    % variables ordered by sensor/source names and variable names.
            %{
            % Formerly we created a tree of sensors, but now we put all variables in the same
            %   basket. 2023-12-13.
                sensorTexts = unique(regionVarConf.web_sensor_text);
                for sensorTextIdx = 1:length(sensorTexts)
                    thisVarConf = regionVarConf(strcmp(regionVarConf.web_sensor_text, ...
                        sensorTexts{sensorTextIdx}), :);
                    thatSubdivisionInfo.sources.(['t', num2str(sensorTextIdx)]) = ...
                        struct(source = sensorTexts{sensorTextIdx}, isDefault = 0);
            %}
                thisVarConf = regionVarConf;
                % Construct the array of variables within this sensor/source for the
                % root subdivision.
                % NB: Value range for each variable should be done dynamically from the
                % geotiff data for each variable,
                % but the specs are to be clarified        @todo
                for varIdx = 1:size(thisVarConf, 1)
                    varMetadata = table2struct(thisVarConf(varIdx, {'isDefault'}));
            %{      
            % Don't need this anymore with the removal of sensor levels. 2023-12-13.
                    % if one the variable is default one, set the sensor/source to
                    % default too.
                    if varMetadata.isDefault == 1
                        thatSubdivisionInfo.sources. ...
                            (['t', num2str(sensorTextIdx)]).isDefault = 1;
                    end
            %}
                    
                    % Get the waterYearDate dynamically from the last geotiff available
                    % for this region
                    % and determine waterYear, waterYearStartDate, lastDateWithData,
                    % historicWaterYearRange, historicSource. NB: historicSource should
                    % be DYNAMIC                                                   @todo
                    % NB: what if there is only the not_processed geotiff?         @todo

                    thisDate = '';
                    varName = thisVarConf.id(varIdx); % And not output_name.
                        % NB: a bit confusional, should find a solution in file name
                        % methods in ESPEnv.                                       @todo
                    complementaryLabel = ['EPSG_', num2str(Regions.webGeotiffEPSG)];
                    patternsToReplaceByJoker = {'thisDate', 'thisWaterYear', 'thisYear'};
                    [filePath, ~, ~] = thisEspEnv. ...
                        getFilePathForDateAndVarName(objectName, dataLabel, ...
                            thisDate, varName, complementaryLabel, ...
                            patternsToReplaceByJoker = patternsToReplaceByJoker);
                    if isempty(filePath) || ...
                        (size(filePath, 1) == 1 && contains(filePath, '*')) % Add joker case, because popup an error for OCNewZealand, dont know why. @warning
                        continue;
                    elseif size(filePath, 1) > 1
                        filePath = filePath{1}; % the first is the most recent.
                    end
                    [~, ~, thisDate, ~, ~] = thisEspEnv. ...
                        getMetadataFromFilePath(filePath, dataLabel);
                    thisWaterYearDate = WaterYearDate(thisDate, ...
                        rootSubdivisionTable.firstMonthOfWaterYear(rootIdx), ...
                        WaterYearDate.yearMonthWindow);
                    varMetadata.waterYear = thisWaterYearDate.getWaterYear();
                    varMetadata.waterYearStartDate = ...
                        convertStringsToChars( ...
                            string(thisWaterYearDate.getFirstDatetimeOfWaterYear(), ...
                            'yyyy-MM-dd'));                
                    varMetadata.lastDateWithData = ...
                        convertStringsToChars( ...
                            string(thisWaterYearDate.thisDatetime, 'yyyy-MM-dd'));

                    % Determine the max nb days for snow_cover_days variable.
                    % NB: based on the last geotiff. Doesn't check if snow_cover_days
                    % has been effectively updated.                             @warning
                    if ismember(thisVarConf.id(varIdx), ...
                        Variables.varIdsForSnowCoverDays)
                        thisVarConf.web_colormap_value_max(varIdx) = daysact( ...
                            thisWaterYearDate.getFirstDatetimeOfWaterYear(), ...
                            thisWaterYearDate.thisDatetime) + 1;
                    end
                    % replace isDefault = uint by true or false text values
                    % (expected by web-app).
                    if varMetadata.isDefault == 0
                        varMetadata.isDefault = 'false';
                    else
                        varMetadata.isDefault = 'true';
                    end
                    varMetadata.colormap_value_range = ...
                        [thisVarConf.web_colormap_value_min(varIdx), ...
                        thisVarConf.web_colormap_value_max(varIdx)];
                    % Dynamic for albedos, deltavis, radiative forcing Seb 20241125.
                    if thisVarConf.web_colormap_is_dynamic(varIdx) == 1
                      [varData, ~] = readgeoraster(filePath);
                      thatClass = class(varData);
                      thatMinMax = ...
                        prctile(varData(varData ~= intmax(thatClass)), [5 95], "all");
                      % obsolete. thatMin = min(varData(varData ~= intmax(thatClass)), [], 'all');
                      % obsolete. thatMax = max(varData(varData ~= intmax(thatClass)), [], 'all');
                      varData = [];
                      if strcmp(thatClass, 'uint8')
                        varMetadata.colormap_value_range = ...
                          [floor(thatMinMax(1) / 5) * 5, ceil(thatMinMax(2) / 5) * 5];
                      elseif strcmp(thatClass, 'uint16')
                        varMetadata.colormap_value_range = ...
                          [floor(thatMinMax(1) / 50) * 50, ceil(thatMinMax(2) / 50) * 50];
                      end
                    end
                    
                    % Geotiff relative paths in json.
                    thisDate = '';
                    varName = thisVarConf.id(varIdx); % And not output_name.
                        % NB: a bit confusional, should find a solution in file name
                        % methods in ESPEnv.                                       @todo
                    complementaryLabel = ['EPSG_', num2str(Regions.webGeotiffEPSG)]; 
                    tmpFilePath = Tools.valueInTableForThisField( ...
                        myConfWOFilter.filePath, 'dataLabel', ...
                        dataLabel, 'webRelativeFilePathInJson');
                    varMetadata.geotiffRelativePath = ...
                        thisEspEnv.replacePatternsInFileOrDirPaths(...
                            tmpFilePath, rootId, ...
                            dataLabel, thisDate, varName, complementaryLabel);
%%{
%TEMPORARY WAIT FOR MATT CHANGE VALIDATION SCHEMA 2024-02-22                       @todo
                    varMetadata.legendRelativePath = replace( ...
                        varMetadata.geotiffRelativePath, ...
                        {'cogs', 'tif'}, {'legends', 'svg'});
%%}

                    % Historic info.
                    % NB: this info depends on the sensor too, so it should and need to 
                    % be transferred at the variable level in a future version
                    % 2024-02-20.
                    %                                                           @warning
                    thisRegionConf = thisEspEnv.myConf.region( ...
                        strcmp(thisEspEnv.myConf.region.name, ...
                        rootSubdivisionTable.sourceRegionName{rootIdx}), :);
%{                       
                    thatSubdivisionInfo.historicStartWaterYear = ...
                        thisRegionConf.historicStartWaterYear; % TEMPORARY
%}
                    varMetadata.historicWaterYearRange = ...
                        [thisRegionConf.historicStartWaterYear, ...
                            thisWaterYearDate.getWaterYear() - 1]; 
                        % NB: kindof problematic if there is no historics.         @todo
    %}
                    varMetadata.historicSource = 'LPDAAC mod09ga v6.1';
                        % NB: shouldn't be hard-coded. 'JPL modscag/drfs' for other stc
                        %                                                          @todo
                        % IMPORTANT!!!!
                    
                    % Set the metadata for the variable in the struct...
                    thatSubdivisionInfo. ...
                        variables.(['t', num2str(thisVarConf.id(varIdx))]) = ...
                        varMetadata;
                        % Formerly variables was kid of source:
                        % sources.(['t', num2str(sensorTextIdx)]). 2023-12-13.
                end % varIdx
                    
                % Relative paths of ancillary files related to the current root subdivision:
                for relativePathIdx = 1:length(relativePathDataLabels)
                    webFilePathConf = ...
                        myConfWOFilter.filePath( ...
                        strcmp(myConfWOFilter.filePath.dataLabel, ...
                        relativePathDataLabels{relativePathIdx}), :);
                    dataLabel = relativePathDataLabels{relativePathIdx};
                    thisDate = '';
                    varName = '';
                    complementaryLabel = ''; 
                    tmpFilePath = Tools.valueInTableForThisField( ...
                        myConfWOFilter.filePath, 'dataLabel', ...
                        dataLabel, 'webRelativeFilePathInJson');        
                    thatSubdivisionInfo.( ...
                        relativePathFieldNames{relativePathIdx}) = ...
                        thisEspEnv.replacePatternsInFileOrDirPaths(...
                            tmpFilePath, rootId, ...
                            dataLabel, thisDate, varName, complementaryLabel);
                end
                % If no geotiff is available, the region is not displayed.
                if ismember('variables', fieldnames(thatSubdivisionInfo))
                    subdivisionList.(rootIdWithT) = thatSubdivisionInfo;
                end
            end
            
            thisStruct = subdivisionList;
            dataLabel = 'landsubdivisionrootinjson';
            text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                outFilePath);
            rootSubdivisionTable(rootIdxToRemoveFromRootSubdivisionTable, :) = [];
            fprintf('%s: Done generating subdivision root file %s.\n', ...
                mfilename(), outFilePath);
        end
        function subdivisionTable = writeSubdivisionLinks(obj)
            % Generate two hierarchy files listing how subdivisions ( web regions) are
            % linked:
            % - one file for visualization of the full hierarchy, based on a format
            %   close to the regions.json format used in snow-today v2023.
            % - a mother-children file per root subdivision that will be exported to
            %   the website.
            %
            % Return
            % ------
            % subdivisionTable: table(). Contain the list of subdivisions in the
            %   hierarchy of each root subdivision. Used in .writeSubdivisionMetadata().
            %
            % [WARNING] sourceRegionName must be filled for used
            % landsubdivisionshapeingeojson
            % in configuration_of_landsubdivisions.csv,
            % because the following variables are filtered based on this to determine
            % the version of ancillary.                                         @warning
            %
            % NB: We don't have to remove the roots which don't have variables, because
            %   done above.
            %   Beware to keep this functionality if changing code organization.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            fprintf('%s: Start generating subdivision links files...\n', mfilename());
            
            myConfWOFilter = obj.espEnvWOFilter.myConf;
            subdivisionTable = myConfWOFilter.landsubdivision( ...
                myConfWOFilter.landsubdivision.used >= obj.toBeUsedFlag & ...
                myConfWOFilter.landsubdivision.root ~= 1, {'id', 'name', 'code', ...
                'subdivisionType', 'root', 'CRS'});
            subdivisionLinkTable = myConfWOFilter.landsubdivisionlink( ...
                myConfWOFilter.landsubdivisionlink.websiteDisplay >= ...
                obj.toBeUsedFlag, {'groupId', 'id'});
            subdivisionTable = innerjoin(subdivisionLinkTable, ...
                subdivisionTable, 'LeftKeys', 'id', 'RightKeys', 'id');
                % NB: generate error when sourceRegionName not correctly filled in 
                % configuration_of_landsubdivisions.csv.
                %
                % NB: there's a problem when I do join only, because there's no
                % correspondance between active subdivisions and active links.
                %                                                         @warning @todo

            subdivisionTree = struct(); % Stores all the hierarchy and metadata, all regions
                %in 1 file, for visualization by dev only.

            % Field to determine in which root subdivision file the subdivision should be.
            % NB: all root subdivision metadata are in the root .json file.
            subdivisionTable.rootId(:) = 0;

            % NB: Very ugly and dirty code with multiple imbricated loops :/
            % Maybe we could build a recursive function?                           @todo
            % rank1x, rank2x, rank3x store attributes for level 1, 2, 3 of the
            % hierarchy.
            % rank 2, 4, 6 codes are identic (with only variable names changing because
            % depend on rank (=level). Rank 1, 3, 5 codes are identic.
            rootSubdivisionTable = myConfWOFilter.landsubdivision( ...
                myConfWOFilter.landsubdivision.used >= obj.toBeUsedFlag & ...
                myConfWOFilter.landsubdivision.root == 1, ...
                {'id', 'name', 'code', 'subdivisionType', 'sourceRegionName', ...
                'root', 'CRS'});
            rootSubdivisionTable = sortrows(rootSubdivisionTable, 'name');
            for rank0Idx = 1:size(rootSubdivisionTable, 1)

                rank0Id = strcat('t', num2str(rootSubdivisionTable.id(rank0Idx)));
                    % Format the id with a t because struct fieldnames used below can't be numeric.
                subdivisionTree.(rank0Id) = ...
                    table2struct( ...
                    rootSubdivisionTable(rank0Idx, {'name', 'code', 'subdivisionType'}));

                rank2Data = subdivisionTable(subdivisionTable.groupId == ...
                    rootSubdivisionTable.id(rank0Idx), :);
                rank1Codes = unique(rank2Data.subdivisionType);
                rank1Data = myConfWOFilter.landsubdivisiontype( ...
                    ismember(myConfWOFilter.landsubdivisiontype.code, rank1Codes), :);
                rank1Tree = struct();

                webRank1Tree = struct(collections = struct()); % Stores the hierarchy of the current root region
                    % (rank0Idx), which will be saved for use in the website.

                for rank1Idx = 1:size(rank1Data, 1)

                    rank1Id = rank1Data.code{rank1Idx};
                    rank1Tree.(rank1Id) = struct(name = rank1Data.name{rank1Idx}, code = rank1Id);

                    webRank1Tree.collections.(rank1Id) = struct();

                    rank2IndicesInsubdivisionTable = subdivisionTable.groupId == ...
                        rootSubdivisionTable.id(rank0Idx) & ...
                        strcmp(subdivisionTable.subdivisionType, rank1Data.code{rank1Idx});
                    subdivisionTable(rank2IndicesInsubdivisionTable, :).rootId = ...
                        repelem(rootSubdivisionTable.id(rank0Idx), ...
                        sum(rank2IndicesInsubdivisionTable))';

                    rank2Data = subdivisionTable(rank2IndicesInsubdivisionTable, :);
                    rank2Tree = struct();
                    webRank2Tree = struct();

                    for rank2Idx = 1:size(rank2Data, 1)
                        rank2Id = strcat('t', num2str(rank2Data.id(rank2Idx)));
                        rank2Tree.(rank2Id) = ...
                            table2struct(rank2Data(rank2Idx, {'name', 'code', 'subdivisionType'}));

                        webRank2Tree.(rank2Id) = table2struct(rank2Data(rank2Idx, {'code'}));

                        rank4Data = subdivisionTable(subdivisionTable.groupId == ...
                            rank2Data.id(rank2Idx), :);
                        rank3Codes = unique(rank4Data.subdivisionType);
                        rank3Data = myConfWOFilter.landsubdivisiontype( ...
                            ismember(myConfWOFilter.landsubdivisiontype.code, rank3Codes), :);
                        rank3Tree = struct();
                        webRank3Tree = struct();

                        for rank3Idx = 1:size(rank3Data, 1)
                            rank3Id = rank3Data.code{rank3Idx};
                            rank3Tree.(rank3Id) = ...
                                struct(name = rank3Data.name{rank3Idx}, code = rank3Id);

                            webRank3Tree.collections.(rank3Id) = struct();

                            rank4IndicesInsubdivisionTable = ...
                                subdivisionTable.groupId == rank2Data.id(rank2Idx) & ...
                                strcmp(subdivisionTable.subdivisionType, rank3Data.code{rank3Idx});
                            subdivisionTable(rank4IndicesInsubdivisionTable, :).rootId = ...
                                repelem(rootSubdivisionTable.id(rank0Idx), ...
                                sum(rank4IndicesInsubdivisionTable))';

                            rank4Data = subdivisionTable(rank4IndicesInsubdivisionTable, :);
                            rank4Tree = struct();
                            webRank4Tree = struct();

                            for rank4Idx = 1:size(rank4Data, 1)
                                rank4Id = strcat('t', num2str(rank4Data.id(rank4Idx)));
                                rank4Tree.(rank4Id) = ...
                                    table2struct( ...
                                    rank4Data(rank4Idx, {'name', 'code', 'subdivisionType'}));
                                webRank4Tree.(rank4Id) = ...
                                    table2struct(rank4Data(rank4Idx, {'code'}));

                                webSubdivisionTree.(rank0Id).children. ...
                                    (rank2Id).children.(rank4Id) = struct();

                                rank6Data = subdivisionTable( ...
                                    subdivisionTable.groupId == rank4Data.id(rank4Idx), :);
                                rank5Codes = unique(rank6Data.subdivisionType);
                                rank5Data = myConfWOFilter.landsubdivisiontype( ...
                                    ismember(myConfWOFilter.landsubdivisiontype.code, rank5Codes), :);
                                rank5Tree = struct();
                                webRank5Tree = struct();

                                for rank5Idx = 1:size(rank5Data, 1)
                                    rank5Id = rank5Data.code{rank5Idx};
                                    rank5Tree.(rank5Id) = ...
                                        struct(name = rank5Data.name{rank5Idx}, code = rank5Id);

                                    webRank5Tree.collections.(rank5Id) = struct();

                                    rank6IndicesInsubdivisionTable = ...
                                        subdivisionTable.groupId == rank4Data.id(rank4Idx) & ...
                                        strcmp(subdivisionTable.subdivisionType, ...
                                        rank5Data.code{rank5Idx});
                                    subdivisionTable(rank6IndicesInsubdivisionTable, :).rootId = ...
                                        repelem(rootSubdivisionTable.id(rank0Idx), ...
                                        sum(rank6IndicesInsubdivisionTable))';

                                    rank6Data = subdivisionTable(rank6IndicesInsubdivisionTable, :);
                                    rank6Tree = struct();
                                    webRank6Tree = struct();

                                    for rank6Idx = 1:size(rank6Data, 1)
                                        rank6Id = strcat('t', num2str(rank6Data.id(rank6Idx)));
                                        rank6Tree.(rank6Id) = ...
                                            table2struct(rank6Data(rank6Idx, ...
                                            {'name', 'code', 'subdivisionType'}));

                                        webRank6Tree.(rank6Id) = struct();
                                    end % rank 6
                                    rank5Tree.(rank5Id).items = rank6Tree;
                                    webRank5Tree.collections.(rank5Id).items = webRank6Tree;
                                end % rank 5
                                rank4Tree.(rank4Id).subregion_collections = rank5Tree;
                                webRank4Tree.(rank4Id) = webRank5Tree;
                            end % rank4
                            rank3Tree.(rank3Id).items = rank4Tree;
                            webRank3Tree.collections.(rank3Id).items = webRank4Tree;
                        end % rank3
                        rank2Tree.(rank2Id).subregion_collections = rank3Tree;
                        webRank2Tree.(rank2Id) = webRank3Tree;
                    end % rank2
                    rank1Tree.(rank1Id).items = rank2Tree;
                    webRank1Tree.collections.(rank1Id).items = webRank2Tree;
                end % rank1
                subdivisionTree.(rank0Id).subregion_collections = rank1Tree;

                % Save the mother-children hierarchy in 1 file for the current root subdivision (
                % (= region).
                % NB: we instantiate the modisData/espEnv corresponding to the versionOfAncillary
                % of the source region to store this file in the correct version subfolder of
                % modis_ancillary.
                thisVersionOfAncillary = ...
                    myConfWOFilter.region(strcmp(myConfWOFilter.region.name, ...
                    rootSubdivisionTable.sourceRegionName{rank0Idx}), :). ...
                    versionOfAncillary{1};
                thisModisData = MODISData(label = ...
                    obj.espEnvWOFilter.modisData.versionOf.VariablesGeotiff, ...
                    versionOfAncillary = thisVersionOfAncillary);
                thisEspEnv = ESPEnv(modisData = thisModisData, ...
                    scratchPath = obj.espEnvWOFilter.scratchPath);
                
                thisStruct = webRank1Tree;
                objectName = rootSubdivisionTable.id(rank0Idx);
                dataLabel = 'landsubdivisionlinkinjson';
                outFilePath = thisEspEnv.getFilePathForObjectNameDataLabel( ...
                    objectName, dataLabel);
                
                text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                    outFilePath);
                fprintf('%s: Done generating subdivision link file %s.\n', ...
                    mfilename(), outFilePath);
            end % rank0

            % Save the visualization file.
            thisStruct = subdivisionTree;
            dataLabel = 'landsubdivisionlinkvisualization';
            outFilePath = obj.espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
                '', dataLabel);
            text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                outFilePath);

            fprintf('%s: Done generating subdivision link visualization file %s.\n', ...
                mfilename(), outFilePath);
        end
        function writeSubdivisionMetadata(obj, subdivisionTable)
            % Generate the subdivision list and metadata file for each root subdivision.
            %
            % Parameters
            % ----------
            % subdivisionTable: table. Should be previously obtained by 
            %   .writeSubdivisionLinks(). Contain the list of subdivisions in the
            %   hierarchy of each root subdivision.
            %  
            % NB: most hydroshed subdivisions don't have a name and we attribute one
            % standard name.
            % NB: We don't have to remove the roots which don't have variables, because
            %   done above.
            %   Beware to keep this functionality if changing code organization.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            relativePathDataLabels = { ...
                'landsubdivisionshapeingeojson', 'SubdivisionStatsWebJson'};
            relativePathFieldNames = { ...
                'shapefileRelativePath'}; %, 'variablePlotRelativePaths'};         TEMPORARY 2024-02-22 WAIT MATT MODIF SCHEMA @todo
            fieldList = {'name', 'code'};
            if obj.includeSubdivisionTypeInJson
                fieldList = {'name', 'code', 'subdivisionType'};
            end % this is for debug only, the schema doesn't accept subdivisionType.
            
            fprintf('%s: Start generating subdivision links files...\n', mfilename());

            myConfWOFilter = obj.espEnvWOFilter.myConf;
            rootSubdivisionTable = myConfWOFilter.landsubdivision( ...
                myConfWOFilter.landsubdivision.used >= obj.toBeUsedFlag & ...
                myConfWOFilter.landsubdivision.root == 1, ...
                {'id', 'name', 'code', 'subdivisionType', 'sourceRegionName', ...
                'root', 'CRS'});
            rootSubdivisionTable = sortrows(rootSubdivisionTable, 'name');
            
            for rootIdx = 1:size(rootSubdivisionTable, 1)
                subdivisionList = struct();
                subdivisionsInSubdivisionTableForRootId = ...
                    subdivisionTable( ...
                        subdivisionTable.rootId == rootSubdivisionTable.id(rootIdx), :);
                
                % Get the list of variables associated to the root subdivision.  
                regionVarConf = myConfWOFilter.variableregion( ...
                    strcmp(myConfWOFilter.variableregion.regionName, ...
                    rootSubdivisionTable.sourceRegionName{rootIdx}) & ...
                    (myConfWOFilter.variableregion.writeGeotiffs == 1 & ...
                     myConfWOFilter.variableregion.writeStats == 1), {'varId'});

                for subdivisionIdx = 1:size(subdivisionsInSubdivisionTableForRootId, 1)
                    subdivisionId = ...
                        subdivisionsInSubdivisionTableForRootId.id(subdivisionIdx);
                    subdivisionIdWithT = strcat('t', num2str(subdivisionId));
                        % Format the id with a t because struct fieldnames used below
                        % can't be numeric.
                    subdivisionList.(subdivisionIdWithT) = ...
                        table2struct(subdivisionsInSubdivisionTableForRootId( ...
                            subdivisionIdx, fieldList));
                    if isempty(subdivisionList.(subdivisionIdWithT).name) & ...
                        strcmp(subdivisionList.(subdivisionIdWithT).code(1:3), 'HYD')
                        subdivisionList.(subdivisionIdWithT).name = ...
                            ['Catchment ', subdivisionList.(subdivisionIdWithT).code];
                    end
                    % include the relative path of shapefiles
                    relativePathIdx = 1;   
                    dataLabel = relativePathDataLabels{relativePathIdx};
                    thisDate = '';
                    varName = '';
                    complementaryLabel = ''; 
                    tmpFilePath = Tools.valueInTableForThisField( ...
                        myConfWOFilter.filePath, 'dataLabel', ...
                        dataLabel, 'webRelativeFilePathInJson');        
                    subdivisionList.(subdivisionIdWithT).( ...
                        relativePathFieldNames{relativePathIdx}) = ...
                        obj.espEnvWOFilter.replacePatternsInFileOrDirPaths(...
                            tmpFilePath, subdivisionId, ...
                            dataLabel, thisDate, varName, complementaryLabel);
                    
                    % include the relative path of plots for each available variable.
                    % Get the available variables for the root subdivision.   
                    regionVarConf = myConfWOFilter.variableregion( ...
                        strcmp(myConfWOFilter.variableregion.regionName, ...
                        rootSubdivisionTable.sourceRegionName{rootIdx}) & ...
                        (myConfWOFilter.variableregion.writeGeotiffs == 1 & ...
                         myConfWOFilter.variableregion.writeStats == 1), {'varId'});
%{
TEMPORARY WAIT FOR MATT CHANGE VALIDATION SCHEMA 2024-02-22                        @todo
                    relativePathIdx = 2;
                    objectName = subdivisionId;
                    dataLabel = relativePathDataLabels{relativePathIdx};
                    thisDate = '';
                    complementaryLabel = '';
                    for varIdx = 1:size(regionVarConf, 1)
                        varName = regionVarConf.varId(varIdx);
                        tmpFilePath = Tools.valueInTableForThisField( ...
                            myConfWOFilter.filePath, 'dataLabel', ...
                            dataLabel, 'webRelativeFilePathInJson');    
                        subdivisionList.(subdivisionIdWithT).( ...
                            relativePathFieldNames{relativePathIdx}). ...
                            (['t', num2str(regionVarConf.varId(varIdx))]) = ...
                            obj.espEnvWOFilter.replacePatternsInFileOrDirPaths(...
                                tmpFilePath, subdivisionId, ...
                                dataLabel, thisDate, varName, complementaryLabel);
                    end
%}
                end
                % NB: we instantiate the modisData/espEnv corresponding to the
                % versionOfAncillary of the source region to store this file in the
                % correct version subfolder of modis_ancillary.
                thisVersionOfAncillary = ...
                    myConfWOFilter.region(strcmp(myConfWOFilter.region.name, ...
                    rootSubdivisionTable.sourceRegionName{rootIdx}), :). ...
                    versionOfAncillary{1};
                thisModisData = MODISData(label = ...
                    obj.espEnvWOFilter.modisData.versionOf.VariablesGeotiff, ...
                    versionOfAncillary = thisVersionOfAncillary);
                thisEspEnv = ESPEnv(modisData = thisModisData, ...
                    scratchPath = obj.espEnvWOFilter.scratchPath);
                
                thisStruct = subdivisionList;
                dataLabel = 'landsubdivisioninjson';
                objectName = rootSubdivisionTable.id(rootIdx);
                outFilePath = thisEspEnv.getFilePathForObjectNameDataLabel( ...
                    objectName, dataLabel);
                
                text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                    outFilePath);

                fprintf('%s: Done generating subdivision metadata file %s.\n', ...
                    mfilename(), outFilePath);
            end
        end
        function writeSubdivisionTypes(obj)
            % Generate the subdivision type conf file (1 file only).
            % NB: subdivision type is called region category in the web-app.
            dataLabel = 'landsubdivisiontypeinjson';
            outFilePath = obj.espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
                '', dataLabel);
                % NB: no version in the path, see configuration_of_filepaths.csv.
            fprintf('%s: Start generating subdivision types file %s...\n', ...
                mfilename(), outFilePath);
            tmpLandSubdivisionType = obj.espEnvWOFilter.myConf.landsubdivisiontype;
            tmpLandSubdivisionType.name2 = tmpLandSubdivisionType.name; 
                % json schema requires 2 names
                
            subdivisionType = struct();
            for typeIdx = 1:size(tmpLandSubdivisionType, 1)
                typeCode = tmpLandSubdivisionType.code{typeIdx};
                subdivisionType.(typeCode) = ...
                    table2struct(tmpLandSubdivisionType(typeIdx, {'name', 'name2'}));
            end
            thisStruct = subdivisionType;
            text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                outFilePath);

            fprintf('%s: Done generating subdivision types file %s.\n', ...
                mfilename(), outFilePath);
        end
        function writeVariables(obj)
            % Generate the variable conf file (1 file only).
            % NB: may be stored in the github rather than sent everyday         @tocheck
            %
            % NB: The output file is stored in
            % https://github.com/nsidc/snow-today-webapp-server/blob/main/static/snow-surface-properties/variables.json
            % and should be formatted with pretty. 
            % Current version includes labelPlotYAxis instead of labelPlotYaxis
            % and colormapId for not_processed are 0 instead of 7 (but it should be 0?)
            %                                                                      @todo
            dataLabel = 'webvariableconfinjson';
            outFilePath = obj.espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
                '', dataLabel);
                % NB: no version in the path, see configuration_of_filepaths.csv.
            fprintf('%s: Start generating variables conf file %s...\n', ...
                mfilename(), outFilePath);
                
            webVarConf = obj.espEnvWOFilter.myConf.variable( ...
                obj.espEnvWOFilter.myConf.variable.web_ispresent == 1, :);
            webVarConf = sortrows(webVarConf, 'id');
            varList = struct();
            for varIdx = 1:size(webVarConf, 1)
                varList.(['t', num2str(webVarConf(varIdx, :).id)]) = ...
                    table2struct(webVarConf(varIdx, ...
                    {'sensor', 'platform', 'algorithm', 'web_layer_type', ...
                    'web_longname', ...
                    'web_longnameplot', 'web_label_map_legend',	...
                    'web_label_plot_yaxis', ...
                    'web_helptext', 'web_value_precision', 'web_colormap_id', ...
                    'web_transparent_zero',	'web_sensor_text', 'nodata_value'}));
                varList.(['t', num2str(webVarConf(varIdx, :).id)]).value_range = ...
                    [webVarConf(varIdx, :).min, webVarConf(varIdx, :).max];
            end
            thisStruct = varList;
            text = obj.getAndWriteJsonFromStruct(thisStruct, dataLabel, ...
                outFilePath);
            fprintf('%s: Done generating variables conf file %s.\n', ...
                mfilename(), outFilePath);
        end
    end
end
