classdef ESPEnv
    % ESPEnv - environment for ESP data directories
    %   Directories with locations of various types of data needed for ESP
   properties
      colormapDir    % directory with color maps
      mappingDir     % directory with MODIS tiles projection information
      shapefileDir     % directory with MODIS tiles projection information
      extentDir      % directory with geographic extent definitions
      confDir         % directory with configuration files (including variable names)
      regionMaskDir  % directory with region mask ids files
      heightmaskDir  % directory heightmask for Landsat canopy corrections
      MODISDir       % directory with MODIS scag STC cubes from UCSB (.mat)
      LandsatDir     % directory with Landsat scag images
      LandsatResampledDir % directory with resample Landsat images
      viirsDir       % directory with TBD for VIIRS
      watermaskDir   % directory with water mask
      modisWatermaskDir   % directory with MODIS watermask files
      modisForestDir      % directory with MODIS canopy corrections
      modisElevationDir   % directory with MODIS DEMs
      modisTopographyDir  % directory with MODIS topography files
      MODICEDir      % directory with (annual) MODICE data
             % by tile/year (.hdr/.dat, .tif)
      dirWith % struct with various STC pipeline directories
   end
   methods
       function obj = ESPEnv(varargin)
           % The ESPEnv constructor initializes all directory settings
           % based on locale

           p = inputParser;

           defaultHostName = 'CURC';
           validHostNames = {'CURC', 'CURCScratchAlpine'};
           checkHostName = @(x) any(validatestring(x, validHostNames));
           addOptional(p, 'hostName', defaultHostName, ...
               checkHostName);

           p.KeepUnmatched = false;
           parse(p, varargin{:});

           if contains(p.Results.hostName, 'CURC')
           % Default path is relative to this file, 2 levels up
               [path, ~, ~] = fileparts(mfilename('fullpath'));
               parts = split(path, filesep);

               % 1 level up
               path = join(parts(1:end-1), filesep);

               obj.colormapDir = fullfile(path, 'colormaps');
               obj.mappingDir = fullfile(path, 'mapping');
               obj.extentDir = fullfile(path, 'StudyExtents');
               obj.confDir = fullfile(path, 'conf');

               % For Data Fusion stuff, paths are on PetaLibrary
               path = fullfile('/pl', 'active', 'rittger_esp');
               obj.MODISDir = fullfile(path, ...
           'scag', 'MODIS', 'SSN', 'v01');

               obj.viirsDir = fullfile(path, 'viirs');
               obj.watermaskDir = fullfile(path, 'landcover', 'NLCD_ucsb');
               obj.LandsatDir = fullfile(path, 'Landsat_test');
               obj.LandsatResampledDir = fullfile(path, ...
               'Landsat_test', 'Landsat8_resampled');
               obj.heightmaskDir = fullfile(path, ...
                   'SierraBighorn', 'landcover', 'LandFireEVH_ucsb');
               obj.MODICEDir = fullfile(path, 'modis', 'modice');
               
               obj.regionMaskDir = fullfile(path, ...
                    'region_masks', 'v3');

               % For ESP pipelines, set scratch locations
           if strcmp(p.Results.hostName, 'CURCScratchAlpine')
                   path = fullfile('/scratch', 'alpine', getenv('USER'));
           end

               obj.modisWatermaskDir = fullfile(path, 'landcover');
               obj.modisForestDir = fullfile(path, 'forest_height');
               obj.modisElevationDir = fullfile(path, 'elevation');
               obj.modisTopographyDir = fullfile(path, 'topography');
               obj.shapefileDir = fullfile(path, 'shapefiles');

               path = fullfile(path, 'modis');

           % In practice, these directories will be
           % appended with labels from MODISData class
               obj.dirWith = struct(...
                   'MOD09Raw', fullfile(path, 'mod09_raw'), ...
                   'SCAGDRFSRaw', fullfile(path, 'scagdrfs_raw'), ...
                   'SCAGDRFSGap', fullfile(path, 'scagdrfs_gap'), ...
                   'SCAGDRFSSTC', fullfile(path, 'scagdrfs_stc'), ...
                   'SCAGDRFSDaily', fullfile(path, 'scagdrfs'), ...
                   'publicFTP', ...
           fullfile('/pl', 'active', ...
                'rittger_esp_public', ...
                'snow-today'), ...
                   'csv_output', fullfile(path, 'output', 'csv'));

       else
           fprintf(['%s: Unrecognized host=%s, ' ...
               'cannot set expected paths\n'], ...
               mfilename(), p.Results.hostName);

           end

           % Convert these from 1x1 cells to plain char arrays
           props = properties(obj);
           for i = 1:length(props)
               if iscell(obj.(props{i}))
                   obj.(props{i}) = obj.(props{i}){1};
               end
           end

       end

       function f = LandsatScagDirs(obj, platform, path, row, varargin)
           % LandsatFile returns list of Landsat scag directories for platform/path/row
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.LandsatDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           platformStr = sprintf('Landsat%1i', platform);
           pathRowStr = sprintf('p%03ir%03i', path, row);

           f = dir(fullfile(myDir, ...
               platformStr, ...
               pathRowStr, ...
               'LC*'));

       end

       function f = MODISFile(obj, varargin)
           % MODISFile returns a list of MODIS STC cube files
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.MODISDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, '*_*Y*.mat'));

       end

       function f = MOD09File(obj, MData, regionName, yr, mm)
           % MOD09File returns the name of a monthly MOD09 cubefile
       myDir = sprintf('%s_%s', obj.dirWith.MOD09Raw, ...
               MData.versionOf.MOD09Raw);

           %TODO: make this an optional input
           platformName = 'Terra';
           yyyymm = sprintf('%04d%02d', yr, mm);

           f = fullfile(myDir, ...
            sprintf('v%03d', MData.versionOf.MODISCollection), ...
            sprintf('%s', regionName), ...
            sprintf('%04d', yr), ...
            sprintf('RawMOD09_%s_%s_%s.mat', ...
                platformName, regionName, yyyymm));

       end

       function f = MODICEFile(obj, version, tileID, ...
                  yr, nstrikes, fileType, varargin)

           % MODICEFile returns the name of an annual MODICE tile
           % fileType is one of: 'hdr', 'merged.ice.tif',
           % 'modice_last_update.dat'or 'modice_persistent_ice.dat'
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.MODICEDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           yrStr = sprintf('%04d', yr);
           vStr = sprintf('v%03.1f', version);
           strikeStr = sprintf('%1dstrike', nstrikes);

           f = fullfile(myDir, ...
               vStr, ...
               tileID, ...
               yrStr, ...
               sprintf('MODICE.%s.%s.%s.%s.%s', ...
               vStr, tileID, yrStr, strikeStr, fileType));

       end

       function f = SCAGDRFSFile(obj, MData, regionName, ...
               fileType, yr, mm)
           % SCAGDRFSFile returns the name of a monthly filetype
           % SCAGDRFS cube
           % fileType should be one of obj.dirWith 'SCAGDRFS*' cubes:
           %   SCAGDRFSRaw
           %   SCAGDRFSGap
           %   SCAGDRFSSTC

           myDir = sprintf('%s_%s', obj.dirWith.(fileType), ...
               MData.versionOf.(fileType));

           % use versionOf value for file labelName
           % if it is not empty, prepend a period
           labelName = MData.versionOf.(fileType);
           if ~isempty(labelName)
               labelName = sprintf('.%s', labelName);
           end

           %TODO: make this an optional input
           platformName = 'Terra';
           yyyymm = sprintf('%04d%02d', yr, mm);

           prefix = struct('SCAGDRFSRaw', 'Raw', ...
               'SCAGDRFSGap', 'Gap', ...
               'SCAGDRFSSTC', 'Interp');

           f = fullfile(myDir, ...
               sprintf('v%03d', MData.versionOf.MODISCollection), ...
               sprintf('%s', regionName), ...
               sprintf('%04d', yr), ...
               sprintf('%sSCAG_%s_%s_%s%s.mat', ...
               prefix.(fileType), platformName, ...
               regionName, yyyymm, labelName));

       end

       function f = MosaicFile(obj, MData, regionName, ...
                   yr, mm, dd)
           % MosaicFile returns the name of a daily mosaic image file
       myDir = sprintf('%s_%s', obj.dirWith.SCAGDRFSDaily, ...
               MData.versionOf.SCAGDRFSDaily);

           %TODO: make this an optional input
           platformName = 'Terra';
           yyyymmdd = sprintf('%04d%02d%02d', yr, mm, dd);

           % use versionOf value for file labelName
       % if it is not empty, prepend a period
       labelName = MData.versionOf.SCAGDRFSDaily;
           if ~isempty(labelName)
               labelName = sprintf('.%s', labelName);
           end

           f = fullfile(myDir, ...
               sprintf('v%03d', MData.versionOf.MODISCollection), ...
               sprintf('%s', regionName), ...
               sprintf('%04d', yr), ...
               sprintf('%s_%s_%s%s.mat', ...
               regionName, platformName, yyyymmdd, labelName));

       end

       function f = SummarySnowFile(obj, MData, regionName, ...
           partitionName, startYr, stopYr, doTest)
           % SummarySnowFile returns the name of statistics summary file
       myDir = sprintf('%s_%s', obj.dirWith.SCAGDRFSDaily, ...
               MData.versionOf.SCAGDRFSDaily);

           if doTest
               testDir = 'testRegions';
           else
               testDir = '';
           end

           f = fullfile(myDir, ...
               sprintf('v%03d', MData.versionOf.MODISCollection), ...
               sprintf('%s_statistics', regionName), ...
               testDir, ...
               sprintf('%04d_to_%04d_%sby%s_Summary.mat', ...
               startYr, stopYr, regionName, partitionName));

       end

       function f = SnowTodayFile(obj, MData, ...
               regionName, ...
               shortName, ...
               inputDt, creationDt, labelName, doTest)
           % SnowTodayFile returns the name of a Snow Today
           % map or plot .png file
       myDir = sprintf('%s_%s', obj.dirWith.SCAGDRFSDaily, ...
               MData.versionOf.SCAGDRFSDaily);

           if doTest
               testDir = 'testRegions';
           else
               testDir = '';
           end

           f = fullfile(myDir, ...
               sprintf('v%03d', MData.versionOf.MODISCollection), ...
               sprintf('%s_SnowToday', regionName), ...
               testDir, ...
               shortName, ...
               sprintf('%sinputs_createdOn%s_%s_%s.png', ...
               datestr(inputDt, 'yyyymmdd'), ...
               datestr(creationDt, 'yyyymmdd'), ...
               shortName, ...
               labelName));

       end

       function [files, haveDaysPerMonth, expectedDaysPerMonth] = ...
               rawFilesFor3months(obj, MData, regionName, yr, mm)
           % RawFilesFor3months returns MOD09/SCAGDRFS cubes surrounding
           % this month

           % Look for cubes for previous and subsequent month
           thisMonthDt = datetime(yr, mm, 1);
           priorMonthDt = thisMonthDt - calmonths(1:1);
           nextMonthDt = thisMonthDt + calmonths(1:1);

           Dts = [priorMonthDt, thisMonthDt, nextMonthDt];
           nMonths = length(Dts);
           expectedDaysPerMonth = zeros(nMonths, 1);
           haveDaysPerMonth = zeros(nMonths, 1);
           files = {};
           nextIndex = 1;
           for i=1:nMonths

               thisYYYY = year(Dts(i));
               thisMM = month(Dts(i));
               yyyymm = sprintf('%04d%02d', thisYYYY, thisMM);

               % Save the expected number of days in this month
               expectedDaysPerMonth(i) = eomday(thisYYYY, thisMM);

               % Look for Raw cubes for this month
               mod09file = obj.MOD09File(MData, regionName, thisYYYY, thisMM);
               scagfile = obj.SCAGDRFSFile(MData, regionName, ...
                   'SCAGDRFSRaw', thisYYYY, thisMM);

               if ~isfile(mod09file) || ~isfile(scagfile)

                   % Either prev or next cubes might be missing, but
                   % there must be cubes for this month to continue
                   if thisMonthDt == Dts(i)
                       errorStruct.identifier = ...
                           'rawFilesFor3months:NoDataForRequestedMonth';
                       errorStruct.message = sprintf( ...
                           '%s: %s MOD09 and/or SCAGDRFS cubes missing.', ...
                           mfilename(), yyyymm);
                       error(errorStruct);
                   else
                       fprintf(['%s: %s: No MOD09 or SCAGDRFS cubes ' ...
                           'for adjacent month %s\n'], ...
                           mfilename(), datestr(thisMonthDt), yyyymm);
                       continue;
                   end
               end

               % Get actual number of days in this month with data
               mdata = load(mod09file, 'umdays');
               sdata = load(scagfile, 'usdays');
               nMOD09days = length(mdata.umdays);
               nSCAGdays = length(sdata.usdays);
               if nMOD09days ~= nSCAGdays
                   errorStruct.identifier = ...
                       'rawFilesFor3months:ArchiveError';
                   errorStruct.message = sprintf( ...
                       '%s: %s umdays=%d ~= usdays=%d.', ...
                       mfilename(), yyyymm, nMOD09days, nSCAGdays);
                   error(errorStruct);
               end

               haveDaysPerMonth(i) = nSCAGdays;

               files.MOD09{nextIndex} = mod09file;
               files.SCAGDRFS{nextIndex} = scagfile;
               nextIndex = nextIndex + 1;

           end

       end

       function f = geotiffFile(~, extentName, platformName, sensorName, ...
               baseName, varName, version)
           % builds a geoTiff file name based on the input values

           if (regexpi(platformName, 'Landsat'))

               f = sprintf('%s.%s.%s.v%02d.tif', ...
                   extentName, ...
                   baseName, ...
                   varName, ...
                   version);
           else

               if strcmp(platformName, '')
                   switch sensorName
                       case 'MODIS'
                           platformName = 'Terra';
                       otherwise
                           error("%s: Unknown sensorName=%s", ...
                               mfilename(), sensorName);
                   end
               end

               f = sprintf('%s.%s.%s-%s.%s.v%02d.tif', ...
                   extentName, baseName, ...
                   platformName, sensorName, varName, ...
                   version);

           end

       end

       function m = colormap(obj, colormapName, varargin)
           % colormap reads and returns the color map from the given file

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.colormapDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('%s.mat', colormapName)));
           m = load(fullfile(f.folder, f.name));

       end

       function f = watermaskFile(obj, path, row, varargin)
           % watermaskFile returns a list of water mask file for the given
           % path/row

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.watermaskDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('p%03ir%03i_water.tif', path, row)));

       end

       function f = heightmaskFile(obj)
           % heightmaskFile returns the current height mask file name

           f = dir(fullfile(obj.heightmaskDir, ...
               'Sierra_utm_LandFire_EVH_gt2.5m_mask.tif'));

       end

       function s = heightmask(obj)
           % heightmask reads and returns the height mask

           f = obj.heightmaskFile();
           s.mask = readgeoraster(fullfile(f.folder, f.name));
           s.info = geotiffinfo(fullfile(f.folder, f.name));

       end

       function f = modisForestHeightFile(obj, regionName, varargin)
           % modisForestHeighFile returns forest height file for regionName

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.modisForestDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('%s_CanopyHeight.mat', ...
               regionName)));

           if length(f) ~= 1
               errorStruct.identifier = ...
                   'MODISData.modisForesstHeightFile:FileError';
               errorStruct.message = sprintf( ...
                   ['%s: Unexpected forest height files found ' ...
                   'for %s at %s'], ...
                   mfilename(), regionName, myDir);
               error(errorStruct);
           end

           f = fullfile(f(1).folder, f(1).name);

       end

       function f = modisWatermaskFile(obj, regionName, varargin)
           % modisWatermaskFile returns water mask file for the regionName

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.modisWatermaskDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           %TODO: what does the 50 stand for in these filenames?
           f = dir(fullfile(myDir, ...
               sprintf('%s_MOD44_50_watermask_463m_sinusoidal.mat', ...
               regionName)));

           if length(f) ~= 1
               errorStruct.identifier = ...
                   'MODISData.modisWatermaskFile:FileError';
               errorStruct.message = sprintf( ...
                   '%s: Unexpected watermasks found for %s at %s', ...
                   mfilename(), regionName, myDir);
               error(errorStruct);
           end

           f = fullfile(f(1).folder, f(1).name);

       end

       function f = modisElevationFile(obj, regionName, varargin)
           % modisElevationFile returns DEM for the regionName

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.modisElevationDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('%s_dem.mat', ...
               regionName)));

           if length(f) ~= 1
               errorStruct.identifier = ...
                   'ESPEnv.modisElevationFile:FileError';
               errorStruct.message = sprintf( ...
                   '%s: Unexpected DEMs found for %s at %s', ...
                   mfilename(), regionName, myDir);
               error(errorStruct);
           end

           f = fullfile(f(1).folder, f(1).name);

       end

       function f = modisTopographyFile(obj, regionName, varargin)
           % modisTopographyFile file with regionName elevation-slope-aspect

           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.modisTopographyDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('%s_Elevation_Slope_Aspect.mat', ...
               regionName)));

           if length(f) ~= 1
               errorStruct.identifier = ...
                   'ESPEnv.modisTopographyFile:FileError';
               errorStruct.message = sprintf( ...
                   '%s: Unexpected Topographies found for %s at %s', ...
                   mfilename(), regionName, myDir);
               error(errorStruct);
           end

           f = fullfile(f(1).folder, f(1).name);

       end

       function f = studyExtentFile(obj, regionName)
           % studyExtentFile returns the study extent file for the
           % given regionName

           f = dir(fullfile(obj.extentDir, ...
               sprintf('%s.mat', regionName)));
           if length(f) ~= 1
               errorStruct.identifier = ...
                   'ESPEnv.studyExtentFile:FileError';
               errorStruct.message = sprintf( ...
                   '%s: Unexpected study extentsfound for %s at %s', ...
                   mfilename(), regionName, obj.extentDir);
               error(errorStruct);
           end

           f = fullfile(f(1).folder, f(1).name);

       end

       function projInfo = projInfoFor(obj, tileID, varargin)
           % projInfoFor reads and returns tileID's projection information
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.mappingDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           try
               projInfo = load(fullfile(myDir, ...
                   sprintf('%s_ProjInfo.mat', tileID)));
           catch e
               fprintf("%s: Error reading projInfo in %s for %s\n", ...
                   mfilename(), myDir, tileID);
               rethrow(e);
           end

       end

       function s = readShapefileFor(obj, shapeName, varargin)
           % shapefileFor - returns the request shapefile contents
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.shapefileDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};

           try
               shapeFile = fullfile(myDir, ...
           shapeName, ...
                   sprintf('%s.shp', shapeName));
               s = shaperead(shapeFile);
           fprintf('%s: Read shapefile from %s\n', mfilename(), ...
               shapeFile);
           catch e
               fprintf("%s: Error reading shapefile in %s for %s\n", ...
                   mfilename(), myDir, shapeName);
               rethrow(e);
           end

       end

       function f = field_names_and_descriptions(obj)
            f = readtable(fullfile(obj.confDir, ...
                "field_names_and_descriptions.csv"), 'Delimiter', ',');
            f([1],:) = []; % delete comment line
       end

   end
end
