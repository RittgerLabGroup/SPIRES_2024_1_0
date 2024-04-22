%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generation of individual .geojson shapefiles for each subdivision, that will be
% exported to snow-today website.
%
% Launch this script after generating the .geojson shapefiles for each subdivision type
% using QGIS 3 (QGIS 3.28 2023-10-16). Each subdivision type .geojson contains all
% subdivision features/polygons for the subdivision
% type (e.g. 1 .geojson for all adm0 on Earth). The .geojson should be placed in
% {scratch_path}/modis_ancillary/{subFolderOfSubdivisionTypeGeojsonFiles}.
%
% The script extracts each subdivision feature/polygon from each .geojson and save it in
% an individual .geojson per subdivision stored in a tree defined in
% configuration_of_filepaths, with
% subfolders depending on the versionOfAncillary v3.1/v3.2 and the thousand part of the
% subdivisionId (to limit to 1,000 max files per folder). E.g.:
% 'modis_ancillary/v3.1/landsubdivisionshape/26/26000_202309.geojson'
%
% NB: the subdivisions that are not attached to a sourceRegion in
% configuration_of_subdivisions.csv won't be extracted into a .geojson.
% NB: reminder, the diff between v3.1 (westernUS) and v3.2 (all others) is that the
% ancilly water/land and other modis tiles were generated in a very slightly different
% way (projection).

% 1. Parameters to change if necessary.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
uncondensedGeojsn = 0; % if 0, condense the geojsn files by removing new lines/spaces.
versionLabel = 'v2023.1'; % Not used, but necessary to instantiate espEnv
versionOfAncillary = 'v3.1'; % This is not used to save each subdivision shapefile,
    % another espEnv with the versionOfAncillary of the source region is used.

subFolderOfSubdivisionTypeGeojsonFiles = 'landsubdivision';

% 2. Initialize and get the list of big .geojson files.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

modisData = MODISData(label = versionLabel, versionOfAncillary = versionOfAncillary);
espEnv = ESPEnv(modisData = modisData, scratchPath = getenv('espScratchDir'));

% Get the subdivision names and source regions (to get ancillary version) and
% the hierarchy from the configuration.
espEnv.setAdditionalConf('landsubdivision');
espEnv.setAdditionalConf('landsubdivisiontype');
myConf = espEnv.myConf;

subdivisionTypeGeojsonDirPath = fullfile(espEnv.scratchPath, 'modis_ancillary', ...
    subFolderOfSubdivisionTypeGeojsonFiles);
        % Path of the subdivision type .geojson generated using QGIS 3.28,
        % which have all subdivisions for a certain subdivision type.
subdivisionTypeGeojsonFilePaths = struct2table(dir(subdivisionTypeGeojsonDirPath));

