classdef AlbedoInversorForLc < handle
  % Calculates deltavis and albedo for landsat oli lc08 and lc09 scenes, based on
  % raw data, and pre-calculated bip and scag .tif files.
  % Also generate RGB image of reflectance.
  %
  % WARNING: The class uses specific environment variables, which must be defined at the
  % environment level, either
  % with the .bashrc or using Matlab, setenv(varName, value).

%{
  % Use case to generate deltavis and albedo for p042r034 lc08.l2sp.02.t1 and
  % julian year 2023.
  addpath(genpath(getenv('matlabPathForESPToolbox'));
  addpath(genpath(getenv('matlabPathForParBal'));

  regionName = 'p068r015'; %'p068r014'; 'p042r034';
  objectName = regionName;

  theseYears = 2020:2023;
  archivePath = getenv('espArchiveDirNrt');
  scratchPath = getenv('slurmScratchDir1');
  label = 'v2024.0';
  versionOfAncillary = 'v3.2';
  inputProducts = {'lc08.l2sp', 'lc09.l2sp'};
  inputProductVersions = {'02.t1', '02.t1'};
  parfor thisYearIdx = 1:length(theseYears)
    thisYear = theseYears(thisYearIdx);
    for inputProductIdx = 1:length(inputProducts)
      inputProduct = inputProducts{inputProductIdx};
      inputProductVersion = inputProductVersions{inputProductIdx};
      fprintf("Starting %d - %s.%s for %s.\n", thisYear, inputProduct, ...
        inputProductVersion, regionName);
      modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary, ...
        inputProduct = inputProduct, inputProductVersion = inputProductVersion);
      espEnv = ESPEnv(modisData, scratchPath = scratchPath, ...
        archivePath = archivePath);
      region = Regions(regionName, '', espEnv, modisData);

      % Determine which dates are available.
      varName = 'scag_snow_fraction';
      dataLabel = 'scagdailytif';
      [~, fileExists, ~, ~, theseDates] = ...
        espEnv.getFilePath(objectName, dataLabel, ...
        thisYear = thisYear, varName = varName);
      theseDates = theseDates(fileExists); % NB: fileExists is array(uint8).
      theseDates = sort(theseDates);
      albedoInversorForLc = AlbedoInversorForLc(region);
      % Run inversion.
      for thisDateIdx = 1:length(theseDates)
        thisDate = theseDates(thisDateIdx);
        albedoInversorForLc.inverseDeltavisAndAlbedo(thisDate);
      end
    end
  end
%}
  properties
    region  % char. Pathrow of the landsat scene. E.g. for p042r034: '042034'
    deltavisLookupTable % struct(gs = '', sim_refl = '', wvl = '');
      % data from the deltavisLookupTable.
  end
  methods
    function obj = AlbedoInversorForLc(region)
        % Constructor.
        %
        % Parameters
        % ----------
        % region: Regions obj. With name of the pathrow of the landsat scene.
        %   E.g. 'p042r034'.
        %
        % Return
        % ------
        % obj: albedoInversorForLc.
        obj.region = region;
    end % albedoInversorForLc().
    function inverseDeltavisAndAlbedo(obj, thisDate)
      % Calculates deltavis and albedo using a precalculated lookup tables.
      % Also generates RGB image of reflectance.
      % For deltavis:
      % Original Code and table here https://github.com/UofU-Cryosphere/DRFS
      % (cloned 20240831). Code was modified and adapted to our hierarchy of
      % files/names/directories and variable types.
      % lookup table variables generated from OLI.z30.LIB.csv (?).
      % Cite: McKenzie Skiles et al., 2022. https://github.com/UofU-Cryosphere/DRFS
      %
      % Produces a delta vis geotiff (reduction in visible albedo due to light absorbing
      % particles) for Landsat-8 OLI scenes using grain size and snow fraction from
      % OLI-SCAG. These files need to be in the path: multiband Landsat-8 reflectance
      % file (.bip), snow fraction file (.snow.tif), snow grainsize file (.grnsz.tif),
      % and (appropriate zenith angle look up table (.mat): changed 20240821).
      % Spatial reference data is found in basic scene metadata (.txt), the only
      % thing that should need updating is the epsg (coordRefSysCode) code when moving
      %  to a new scene in a different UTM zone.
      % Data Ranges: 0-100 Delta Vis, 245 Not Snow, 255 Off Grid/Not Run/No Data
      %
      % For albedo, use of ParBal package: .sunslope() and .spires_albedo() giving
      % albedos (not slope-corrected).
      %
      % Parameters
      % ----------
      % thisDate: datetime. Date for which the calculation is done.

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % 1. Deltavis.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      fprintf('Start generating deltavis and albedo for %s, %s...\n', ...
        obj.region.name, char(thisDate, 'yyyy-MM-dd'));
      espEnv = obj.region.espEnv;
      objectName = '';
      if isempty(obj.deltavisLookupTable)
        deltavisLookupFilePath = ...
          espEnv.getFilePath(objectName, 'deltavislookupforlc');
        obj.deltavisLookupTable = load(deltavisLookupFilePath);
      end
      objectName = obj.region.name;

      % Load snow fraction and grain size and get projection (mapCellsReference).
      dataLabel = 'scagdailytif';
      varName = 'scag_snow_fraction';
      [filePath, ~, ~, metaData, ~] = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName);
      timestampAndNrt = metaData.timestampAndNrt;
      [frac, mapCellsReference] = readgeoraster(filePath);
      frac = double(frac);
      [row col] = size(frac);

      varName = 'scag_grain_size';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName); 
      [grainSize, ~] = readgeoraster(filePath);
      grainSize = double(grainSize);
      
      isNoData = frac == 255 | frac < 90 | frac > 100 | ismember(grainSize, [0, 65535]);

      % Metadata and get the correct georeference sys code (EPSG) Seba 20240809.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      dataLabel = 'scagdailybipmeta';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate); 
      cmd = ['cat ', filePath, ' | grep NBANDS | cut -d ''='' -f 2'];
      [status, cmdout] = system(cmd);
      countOfReflectanceBands = str2num(cmdout);
      cmd = ['cat ', filePath, ' | grep ZONE_NUMBER | cut -d ''='' -f 2'];
      [status, cmdout] = system(cmd);
      utmZone = str2num(cmdout);

      dataLabel = [strrep(espEnv.modisData.inputProduct, '.', '_'), 'txt'];
      varName = 'metaData'; % MTL.
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName); 
      cmd = ['cat ', filePath, ' | grep CORNER_LR_LAT_PRODUCT | head -1 | ', ...
        'tr -d '' '' | cut -d = -f 2'];
      [status, cmdout] = system(cmd);
      latitude = str2num(cmdout);
      if latitude > 0 && latitude < 84
        coordRefSysCode = 32600 + utmZone;
      elseif latitude < 0 && latitude > -80
        coordRefSysCode = 32700 + utmZone;
      else
        error();
      end
        % https://docs.up42.com/data/reference/utm
        % Not sure it works well for swaths close to Equator                    @warning
        % coordRefSysCode = 32642; %UTM 42N
        % coordRefSysCode = 32632; % for Swiss

      % For albedo. Calculations of mu0 (cosinus of solar zenith)
      % considering a flat surface (mu0)
      % use of ParBal package: .sunslope and .spires_albedo.
      % spires_albedo needs no data values to be NaNs
      %-----------------------------------------------------------

      cmd = ['cat ', filePath, ' | grep SUN_ELEVATION | head -1 | ', ...
        'tr -d '' '' | cut -d = -f 2'];
      [status, cmdout] = system(cmd);
      solarZenith = str2num(cmdout);

      %{
        cmd = ['cat ', inputMTLFilePath, ' | grep SUN_AZIMUTH | head -1 | ', ...
          'tr -s '' '' | cut -d ''='' -f 4'];
        [status, cmdout] = system(cmd);
        solarAzimuth = str2num(cmdout);
      %}
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      % Load OLI bands.
      dataLabel = 'scagdailybip';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate); 
      OLI = multibandread(filePath, [row, col, countOfReflectanceBands], ...
        'uint16', 0, 'bip', 'ieee-le');

      OLI_b1 = OLI(:, :, 1);
      OLI_b3 = OLI(:, :, 3);
      OLI_b4 = OLI(:, :, 4);
      OLI_b5 = OLI(:, :, 5);
      
      % Generates RGB from reflectance.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      saturationRange = [0.01 0.99];
      bands = [6 4 2];
      Rs_scale = 1000.;
      data = zeros([size(OLI, 1), size(OLI, 2), length(bands)], 'single'); %row, col, length(bands)]);
      for bandIdx = 1:length(bands)
        thisMax = max(OLI(:, :, bands(bandIdx)), [], 'all');
        data(:, :, bandIdx) = single(OLI(:, :, bands(bandIdx)));  
      end
      % Adjust for contrast, Convert to floats in range 0-1
      data = uint8(min(data, 1000) / 10);
      % data = data / 1600; %Rs_scale;
      
      % Stretch requested input range to full range of outputs
      % data = uint8(100 * imadjust(data, stretchlim(data, saturationRange), []));
      dataLabel = 'scagdailytif';
      varName = 'reflectance_rgb';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName, timestampAndNrt = timestampAndNrt);  
      geotiffwrite(filePath, data, mapCellsReference, ...
        CoordRefSysCode = coordRefSysCode, TiffTags = struct(Compression = 'LZW'));
      
      % Back DRFS Deltavis.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  
      % Generate find reflectance at each band in .tif based on lookup table and
      % find lookup table reflectance.
      scag_refl = NaN(row, col, 4); % preallocate 4 band reflectance from lookup table.
      for i = 1:row
        for j= 1:col
          if ~isNoData(i, j)
            gs_ind = find(obj.deltavisLookupTable.gs == grainSize(i, j));
            scag_refl(i, j, 1:4) = ...
              obj.deltavisLookupTable.sim_refl(1:4, gs_ind) * 10;
              % change order of magnitude to match OLI (?).
          end
        end
      end

      % Find reflectance difference at band 5 = wvl(4) = 0.87.
      % NB: deltavisLookupTable.wvl doesnt seem to be used, contrary to suggested.
      diff = scag_refl(:, :, 4) - OLI_b5;

      % add difference to OLI bands.
      OLI_diff = NaN(row, col, 4);
      OLI_diff(:, :, 1) = diff + OLI_b1;
      OLI_diff(:, :, 2) = diff + OLI_b3;
      OLI_diff(:, :, 3) = diff + OLI_b4;
      OLI_diff(:, :, 4) = diff + OLI_b5;

      % calculate scag - OLI for raditative forcing.
      radf = scag_refl - OLI_diff;

      deltavis = mean(radf, 3); % average bands.
      deltavis = deltavis / 1000; % change to reflectance scale.

      % apply FSCA mask.
      % remove all pixels that are <90% FSCA.
      [row col] = size(frac);
