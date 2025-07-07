classdef DailyDataVisualizer
  % Handles the daily mosaic files that join tiles together
  % for an upper-level region and provide the values
  % for variables required to generate the data expected by the SnowToday
  % website
  %
%{
  % Use Case for landsat (swiss).
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % output visualization files are in the same directory tree, with folder visualization
  % instead of output.
  addpath(genpath(getenv('matlabPathForESPToolbox')));
  regionShortName = '068014'; %'042034'; % '194027';
  regionName = 'p068r014'; %'p042r034';
  varName = 'snow';
  years = 2020:2023;
  archivePath = getenv('espArchiveDirNrt');
  scratchPath = getenv('slurmScratchDir1');
  inputProducts = {'lc08.l2sp', 'lc09.l2sp'};
  inputProductVersions = {'02.t1', '02.t1'};
  label = 'v2024.0';
  versionOfAncillary = 'v3.2';
  inputProductIdx = 1;
  inputProduct = inputProducts{inputProductIdx};
  inputProductVersion = inputProductVersions{inputProductIdx};

  modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary, ...
        inputProduct = inputProduct, inputProductVersion = inputProductVersion);
  espEnv = ESPEnv(modisData, scratchPath = scratchPath, ...
    archivePath = archivePath);
  region = Regions(regionName, '', espEnv, modisData);

  filePathPattern = [getenv('espScratchDir'), inputProductAndVersion, ...
    '/scagdrfs/v2024.0/output/', ...
    regionShortName, '/', num2str(thisYear), '/*', varName, '.tif'];
  [status, cmdout] = ...
    system(['ls ', filePathPattern]);
  filePaths = splitlines(cmdout);
  
  dailyDataVisualizer = DailyDataVisualizer(region);
  for fileIdx = 1:length(filePaths)
    filePathForSnowFractionTif = filePaths{fileIdx};
    if ~isempty(filePathForSnowFractionTif)
      dailyDataVisualizer.generatePngForDailyLandsatScagTif( ...
        filePathForSnowFractionTif, visible = 1);
    end
    close;
  end
