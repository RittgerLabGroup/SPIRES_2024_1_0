%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generation of all "region" and "variable" .json files for each subdivision, that will
% be exported to snow-today website.
%
% NB: landSubdivision = subdivision = region for snow-today website, different object
% from the ESPEnv Region object; this latter handles the tiles and the group of tiles 
% imported and upon which the STC pipeline is executed. Beware because you have some
% Regions which have the same name as some subdivisions (= region for the website), e.g.
% "westernUS".
% NB: subdivision type = region category for snow-today website.
%
% Rules:
% - the root subdivision won't be included in the root .json if no variable are visible
%   for the associated big region (determined from
%   configuration_of_variablesvyregions.csv.
% - the root subdivision is included in the root .json even if no children are
%   associated to the root subdivision.
%
% Input:
%   - configuration_of_landsubdivisions.csv: list of all subdivisions and metadata,
%       including names and if it is used in the website.
%   - configuration_of_landsubdivisionlinks.csv: defines the hierarchy of subdivisions,
%       that is a list of all mother-child subdivision associations.
%   - configuration_of_landsubdivisiontypes.csv: list of types of subdivisions and their
%       names.

% 1. Parameters to change if necessary.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
toBeUsedFlag = 2; % We temporarily use this value of 2 to limit the number of
    % subdivisions, but for launch and having all subdivisions, we have to update
    % configuration_of_landsubdivisions.csv and
    % configuration_of_landsubdivisionlinks.csv to 1 and update toBeUsedFlag to 1 too.
uncondensedGeojsn = 1; % if 0, condense the geojsn files by removing new lines/spaces.
includeSubdivisionTypeInJson = 0; % if 1, include the subdivision type in root and region
    % json files.
versionLabel = 'v2023.1'; % Not used, but necessary to instantiate espEnv
versionOfAncillary = 'v3.1'; % This is not used to save each subdivision shapefile,
    % another espEnv with the versionOfAncillary of the source region is used.
lastDateWithData = datetime(2023, 4, 3); % to force the date to a date for which we have
    % something to display for both hemisphere.
    % NB: should be removed in production                                          @todo
scratchPath = getenv('espArchiveDir');

% 2. Initialize ...
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

modisData = MODISData(label = versionLabel, versionOfAncillary = versionOfAncillary);
espEnvWOFilter = ESPEnv(modisData = modisData, scratchPath = scratchPath, ...
    filterMyConfByVersionOfAncillary = 0);

% Get the subdivision names and source regions (to get ancillary version) and
% the hierarchy from the configuration.
espEnvWOFilter.setAdditionalConf('landsubdivision');
espEnvWOFilter.setAdditionalConf('landsubdivisionlink');
espEnvWOFilter.setAdditionalConf('landsubdivisiontype');
espEnvWOFilter.setAdditionalConf('webname');
myConfWOFilter = espEnvWOFilter.myConf;

% 3. Generate the subdivision type conf file (1 file only).
% NB: subdivision type is called region category in the web-app.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tmpLandSubdivisionType = myConfWOFilter.landsubdivisiontype;
tmpLandSubdivisionType.name2 = tmpLandSubdivisionType.name; 
    % json schema requires 2 names
    
subdivisionType = struct();
for typeIdx = 1:size(tmpLandSubdivisionType, 1)
    typeCode = tmpLandSubdivisionType.code{typeIdx};
    subdivisionType.(typeCode) = ...
        table2struct(tmpLandSubdivisionType(typeIdx, {'name', 'name2'}));
end
text = replace(jsonencode(subdivisionType, ...
    PrettyPrint = logical(uncondensedGeojsn)), '  ', '    ');
replaceValuesBy = espEnvWOFilter.myConf.webname( ...
    strcmp(espEnvWOFilter.myConf.webname.dataLabel, 'landsubdivisiontypeinjson'), :);
text = replace(text, ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.backendName, 'UniformOutput', false), ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.webName, 'UniformOutput', false));
outFilePath = espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
    '', 'landsubdivisiontypeinjson');
    % NB: no version in the path, see configuration_of_filepaths.csv.