% 3. For each subdi, Extract the geojson for each subdivision and
% subdivision type and then save it in its own .geojsn file, with coordinate precision
% round to units (precision 0).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for subdivisionTypeIdx = 1:size(subdivisionTypeGeojsonFilePaths, 1)
    fileName = subdivisionTypeGeojsonFilePaths(subdivisionTypeIdx, :).name{1};
    if length(fileName) < 8 || sum(fileName(end-7:end) ~= '.geojson')
        continue;
    end
    % Extract the geojson in a struct. Include a reduction of coordinate precision
    % from 15 to 0 (done by regexp because once in struct, the coordinates are a mix
    % of doubles, cells of doubles, cells of cells of doubles :/
    thisSubdivisionTypeGeojson = fileread( ...
        fullfile(subdivisionTypeGeojsonFilePaths(subdivisionTypeIdx, :).folder{1}, ...
            fileName));
    thisSubdivisionTypeGeojson = jsondecode(thisSubdivisionTypeGeojson);

    % For each subdivision with a source Region (e.g. westernUS),
    % Extract the subdivision shape and save it in an individual .geojsn
    for subdivisionIdx = 1:size(thisSubdivisionTypeGeojson.features, 1)
        thisSubdivisionFeature = thisSubdivisionTypeGeojson.features(subdivisionIdx);
        theseCoordinates = thisSubdivisionFeature.geometry.coordinates;
        subdivisionId = thisSubdivisionFeature.properties.snowtod_id;
        regionName = myConf.landsubdivision( ...
            myConf.landsubdivision.id == subdivisionId, :).sourceRegionName;
        if isempty(regionName) | isempty(regionName{1})
            continue;
        else
            regionName = regionName{1};
        end
        
        if strcmp(class(theseCoordinates), 'cell')
            % we try the same comparision cell or double on each of the cell 
            % coordinates (kind of recursive function, no time to implement it)
            for coordinateCellIdx = 1:size(theseCoordinates, 1);
                if strcmp(class(theseCoordinates{coordinateCellIdx, 1}), 'cell')                
                    theseCoordinates{coordinateCellIdx, 1} = ...
                        cellfun(@int64, cellfun(@round, ...
                       theseCoordinates{coordinateCellIdx, 1}, 'UniformOutput', ...
                        false), 'UniformOutput', false); 
                        % this may not work because coordinates are a mix of cells, 
                        % doubles, cells of cells.
                else
                    theseCoordinates{coordinateCellIdx, 1} = ...
                        int64(round(theseCoordinates{coordinateCellIdx, 1}));
                end
            end
        else % class double, I guess, but are some cases different? 20231017
            theseCoordinates = int64(round(theseCoordinates));
        end
        thisSubdivisionGeojson = struct(type = thisSubdivisionTypeGeojson.type, ...
            crs = thisSubdivisionTypeGeojson.crs, ...
            features = [struct(type = 'Feature', ...
                properties = struct( ...
                id = thisSubdivisionFeature.properties.snowtod_id), ...
            geometry = struct(type = 'MultiPolygon', ...
            coordinates = theseCoordinates))]);
            % make coordinates precision = 0 rather than 15
            % (precision will still be at the meter ...) to lower file size
            % NB: convert to int64 to avoid that jsonencode format coordinates to
            % scientific notation (which increases file size).
        thisSubdivisionGeojson = replace(jsonencode(thisSubdivisionGeojson, ...
            PrettyPrint= logical(uncondensedGeojsn)), '  ', '    ');
        thisSubdivisionGeojson = regexprep(thisSubdivisionGeojson, ...
            ['"features":{"type":"Feature","properties":{"id":([0-9]*)},', ...
            '"geometry":{"type":"MultiPolygon","coordinates":([\[\],0-9]*)}}}'], ...
            ['"features":[{"type":"Feature","properties":{"id":$1},', ...
            '"geometry":{"type":"MultiPolygon","coordinates":$2}}]}']);
            % We force the format into an array of features (matlab/jsonencode cannot do
            % that because an array with one element is translated to an element only.
        
        thisEspEnv = ESPEnv.getESPEnvForRegionNameAndVersionLabel(regionName, ...
            versionLabel, scratchPath); % to allow to store the geojson in the correct
                % version v3.1/v3.2 directory.
                % Reminder: the geojson are only different because the initial land
                % modis tiles were generated very slightly differently between v3.1 and
                % v3.2
        outFilePath = thisEspEnv.getFilePathForObjectNameDataLabel( ...
            subdivisionId, 'landsubdivisionshapeingeojson');
        fileResource = fopen(outFilePath, 'w');
        fprintf(fileResource, thisSubdivisionGeojson);
        fclose(fileResource);
    end % subdivisionIdx
end %subdivisionTypeIdx


% To remove the decimals I also tried 2023-10-17:
% thisSubdivisionTypeGeojson = regexprep(thisSubdivisionTypeGeojson, ...
%    '\[ ([0-9])+\.[0-9]+, ([0-9])+\.[0-9]+ \]', '[$1, $2]');
