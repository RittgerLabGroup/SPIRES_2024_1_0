classdef SpiresAncillary < handle
  % Generation of the background reflectance necessary to calculate spires inversion.
  % Class derived from createR0 by Ned 2023/11.
  
%{
  % Use case to generate Background reflectance for USAlaska tiles.
  regionNames = {'h10v05', 'h11v04'};
  % regionNames = {'h07v03', 'h08v03', 'h09v02', 'h09v03', 'h10v02', 'h10v03', 'h11v02', 'h11v03', 'h12v01', 'h12v02', 'h13v01', 'h13v02'};
  archivePath = getenv('espArchiveDirNrt');
  scratchPath = getenv('slurmScratchDir1');
  label = 'v2024.0f'; % not used
  versionOfAncillary = 'v3.2';
  inputProduct = 'mod09ga'; % 'vnp09ga';
  inputProductVersion = '061'; % '002';
  addpath(genpath([getenv('projectDir'), 'MATLAB/SPIRES/MATLABFileExchange/Inpaint_nans']));

  modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary, ...
    inputProduct = inputProduct, inputProductVersion = inputProductVersion);
  espEnv = ESPEnv(modisData = modisData, scratchPath = scratchPath, ...
    archivePath = archivePath);
  espEnv.configParallelismPool();
  for regionIdx = 1:length(regionNames)
    regionName = regionNames{regionIdx};
    fprintf("start %s.\n", regionName);
    region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);
    spiresAncillary = SpiresAncillary(region);
    spiresAncillary.calculateBackgroundReflectance();
  end
