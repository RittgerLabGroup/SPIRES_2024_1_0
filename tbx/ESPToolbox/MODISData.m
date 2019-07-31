classdef MODISData
%MODISData - manages our inventory of MODIS tile data
%   This class contains functions to manage our copy of MODIS tile
%   data, including MOD09, modscag and moddrfs
    properties      % public properties
        archiveDir    % top-level directory with tile data
    end
    methods         % public methods
        
        function obj = MODISData(varargin)
            % The MODISData constructor initializes the directory
            % for local storage of MODIS tile data
            
            p = inputParser;

            defaultArchiveDir = '/pl/active/rittger_esp/modis';
            checkArchiveDir = @(x) exist(x, 'dir');
            addOptional(p, 'archiveDir', defaultArchiveDir, ...
                checkArchiveDir);

            p.KeepUnmatched = true;

            parse(p, varargin{:});

            obj.archiveDir = p.Results.archiveDir;
           
        end
        
    end
    
    methods(Static)  % static methods can be called for the class
    
        function list = tilesFor(region)
            % tilesFor returns cell array of tileIDs for the region
            switch lower(region)
                case 'westernus'
                    list = {...
                        'h08v04'; 'h09v04'; 'h10v04'; ...
                        'h08v05'; 'h09v05'};
                case 'hma'
                    list = {...
                        'h22v04'; 'h23v04'; 'h24v04'; ...
                        'h22v05'; 'h23v05'; 'h24v05'; 'h25v05'; ...
                        'h26v05';...
                                  'h23v06'; 'h24v06'; 'h26v06'; ...
                        'h26v06'};
                otherwise
                    error("%s: Unknown region=%s", ...
                        mfilename(), region);
            end
            
        end
        
    end

end