fileResource = fopen(outFilePath, 'w');
fprintf(fileResource, text);
fclose(fileResource);

% 3b. Generate the variable conf file (1 file only).
%   NB: may be stored in the github rather than sent everyday                   @tocheck
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
webVarConf = myConfWOFilter.variable(myConfWOFilter.variable.web_ispresent == 1, :);
varList = struct();
for varIdx = 1:size(webVarConf, 1)
    varList.(['t', num2str(webVarConf(varIdx, :).id)]) = ...
        table2struct(webVarConf(varIdx, ...
        {'sensor', 'platform', 'algorithm', 'web_layer_type', 'web_longname', ...
        'web_longnameplot', 'web_label_map_legend',	'web_label_plot_yaxis', ...
        'web_helptext', 'web_value_precision', 'web_colormap_id', ...
        'web_transparent_zero',	'web_sensor_text', 'nodata_value'}));
    varList.(['t', num2str(webVarConf(varIdx, :).id)]).value_range = ...
        [webVarConf(varIdx, :).min, webVarConf(varIdx, :).max];
end
text = replace(regexprep(jsonencode(varList, ...
    PrettyPrint = logical(uncondensedGeojsn)), ...
    '"t([0-9])+":', '"$1":'), {'  ', 'web_', '%', 'sensor_text'}, ...
    {'    ', '', '%%', 'source'});
    % Matlab: We escape the % special character, otherwise the text will be written
    % uncomplete in the file.
outFilePath = espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
    '', 'webvariableconfinjson');
    % NB: no version in the path, see configuration_of_filepaths.csv.
fileResource = fopen(outFilePath, 'w');
fprintf(fileResource, text);
fclose(fileResource);

% 4. Generate the root subdivision conf file (1 file only), listing metadata for root
% regions and the available variables.
% NB: subdivision is called region in the web-app.
% The website will use this to quickly display the list of root regions.
% NB: This file should be updated every day with the variable value range          @todo
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rootSubdivisionTable = myConfWOFilter.landsubdivision( ...
    myConfWOFilter.landsubdivision.used == toBeUsedFlag & ...
    myConfWOFilter.landsubdivision.root == 1, ...
    {'id', 'name', 'code', 'subdivisionType', 'sourceRegionName', 'root', 'CRS'});
rootSubdivisionTable = sortrows(rootSubdivisionTable, 'name');
subdivisionList = struct();
relativePathDataLabels = {'landsubdivisioninjson', 'landsubdivisionlinkinjson', ...
    'landsubdivisionshapeingeojson'};
relativePathFieldNames = {'subdivisionListAndMetadataRelativePath', ...
    'subdivisionHierarchyRelativePath', ...
    'shapefileRelativePath'};
fieldList = {'name', 'code', 'CRS'};
if includeSubdivisionTypeInJson
    fieldList = {'name', 'code', 'subdivisionType', 'CRS'};
end  % this is for debug only, the schema doesn't accept subdivisionType.

