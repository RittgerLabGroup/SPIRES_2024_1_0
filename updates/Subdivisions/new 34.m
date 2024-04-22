% A QUOI CA SERT les fichiers csv de tiles par subdivision ?



% Parameters.
versionLabel = 'v2023.1'; % obligatory, but don't influence the final result.
versionOfAncillaries = {'v3.1', 'v3.2', 'test'}; % Used for saving the result table in the different version folders. Note that it will be the same table for the all versions and we do that because of the inner working of ESPEnv/MODISData ancillary file find.
allDataLabels = {'landsubdivisionadm0', 'landsubdivisionadm1', 'landsubdivisiongroup0', 'landsubdivisiongroupadm0', 'landsubdivisionhuc2', 'landsubdivisionhuc4', 'landsubdivisionhuc6', 'landsubdivisionhydrolevel3', 'landsubdivisionhydrolevel4', 'landsubdivisionhydrolevel5'}; % if new type of subdivision, add the new label here.
allRegionNames = {'h07v03', 'h08v03', 'h08v04', 'h08v05', 'h09v02', 'h09v03', 'h09v04', 'h09v05', 'h10v02', 'h10v03', 'h10v04', 'h10v09', 'h10v10', 'h11v02', 'h11v03', 'h11v10', 'h11v11', 'h11v12', 'h12v01', 'h12v02', 'h12v12', 'h12v13', 'h13v01', 'h13v02', 'h13v13', 'h13v14', 'h18v04', 'h19v04', 'h22v04', 'h22v05', 'h23v04', 'h23v05', 'h23v06', 'h24v04', 'h24v05', 'h24v06', 'h25v05', 'h25v06', 'h26v05', 'h26v06'}; % Add here a name of a modis tile when changing/adding subdivision or new region.

% Fields of final result table. This table list for each subdivision id (the id in 
% configuration_of_landsubdivisions.csv), its presence in the ancillary data of type
% dataLabel (type of landsubdivision) linked to the region name. For instance, there
% will be a row for landsubdivision id 12515, corresponding to Great Basin, present in
% region name h08v04 for dataLabel landsubdivisionhuc2. This means that to reconstruct
% the Great Basin, we need (among others) to load the ancillary file of type 
% landsubdivisionhuc2 linked to the tile h08v04 (in westernUS).
landSubdivisionId = []; % the id can be zero for pixel with nodata in the 
    % landsubdivision masks.
regionName = {};
dataLabel = {};

% Filling of the table fields based on unique values in the landsubdivision masks found
% for all region names and subdivision data labels.
for thisRegionIdx = 1:length(allRegionNames)
    thisRegionName = allRegionNames{thisRegionIdx};
    thisEspEnv = ESPEnv.getESPEnvForRegionNameAndVersionLabel( ...
        thisRegionName, versionLabel);
    fprintf('Handling tile %s ...\n', thisRegionName);
    for thisDataLabelIdx = 1:length(allDataLabels)
        thisDataLabel = allDataLabels{thisDataLabelIdx};
        fprintf('Handling type %s ...\n', thisDataLabel);
        [thisLandsubdivisionId, ~, ~] = thisEspEnv.getDataForObjectNameDataLabel( ...
            thisRegionName, thisDataLabel);
        thisLandsubdivisionId = unique(thisLandsubdivisionId);
        landSubdivisionId = [landSubdivisionId; thisLandsubdivisionId];
        regionName = [regionName; repmat( ...
            {thisRegionName}, length(thisLandsubdivisionId), 1)];
        dataLabel = [dataLabel; repmat( ...
            {thisDataLabel}, length(thisLandsubdivisionId), 1)];
    end
    fprintf('Done tile %s.\n', thisRegionName); 
end

thisTable = table(landSubdivisionId, regionName, dataLabel);
for thisVersionIdx = 1:length(versionOfAncillaries)
    thisVersionOfAncillary = versionOfAncillaries{thisVersionIdx};
    modisData = MODISData(versionOfAncillary = thisVersionOfAncillary);
    espEnv = ESPEnv(modisData = modisData);
    outFilePath = espEnv.getFilePathForObjectNameDataLabel( ...
        '', 'landsubdivisionidpertileandtype');
    writetable(thisTable, outFilePath);
    fprintf('Save list in %s.\n', outFilePath);
end


for f in *.tif; do mv "$f" "$(echo "$f" | sed s/_admin/_adm/)"; done
