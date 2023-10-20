# NetCDF

Snippet to generate test v2023.1 Netcdf output files:
```
modisData = MODISData(label = 'v2023.1', versionOfAncillary = 'v3.1');    
espEnv = ESPEnv(modisData = modisData); %, scratchPath = ESPEnv.defaultArchivePath);
bigRegionName = 'westernUS';
bigRegion = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
thisDate = datetime(2023, 4, 15);

for tileIdx = 1:length(bigRegion.tileIds)
    regionName = bigRegion.tileIds{tileIdx};
    region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);
    matFilePath = espEnv.getFilePathForDateAndVarName(regionName, 'VariablesMatlab', ...
        thisDate, '');
    netCDFFilePath = espEnv.getFilePathForDateAndVarName(regionName, ...
        'VariablesNetCDF', thisDate, '');
    ESPNetCDF.generateNetCDFFromRegionAndMatFile(region, thisDate, matFilePath, ...
        netCDFFilePath);
end

modisData = MODISData(label = 'v2023.1', versionOfAncillary = 'v3.2');    
espEnv = ESPEnv(modisData = modisData, scratchPath = ESPEnv.defaultArchivePath);
bigRegionName = 'USAlaska';
bigRegion = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
thisDate = datetime(2023, 4, 15);

for tileIdx = 1:length(bigRegion.tileIds)
    regionName = bigRegion.tileIds{tileIdx};
    region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);
    matFilePath = espEnv.getFilePathForDateAndVarName(regionName, 'VariablesMatlab', ...
        thisDate, '');
    netCDFFilePath = espEnv.getFilePathForDateAndVarName(regionName, ...
        'VariablesNetCDF', thisDate, '');
    ESPNetCDF.generateNetCDFFromRegionAndMatFile(region, thisDate, matFilePath, ...
        netCDFFilePath);
end
```