for rootIdx = 1:size(rootSubdivisionTable, 1)
    rootId = rootSubdivisionTable.id(rootIdx);
    rootIdWithT = strcat('t', num2str(rootId));
        % Format the id with a t because struct fieldnames used below can't be numeric.
        
    % Get the available variables for the root subdivision and if none available, don't
    % include this root subdivision in the .json file ...    
    regionVarConf = myConfWOFilter.variableregion( ...
        strcmp(myConfWOFilter.variableregion.regionName, ...
        rootSubdivisionTable.sourceRegionName{rootIdx}) & ...
        (myConfWOFilter.variableregion.writeGeotiffs == 1 & ...
         myConfWOFilter.variableregion.writeStats == 1), {'varId', 'isDefault'});
    % Here check if variables have actually geotiffs and stats data                @todo
    if isempty(regionVarConf)
        continue;
    end
    
    % Filling metadata of the root subdivision.
    subdivisionList.(rootIdWithT) = ...
        table2struct(rootSubdivisionTable(rootIdx, fieldList)); 
    
    % Water Year info.
    regionConf = myConfWOFilter.region(strcmp(myConfWOFilter.region.name, ...
        rootSubdivisionTable.sourceRegionName{rootIdx}), :);
    thisModisData = MODISData(label = versionLabel, versionOfAncillary = ...
        regionConf.versionOfAncillary{1});
    thisEspEnv = ESPEnv(modisData = thisModisData, ...
        scratchPath = espEnvWOFilter.scratchPath);
    region = Regions(regionConf.name{1}, [regionConf.name{1}, '_mask'], thisEspEnv, ...
        thisModisData);
    waterYearDate = WaterYearDate(datetime('today'), ...
        region.getFirstMonthOfWaterYear(), 0);
    subdivisionList.(rootIdWithT).waterYear = waterYearDate.getWaterYear();
    subdivisionList.(rootIdWithT).waterYearStartDate = ...
        convertStringsToChars( ...
            string(waterYearDate.getFirstDatetimeOfWaterYear(), 'yyyy-MM-dd'));
    subdivisionList.(rootIdWithT).lastDateWithData = string(lastDateWithData, ...
        'yyyy-MM-dd');
        % this date should be dynamic, depending on the stats and geotiffs !       @todo

    % Historic info.
    % NB: Should be dynamic and depend on real data                                @todo
    thisRegionConf = thisEspEnv.myConf.region( ...
        strcmp(thisEspEnv.myConf.region.name, ...
        rootSubdivisionTable.sourceRegionName{rootIdx}), :);
    subdivisionList.(rootIdWithT).historicStartWaterYear = ...
        thisRegionConf.historicStartWaterYear; 
            % 2027 for AMAndes, 2001 for other regions.
    subdivisionList.(rootIdWithT).historicSource = 'JPL modscag/drfs';
    
    % Get the variables and build the array of sensor sources for the
    % root subdivision.
    regionVarConf = join(regionVarConf, thisEspEnv.myConf.variable, ...
        LeftKeys = 'varId', ...
        RightKeys = 'id', LeftVariables = {'isDefault'}, ...
        RightVariables = {'id', 'output_name', 'nodata_value', 'web_longname', ...
        'web_colormap_value_min', 'web_colormap_value_max', 'web_sensor_text'});
    regionVarConf = sortrows(regionVarConf, {'web_sensor_text', 'web_longname'});
        % variables ordered by sensor/source names and variable names.
    sensorTexts = unique(regionVarConf.web_sensor_text);
    for sensorTextIdx = 1:length(sensorTexts)
        thisVarConf = regionVarConf(strcmp(regionVarConf.web_sensor_text, ...
            sensorTexts{sensorTextIdx}), :);
        subdivisionList.(rootIdWithT).sources.(['t', num2str(sensorTextIdx)]) = ...
            struct(source = sensorTexts{sensorTextIdx}, isDefault = 0);
        
        % Construct the array of variables within this sensor/source for the
        % root subdivision.
        % NB: Value range for each variable should be done dynamically from the
        % geotiff data for each variable, but the specs are to be clarified        @todo
        for varIdx = 1:size(thisVarConf, 1)
            varMetadata = table2struct(thisVarConf(varIdx, {'isDefault'}));
            
            % if one the variable is default one, set the sensor/source to default too.
            if varMetadata.isDefault == 1
                subdivisionList.(rootIdWithT).sources. ...
                    (['t', num2str(sensorTextIdx)]).isDefault = 1;
            end
            % Determine the max nb days for snow_cover_days variable.
            if thisVarConf.id(varIdx) == 45
                thisVarConf.web_colormap_value_max(varIdx) = 91; % 2023/4/1
                    % change this to dynamic !!!                                   @todo
            end
            varMetadata.colormap_value_range = ...
                [thisVarConf.web_colormap_value_min(varIdx), ...
                thisVarConf.web_colormap_value_max(varIdx)];
            
            % Geotiff relative paths in json.
            dataLabel = 'VariablesGeotiff';
            thisDate = '';
            varName = thisVarConf.output_name{varIdx};
            complementaryLabel = ['EPSG_', num2str(Regions.webGeotiffEPSG)]; 
            tmpFilePath = Tools.valueInTableForThisField( ...
                myConfWOFilter.filePath, 'dataLabel', ...
                dataLabel, 'webRelativeFilePathInJson');
            varMetadata.geotiffRelativePath = ...
                thisEspEnv.replacePatternsInFileOrDirPaths(...
                    tmpFilePath, rootId, ...
                    dataLabel, thisDate, varName, complementaryLabel);
                
            subdivisionList.(rootIdWithT).sources.(['t', num2str(sensorTextIdx)]). ...
                variables.(['t', num2str(thisVarConf.id(varIdx))]) = varMetadata;
        end
    end
        
    % Relative paths of ancillary files related to the current root subdivision:
    for relativePathIdx = 1:length(relativePathDataLabels)
        webFilePathConf = ...
            myConfWOFilter.filePath(strcmp(myConfWOFilter.filePath.dataLabel, ...
            relativePathDataLabels{relativePathIdx}), :);
        dataLabel = relativePathDataLabels{relativePathIdx};
        thisDate = '';
        varName = '';
        complementaryLabel = ''; 
        tmpFilePath = Tools.valueInTableForThisField( ...
            myConfWOFilter.filePath, 'dataLabel', ...
            dataLabel, 'webRelativeFilePathInJson');        
        subdivisionList.(rootIdWithT).(relativePathFieldNames{relativePathIdx}) = ...
            thisEspEnv.replacePatternsInFileOrDirPaths(...
                tmpFilePath, rootId, ...
                dataLabel, thisDate, varName, complementaryLabel);
    end
