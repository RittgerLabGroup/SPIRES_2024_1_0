classdef ESPEnv
   properties
      colormapDir
      extentDir
      heightmaskDir
      MODISDir
      LandsatDir
      viirsDir
      watermaskDir
   end
   methods
       function obj = ESPEnv(varargin)
           
           p = inputParser;
           
           defaultHostName = 'Macice';
           validHostNames = {'Summit', 'Macice'};
           checkHostName = @(x) any(validatestring(x, validHostNames));
           addOptional(p, 'hostName', defaultHostName, ...
               checkHostName);
           
           p.KeepUnmatched = true;
           
           parse(p, varargin{:});
           
           switch p.Results.hostName
               case 'Macice'
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
                   obj.heightmaskDir = fullfile('/Users', 'brodzik', ...
                       'SierraBighorn_data', 'landcover', ...
                       'LandFireEVH_ucsb');
                   
               otherwise
    
                   % Default path is relative to this file, 2 levels up
                   [path, ~, ~] = fileparts(mfilename('fullpath'));
                   parts = split(path, filesep);
                   path = join(parts(1:end-2), filesep);
    
                   obj.extentDir = fullfile(path, 'tbx', 'StudyExtents');
                   
                   % For all else, default path is PetaLibrary
                   path = fullfile('/pl', 'active', 'SierraBighorn');
           
                   obj.MODISDir = fullfile(path, 'scag', 'MODIS', 'v0');
                   obj.viirsDir = fullfile(path, 'viirs');
                   obj.watermaskDir = fullfile(path, 'landcover', ...
                       'NLCD_ucsb');
                   
                   obj.colormapDir = fullfile(path, 'colormaps');
                   obj.LandsatDir = fullfile(path, 'scag', 'Landsat', ...
                       'UCSB_v3_processing', 'test');
                   obj.heightmaskDir = fullfile(path, 'landcover', ...
                       'LandFireEVH_ucsb');
                   
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
       
       function f = MODISFile(obj, varargin)
           numvarargs = length(varargin);
           if numvarargs > 1
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
           end

           optargs = {obj.MODISDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, 'SN_WY*.mat'));
           
       end
       
       function f = geotiffFile(obj, extentName, platformName, sensorName, ...
                baseName, varName, version)

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

           f = dir(fullfile(obj.heightmaskDir, ...
               'Sierra_utm_LandFire_EVH_gt2.5m_mask.tif'));
           
       end
       
       function s = heightmask(obj)
           
           f = obj.heightmaskFile();
           s.mask = geotiffread(fullfile(f.folder, f.name));
           s.info = geotiffinfo(fullfile(f.folder, f.name));
           
       end
       
       function f = studyExtentFile(obj, regionName)
           
           f = dir(fullfile(obj.extentDir, ...
               sprintf('%s.mat', regionName)));
           
       end
       
   end
end
