classdef DailyDataVisualizer
  % Handles the daily mosaic files that join tiles together
  % for an upper-level region and provide the values
  % for variables required to generate the data expected by the SnowToday
  % website
  %
%{
  % Use Case for landsat (swiss).
  % output visualization files are in the same directory tree, with folder visualization
  % instead of output.

  [status, cmdout] = ...
    system('ls /scratch/alpine/sele7124/*/scagdrfs/v2024.0/output/194027/2024/*snow*');
  filePaths = splitlines(cmdout);
  for fileIdx = 1:length(filePaths)
    filePathForSnowFractionTif = filePaths{fileIdx};
    if ~isempty(filePathForSnowFractionTif)
      DailyDataVisualizer.generatePngForDailyLandsatScagTif(filePathForSnowFractionTif);
    end
    close;
  end
%}
  properties (Constant)
    colormapDir = fullfile(getenv('espProjectDir'), 'tbx', 'colormaps'); % to put ancillary elsewhere @todo
  end

  methods (Static)
    function [ S ] = generatePngForDailyLandsatScagTif(filePathForSnowFractionTif, ...
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
      p = inputParser;
      addParameter(p, 'saturationRange', saturationRange);
      addParameter(p, 'doSave', doSave);
      addParameter(p, 'xRangeForImageSubset', xRangeForImageSubset);
      addParameter(p, 'yRangeForImageSubset', yRangeForImageSubset);
      p.StructExpand = false;
      parse(p, varargin{:});
      saturationRange = p.Results.saturationRange;
      doSave = p.Results.doSave;
      xRangeForImageSubset = p.Results.xRangeForImageSubset;
      yRangeForImageSubset = p.Results.yRangeForImageSubset;

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
      m = DailyDataVisualizer.getColorMap('cmap_fractions');
      cmap_rock = DailyDataVisualizer.partitionColorMap(m.cmap_rock);
      cmap_sca = DailyDataVisualizer.partitionColorMap(m.cmap_sca);
      cmap_veg = DailyDataVisualizer.partitionColorMap(m.cmap_veg);
      cmap_gs = DailyDataVisualizer.partitionColorMap(m.cmap_gs);
      cmap_albedo = DailyDataVisualizer.partitionColorMap(m.cmap_albedo);

      cmap_gray = flipud(colormap('gray'));
      close
      cmap_gray = DailyDataVisualizer.partitionColorMap(cmap_gray);

      % Set zero in gray images to yellow
      cmap_gray(1, :) = [1., 1., 0.];

      % Read TMscag images for snow, veg, rock
      version = 2024;
      info.filetype = {'RGB', 'shade', 'fSCA', 'fVEG', 'fROCK', ...
        'fOther', 'grSize', 'albedo_clean_mu0', 'albedo_observed_mu0'};
      info.picfiletype = {'bip', 'shade.tif', 'snow.tif', 'veg.tif', 'rock.tif', ...
        'other.tif', 'grnsz.tif', 'albedo_clean_mu0.tif', 'albedo_observed_mu0.tif'};
      info.fileFolder = {'intermediary', 'output', 'output', 'output', 'output', ...
        'output', 'output', 'output', 'output'};
      info.cmap = {NaN, cmap_gray, cmap_sca, cmap_veg, cmap_rock, ...
        cmap_sca, cmap_gs, cmap_albedo, cmap_albedo};
      info.maxValue = {NaN, 100., 100., 100., 100., 100., 1100.0, 100., 100.};

      plotRows = 1;
      plotCols = numel(info.filetype);
      figure(Units = 'pixels', Position = [0, 0, (plotCols * 400), (plotRows * 400)]);
      titleFontSize = 12;

      tiledlayout(plotRows, plotCols, Padding = 'none', TileSpacing = 'compact');
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
          rgb = DailyDataVisualizer.readBandsRGB( ...
          thisFilePath, countOfRows, countOfColumns, [6 4 2], ...
                  saturationRange);
          rgb = rgb(yRangeForImageSubset(1):yRangeForImageSubset(2), xRangeForImageSubset(1):xRangeForImageSubset(2), :);
          im = image(rgb);
          axis image;
          axis off;
          title([info.filetype{varIdx} ' ' dateStr], ...
          'FontSize', titleFontSize);

        else
%{
          img = DailyDataVisualizer.readTmscag(thisFilePath, countOfRows, countOfColumns);
%}
          img = readgeoraster(thisFilePath);

          fprintf('%s: %s min=%6.2f, max=%6.2f\n', mfilename(), ...
          info.filetype{varIdx}, min(img(:)), max(img(:)));

          % scale the image here
          scImg = DailyDataVisualizer.scaleRawFractionImage(img, info.maxValue{varIdx});

          % Plot
          im = imshow(scImg, info.cmap{varIdx});
          cb = colorbar('southoutside', Ticks = [2, 250], ...
            Ticklabels = {'0', string(info.maxValue{varIdx})}, ...
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
          sprintf("%s.dailyvisu.v%02d.png", name, version));
        print(gcf, outFilename, '-dpng', '-r300');
        fprintf("%s: saved visualization to: %s\n", mfilename(), outFilename);

        %close all;
      end
    end
    function m = getColorMap(colormapName)
      % colormap reads and returns the color map from the given file

      f = dir(fullfile(DailyDataVisualizer.colormapDir, ...
        sprintf('%s.mat', colormapName)));
      m = load(fullfile(f.folder, f.name));
    end
    function partCmap = partitionColorMap(cmap)
      %partitionColorMap partitions cmap with gray/black/red/white
      %
      % Input
      %   cmap = 256x3 colormap
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
      addRequired(p, 'cmap', cmapValidation);

      p.KeepUnmatched = true;
      parse(p, cmap);

      if ~all(size(p.Results.cmap) == [256 3])
          error('partitionColorMap:InputError', ...
                'Unexpected input cmap dimensions');
      end

      black = [0 0 0];
      white = [1 1 1];
      lightgray = [0.75 0.75 0.75];
      gray  = [0.5 0.5 0.5];
      red = [1 0 0];
      yellow = [1 1 0];
      blue = [0 0 1];

      partCmap = zeros([256 3]);
      partCmap(1, :) = gray;
      partCmap(2:250, :) = cmap(1:249, :);
      partCmap(251, :) = white;
      partCmap(252, :) = black;
      partCmap(253, :) = yellow;
      partCmap(254, :) = red;
      partCmap(255, :) = blue;
      partCmap(256, :) = lightgray;
    end
    function rgb = readBandsRGB(fileName, countOfRows, countOfColumns, bands, saturationRange)
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
%{
    function img = readTmscag(fileName, countOfRows, countOfColumns)
      %readTmscag reads a binary TMscag output .img file
      %
      % Input
      %   fileName - fileName to read, e.g. base.fSCA.img
      %   countOfRows - number of lines
      %   countOfColumns - number samples
      %
      % Optional Input
      %
      % Output
      %   Matrix with transposed image
      %
      % Notes
      %
      % Example
      % TBD
      %
      %  Copyright 2021 The Regents of the University of Colorado

      % Determine the element type by the file extension and contents
      [ ~, base, ext ] = fileparts(fileName);
      [ ~, ~, filetype ] = fileparts(base);
      datatype = 'uint8';
      if strcmp(filetype, '.grnsz')
        datatype = 'uint16';
      end
%{
      if ( strcmp( ext, '.pic' ) )
        datatype = 'float';
      elseif ( strcmp( ext, '.bin' ))
        datatype = 'uint8';
        % grain size is 16-bit
        if ( strcmp ( filetype, '.grnsz' ) )
        datatype = 'uint16';
        end
      end
%}
      
      precision = [datatype '=>' datatype];

      fprintf("%s: reading %s as %s...\n", mfilename(), fileName, datatype);

      % Swap rows/cols on read and then transpose back to expected dims
      fileID = fopen(fileName, 'r');
      img = fread(fileID, [countOfColumns countOfRows], precision);
      fclose(fileID);
      img = img';
    end
%}
    function [sdata, flagVal] = scaleRawFractionImage(data, maxValue)
      %scaleRawFractionImage scales raw image to uint8 
      %
      % Input
      %   data = numeric matrix, with data values 0.0 - maxValue, possible
      %          NaNs and possible negative values
      %   maxValue = maximum valid value in data
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

      %  Copyright 2019 The Regents of the University of Colorado

      % Parse inputs
      p = inputParser;

      dataValidation = @(x) isnumeric(x) || islogical(x);
      addRequired(p, 'data', dataValidation);

      maxValueValidation = @(x) isnumeric(x);
      addRequired(p, 'maxValue', maxValueValidation);

      p.KeepUnmatched = true;
      parse(p, data, maxValue);

      % Define index flags
      zeroIndex = 1;
      maxIndex = 250; % top valid index
      lowIndex = 255; % data too low
      highIndex = 254; % data too high
      missingIndex = 253; % data missing

      % Save locations with special values
      % Assume missing is NaN for floats, or maxInt for integer types
      if any( strcmp(class(data), {'single', 'double'}) )
      fprintf('%s: assuming Nans for missing...\n', mfilename());
      missingMask = isnan(data);
      else
      missingValue = intmax(class(data));
      fprintf('%s: assuming %d for missing...\n', mfilename(), ...
      missingValue);
      missingMask = data == missingValue;
      end

      lowMask = data < 0.;
      zeroMask = data == 0;
      highMask = data > maxValue;

      % Set all special values to zero
      data(missingMask | lowMask | zeroMask | highMask) = 0;

      % Scale the rest into [2, maxIndex]
      sdata = uint8((maxIndex - 2) * (double(data)/double(maxValue))) + 2;

      % Order is important, here, since, for integer types the
      % missing value will be in range and needs to be set last
      sdata(lowMask) = lowIndex;
      sdata(zeroMask) = zeroIndex;
      sdata(highMask) = highIndex;
      sdata(missingMask) = missingIndex;

      % at this point, the ROV of the scaled image is 1-255
      % But the index into the cmap array will be 1 above these values,
      % which will not be the color I intend
      % so subtract 1
      sdata = sdata - 1;
      flagVal.missingIndex = missingIndex;
      flagVal.zeroIndex = zeroIndex;
      flagVal.lowIndex = lowIndex;
      flagVal.highIndex = highIndex;

      numMissing = sum(missingMask(:));
      numLow = sum(lowMask(:));
      numZeros = sum(zeroMask(:));
      numHigh = sum(highMask(:));
      if numMissing > 0
        fprintf('%s: %d missing values are mapped to scaled value %d\n', ...
          mfilename(), numMissing, flagVal.missingIndex - 1);
      end
      if numLow > 0
        fprintf('%s: %d low values are mapped to scaled value %d\n', ...
        mfilename(), numLow, flagVal.lowIndex - 1);
      end
      if numZeros > 0
        fprintf('%s: %d zero values are mapped to scaled value %d\n', ...
          mfilename(), numZeros, flagVal.zeroIndex - 1);
      end
      if numHigh > 0
        fprintf('%s: %d values > %d are mapped to scaled value %d\n', ...
          mfilename(), numHigh, maxValue, flagVal.highIndex - 1);
      end
    end
  end
end