end
text = replace(regexprep(jsonencode(subdivisionList, ...
    PrettyPrint = logical(uncondensedGeojsn)), ...
    '"t([0-9])+":', '"$1":'), '  ', '    ');
replaceValuesBy = espEnvWOFilter.myConf.webname( ...
    strcmp(espEnvWOFilter.myConf.webname.dataLabel, 'landsubdivisionrootinjson'), :);
text = replace(text, ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.backendName, 'UniformOutput', false), ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.webName, 'UniformOutput', false));
outFilePath = espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
    '', 'landsubdivisionrootinjson');
    % NB: no version in the path, see configuration_of_filepaths.csv.
fileResource = fopen(outFilePath, 'w');
fprintf(fileResource, text);
fclose(fileResource);

% 5. Generate two hierarchy files listing how subdivisions ( web regions) are linked:
% - one file for visualization of the full hierarchy, based on a format close to
%   the regions.json format used in snow-today v2023.
% - a mother-children file per root subdivision that will be exported to the website.
%
% [WARNING] sourceRegionName must be filled for used landsubdivisionshapeingeojson
% in configuration_of_landsubdivisions.csv,
% because the following variables are filtered based on this to determine the version
% of ancillary.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

subdivisionTable = myConfWOFilter.landsubdivision( ...
    myConfWOFilter.landsubdivision.used == toBeUsedFlag & ...
    myConfWOFilter.landsubdivision.root ~= 1, {'id', 'name', 'code', ...
    'subdivisionType', 'root', 'CRS'});
subdivisionLinkTable = myConfWOFilter.landsubdivisionlink( ...
    myConfWOFilter.landsubdivisionlink.websiteDisplay == toBeUsedFlag, ...
    {'groupId', 'id'});
subdivisionTable = join(subdivisionLinkTable, ...
    subdivisionTable, 'LeftKeys', 'id', 'RightKeys', 'id');
    % NB: generate error when sourceRegionName not correctly filled in 
    % configuration_of_landsubdivisions.csv.

subdivisionTree = struct(); % Stores all the hierarchy and metadata, all regions
    %in 1 file, for visualization by dev only.

% Field to determine in which root subdivision file the subdivision should be.
% NB: all root subdivision metadata are in the root .json file.
subdivisionTable.rootId(:) = 0;

