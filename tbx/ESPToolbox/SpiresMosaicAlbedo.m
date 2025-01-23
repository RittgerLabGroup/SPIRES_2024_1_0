classdef SpiresMosaicAlbedo < handle
  % Mosaic the cell-split time interpolation files and calculates deltavis, radiative
  % forcing and albedo.
  properties
    region  % Regions Obj.
  end
  properties(Constant)
    dataLabels = struct( ...
      mod09ga = 'spiresdailytifsinu', ...
      vnp09ga = 'spiresdailytifsinu');
  end
  methods
    function obj = SpiresMosaicAlbedo(region)
      % Parameters
      % ----------
      % region: Regions obj. Modis tile only.
      thisFunction = 'SpiresMosaicAlbedo.SpiresMosaicAlbedo';
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      obj.region = region;

      fprintf(['%s: Created SpiresMosaicAlbedo, region: %s.\n'], ...
        thisFunction, region.name);
    end
    function mosaic(obj, waterYearDate, varargin)
      % Mosaicing of the time interpolator cell output into 1 file per tile(region)
      % water year, calculates deltavis, radiative forcing and albedos, and save in 
      % the daily files. This mosaicing is necessary because the 
      % load of the 36 cells per day per variable during the repatriation of data to
      % spiresdaily file was taking one min per variable per day...
      %
      % Parameters
      % ----------
      % waterYearDate: WaterYearDate obj.
      % optim: struct(cellIdx, countOfCellPerDimension, force, logLevel,
      %       parallelWorkersNb).
      %   cellIdx: array(int), optional. [rowCellIdx, columnCellIdx].
      %       Indices of the cell part of a tile. Row indices are counted from
      %       top to bottom, column indices from left to right. Default [1, 1].
      %   countOfCellPerDimension: array(int), optional.
      %       [rowCellCount, columnCellCount]. Number of cells dividing the set of
      %       rows and same for columns. E.g. if we want to divide a 2400x2400
      %       tile in 9 cells, countOfCellPerDimension = [3, 3]. Default [1, 1].
      %   force: int, optional. Default 0. Unused.
      %   logLevel: int, optional. Indicate the density of logs.
      %       Default 0, all logs. The higher the less logs.
      %   parallelWorkersNb: int, optional. If 0 (default), no parallelism.
      thisTimer = tic;
      thisFunction = 'SpiresMosaicAlbedo.mosaic';
      thisFunctionCode = 'spiMosaA';
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      logger = Logger(thisFunctionCode);
      logger.printDurationAndMemoryUse(dbstack);
      espEnv = obj.region.espEnv;
      modisData = espEnv.modisData;
      objectName = obj.region.name;
      
      defaultOptim = struct(cellIdx = [1, 1], ...
        countOfCellPerDimension = [1, 1], force = 0, logLevel = 0, ...
        parallelWorkersNb = 0);
        % NB: There's a problem here, since input is with cellIdx 3D and output is with
        % cellIdx 2D...                                                            @todo

      p = inputParser;
      addParameter(p, 'optim', struct());
      p.StructExpand = false;
      parse(p, varargin{:});
      optim = p.Results.optim;

      optimFieldNames = fieldnames(defaultOptim);
      for fieldIdx = 1:length(optimFieldNames)
        thisFieldName = optimFieldNames{fieldIdx};
        if ~ismember(thisFieldName, fieldnames(optim))
          optim.(thisFieldName) = defaultOptim.(thisFieldName);
        end
      end % fieldIx
      fprintf(['%s %s: STARTING, region: %s, waterYearDate: %s, ', ...
        'cellIdx: [%s], countOfCellPerDimension: [%s], ', ...
        'force: %d, logLevel: %d, ', ...
        'parallelWorkersNd: %d...\n'], thisFunction, thisFunctionCode, objectName, ...
        waterYearDate.toChar(), ...
        join(num2str(optim.cellIdx), ', '), ...
        join(num2str(optim.countOfCellPerDimension), ', '), ...
        optim.force, optim.logLevel, optim.parallelWorkersNb);
      
      % Determination of the time window for valid observation detection and
      % interpolation, based on raw_viewable_snow_fraction_s data.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      theseDates = waterYearDate.getDailyDatetimeRange();

      inputDataLabel = SpiresTimeInterpolator.dataLabels.(modisData.inputProduct);
      outputDataLabel = obj.dataLabels.(modisData.inputProduct);
      [outputVariable, ~] = espEnv.getVariable(outputDataLabel, ...
        inputDataLabel = inputDataLabel);
      [albedoVariable, ~] = espEnv.getVariable(outputDataLabel, ...
        inputDataLabel = outputDataLabel);
      albedoVariable = albedoVariable( ...
        ismember(albedoVariable.id, [62, 63, 96, 99]), :);
  
      % Check files and their dates.
      % NB: we assume it's the same set of files for all the dates of the
      %   called waterYearDate.                                           @warning
      % NB: the spires smooth files are saved by chunks-cells split files
      % and need to be combine/aggregate to form a full tile.         @warning
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      tic;
      dataLabel = inputDataLabel;
      thisDate = theseDates(1);
      varName = '';
      complementaryLabel = '';
      patternsToReplaceByJoker = ...
        {'rowStartId', 'rowEndId', 'columnStartId', 'columnEndId'};
        % Here the input consists in cell-split files, to be combine in 1
        % tile file only.
      [filePath, fileExists, ~] = espEnv.getFilePathForDateAndVarName( ...
        objectName, dataLabel, thisDate, varName, complementaryLabel, ...
        patternsToReplaceByJoker = patternsToReplaceByJoker);
      if sum(cell2mat(fileExists)) ~= 36
        % NB: Hard-coded 36 cell files expected. Improve....           @todo
        ME = MException('SpiresTimeInterpolator:mosaicNoFile', ...
            sprintf(['%s: No 36 spires smooth/time cell files for %s, ', ...
            ' %s, %s. Generate or sync them to scratch and rerun', ...
            '.\n'], mfilename(), objectName, dataLabel, ...
            string(thisDate, 'yyyy-MM-dd')));
        throw(ME);
      end
      % Test one file whether the input files have the date, we suppose that
      % if one of the input file has the date, all have, which can be false
      % if the smoothing process failed for some of the cells.        @warning
      inputFileDates = [];
      % .mat files.
      thisFilePath = filePath{1};
      fprintf('Testing validity of %s...\n', thisFilePath);
      fileObj = matfile(thisFilePath);
      inputFileDates = fileObj.theseDates;
      for filePathIdx = 2:length(filePath)
        thisFilePath = filePath{filePathIdx};
        fprintf('Testing validity of %s...\n', thisFilePath);
        fileObj = matfile(thisFilePath);
          % Raise an error if inexistent file or file corrupted (but don't 
          % detect all corruption cases.                            @warning
        thoseDates = fileObj.theseDates;
        if ~isequal(thoseDates, inputFileDates)
          ME = MException('SpiresTimeInterpolator:mosaicBadDates', ...
            sprintf(['SpiresTimeInterpolator:mosaic: ', ...
            'not the range of dates expected in %s.\n'], thisFilePath));
          throw(ME);
        end
      end
      fprintf('%s-%s: Tested validity of input in %.2f mins.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60, varName);
      
      % Get the wateryear data for each variable and save them in each spiresdaily file.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      varDataGetAndSaveTimer = tic;
      data = struct();
      isData = 0;

      outputFilePath = espEnv.getFilePathForWaterYearDate(objectName, ...
        outputDataLabel, waterYearDate);

      S.pool = gcp('nocreate');
      countOfDateBlocks = ceil(length(theseDates) / S.pool.NumWorkers);
      for varIdx = 1:size(outputVariable, 1)
        varName = outputVariable.name{varIdx};
        if strcmp(varName, 'metaData')
          continue;
        end
        tic
        varData = espEnv.getDataForWaterYearDateAndVarName( ...
          objectName, inputDataLabel, waterYearDate, varName,...
          patternsToReplaceByJoker = patternsToReplaceByJoker);
        fprintf('%s-%s: Data loaded in %.2f mins, variable %s.\n\n', ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc / 60, varName);
        if isempty(varData)
          error([thisFunctionCode, ':noData'], 'Error No data for variable %s.\n', ...
            varName);
        end
        
        tic
        % Small try by a pre-for loop to reduce size of matrix used by parallel workers.
        for dateBlockIdx = 1:countOfDateBlocks
          thoseDateIndices = ((dateBlockIdx - 1) * S.pool.NumWorkers + 1) : ...
            min((dateBlockIdx) * S.pool.NumWorkers, length(theseDates));
          thatData = varData(:, :, thoseDateIndices);
          thoseDates = theseDates(thoseDateIndices);
          
          parfor dateIdx = 1:length(thoseDates)
            thisDate = thoseDates(dateIdx);
            espEnv.saveData(thatData(:, :, dateIdx), objectName, ...
                outputDataLabel, theseDate = thisDate, varName = varName);
            % Metadata from the configuration file for this variable...
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            if espEnv.slurmEndDate <= ...
                datetime('now') + ...
                    seconds(espEnv.slurmSafetySecondsBeforeKill)
                error('ESPEnv:TimeLimit', ...
                    'Error, Job has reached its time limit.');
            end
%{
            TEMPORARY DEACTIVATION 20241209.
            thisMatfile = matfile(outputFilePath{dateIdx}, Writable = true);
            thisMatfile.([varName '_type']) = ...
                outputVariable.type{varIdx};
            thisMatfile.([varName '_units']) = ...
                outputVariable.unit{varIdx};
            thisMatfile.([varName '_multiplicator_for_mosaics']) = ...
                outputVariable.multiplicator_for_mosaics(varIdx);
            thisMatfile.([varName '_divisor']) = ...
                outputVariable.divisor(varIdx);
            thisMatfile.([varName '_min']) = outputVariable.min(varIdx) * ...
                outputVariable.divisor(varIdx);
            thisMatfile.([varName '_max']) = outputVariable.max(varIdx) * ...
                outputVariable.divisor(varIdx);
            thisMatfile.([varName '_nodata_value']) = ...
                outputVariable.nodata_value(varIdx);
            thisMatfile.statusOfTimeSmoothing = 1;
            thisMatfile = [];
%}
          end
        end
        thatData = [];
        fprintf('%s-%s: Data saved in %.2f mins, variable %s.\n\n', ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc / 60, varName);
          
        % Only keep the data necessary for calculation of radiative
        % forcing, deltavis and albedos.
        if ismember(varName, ...
          {'dust_concentration_s', 'grain_size_s'})
          data.(varName) = varData;
          if isData == 0
              isData = data.(varName) ~= intmax('uint16');
          else
              isData = isData & data.(varName) ~= intmax('uint16');
          end
          % NB: isData can be different for grain size and dust,
          % mainly in summer and early fall. 
        end
      end % for varIdx.
      varData = [];
      fprintf('%s-%s: Data got and saved in %.2f mins.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc(varDataGetAndSaveTimer) / 60);
      
      albedoCalculatorTimer = tic;
      % calculation of radiative forcing, deltavis and albedos.
      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
      % Dirty albedo and radiative forcing from Jeff lookup tables.
      albedoForcingCalculator = AlbedoForcingCalculator(obj.region);
      % solar zenith.
      % Spatial interpolation method to rescale rasters at 1 km to 500m 
      % with imresize.
      tic;
      data.grain_size_s = ...
        data.grain_size_s(isData);
      data.dust_concentration_s = ...
        data.dust_concentration_s(isData);
      parameterName = 'imresizeInterpolationMethod';
      parameterValue = ...
        Tools.valueInTableForThisField( ...
        obj.region.filter.spires, 'lineName', ...
        parameterName, 'minValue');
        % 1: nearest, 2: bilinear, 3: bicubic.
      thoseImresizeMethod = {'nearest', 'bilinear', 'bicubic'};
      resamplingMethod = thoseImresizeMethod{parameterValue};
      force = struct( ...
        resamplingFactor = 1, resamplingMethod = resamplingMethod);
      varName = 'solar_zenith';
      data.(varName) = espEnv.getDataForWaterYearDateAndVarName( ...
        objectName, outputDataLabel, waterYearDate, varName,...
        force = force);
      mu0 = cosd(single(data.solar_zenith(isData)));
      data.solar_zenith = [];
      
      data.grain_size_s = sqrt(single(data.grain_size_s));
          % grain_size is converted to sqrt for AlbedoLookup.
      data.dust_concentration_s = single(data.dust_concentration_s) ...
          / 10 / 1000; % spires dust is in ppm while
          % AlbedoLookup expects ppt.
      sootFraction = zeros(size(mu0), 'uint8');
      fprintf('%s-%s: Albedo step 1 in %.2f mins.\n\n', ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc / 60);
      
      tic
      varName = 'albedo_s';
      data.(varName) = intmax('uint8') * ones(size(isData), 'uint8');
      data.(varName)(isData) = uint8( ...
          albedoForcingCalculator.dirtyAlbedoGriddedInterpolant( ...
          mu0, mu0, data.grain_size_s, ...
          data.dust_concentration_s, ...
          single(sootFraction)) * 100);
      % cosOfSolarZenith: mu0, cosOfIllumination = muI, grainSize: radius,
      % dustFraction: LAPfraction(1) in Jeff function.
      fprintf('%s-%s: Albedo step 2 in %.2f mins.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60);
      tic
      for dateBlockIdx = 1:countOfDateBlocks
        thoseDateIndices = ((dateBlockIdx - 1) * S.pool.NumWorkers + 1) : ...
          min((dateBlockIdx) * S.pool.NumWorkers, length(theseDates));
        thatData = data.(varName)(:, :, thoseDateIndices);
        thoseDates = theseDates(thoseDateIndices);
        
        parfor dateIdx = 1:length(thoseDates)
          thisDate = thoseDates(dateIdx);
          espEnv.saveData(thatData(:, :, dateIdx), objectName, ...
          outputDataLabel, theseDate = thisDate, varName = varName);
        end
      end
      data.(varName) = [];
      fprintf('%s-%s: Data saved in %.2f mins, variable %s.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60, varName);

      tic
      varName = 'deltavis_s';
      data.(varName) = intmax('uint8') * ones(size(isData), 'uint8');
      data.(varName)(isData) = uint8( ...
        albedoForcingCalculator.deltavisGriddedInterpolant( ...
        mu0, mu0, data.grain_size_s, ...
        data.dust_concentration_s, single(sootFraction)) * 100);
      fprintf('%s-%s: Albedo step 3 in %.2f mins.\n\n', ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc / 60);
      tic
      for dateBlockIdx = 1:countOfDateBlocks
        thoseDateIndices = ((dateBlockIdx - 1) * S.pool.NumWorkers + 1) : ...
          min((dateBlockIdx) * S.pool.NumWorkers, length(theseDates));
        thatData = data.(varName)(:, :, thoseDateIndices);
        thoseDates = theseDates(thoseDateIndices);
        
        parfor dateIdx = 1:length(thoseDates)
          thisDate = thoseDates(dateIdx);
          espEnv.saveData(thatData(:, :, dateIdx), objectName, ...
          outputDataLabel, theseDate = thisDate, varName = varName);
        end
      end
      data.(varName) = [];
      fprintf('%s-%s: Data saved in %.2f mins, variable %s.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60, varName);
      
      tic
      varName = 'radiative_forcing_s';
      data.(varName) = intmax('uint16') * ones(size(isData), 'uint16');
      data.(varName)(isData) = uint16( ...
        albedoForcingCalculator.radiativeForcingGriddedInterpolant( ...
        mu0, mu0, data.grain_size_s, ...
        data.dust_concentration_s, single(sootFraction)));
      fprintf('%s-%s: Albedo step 4 in %.2f mins.\n\n', ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc / 60);
      tic
      for dateBlockIdx = 1:countOfDateBlocks
        thoseDateIndices = ((dateBlockIdx - 1) * S.pool.NumWorkers + 1) : ...
          min((dateBlockIdx) * S.pool.NumWorkers, length(theseDates));
        thatData = data.(varName)(:, :, thoseDateIndices);
        thoseDates = theseDates(thoseDateIndices);
        
        parfor dateIdx = 1:length(thoseDates)
          thisDate = thoseDates(dateIdx);
          espEnv.saveData(thatData(:, :, dateIdx), objectName, ...
          outputDataLabel, theseDate = thisDate, varName = varName);
        end
      end
      data.(varName) = [];
      fprintf('%s-%s: Data saved in %.2f mins, variable %s.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60, varName);

      tic
      slope = ...
        repmat(espEnv.getDataForObjectNameDataLabel(objectName, 'slope'), ...
          [1, 1, size(isData, 3)]);
      aspect = ...
        repmat(espEnv.getDataForObjectNameDataLabel(objectName, 'aspect'), ...
          [1, 1, size(isData, 3)]);
      
      % solar azimuth.
      varName = 'solar_azimuth';
      data.(varName) = espEnv.getDataForWaterYearDateAndVarName( ...
        objectName, outputDataLabel, waterYearDate, varName,...
        force = force);
      % phi0: Normalize stored azimuths to expected azimuths
      % stored data is assumed to be -180 to 180 with 0 at North
      % expected data is assumed to be +ccw from South, -180 to 180
      phi0 = int16(180) - data.solar_azimuth(isData);
      data.solar_azimuth = [];
      phi0(phi0 > 180) = phi0(phi0 > 180) - 360;
      % Based on conversation with Dozier, Aug 2023:
      % N.B.: phi0 and aspect must be referenced to the same
      % angular convention for this function to work properly
      muZ = Mosaic.sunslope(mu0, single(phi0), single(slope(isData)), ...
          single(aspect(isData)));
      mu0 = [];
      phi0 = [];
      muZ(muZ > 1.0) = 1.0; % 2024-01-05, occasionally ParBal.sunslope()
          % returns a few 10-16 higher than 1 (h24v05, 2011/01/08)
          % Patch should be inserted in ParBal.sunslope().
      
      varName = 'albedo_muZ_s';
      data.(varName) = intmax('uint8') * ones(size(slope), 'uint8');
      data.(varName)(isData) = uint8( ...
          albedoForcingCalculator.dirtyAlbedoGriddedInterpolant( ...
          muZ, muZ, data.grain_size_s, ...
          data.dust_concentration_s, single(sootFraction)) * 100);
      % cosOfSolarZenith: mu0, cosOfIllumination = muI, grainSize: radius,
      % dustFraction: LAPfraction(1) in Jeff function.
      fprintf('%s-%s: Albedo step 5 in %.2f mins.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60);
      tic
      for dateBlockIdx = 1:countOfDateBlocks
        thoseDateIndices = ((dateBlockIdx - 1) * S.pool.NumWorkers + 1) : ...
          min((dateBlockIdx) * S.pool.NumWorkers, length(theseDates));
        thatData = data.(varName)(:, :, thoseDateIndices);
        thoseDates = theseDates(thoseDateIndices);
        
        parfor dateIdx = 1:length(thoseDates)
          thisDate = thoseDates(dateIdx);
          espEnv.saveData(thatData(:, :, dateIdx), objectName, ...
          outputDataLabel, theseDate = thisDate, varName = varName);
        end
      end
      data.(varName) = [];
      fprintf('%s-%s: Data saved in %.2f mins, variable %s.\n\n', ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60, varName);
      
      fprintf(['%s-%s: Albedo/radiative forcing/deltavis ', ...
          'determined in %.2f mins.\n\n'], ...
          thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
          toc(albedoCalculatorTimer) / 60);
%{
      TEMPORARY DEACTIVATE 20241209.
      tic
      parfor fileIdx = 1:numel(outputFilePath)
        thisMatfile = matfile(outputFilePath{fileIdx}, Writable = true);
        for varIdx = 1:height(albedoVariable)
            varName = albedoVariable.name{varIdx};
            thisMatfile.([varName '_type']) = ...
                albedoVariable.type{varIdx};
            thisMatfile.([varName '_units']) = ...
                albedoVariable.unit{varIdx};
            thisMatfile.([varName '_multiplicator_for_mosaics']) = ...
                albedoVariable.multiplicator_for_mosaics(varIdx);
            thisMatfile.([varName '_divisor']) = ...
                albedoVariable.divisor(varIdx);
            thisMatfile.([varName '_min']) = albedoVariable.min(varIdx) * ...
                albedoVariable.divisor(varIdx);
            thisMatfile.([varName '_max']) = albedoVariable.max(varIdx) * ...
                albedoVariable.divisor(varIdx);
            thisMatfile.([varName '_nodata_value']) = ...
                albedoVariable.nodata_value(varIdx);
        end% for varIdx.
      end
      fprintf(['%s-%s: Metadata updated in %.2f mins.\n\n'], ...
        thisFunctionCode, char(thisDate, 'yyyyMMdd'), ...
        toc / 60);
%}
      fprintf('%s: Done in %.2f mins.\n\n', ...
          thisFunctionCode, toc(thisTimer) / 60);
    end
  end % methods.
end
