classdef ESPEnv
    % ESPEnv - environment for ESP data directories
    %   Directories with locations of various types of data needed for ESP
   properties
      colormapDir    % directory with color maps
      extentDir      % directory with geographic extent definitions
      heightmaskDir  % directory heightmask for Landsat canopy corrections
      MODISDir       % directory with MODIS scag STC cubes (.mat)
      LandsatDir     % directory with Landsat scag images (.mat)
      LandsatProbCloudDir % directory with liberal "probable" cloud masks (.tif)
      viirsDir       % directory with TBD for VIIRS
      watermaskDir   % directory with water mask
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
    
                   % elsewhere
                   obj.MODISDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'MODIS');
                   obj.LandsatDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'Landsat');
                   obj.LandsatProbCloudDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'Landsat_cloud');
                   obj.heightmaskDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'landcover', ...
                       'LandFireEVH_ucsb');
                   
               otherwise
    
                   % Default path is relative to this file, 2 levels up
                   [path, ~, ~] = fileparts(mfilename('fullpath'));
                   parts = split(path, filesep);
                   path = join(parts(1:end-2), filesep);
    
                   % 1 level up
                   path = join(parts(1:end-1), filesep);

                   obj.colormapDir = fullfile(path, 'colormaps');
                   obj.extentDir = fullfile(path, 'StudyExtents');
                   
                   % For all else, default path is PetaLibrary
                   path = fullfile('/pl', 'active', 'SierraBighorn');
           
                   obj.MODISDir = fullfile(path, ...
                       'scag', 'MODIS', 'SSN', 'v01');
                   obj.viirsDir = fullfile(path, ...
                       'viirs');
                   obj.watermaskDir = fullfile(path, ...
                       'landcover', 'NLCD_ucsb');
                   obj.LandsatDir = fullfile(path, ...
					     'scag', 'Landsat', 'UCSB_v3_processing');
                   obj.LandsatProbCloudDir = fullfile(path, ...
					     'scag', 'Landsat', 'UCSB_v3_processing_cloud');
                   obj.heightmaskDir = fullfile(path, ...
                       'landcover', 'LandFireEVH_ucsb');
                   
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
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
           end

           optargs = {obj.LandsatDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('p%03ir%03i_*.mat', path, row)));
       end
       
       function f = LandsatProbCloudFile(obj, matFile)
           % landsatProbCloudMaskFile returns probable cloud file for matFile

           % Parse the matFile for a date string
           [~, basename, ~] = fileparts(matFile);
           tokenNames = regexp(basename, ...
               ['_(?<yyyymmdd>\d{8})'], ...
               'names');
           cloudBasename = sprintf('%s_cloud.tif', tokenNames.yyyymmdd);
           
           f = dir(fullfile(obj.LandsatProbCloudDir, cloudBasename));
           
       end
       
       function f = MODISFile(obj, varargin)
           % MODISFile returns a list of MODIS STC cube files
           numvarargs = length(varargin);
           if numvarargs > 1
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
           end

           optargs = {obj.MODISDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, '*_*Y*.mat'));
           
       end
       
       function f = geotiffFile(obj, extentName, platformName, sensorName, ...
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
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
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
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
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
       
       function f = studyExtentFile(obj, regionName)
           % studyExtentFile returns a list of study extent files for the
           % given regionName
           
           f = dir(fullfile(obj.extentDir, ...
               sprintf('%s.mat', regionName)));
           
       end
       
   end
end