%{
      mask = frac; % Before modifying frac use 0 and 255 values to place final mask.
      frac(frac < 90 | frac > 100) = NaN;
      deltavis(isnan(frac)) = 245;
      deltavis(mask == 255) = 255;
      deltavis(mask == 0) = 245;
      deltavis(isnan(deltavis)) = 255; % snow,  but no grnsz value.
%}
      % I decided to only have 1 nodataValue. Seba 20241013.
      deltavis(isnan(deltavis)) = 255;
      deltavis = uint8(deltavis);


      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % save as geotiff. Get the correct georeference sys code (EPSG),
      % e.g. 32632 for Swiss.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      dataLabel = 'scagdailytif';
      varName = 'deltavis';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName, timestampAndNrt = timestampAndNrt); 
      geotiffwrite(filePath, deltavis, mapCellsReference, ...
        CoordRefSysCode = coordRefSysCode, TiffTags = struct(Compression = 'LZW'));
      fprintf('Saved deltavis %s.\n', filePath);

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % 2. Albedo.
      % Parbal code... (only for non-corrected by topography).
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      mu0 = cosd(solarZenith);

      % Grain size.
      % Load of scag output values
      % + cap of grain size to max value accepted by parBal.spires
      grainSize(grainSize == intmax('uint16')) = NaN;

      albedoMinGrainSize = 1;  % Min grain size accepted to calculate albedo
                                % spires in parBal package.
      albedoMaxGrainSize = 1999;  % Max grain size accepted to calculate albedo
                                  % spires in parBal package.
      grainSize(grainSize > ...
          albedoMaxGrainSize) = albedoMaxGrainSize;
      grainSize(grainSize < ...
          albedoMinGrainSize) = albedoMinGrainSize;
      atmosphericProfile = 'mlw';

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % Albedo clean mu0.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

      data = spires_albedo(...
          grainSize, repmat(mu0, size(grainSize)), atmosphericProfile);
      isNoData = isnan(data);
      data = uint8(data * 100);
      data(isNoData) = intmax('uint8');
      varName = 'albedo_clean_mu0';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName, timestampAndNrt = timestampAndNrt); 
      geotiffwrite(filePath, data, mapCellsReference, ...
        CoordRefSysCode = coordRefSysCode, TiffTags = struct(Compression = 'LZW'));
      fprintf('Saved albedo_clean_mu0 %s.\n', filePath);

      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % Albedo observed mu0.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      isNoData = deltavis == 255 | isNoData;
        % ismember(deltavis, [245, 255]) | isNoData;
      albedoDownscaleFactor = 0.63;
      albedoObservedMu0 = intmax('uint8') * ones(size(deltavis),'uint8');
      albedoObservedMu0(~isNoData) = uint8(data(~isNoData) - ...
        deltavis(~isNoData) * albedoDownscaleFactor);
        % gives 0 if deltavis anomalously too big.
      varName = 'albedo_observed_mu0';
      filePath = espEnv.getFilePath(objectName, dataLabel, ...
        thisDate = thisDate, varName = varName, timestampAndNrt = timestampAndNrt); 
      geotiffwrite(filePath, albedoObservedMu0, mapCellsReference, ...
        CoordRefSysCode = coordRefSysCode, TiffTags = struct(Compression = 'LZW'));
      fprintf('Saved albedo_observed_mu0 %s.\n', filePath);
    end % inverseDeltavisAndAlbedo()
  end % methods.
end % classdef.
