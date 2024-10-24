# NetCDF

Snippet to generate test v2023.1 Netcdf output files:
```
modisData = MODISData(label = 'v2023.1', versionOfAncillary = 'v3.1');    
espEnv = ESPEnv(modisData = modisData);
bigRegionName = 'westernUS';
bigRegion = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
thisDate = datetime(2022, 4, 15);

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
espEnv = ESPEnv(modisData = modisData, scratchPath = getenv('espArchiveDir'));
bigRegionName = 'USAlaska';
bigRegion = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
thisDate = datetime(2022, 4, 15);

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

Snippet to generate test v2022.0 Netcdf output files for High Mountain Asia:
```
modisData = MODISData(label = 'v03', versionOfAncillary = 'v3.2');
modisData.versionOf.VariablesNetCDF = 'v2022.0';
espEnv = ESPEnv(modisData = modisData, scratchPath = getenv('espArchiveDir'));
bigRegionName = 'ASHimalaya';
bigRegion = Regions(bigRegionName, [bigRegionName, '_mask'], espEnv, modisData);
thisDate = datetime(2022, 4, 15);

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