%}
  properties
    region    % Regions obj.
  end
  properties(Constant)
    backgroundReflectanceDataLabels = struct( ...
      mod09ga = 'backgroundreflectanceformodis', ...
      vnp09ga = 'backgroundreflectanceforviirs');
  end
  methods
    function obj = SpiresAncillary(region)
      % Parameters
      % ----------
      % region: Regions obj. Modis tile only.
      thisFunction = 'SpiresAncillary.SpiresAncillary';
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      obj.region = region;

      fprintf(['%s: Created SpiresAncillary, region: %s.\n'], ...
        thisFunction, region.name);
    end
    function calculateBackgroundReflectance(obj)
      % Calculates R0 the spires background snow-free reflectance by examing a stack of
      % images.
      % Method derived from createR0() by Ned 202311.
      regionName = obj.region.name;
      objectName = regionName;
      espEnv = obj.region.espEnv;
      modisData = espEnv.modisData;

      % Dates of collection of reflectances for south hemisphere.
      if contains(regionName, 'v1') | contains(regionName, 'v09')
        theseDate = datetime(2019, 2, 1, 12, 0 ,0):datetime(2019, 3, 31, 12, 0 ,0);
        fprintf('South...\n');
      else
        theseDate = datetime(2019, 8, 1, 12, 0 ,0):datetime(2019, 9, 30, 12, 0 ,0);
        fprintf('North...\n');
      end

      thisSize = [ ...
        espEnv.modisData.sensorProperties.tiling.rowPixelCount, ...
        espEnv.modisData.sensorProperties.tiling.columnPixelCount, ...
        length(SpiresInversor.reflectanceNames)];
      
      backgroundReflectance = intmax('uint8') * ones([thisSize, length(theseDate)], 'uint8');
        % Seb 20240310. Format and mode ndvi/ndsi declaration here 
        % (maybe we can reduce them to int?)
      ndvi = NaN([thisSize(1), thisSize(2), length(theseDate)], 'single');
      ndsi = NaN(size(ndvi), 'single');

      dataLabels = struct(mod09ga = 'modspiresdaily', vnp09ga = 'vnpspiresdaily');
      dataLabel = dataLabels.(modisData.inputProduct);
      complementaryLabel = '';
      force = struct(resamplingFactor = 1, ...
        resamplingMethod = 'nearest', type = 'single');
      parfor dateIdx = 1:length(theseDate)
        thisDate = theseDate(dateIdx);
        reflectance = zeros(thisSize, 'single');
        % Get all reflectances....
        for varIdx = 1:length(SpiresInversor.reflectanceNames)
          varName = SpiresInversor.reflectanceNames{varIdx}; % varIdx from 1 to 7.
          [varData, ~] = ...
            espEnv.getDataForDateAndVarName(objectName, ...
            dataLabel, thisDate, varName, complementaryLabel, force = force);
            % varData expected uint8 on 100.
            % imresize used within getData for viirs M 1km bands 3, 4, 5, 7
            % with 1, 2, 6 I 500m bands.
          reflectance(:, :, varIdx) = varData;
        end
        % Get clouds....
        varName = 'neural_classification_snow_cloud';
        neuralClassification = espEnv.getDataForDateAndVarName(objectName, ...
          dataLabel, thisDate, varName, complementaryLabel);
          % 'snow' = 0; 'cloud' = 1; 'neither') = 2;

        %compute ndvi
        ndvi_ = (reflectance(:, :, 2) - reflectance(:, :, 1)) ./ ...
          (reflectance(:, :, 2) + reflectance(:, :, 1));
        %set clouds, snow to NaN for ndvi only (not ndsi)
        ndvi_(neuralClassification == 2) = NaN;
        neuralClassification = [];

        %compute ndsi
        ndsi_ = (reflectance(:, :, 4) - reflectance(:, :, 6)) ./ ...
          (reflectance(:, :, 4) + reflectance(:, :, 6));
        reflectance = cast(reflectance, 'uint8');

        %set off nadir shots to NaN
        varName = 'sensor_zenith';
        % sensor_zenith. 1200x1200 reinterpolated to 2400x2400.
        sensorZenith = espEnv.getDataForDateAndVarName(objectName, ...
          dataLabel, thisDate, varName, complementaryLabel, force = force);

        highSensorZenith = sensorZenith > 30;
        sensorZenith = [];
        ndvi_(highSensorZenith) = NaN;
        ndsi_(highSensorZenith) = NaN;

        ndvi(:, :, dateIdx) = ndvi_;
        ndsi(:, :, dateIdx) = ndsi_;
        backgroundReflectance(:, :, :, dateIdx) = reflectance;
      end

      %compute max and max index for ndvi (max green up)
      [~, idx_max_ndvi] = max(ndvi, [], 3);
      ndvi = [];

      %compute min and min index for ndsi (snow cover minimum)
      [min_ndsi, idx_min_ndsi] = min(ndsi, [], 3);
      ndsi = [];
      minNdsiISPositive = min_ndsi > 0;
      min_ndsi = [];

      %compute b3 min and min ind
      b3 = squeeze(backgroundReflectance(:, :, 3, :));

      b3(b3 < 0.10) = NaN; %too dark

      %compute min and min index for b3
      [min_b3, idx_min_b3] = min(b3, [], 3);
      b3 = [];

      X = NaN(thisSize);
      for i = 1:thisSize(1)
        for j = 1:thisSize(2)
          %spectra for max ndvi day
          max_ndvi_vals = squeeze(backgroundReflectance(i, j, :, idx_max_ndvi(i, j)));
          %min_ndsi_vals = squeeze(backgroundReflectance(i, j, :, idx_min_ndsi(i, j)));
          %spectra for min b3 day
          min_b3_vals = squeeze(backgroundReflectance(i, j, :, idx_min_b3(i, j)));

          if minNdsiISPositive(i, j)
            %then use the spectra from min b3 day
            X(i, j, :) = min_b3_vals;
            %X(i, j, :) = min_ndsi_vals;
          else %use spectra from max ndvi day
            X(i, j, :) = max_ndvi_vals;
          end
        end
      end
      backgroundReflectance = X;

      % interpolate NaNs. Seb 20240310: may not be necessary since backgroundReflectance 
      % is set to 0 when NaN during the loading in the parfor loop.
      for j = 1:size(backgroundReflectance, 3)
        backgroundReflectance(:, :, j) = ...
          inpaint_nans(double(squeeze(backgroundReflectance(:, :, j))), 3);
      end
      data = uint8(backgroundReflectance);
      mapCellsReference = modisData.getMapCellsReference( ...
        modisData.getTilePositionIdsAndColumnRowCount(regionName));
      
      dataLabel = obj.backgroundReflectanceDataLabels.(modisData.inputProduct);
      outputFilePath = espEnv.getFilePathForObjectNameDataLabel(objectName, dataLabel);
      save(outputFilePath, 'data', 'mapCellsReference', '-v7.3'); % Seb 20240309.
    end
  end
end