% NB: Very ugly and dirty code with multiple imbricated loops :/
% Maybe we could build a recursive function?                                       @todo
% rank1x, rank2x, rank3x store attributes for level 1, 2, 3 of the hierarchy.
% rank 2, 4, 6 codes are identic (with only variable names changing because depend
% on rank (=level). Rank 1, 3, 5 codes are identic.
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

    webRank1Tree = struct(); % Stores the hierarchy of the current root region
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
    text = replace(regexprep(jsonencode(webRank1Tree, ...
        PrettyPrint = logical(uncondensedGeojsn)), ...
        '"t([0-9])+":', '"$1":'), '  ', '    '); % pattern was initially '"t([0-9])+":'
        % to make keys actual integers, but matlab can't read integer keys (in the
        % improbable case we have to read the .json files. So I came back to string
        % keys. We reverse to the numeric id by removing the t.

    % replace some attribute names to fit web .json schema:
    text = replace(text, 'items', 'regions');
    thisVersionOfAncillary = ...
        myConfWOFilter.region(strcmp(myConfWOFilter.region.name, ...
        rootSubdivisionTable.sourceRegionName{rank0Idx}), :).versionOfAncillary{1};
    thisModisData = MODISData(label = versionLabel, ...
        versionOfAncillary = thisVersionOfAncillary);
    thisEspEnv = ESPEnv(modisData = thisModisData, ...
        scratchPath = scratchPath);
    outFilePath = thisEspEnv.getFilePathForObjectNameDataLabel( ...
        rootSubdivisionTable.id(rank0Idx), 'landsubdivisionlinkinjson');
    fileResource = fopen(outFilePath, 'w');
    fprintf(fileResource, text);
    fclose(fileResource);
end % rank0

% Save the visualization file.
text = replace(regexprep(jsonencode(subdivisionTree, PrettyPrint = true), ...
    '"t([0-9])+":', '"$1":'), '  ', '    ');
    % we reverse to the numeric id by removing the t.
fileResource = fopen(espEnvWOFilter.getFilePathForObjectNameDataLabel( ...
        '', 'landsubdivisionlinkvisualization') , 'w');
fprintf(fileResource, text);
fclose(fileResource);

% 6. Generate the subdivision list and metadata file for each root subdivision.
% NB: most hydroshed subdivisions don't have a name and we attribute one standard name.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fieldList = {'name', 'code'};
if includeSubdivisionTypeInJson
    fieldList = {'name', 'code', 'subdivisionType'};
end % this is for debug only, the schema doesn't accept subdivisionType.
for rootIdx = 1:size(rootSubdivisionTable, 1)
    subdivisionList = struct();
    subdivisionsInSubdivisionTableForRootId = ...
        subdivisionTable( ...
            subdivisionTable.rootId == rootSubdivisionTable.id(rootIdx), :);

    for subdivisionIdx = 1:size(subdivisionsInSubdivisionTableForRootId, 1)
        subdivisionId = subdivisionsInSubdivisionTableForRootId.id(subdivisionIdx);
        subdivisionIdWithT = strcat('t', num2str(subdivisionId));
            % Format the id with a t because struct fieldnames used below can't be numeric.
        subdivisionList.(subdivisionIdWithT) = ...
            table2struct(subdivisionsInSubdivisionTableForRootId( ...
                subdivisionIdx, fieldList));
        if isempty(subdivisionList.(subdivisionIdWithT).name) & ...
            strcmp(subdivisionList.(subdivisionIdWithT).code(1:3), 'HYD')
            subdivisionList.(subdivisionIdWithT).name = ...
                ['Catchment ', subdivisionList.(subdivisionIdWithT).code];
        end
        % include the relative path of shapefile.
        relativePathIdx = 3;        
        dataLabel = relativePathDataLabels{relativePathIdx};
        thisDate = '';
        varName = '';
        complementaryLabel = ''; 
        tmpFilePath = Tools.valueInTableForThisField( ...
            myConfWOFilter.filePath, 'dataLabel', ...
            dataLabel, 'webRelativeFilePathInJson');        
        subdivisionList.(subdivisionIdWithT).( ...
            relativePathFieldNames{relativePathIdx}) = ...
            thisEspEnv.replacePatternsInFileOrDirPaths(...
                tmpFilePath, subdivisionId, ...
                dataLabel, thisDate, varName, complementaryLabel);
    end

    text = replace(regexprep(jsonencode( ...
        subdivisionList, PrettyPrint = logical(uncondensedGeojsn)), ...
        '"t([0-9])+":', '"$1":'), '  ', '    ');
    replaceValuesBy = espEnvWOFilter.myConf.webname( ...
        strcmp(espEnvWOFilter.myConf.webname.dataLabel, ...
        'landsubdivisioninjson'), :);
    text = replace(text, ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.backendName, 'UniformOutput', false), ...
    cellfun(@(x) ['"',x, '"'], replaceValuesBy.webName, 'UniformOutput', false));

    % NB: we instantiate the modisData/espEnv corresponding to the versionOfAncillary
    % of the source region to store this file in the correct version subfolder of
    % modis_ancillary.
    thisVersionOfAncillary = ...
        myConfWOFilter.region(strcmp(myConfWOFilter.region.name, ...
        rootSubdivisionTable.sourceRegionName{rootIdx}), :).versionOfAncillary{1};
    thisModisData = MODISData(label = versionLabel, ...
        versionOfAncillary = thisVersionOfAncillary);
    thisEspEnv = ESPEnv(modisData = thisModisData, ...
        scratchPath = scratchPath);
    outFilePath = thisEspEnv.getFilePathForObjectNameDataLabel( ...
        rootSubdivisionTable.id(rootIdx), 'landsubdivisioninjson');

    fileResource = fopen(outFilePath, 'w');
    fprintf(fileResource, text);
    fclose(fileResource);
