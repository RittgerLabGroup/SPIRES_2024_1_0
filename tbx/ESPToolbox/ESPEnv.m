classdef ESPEnv
   properties
      colormapDir
      extentDir
      heightmaskDir
      modscagDir
      oliDir
      tmDir
      viirsDir
      watermaskDir
   end
   methods
       function obj = ESPEnv()
           % Default path is relative to this file, 2 levels up
           [path, ~, ~] = fileparts(mfilename('fullpath'));
           parts = split(path, filesep);
           path = join(parts(1:end-2), filesep);
           
           obj.modscagDir = fullfile(path, 'data', 'modscag');
           obj.oliDir = fullfile(path, 'data', 'oli');
           obj.viirsDir = fullfile(path, 'data', 'viirscag');
           obj.watermaskDir = fullfile(path, 'data', 'masks');
           
           % 1 level up
           path = join(parts(1:end-1), filesep);
           obj.colormapDir = fullfile(path, 'colormaps');

           % elsewhere
           obj.tmDir = fullfile('/Users', 'brodzik', ...
               'SierraBighorn_data', 'Landsat');
           obj.extentDir = fullfile('/Users', 'brodzik', ...
               'SierraBighorn_data', 'StudyExtents');
           obj.heightmaskDir = fullfile('/Users', 'brodzik', ...
               'SierraBighorn_data', 'landcover', 'LandFireEVH_ucsb');

           % Convert these from 1x1 cells to plain char arrays
           props = properties(obj);
           for i = 1:length(props)
               if iscell(obj.(props{i}))
                   obj.(props{i}) = obj.(props{i}){1};
               end
           end
        
       end
       
       function f = oliFile(obj, datestr, path, row, varargin)
           numvarargs = length(varargin);
           if numvarargs > 1
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
           end

           % fullfile requires char vectors, not modern Strings
           optargs = {obj.oliDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('L8*%s*p%03ir%03i*.mat', datestr, path, row)))
       end
       
       function f = tmFile(obj, path, row, varargin)
           numvarargs = length(varargin);
           if numvarargs > 1
               error(sprintf('%s:TooManyInputs, ', ...
                   'requires at most 1 optional inputs', mfilename()));
           end

           optargs = {obj.tmDir};
           optargs(1:numvarargs) = varargin;  
           [myDir] = optargs{:};

           f = dir(fullfile(myDir, ...
               sprintf('p%03ir%03i_*.mat', path, row)));
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
       
       %function extent = studyExtent(obj, regionName)
           
       %    f = obj.studyExtentFile(regionName);
       %    extent = readtable(fullfile(f.folder, f.name));

       %end
       
   end
end
