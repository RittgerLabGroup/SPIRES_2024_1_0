% NB: requires ancillary data generated first, notably mask and land/water (?)  @warning
% NB: region tile should be (temporarily) indicated as used = 1 to generate the
%   coordinates.                                                                @warning
versionOfAncillaries = {'v3.1', 'v3.2', 'v3.3'};
regionName = {};
boxLongitude1 = [];
boxLongitude2 = [];
boxLongitude3 = [];
boxLongitude4 = [];
boxLatitude1 = [];
boxLatitude2 = [];
boxLatitude3 = [];
boxLatitude4 = [];
thisTable = table(regionName, ...
  boxLongitude1, boxLongitude2, boxLongitude3, boxLongitude4, ...
  boxLatitude1, boxLatitude2, boxLatitude3, boxLatitude4);
for versionOfAncillaryIdx = 1:size(versionOfAncillaries, 2)
  modisData = MODISData(label = 'v2024.0', versionOfAncillary = versionOfAncillaries{versionOfAncillaryIdx}); 
  espEnv = ESPEnv(modisData = modisData, scratchPath = getenv('espArchiveDirNrt'));
  for regionIdx = 1:size(espEnv.myConf.region, 1)
    regionName = espEnv.myConf.region.name{regionIdx};
    region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);
    mapCellsReference = region.getMapCellsReference();
    thisProjection = mapCellsReference.ProjectedCRS;
    [boxLatitude1, boxLongitude1] = projinv(thisProjection, ...
      mapCellsReference.XWorldLimits(1), mapCellsReference.YWorldLimits(2));
    [boxLatitude2, boxLongitude2] = projinv(thisProjection, ...
      mapCellsReference.XWorldLimits(2), mapCellsReference.YWorldLimits(2));
    [boxLatitude3, boxLongitude3] = projinv(thisProjection, ...
      mapCellsReference.XWorldLimits(2), mapCellsReference.YWorldLimits(1));
    [boxLatitude4, boxLongitude4] = projinv(thisProjection, ...
      mapCellsReference.XWorldLimits(1), mapCellsReference.YWorldLimits(1));
    thisTable = [thisTable; array2table([{regionName}, ...
      boxLongitude1, boxLongitude2, boxLongitude3, boxLongitude4, ...
      boxLatitude1, boxLatitude2, boxLatitude3, boxLatitude4], ...
      VariableNames = {'regionName', ...
        'boxLongitude1', 'boxLongitude2', 'boxLongitude3', 'boxLongitude4', ...
        'boxLatitude1', 'boxLatitude2', 'boxLatitude3', 'boxLatitude4'})];
  end
end
writetable(thisTable, 'region_latlon_corners.csv');