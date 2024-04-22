%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generation of the subdivision tile geotiffs for subdivision types amd0part and
% adm1part, derived from existing subdivision tile geotiffs types adm0 and adm1.
% 
% Adm0part and adm1part subdivisions are derived from adm0 and adm1 subdivisions masked
%   by the available tiles. E.g. Argentina (adm0) will produce WArgentina (adm0part) 
%   because no modis tiles are available in east Argentina.
%
% NB: We assume that adm0part are only sourced from adm0 and adm1part only sourced from
%   adm1.
% 
% geojson shapefiles for each subdivision, that
% will be exported to snow-today website.
%
% NB: Should be run after the generation of the subdivision modis tiles using
%   qgis_get_landsubdivision_modis_tile.model3 (see readme here:                @tofindandfill !!!!! 
%
% NB: Zero is the nodata value in these subdivision tile geotiffs.
%
% Input: 
%   - each subdivision modis .tif tile for version of ancillary v3.1 and v3.2, and
%       subdivision type adm0 and adm1
%   - subdivision metadata in configuration_of_landsubdivision.csv and 
%       configuration_of_landsubdivisions.csv
%
% Output:
%   - subdivision modis tiles .tif for both versions of ancillary and for subdivision
%       types amd0part and adm1part (same projection as input, modis sinusoidal).

toBeUsedFlag = 2; % We temporarily use this value of 2 to limit the number of
    % subdivisions, but for launch and having all subdivisions, we have to update
    % configuration_of_landsubdivisions.csv and
    % configuration_of_landsubdivisionlinks.csv to 1 and update toBeUsedFlag to 1 too.
versionOfAncillarys = {'v3.1', 'v3.2'}';
sourceSubdivisionTypes = {'adm0', 'adm1'}';
subdivisionTypesToGenerate = {'adm0part', 'adm1part'}';

% Scratch path, distinct if on alpine supercomputer, personal laptop windows or linux.
% NB: Change this into a function, and use an environment variable, to protect the
%   adresses from external people                                                  @todo
[~, name] = system('hostname');
if (contains(name, ["rc.int", "bnode"]))
    scratchPath = ESPEnv.defaultScratchPath;
else
    if ~isempty(getenv('USERNAME'))
        scratchPath = ['C:\Users\', getenv('USERNAME'), '\Documents\Tmp_data'];
    else
        scratchPath = ['/home/', getenv('USER'), '/Tmp_data']; % Not sure it works for linux?
    end
end

% For each version of ancillary, calculate the subdivision modis tiles for the
% subdivision types to generate.
for versionOfAncillaryIdx = 1:size(versionOfAncillarys, 1)
    % Initialize the configuration ...
    fprintf('%: Initialize version of ancillary %s', ...
         mfilename(), versionOfAncillarys{versionOfAncillaryIdx});
    modisData = MODISData(label = 'v2023.1', ...
        versionOfAncillary = versionOfAncillarys{versionOfAncillaryIdx});
    espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath);
    % Get the subdivision names and the hierarchy from the configuation
    espEnv.setAdditionalConf('landsubdivision');
    espEnv.setAdditionalConf('landsubdivisionlink');
    myConf = espEnv.myConf;
    tileNames = myConf.region(strcmp(myConf.region.type, 'modisTile') & ...
            strcmp(myConf.region.versionOfAncillary, ...
            versionOfAncillarys{versionOfAncillaryIdx}), :).name; % modis tiles
                % available for this version of ancillary, for each one should exist
                % a tile of subdivision for each subdivision type.
    
    % Table of subdivisions to generate with source subdivisionTypes. e.g. source of 
    % adm0part is adm0.
    subdivisionsToGenerate = myConf.landsubdivision( ...
        myConf.landsubdivision.used == toBeUsedFlag & ...
        ismember(myConf.landsubdivision.subdivisionType, ...
        subdivisionTypesToGenerate), {'id', 'name', 'subdivisionType'});
    subdivisionsToGenerate = innerjoin(subdivisionsToGenerate, ...
        myConf.landsubdivisionlink(:, {'id', 'groupId'}), ...
        'LeftKeys', 'id', 'RightKeys', 'id');
    admpart = subdivisionsToGenerate;
    adm = myConf.landsubdivision( ...
        ismember(myConf.landsubdivision.subdivisionType, sourceSubdivisionTypes), ...
        {'id', 'name', 'subdivisionType'});
        % copy of these tables, the name of the table variable is concatenated in the
        % field names of the table join result below.
    subdivisionsToGenerate = innerjoin(admpart, ...
        adm, 'LeftKeys', 'groupId', 'RightKeys', 'id');
    
    % Generate the subdivision type modis tiles for each type.
    % NB: we assume adm0part only sourced from adm0 and adm1part only sourced from adm1.
    for sourceSubdivisionTypeIdx = 1:size(sourceSubdivisionTypes, 1)
        fprintf('%: Handle subdivision type %s', ...
             mfilename(), sourceSubdivisionTypes{sourceSubdivisionTypeIdx});
        versionOfAncillarys{versionOfAncillaryIdx});
        theseSubdivisionsToGenerate = subdivisionsToGenerate( ...
            strcmp(subdivisionsToGenerate.subdivisionType_adm, ...
            sourceSubdivisionTypes{sourceSubdivisionTypeIdx}), :);
        % Get the source data for each tile, replace the source subdivision ids by the
        % destination subdivision ids and save the result in the destination subdivision
        % type folder.
        for tileIdx = 1:size(tileNames, 1)
            [sourceFilePath, fileExists] = espEnv.getFilePathForObjectNameDataLabel( ...
                tileNames{tileIdx}, ['landsubdivision', ...
                sourceSubdivisionTypes{sourceSubdivisionTypeIdx}]);
            if ~fileExists
                continue;
            end
            [data, mapCellsReference] = readgeoraster(sourceFilePath);
                % Uint32, with zero: No data value.
            subdivisionIdToReplaceByZero = unique(data);
            subdivisionIdToReplaceByZero = subdivisionIdToReplaceByZero( ...
                subdivisionIdToReplaceByZero ~= 0 & ...
                ~ismember(subdivisionIdToReplaceByZero, ...
                theseSubdivisionsToGenerate.groupId));
            replacingZeros = zeros([size(subdivisionIdToReplaceByZero), 1], ...
                class(data));
            data = changem(data, [theseSubdivisionsToGenerate.id; ...
                replacingZeros], [theseSubdivisionsToGenerate.groupId; ...
                subdivisionIdToReplaceByZero]); 
                % changem weird, new value argument before old value.
            
            [outFilePath, ~] = espEnv.getFilePathForObjectNameDataLabel( ...
                tileNames{tileIdx}, ['landsubdivision', ...
                subdivisionTypesToGenerate{sourceSubdivisionTypeIdx}]);
            geotiffwrite(outFilePath, ...
                data, ...
                mapCellsReference, ...
                GeoKeyDirectoryTag = ...
                        modisData.projection.modisSinusoidal.geoKeyDirectoryTag, ...
                TiffTags = struct('Compression', 'LZW'));
            fprintf('%: Saved subdivision type modis tile %s', ...
                mfilename(), outFilePath);
        end
    end    
end