%}

  properties (Constant)
    colormapDir = fullfile(getenv('espProjectDir'), 'tbx', 'colormaps'); % to put ancillary elsewhere @todo
    maximalReflectanceValueForRGB = 100  % used to adjust for contrast.
      % Reflectance > 160 are highly reflective material due to a few restrictive
      % reasons included strikelights.
    reflectanceBandsForRGB = {'reflectance_6_1628_1652', ...
      'reflectance_1_620_670', 'reflectance_3_459_479'};
      % NB: Order is important.                                                 @warning
  end
  properties
    region % Regions obj.
    webColorMaps % struct containing all color maps.
  end

  methods
    function obj = DailyDataVisualizer(region)
      % Constructor.
      %
      % Parameters
      % ----------
      % region: Regions obj. With name of the pathrow of the landsat scene.
      %   E.g. for p042r034.
      %
      % Return
      % ------
      % obj: albedoInversorForLc.
      obj.region = region;
      webColorMaps = struct();
      filePath = getenv('webColorMapFilePathInJson');
      thoseColorMaps = jsondecode(fileread(filePath));
      colorIds = fieldnames(thoseColorMaps);
      for colorIdx = 1:length(colorIds)
        colorId = colorIds{colorIdx};
        x = [1:(256 / (height(thoseColorMaps.(colorId).colors) - 1)):256, 256];
        y = thoseColorMaps.(colorId).colors / 256;
        targetX = 1:256;
        webColorMaps.(colorId) = interp1(x, y, targetX);
        webColorMaps.(colorId)(1, :) = [230, 226, 221] / 255;
        webColorMaps.(colorId)(end, :) = [0, 0, 0]; 
      end
      obj.webColorMaps = webColorMaps;
    end
    function [ S ] = generatePngForDailyLandsatScagTif(obj, filePathForSnowFractionTif, ...
      varargin)
      % Former browseTmscag() by Mary Jo and Karl
      %browseTmscag makes browse image of Landsat RGB and TMscag snow/veg/rock
      % The visualization files are saved in a visualization folder at the level of the output folder in lc08.l2sp.02.t1/scagdrfs/v2024.0/output
      %
      % Input
      %   filePathForSnowFractionTif - TMscag snow/veg/rock image files filePathForSnowFractionTif
      %     % e.g. [getenv('espScratchDir'), 'lc08.l2sp.02.t1/scagdrfs/v2024.0/output/194027/2024/LC08_L2SP_194027_20240205_20240212_02_T1.snow.tif']
      %   doSave, optional - if true (default), do save output png
      %   saturationRange, optional - 2 element array of low and high saturation bounds,
      %         in range [0. 1.], default is 2% saturation, or [0.01 0.99]
      %   xRangeForImageSubset - [int, int]. Default [1, nCols]. 2-element vector with sample begin end range to subset [minColId, maxColId].
      %   yRangeForImageSubset - [int, int]. Default [1, nRows]. 2-element vector with line begin end range to subset [minRowId, maxRowId].
      %   savingResolution: int.
      %   visible: int. 0, default, figure will not display and is only saved. 1: figure
      %     will display.
      % Optional Input
      %
      % Output
      %   Browse png image with RGB, fSCA, fVEG, fROCK
      %   Structure with status of commands
      %   S.status = 0 success, nonzero otherwise
      %
      % Notes
      %
      % Example
      % TBD
      %
      %  Copyright 2019 The Regents of the University of Colorado

      % Optionals parameters handling....

      saturationRange = [0.01 0.99];
      doSave = true;
      xRangeForImageSubset = 0;
      yRangeForImageSubset = 0;
      visible = 0;
      p = inputParser;
      addParameter(p, 'saturationRange', saturationRange);
      addParameter(p, 'doSave', doSave);
      addParameter(p, 'xRangeForImageSubset', xRangeForImageSubset);
      addParameter(p, 'yRangeForImageSubset', yRangeForImageSubset);
      addParameter(p, 'visible', visible);
      p.StructExpand = false;
      parse(p, varargin{:});
      saturationRange = p.Results.saturationRange;
      doSave = p.Results.doSave;
      xRangeForImageSubset = p.Results.xRangeForImageSubset;
      yRangeForImageSubset = p.Results.yRangeForImageSubset;
      visible = p.Results.visible;

      S.status = 0;

      % Parse the filePathForSnowFractionTif for date
      % Assumes it is the first occurrence of this kind of string
      tokenNames = regexp(filePathForSnowFractionTif, ...
          ['(?<yyyy>\d{4})(?<mm>\d{2})(?<dd>\d{2})'],...
      'names', 'once');
      dateStrFilename = sprintf('%s%s%s', tokenNames.yyyy, tokenNames.mm, ...
        tokenNames.dd);
      dateStr = sprintf('%s-%s-%s', tokenNames.yyyy, tokenNames.mm, ...
        tokenNames.dd);

      % Read and partition the fractional colormaps
      m = obj.getColorMap('cmap_fractions');
      cmap_rock = obj.partitionColorMap(m.cmap_rock);
      cmap_sca = obj.partitionColorMap(m.cmap_sca);
      cmap_veg = obj.partitionColorMap(m.cmap_veg);
      cmap_gs = obj.partitionColorMap(m.cmap_gs);
      cmap_albedo = obj.partitionColorMap(m.cmap_albedo);

      cmap_gray = flipud(colormap('gray'));
      close
      cmap_gray = obj.partitionColorMap(cmap_gray);

      % Set zero in gray images to yellow
      cmap_gray(1, :) = [1., 1., 0.];

      % Read TMscag images for snow, veg, rock
      version = 2024;
      info.filetype = {'RGB', 'shade_f', 'snow_f', 'veg_f', 'rock_f', ...
        'other_f', 'grain_size', 'albedo_cle_mu0', 'albedo_obs_mu0'};
      info.picfiletype = {'bip', 'shade.tif', 'snow.tif', 'veg.tif', 'rock.tif', ...
        'other.tif', 'grnsz.tif', 'albedo_clean_mu0.tif', 'albedo_observed_mu0.tif'};
      info.fileFolder = {'intermediary', 'output', 'output', 'output', 'output', ...
        'output', 'output', 'output', 'output'};
      info.cmap = {NaN, cmap_gray, cmap_sca, cmap_veg, cmap_rock, ...
        cmap_sca, cmap_gs, cmap_albedo, cmap_albedo};
      info.maxValue = [NaN, 100., 100., 100., 100., 100., 1100.0, 100., 100.];
      info.colorScaleMinValue = [NaN, 0, 0, 0, 0, 0, 0, 55, 55];
      info.colorScaleMaxValue = [NaN, 100., 100., 100., 100., 100., 1100.0, ...
        85., 85.];
      info.colorMapId = {'', '', 'x6', '', '', '', 'x3', 'x1', 'x1'};

      plotRows = 1;
      plotCols = numel(info.filetype);
      thisFigure = figure(Units = 'pixels', ...
        Position = [0, 0, (plotCols * 400), (plotRows * 400)], visible = visible);
      titleFontSize = 12;

      tiledlayout(plotRows, plotCols, Padding = 'loose', TileSpacing = 'compact');
      % output Directory.
      outputDirectoryPath = replace(fileparts(filePathForSnowFractionTif), ...
        'output', 'visualization');
      if ~isdir(outputDirectoryPath)
        mkdir(outputDirectoryPath);
      end
      % extracting rows/columns from landsat bip.meta file.
      countOfRows = 0;
      countOfColumns = 0;
      thisFilePath = replace(replace(filePathForSnowFractionTif, 'snow.tif', 'bip.meta'), ...
        'output', 'intermediary');
      
      [status, cmdout] = system(['cat ', thisFilePath, ' | grep NLINES | cut -d ''='' -f 2']);
      countOfRows = str2num(cmdout);
      if yRangeForImageSubset == 0
        yRangeForImageSubset = [1, countOfRows];
      end
      [status, cmdout] = system(['cat ', thisFilePath, ' | grep NSAMPLES | cut -d ''='' -f 2']);
      countOfColumns = str2num(cmdout);
      if xRangeForImageSubset == 0
        xRangeForImageSubset = [1, countOfColumns];
      end
      for varIdx = 1:numel(info.filetype)
        % Set up next tile position
        j = 1;
        nexttile(((j - 1) * plotCols) + varIdx);
        thisFilePath = replace(replace(filePathForSnowFractionTif, 'snow.tif', info.picfiletype{varIdx}), ...
          'output', info.fileFolder{varIdx});
        fprintf('Handling file %s...\n', thisFilePath);

        if (strcmp(info.filetype{varIdx}, 'RGB'))
          % bip file is one directory up from pic images

          fprintf('%s: reading bip=%s for RGB...\n', ...
          mfilename(), thisFilePath);
          rgb = obj.readBandsRGB( ...
          thisFilePath, countOfRows, countOfColumns, [6 4 2], ...
                  saturationRange);
          rgb = rgb(yRangeForImageSubset(1):yRangeForImageSubset(2), xRangeForImageSubset(1):xRangeForImageSubset(2), :);
          im = image(rgb);
          axis image;
          axis off;
          title([info.filetype{varIdx} ' ' dateStr], ...
          'FontSize', titleFontSize);
        else
          data = readgeoraster(thisFilePath);
          if varIdx == 3
            data(data < 10) = 0;
            snowEqualsZero = data == 0;
            snowIsNoData = data == 255;
          end
          if varIdx == 7
            data(data == 0) = 1;
          end
          if varIdx >= 7
            data(snowEqualsZero | (~snowEqualsZero & ~snowIsNoData & data == intmax(class(data)))) = 0;
          end
          fprintf('%s: %s min=%6.2f, max=%6.2f\n', mfilename(), ...
          info.filetype{varIdx}, min(data(:)), max(data(:)));

          % scale the image here
          maxValue = info.maxValue(varIdx);
          colorScaleMinValue = info.colorScaleMinValue(varIdx);
          colorScaleMaxValue = info.colorScaleMaxValue(varIdx);
          scImg = obj.scaleDataToColorMap(data, ...
            colorScaleMinValue, colorScaleMaxValue);

          % Plot
          if ~ismember(info.colorMapId{varIdx}, {''})
            thisCmap = obj.webColorMaps.(info.colorMapId{varIdx});
          else
            thisCmap = info.cmap{varIdx};
          end
          im = imshow(scImg, thisCmap);
          cb = colorbar('southoutside', Ticks = [2, 250], ...
            Ticklabels = {num2str(colorScaleMinValue), ...
              num2str(colorScaleMaxValue)}, ...
            FontSize = uint8(0.9 * titleFontSize));
          set(cb, 'ylim', [2 250]);
          thisTitle = replace([info.filetype{varIdx} ' %'], '_', '\_');
          set(get(cb, 'title'), 'string', thisTitle);
          %title([info.filetype{varIdx}, ' ', dateStr], ...
          % 'FontSize', titleFontSize);
        end
      end

      if (doSave)
        [~, name, ~] = fileparts(filePathForSnowFractionTif);
        outFilename = fullfile(outputDirectoryPath, ...
          sprintf("%s.dailyvisu.v%02d.png", replace(name, '.snow', ''), version));
        exportgraphics(thisFigure, outFilename, 'Resolution', 1200);
        % print(gcf, outFilename, '-dpng', '-r300');
        fprintf("%s: saved visualization to: %s\n", mfilename(), outFilename);

        %close all;
      end
    end
    function m = getColorMap(obj, colormapName)
      % colormap reads and returns the color map from the given file

      f = dir(fullfile(obj.colormapDir, ...
        sprintf('%s.mat', colormapName)));
      m = load(fullfile(f.folder, f.name));
    end
    function thisCmap = partitionColorMap(obj, thisCmap)
      %partitionColorMap partitions cmap with gray/black/red/white
      %
      % Input
      %   thisCmap = 256x3 colormap
      %
      % Optional Input: n/a
      %
      % Output
      %   Partitioned colormap will shift first 249 values 
      %   indices [1, 249] by 1 index (to [2, 250]), and will
      %   assign fixed values at ends:
      %   index     to
      %   1         gray
      %   251       white 
      %   252       black
      %   253       yellow
      %   254       red
      %   255       blue
      %   256       lightgray
      %
      % Notes:
      %   To limit the range of values in a displayed colorbar,
      %   use:
      %   im = imshow(...)
      %   cb = colorbar(im, ...);
      %   set(cb, 'ylim', [1 250])
      %
      % Example
      % 

      % Parse inputs
      p = inputParser;

      cmapValidation = @(x) isnumeric(x);
      addRequired(p, 'thisCmap', cmapValidation);

      p.KeepUnmatched = true;
      parse(p, thisCmap);

      if ~all(size(p.Results.thisCmap) == [256 3])
          error('partitionColorMap:InputError', ...
                'Unexpected input thisCmap dimensions');
      end
      thisCmap(1, :) = [230, 226, 221] / 255;
      thisCmap(end, :) = [0, 0, 0];
