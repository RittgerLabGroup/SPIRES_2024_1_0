classdef ESPEnv
    % ESPEnv - environment for ESP data directories
    %   Directories with locations of various types of data needed for ESP
   properties
      colormapDir    % directory with color maps
      mappingDir     % directory with MODIS tiles projection information
      shapefileDir     % directory with MODIS tiles projection information
      extentDir      % directory with geographic extent definitions
      heightmaskDir  % directory heightmask for Landsat canopy corrections
      MODISDir       % directory with MODIS scag STC cubes from UCSB (.mat)
      LandsatDir     % directory with Landsat scag images (.mat)
      LandsatProbCloudDir % directory with liberal "probable" cloud masks (.tif)
      viirsDir       % directory with TBD for VIIRS
      watermaskDir   % directory with water mask
      modisWatermaskDir   % directory with MODIS watermask files
      modisForestDir      % directory with MODIS canopy corrections
      modisElevationDir   % directory with MODIS DEMs
      modisTopographyDir  % directory with MODIS topography files
      MOD09Dir       % directory with MODIS scag cubes (.mat)
      SCAGDRFSRawDir % directory with Raw SCAGDRFS cubes (.mat)
      SCAGDRFSDir    % directory with MODIS SCAGDRFS cubes (.mat)
      publicDir      % top-level directory for public FTP site
   end
   methods
       function obj = ESPEnv(varargin)
           % The ESPEnv constructor initializes all directory settings
           % based on locale
           
           p = inputParser;
           
           defaultHostName = 'Arete';
           validHostNames = {'Summit', 'Arete'};
           checkHostName = @(x) any(validatestring(x, validHostNames));
           addOptional(p, 'hostName', defaultHostName, ...
               checkHostName);
           
           p.KeepUnmatched = true;
           
           parse(p, varargin{:});
           
           switch p.Results.hostName
               case 'Arete'
                   % Default path is relative to this file, 2 levels up
                   [path, ~, ~] = fileparts(mfilename('fullpath'));
                   parts = split(path, filesep);
                   path = join(parts(1:end-2), filesep);
    
                   obj.viirsDir = fullfile(path, 'data', 'viirscag');
                   obj.watermaskDir = fullfile(path, 'data', 'masks');
                   obj.extentDir = fullfile(path, 'tbx', 'StudyExtents');
           
                   % 1 level up
                   path = join(parts(1:end-1), filesep);
                   obj.colormapDir = fullfile(path, 'colormaps');
                   obj.mappingDir = fullfile(path, 'mapping');
    
                   % elsewhere
                   obj.MODISDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'MODIS');
                   obj.MOD09Dir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'mod09');
                   obj.MOD09Dir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'scagdrfs');
                   obj.LandsatDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'Landsat');
                   obj.LandsatProbCloudDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'Landsat_cloud');
                   obj.heightmaskDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'landcover', ...
                       'LandFireEVH_ucsb');
                   obj.modisWatermaskDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'landcover');
                   obj.modisForestDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'forest_height');
                   obj.modisElevationDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'elevation');
                   obj.modisTopographyDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'topography');
                   obj.shapefileDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'shapefiles');
                   obj.publicDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'public');
                   
               otherwise
    
                   % Default path is relative to this file, 2 levels up
                   [path, ~, ~] = fileparts(mfilename('fullpath'));
                   parts = split(path, filesep);
    
                   % 1 level up
                   path = join(parts(1:end-1), filesep);

                   obj.colormapDir = fullfile(path, 'colormaps');
                   obj.mappingDir = fullfile(path, 'mapping');
                   obj.extentDir = fullfile(path, 'StudyExtents');
                   
                   % For all else, default paths are on PetaLibrary
                   path = fullfile('/pl', 'active', 'SierraBighorn');
           
                   obj.MODISDir = fullfile(path, ...
                       'scag', 'MODIS', 'SSN', 'v01');
                   
                   obj.viirsDir = fullfile(path, 'viirs');
                   obj.watermaskDir = fullfile(path, ...
                       'landcover', 'NLCD_ucsb');
                   obj.LandsatDir = fullfile(path, ...
					     'scag', 'Landsat', 'UCSB_v3_processing');
                   obj.LandsatProbCloudDir = fullfile(path, ...
					     'scag', 'Landsat', 'UCSB_v3_processing_cloud');
                   obj.heightmaskDir = fullfile(path, ...
                       'landcover', 'LandFireEVH_ucsb');
                   
                   
                   path = fullfile('/pl', 'active', 'rittger_esp');
                   obj.modisWatermaskDir = fullfile(path, 'landcover');
                   obj.modisForestDir = fullfile(path, 'forest_height');
                   obj.modisElevationDir = fullfile(path, 'elevation');
                   obj.modisTopographyDir = fullfile(path, 'topography');
                   obj.shapefileDir = fullfile(path, 'shapefiles');
                   
                   path = fullfile('/pl', 'active', 'rittger_esp', ...
                       'modis');
                   obj.MOD09Dir = fullfile(path, 'mod09');
                   obj.SCAGDRFSRawDir = fullfile(path, 'scagdrfs_raw_v01');
                   obj.SCAGDRFSDir = fullfile(path, 'scagdrfs');
                   
                   path = fullfile('/pl', 'active', 'rittger_esp_public');
                   obj.publicDir = fullfile(path, 'snow-today');

           end
    
           % Convert these from 1x1 cells to plain char arrays
           props = properties(obj);
           for i = 1:length(props)
               if iscell(obj.(props{i}))
                   obj.(props{i}) = obj.(props{i}){1};
               end
           end
        
       end
       
       function f = LandsatFile(obj, path, row, varargin)
           % LandsatFile returns a list of Landsat files for given path/row
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.LandsatDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};
           
           pathRowStr = sprintf('p%03ir%03i', path, row);

           f = dir(fullfile(myDir, ...
               pathRowStr, ...
               sprintf('%s_*.mat', pathRowStr)));
       end
       
       function f = LandsatProbCloudFile(obj, matFile)
           % landsatProbCloudMaskFile returns probable cloud file for matFile

           % Parse the matFile for a date string
           [~, basename, ~] = fileparts(matFile);
           tokenNames = regexp(basename, ...
               '_(?<yyyymmdd>\d{8})', ...
               'names');
           cloudBasename = sprintf('%s_cloud.tif', tokenNames.yyyymmdd);
           
           f = dir(fullfile(obj.LandsatProbCloudDir, cloudBasename));
           
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
       
       function f = MOD09File(obj, version, regionName, ...
			      fileType, yr, mm, varargin)
           % MOD09File returns the name of a monthly MOD09 cubefile
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.MOD09Dir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

    	   %TODO: make this an optional input
    	   platformName = 'Terra';
    	   yyyymm = sprintf('%04d%02d', yr, mm);

           f = fullfile(myDir, ...
			    sprintf('v%03d', version), ...
			    sprintf('%s', regionName), ...
			    sprintf('%04d', yr), ...
			    sprintf('%sMOD09_%s_%s_%s.mat', ...
				    fileType, platformName, ...
				    regionName, yyyymm));
           
       end
       
       function f = SCAGDRFSFile(obj, version, regionName, ...
			      fileType, yr, mm, labelName, varargin)
           % SCAGDRFSFile returns the name of a monthly SCAGDRFS cubefile
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.SCAGDRFSDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};
           
           %if labelName is not empty, append an underscore
           if ~isempty(labelName)
               labelName = sprintf('_%s', labelName);
           end

    	   %TODO: make this an optional input
    	   platformName = 'Terra';
    	   yyyymm = sprintf('%04d%02d', yr, mm);

           f = fullfile(myDir, ...
			    sprintf('v%03d', version), ...
			    sprintf('%s', regionName), ...
			    sprintf('%04d', yr), ...
			    sprintf('%sSCAG_%s_%s_%s%s.mat', ...
				    fileType, platformName, ...
				    regionName, yyyymm, labelName));
           
       end
       
       function f = MosaicFile(obj, version, regionName, ...
			       yr, mm, dd, labelName, varargin)
           % MosaicFile returns the name of a daily mosaic image file
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.SCAGDRFSDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};
           
           %TODO: make this an optional input
    	   platformName = 'Terra';
    	   yyyymmdd = sprintf('%04d%02d%02d', yr, mm, dd);

           f = fullfile(myDir, ...
               sprintf('v%03d', version), ...
               sprintf('%s', regionName), ...
               sprintf('%04d', yr), ...
               sprintf('%s_%s_%s_%s.mat', ...
               regionName, platformName, ...
               yyyymmdd, labelName));

       end
       
       function f = SummarySnowFile(obj, version, regionName, ...
           partitionName, ...				    
           startYr, stopYr, threshSCF, threshZ, varargin)
           % SummarySnowFile returns the name of an SCF and SCD
	   % summary file
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end

           optargs = {obj.SCAGDRFSDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};
           
           f = fullfile(myDir, ...
			sprintf('v%03d', version), ...
			sprintf('%s_statistics', regionName), ...
			sprintf(['%04d_to_%04d_%sby%s_Summary_snow_percent_lt%s' ...
				 '_and_snow_cover_days_above%sm.mat'], ...
				startYr, stopYr, ...
				regionName, partitionName, ...
				num2str(threshSCF), ...
				num2str(threshZ)));
           
       end
       
       function f = SnowTodayFile(obj, version, ...
               regionName, ...
               shortName, ...
               inputDt, creationDt, labelName, varargin)
           % SnowTodayFile returns the name of an SCF and SCD
           % figure file
           numvarargs = length(varargin);
           if numvarargs > 1
               error('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename());
           end
           
           optargs = {obj.SCAGDRFSDir};
           optargs(1:numvarargs) = varargin;
           [myDir] = optargs{:};
           
           f = fullfile(myDir, ...
               sprintf('v%03d', version), ...
               sprintf('%s_SnowToday', regionName), ...
               shortName, ...
               sprintf('%sinputs_createdOn%s_%s_%s.png', ...
               datestr(inputDt, 'yyyymmdd'), ...
               datestr(creationDt, 'yyyymmdd'), ...
               shortName, ...
               labelName));
           
       end
       
       function [files, haveDaysPerMonth, expectedDaysPerMonth] = ...
               rawFilesFor3months(obj, ...
               version, regionName, yr, mm, varargin)
           % RawFilesFor3months returns MOD09/SCAGDRFS cubes surrounding this month
           numvarargs = length(varargin);
           if numvarargs > 2
               error('%s:TooManyInputs, ', ...
                   'requires exactly 2 optional inputs', mfilename());
           end
           
           optargs = {obj.MOD09Dir, obj.SCAGDRFSRawDir};
           optargs(1:numvarargs) = varargin;
           [myMOD09Dir, mySCAGDRFSRawDir] = optargs{:};

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
               
               % Look for cubes for this month
               mod09file = obj.MOD09File(version, regionName, ...
                   'Raw', thisYYYY, thisMM, myMOD09Dir);
               scagfile = obj.SCAGDRFSFile(version, regionName, ...
                   'Raw', thisYYYY, thisMM, '', mySCAGDRFSRawDir);
               
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
            % geotiffFile builds a geoTiff file name based on the input
            % values

            if strcmp(sensorName, '')
                switch platformName
                    case 'Landsat4'
                        sensorName = 'TM';
                    case 'Landsat5'
                        sensorName = 'TM';
                    case 'Landsat7'
                        sensorName = 'ETM';
                    case 'Landsat8'
                        sensorName = 'OLI';
                    otherwise
                        error("%s: Unknown platformName=%s", ...
                            mfilename(), platformName);
                end
            end
            
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
                extentName, baseName, platformName, sensorName, varName, ...
                version);
            
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
           s.mask = geotiffread(fullfile(f.folder, f.name));
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
       
   end
end