end


% 7. Generate the geotiffs for each variable and each region.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%scratchPath = ['/rc_scratch/', getenv('USER')]; % NB: to change                    @todo

% CODE TO CHANGE BECAUSE NOW SUBDIVISIONS ARE FILTERED BY VERSIONS !!!!!! 2023-11-16

scratchPath = ['/scratch/alpine/', getenv('USER')];
rootSubdivisionTable = myConfWOFilter.landsubdivision( ...
    myConfWOFilter.landsubdivision.used == toBeUsedFlag & ...
    myConfWOFilter.landsubdivision.root == 1, ...
    {'sourceRegionName'});
rootSubdivisionTable = unique(rootSubdivisionTable); 
    % e.g. USAlaska and WesternCanada have
    % the same source region.
% NB: change lastDateWithData with real date                                       @todo    
for rootIdx = 1:size(rootSubdivisionTable, 1)
    regionName = rootSubdivisionTable.sourceRegionName{rootIdx};
    thisEspEnv = ESPEnv.getESPEnvForRegionNameAndVersionLabel(regionName, ...
        versionLabel, scratchPath);
    region = Regions(regionName, [regionName, '_mask'], thisEspEnv, ...
        thisEspEnv.modisData);
%{
    % Uncomment when in production, to get the last day of data.
    mosaic = Mosaic(region);
    waterYearDate = WaterYearDate(mosaic.getMostRecentMosaicDt(waterYearDate), ...
    region.getFirstMonthOfWaterYear(), 0);
%}
    waterYearDate = WaterYearDate(lastDateWithData, ...
        region.getFirstMonthOfWaterYear(), 0);
    
    % Build tile/variable geotiff for each tile of the region...
    tileRegions = region.getTileRegions();
    for tileRegionIdx = 1:length(tileRegions)
        tileRegion = tileRegions(tileRegionIdx);
        tileRegion.writeGeotiffs(NaN, waterYearDate, Regions.webGeotiffEPSG);        
    end
    
    % Assemble the tiles into a geotiff of the big region for each required variable...
    % WARNING WARNING: don't execute this assemblage doesn't work (there's some lag in Andes and I don't know why.
    % So generate first the full big region mosaic, and then the geotiffs on the full region.
    theseVariables = ...
        region.myConf.variable(region.myConf.variable.writeGeotiffs == 1, :);
    for varIdx = 1:size(theseVariables, 1);
        varName = theseVariables.output_name{varIdx};
        region.buildTileSet('VariablesGeotiff', waterYearDate.thisDatetime, ...
            varName, Regions.webGeotiffEPSG);
    end
end