%{
      black = [0 0 0];
      white = [1 1 1];
      lightgray = [0.75 0.75 0.75];
      gray  = [0.5 0.5 0.5];
      red = [1 0 0];
      yellow = [1 1 0];
      blue = [0 0 1];

      partCmap = zeros([256 3]);
      partCmap(1, :) = gray;
      partCmap(2:250, :) = thisCmap(1:249, :);
      partCmap(251, :) = white;
      partCmap(252, :) = black;
      partCmap(253, :) = yellow;
      partCmap(254, :) = red;
      partCmap(255, :) = blue;
      partCmap(256, :) = lightgray;
%}
    end
    function rgb = readBandsRGB(obj, fileName, countOfRows, countOfColumns, bands, saturationRange)
      % readBandRGB - reads selected set of bands
      %
      % Input
      %   fileName - fileName to read, e.g. base.bip
      %   countOfRows - number of lines
      %   countOfColumns - number samples
      %   bands - 3 element array of bands to read for rgb
      %   saturationRange - 2 element array of low and high saturation bounds,
      %         in range [0. 1.], default is 2% saturation, or [0.01 0.99]
      %
      % Optional Input
      %
      % Output
      %   3-D Matrix with transposed 3-band image, scaled for
      %   adjusted contrast
      %
      % Notes
      %
      % Example
      % TBD
      %
      %  Copyright 2021 The Regents of the University of Colorado

      nbands = 6;
      rgb = multibandread(fileName, [countOfRows, countOfColumns, nbands], ...
      '*int16', 0, 'bip', 'ieee-le', ...
      {'Band', 'Direct', bands});

      % Adjust for contrast
      % Convert to floats in range 0-1
      Rs_scale = 1000.;
      rgb = single(rgb) / Rs_scale;

      % Stretch requested input range to full range of outputs
      lowHigh = stretchlim(rgb, saturationRange);
      rgb = imadjust(rgb, lowHigh, []);
    end
    function data = scaleDataToColorMap(obj, data, ...
      colorScaleMinValue, colorScaleMaxValue)
      %scaleRawFractionImage scales raw image to uint8 by correcting unexpected things
      % observed for albedo and removing all the nodata stuff...
      %
      % Input
      %   data = numeric matrix, with data values 0.0 - maxValue, possible
      %          NaNs and possible negative values
      % - colorScaleMinValue: double. All values below this value are colored the min
      %   color of the scale.
      % - colorScaleMaxValue: double. All values above this value are colored the max
      %   color of the scale.
      % Optional Input: n/a
      %
      % Output
      %   Scaled uint8 data will be suitable to display with
      %   cmap_fractions colormaps (cmap_sca, cmap_veg,
      %       cmap_rock, etc)
      %   
      %   Any Zeros, Nans and all negative values will be set to flag
      %   values.
      %   Data values in the closed interval [0.0, maxValue] will be
      %       scaled to [2, 250]
      %
      % Notes:
      %
      % Example
      % scImage = scaleRawFractionImage(fsca, 1.0)
      % 

      isNoData = data == intmax(class(data));
      data(data > colorScaleMaxValue & ~isNoData) = colorScaleMaxValue;
      data(data < colorScaleMinValue) = colorScaleMinValue;

      % Scale
      data(~isNoData) = uint8(254 * (double(data(~isNoData) - colorScaleMinValue) / ...
        double(colorScaleMaxValue - colorScaleMinValue)));
      data(isNoData) = 255;
    end
  end
end
