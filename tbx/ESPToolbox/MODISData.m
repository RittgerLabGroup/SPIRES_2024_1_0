classdef MODISData
%MODISData - manages our inventory of MODIS tile data
%   This class contains functions to manage our copy of MODIS tile
%   data, including MOD09, modscag and moddrfs
    properties      % public properties
        archiveDir    % top-level directory with tile data
        historicEndDt   % date of last historic data to use
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
            obj.historicEndDt = datetime("20181229", ...
                'InputFormat', 'yyyyMMdd');
           
        end
        
        function S = readInventoryStatus(obj, whichSet, ...
                tile, imtype)
           
            % Load the inventory file for this set/tile/type
            fileName = fullfile(obj.archiveDir, 'archive_status', ...
                sprintf("%s.%s.%s-inventory.mat", whichSet, tile, imtype));
            try
                S = load(fileName);
            catch e
                fprintf("%s: Error reading inventory file %s", ...
                    mfilename(), fileName);
                rethrow(e);
            end

    	    % Only return historic/nrt data before/after cutoff Dt
            if strcmp(whichSet, 'historic')
                idx = S.datevals <= obj.historicEndDt;
            else
                idx = S.datevals > obj.historicEndDt;
            end
            
            if any(idx)
                S.datevals = S.datevals(idx);
                nameFields = fields(S.filenames);
                for i=1:length(nameFields)
                    S.filenames.(nameFields{i}) = ...
                        S.filenames.(nameFields{i})(idx);
                end
            end
            
        end
        
    end
    
    methods(Static)  % static methods can be called for the class
        
        function dt = getMod09gaDt(fileNames)
            %getMod09gaDate parses the MOD09GA-like filename for datetime
            % Input
            %   fileNames = cell array with MOD09GA filenames, of form
            %   MOD09GA.Ayyyyddd.*
            %
            % Optional Input n/a
            %   
            % Output
            %   dt = datetime extracted from yyyyddd field in filename
            %
            
            % This uses a nice trick that converts to datetime as an
            % offset from Jan 1
            
            try
                
                tokenNames = cellfun(@(x)regexp(x, ...
                    'MOD09GA\.A(?<yyyy>\d{4})(?<doy>\d{3})\.', 'names'), ...
                    fileNames, 'uniformOutput', false);
                dt = cellfun(@(x)datetime(str2num(x.yyyy), 1, ...
                    str2num(x.doy)), ...
                    tokenNames);
                
            catch

                errorStruct.identifier = 'MODISData:FileError';
                errorStruct.message = sprintf(...
                    '%s: Unable to parse dates from %s\n', ...
                    mfilename(), strjoin(fileNames));
                error(errorStruct);

            end

        end

        function [filenames, datevals, missingSCAG, ...
                missingDRFS] = getMODISfilenames(tile, whichSet, imtype, ...
                scagflag, drfsflag, modisDir)
            %getMODISfilenames returns list of scag-related filenames
            %
            % Input
            %   tile - MODIS tile. Example: 'h08v05'
            %   whichSet - 'historic' or 'nrt'
            %   imtype - either 'tif' or 'dat'
            %   scagflag - vector of length 7 1s and 0s for desired files
            %      if empty, then look for all
            %   drfsflag - vector length 3 1s and 0s for desired files
            %      if empty, then look for all
            %   modisDir - directory with directory hierarchy, with
            %      mod09ga, modscag, moddrfs
            %
            % Output
            %   filenames - filenames excluding root directory where 
            %      we have all files
            %   datevals - vector of corresponding datetimes
            %   missingSCAG - list of strings with missing scag/tiles
            %   missingDRFS - list of strings with missing drfs/tiles
            % Notes
            %   This routine uses the list of MOD09GA files for this tile 
            %   to look for matching scag/drfs files.  It assumes that 
            %   there is 1 MOD09GA file for a given date. 
            %TODO: check datevals for dups and quit if they are found?
            % 
            % Original version from Karl Rittger
            % NSIDC, CUB & ERI, UCSB
            % April 27, 2016

            %% MODSCAG and MODDRFS variables of interest
            scag_variables = {'snow_fraction';'vegetation_fraction';...
                'rock_fraction';'other_fraction';'grain_size'};
            %'shade_fraction';
            drfs_variables = {'forcing';'deltavis';'drfs.grnsz'};
            % Used for field names in ouptut, can't use . in Matlab 
            % fieldnames
            drfs_variables2 = {'forcing';'deltavis';'drfs_grnsz'};

            %% Subset the variables specified
            if isempty(scagflag)
                scagflag = ones(size(scag_variables));
            end
            scag_variables = scag_variables(logical(scagflag));

            if isempty(drfsflag)
                drfsflag = ones(size(drfs_variables));
            end
            drfs_variables = drfs_variables(logical(drfsflag));
            drfs_variables2 = drfs_variables2(logical(drfsflag));

            %%FIXME: move this stupid junk to a single function
            switch lower(whichSet)
                case 'historic'
                    processingMode = 'historic';
                case 'nrt'
                    processingMode = 'NRT';
                otherwise
                    error('%s: unrecognized argument %s ', mfilename(), ...
                        whichSet);
            end
            reflectance_version = 6;
            versionStr = sprintf('%03d', reflectance_version);
            
            hdfDir = fullfile(modisDir, 'mod09ga', processingMode, ...
                ['v' versionStr], tile);
            scagDir = fullfile(modisDir, 'modscag', processingMode, ...
                ['v' versionStr], tile);
            drfsDir = fullfile(modisDir, 'moddrfs', processingMode, ...
                ['v' versionStr], tile);
            
            %% List the source hdf files
            hdffiles = dir(fullfile(hdfDir, '*', ...
                ['MOD09GA.A*' tile '*.hdf']));
            fprintf(['%s: %d MOD09GA files found. ' ...
                'Looking for matching %s...\n'], mfilename(), ...
                length(hdffiles), imtype);
            dts = MODISData.getMod09gaDt(string({hdffiles.name})');
            
            %TODO: check for dup dates and quit now if found?
            [~, ind] = unique(dts);
            if length(ind) ~= length(dts)
                fprintf(['\n\n\n%s: WARNING: duplicate ' ...
                    '%s MOD09GA files\n\n\n\n'], ...
                    mfilename(), tile);
            end
            
            %% Start counts
            cntgood=0;% HDF, all SCAG and all DRFS present
            cntmscag=0;% Missing some/all SCAG
            cntmdrfs=0;% Missing some/all DRFS

            %% Allocate storage for output once
            numFiles = length(dts);
            datevals = NaT(numFiles, 1);
            filenames.MOD09GA = cell(numFiles, 1);
            for i=length(scag_variables)
                filenames.(scag_variables{i}) = cell(numFiles, 1);
            end
            for i=length(drfs_variables2)
                filenames.(drfs_variables2{i}) = cell(numFiles, 1);
            end

            %% Loop for each day
            for i=1:numFiles

                thisYYYYStr = datestr(dts(i), 'yyyy');
                thisYYYYDDDStr = sprintf('%04d%03d', dts(i).Year, ...
                    day(dts(i), 'dayofyear')); 

                % Path for hdf, scag, drfs files for this day
                sDir = fullfile(scagDir, thisYYYYStr);
                fDir = fullfile(drfsDir, thisYYYYStr);

                % Parse the hdf base name for this day
                [~, hdfbase, ~] = fileparts(hdffiles(i).name);

                % add SCAG filenames to structure if they exist
                % Looks for "." first, then w/o
                for n=1:length(scag_variables)
                    if exist(fullfile(sDir,...
                            [hdfbase '.' scag_variables{n} '.' imtype]),...
                            'file')==2
                        scagnames.(scag_variables{n}) = fullfile(sDir,...
                            [hdfbase '.' scag_variables{n} '.' imtype]);
                    elseif exist(fullfile(sDir,...
                            [hdfbase scag_variables{n} '.' imtype]),...
                            'file')==2
                        scagnames.(scag_variables{n}) = fullfile(sDir,...
                            [hdfbase scag_variables{n} '.' imtype]);
                    end
                end

                % add DRFS filenames to structure if they exist
                % Looks for "." first, then w/o
                for n=1:length(drfs_variables)
                    if exist(fullfile(fDir,...
                            [hdfbase '.' drfs_variables{n} '.' imtype]),...
                            'file')==2
                        drfsnames.(drfs_variables2{n}) = fullfile(fDir,...
                            [hdfbase '.' drfs_variables{n} '.' imtype]);
                    elseif exist(fullfile(fDir,...
                            [hdfbase drfs_variables{n} '.' imtype]),...
                            'file')==2
                        drfsnames.(drfs_variables2{n}) = fullfile(fDir,...
                            [hdfbase drfs_variables{n} '.' imtype]);
                    end
                end

                % Check to see if there are files for either scag or drfs
                if   exist('scagnames','var')==1 && exist('drfsnames',...
                        'var')==1
                    % Check for all fields
                    if length(fields(scagnames))==length(scag_variables)
                        svars=1;
                    else
                        svars=0;
                    end
                    if length(fields(drfsnames))==length(drfs_variables2)
                        dvars=1;
                    else
                        dvars=0;
                    end
                    % If all files, get filenames
                    if svars==1 && dvars==1

                        cntgood=cntgood+1;

                        % HDF file and datevals
                        filenames.MOD09GA{cntgood, 1} = fullfile(...
                            hdffiles(i).folder, hdffiles(i).name);
                        datevals(cntgood, 1) = dts(i);

                        % SCAG names
                        for n=1:length(scag_variables)
                            filenames.(scag_variables{n}){cntgood,1} = ...
                                scagnames.(scag_variables{n});
                        end

                        % DRFS names
                        for n=1:length(drfs_variables)
                            filenames.(drfs_variables2{n}){cntgood,1}=...
                                drfsnames.(drfs_variables2{n});
                        end

                        % Skip files if some or all scag files are missing
                    elseif svars==0 && dvars==1
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing some SCAG variables'])
                        cntmscag=cntmscag+1;
                        missingSCAG{cntmscag,1}=[tile '_' thisYYYYDDDStr];
                        % Skip files if some or all drfs files are missing
                    elseif svars==1 && dvars==0
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing some DRFS variables'])
                        cntmdrfs=cntmdrfs+1;
                        missingDRFS{cntmdrfs,1}=[tile '_' thisYYYYDDDStr];
                    end
                else
                    if ~exist('scagnames','var')
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing all SCAG variables'])
                        cntmscag=cntmscag+1;
                        missingSCAG{cntmscag,1}=[tile '_' thisYYYYDDDStr];
                    end
                    if ~exist('drfsnames','var')
                        disp(['Skipping ' thisYYYYDDDStr ', ' tile...
                            ' because it is missing all DRFS variables'])
                        cntmdrfs=cntmdrfs+1;
                        missingDRFS{cntmdrfs,1}=[tile '_' thisYYYYDDDStr];
                    end
                end
                clear scagnames drfsnames dvars svars
            end

            %% Delete any unused indices in output variables
            if cntgood > 0
                datevals = datevals(1:cntgood);
                fNames = fieldnames(filenames);
                for i=1:length(fNames)
                    filenames.(fNames{i}) = ...
                        filenames.(fNames{i})(1:cntgood);
                end
            elseif 0 == cntgood
                datevals = {};
                filenames = {};
            end

            %% Define any return variables if they haven't already been set
            if ~exist('missingSCAG','var')
                missingSCAG={};
            end
            if ~exist('missingDRFS','var')
                missingDRFS={};
            end

        end
        
        function saveMODISfilenames(saveFile, filenames, datevals, ...
                missingSCAG, missingDRFS)
            %saveMODISfilenames - saves a MODIS file inventory to .mat file
            
            inventoryDate = datestr(datetime('now'));
            
            save(saveFile, 'inventoryDate', ...
                'filenames', 'datevals', 'missingSCAG', 'missingDRFS');

        end
        
        function S = inventoryMod09ga(folder, whichSet, tileID, varargin)
            %inventoryJPLmod09ga creates an inventory of MOD09GA files for
            %tileID
            %
            % Input TBD
            %
            % Optional Input
            %   beginDate - datetime date to begin looking for files
            %      default is first date in the mod09ga directory for tileID
            %   endDate = datetime date to stop looking for files
            %      default is last date in the mod09ga directory for tileID
            %   
            % Output
            %   Cell array with row for each date in beginDate:endDate
            %
            %
            % Notes
            % 
            % Example
            % 
            % This example will ...
            %
            %

            %% Parse inputs
            p = inputParser;

            addRequired(p, 'folder', @ischar);

            validWhichSet = {'historic' 'nrt'};
            checkWhichSet = @(x) any(strmatch(x, validWhichSet, 'exact'));
            addRequired(p, 'whichSet', checkWhichSet);

            addRequired(p, 'tileID', @ischar);
            addParameter(p, 'beginDate', NaT, @isdatetime);
            addParameter(p, 'endDate', NaT, @isdatetime);

            p.KeepUnmatched = true;
            parse(p, folder, whichSet, tileID, varargin{:});

            if isnat(p.Results.beginDate)
                beginDateStr = 'from input';
            else
                beginDateStr = datestr(p.Results.beginDate);
            end
            if isnat(p.Results.endDate)
                endDateStr = 'from input';
            else
                endDateStr = datestr(p.Results.endDate);
            end

            beginDate = p.Results.beginDate;
            endDate = p.Results.endDate;
            
            fprintf("%s: inventory for: %s, %s, %s, dates: %s - %s...\n", ...
                mfilename(), p.Results.folder, p.Results.whichSet, ...
                p.Results.tileID, beginDateStr, endDateStr);

            %% TODO version should be optional argument
            reflectance_version = 6;

            %% TODO Local folders this junk should be moved to functions with
            % specifics of our file system
            % note that mod09ga levels don't have the year at the end
            switch lower(whichSet)
                case 'historic'
                    processingMode = 'historic';
                case 'nrt'
                    processingMode = 'NRT';
                otherwise
                    error('%s: unrecognized argument %s ', mfilename(), ...
                        whichSet);
            end
            versionStr = sprintf('%03d', reflectance_version);
            mod09Folder = fullfile(folder, 'mod09ga', processingMode, ...
                ['v' versionStr], tileID);        

            %% Handle defaults for begin/end date
            % If using input for begin or end date, get a list of all
            % files in the directory and pull dates from first/last filenames
            if isnat(beginDate) || isnat(endDate)
                yrDirs = MODISData.getSubDirs(mod09Folder);
                
                %list = dir(fullfile(mod09Folder, ...
                %    sprintf('MOD09GA.A*%s.%s*hdf', ...
                %    tileID, versionStr)));
                if isnat(beginDate)
                    list = dir(fullfile(mod09Folder, yrDirs{1}, ...
                        sprintf('MOD09GA.A*%s.%s*hdf', ...
                        tileID, versionStr)));
                    beginDate = MODISData.getMod09gaDt({list(1).name});
                end
                if isnat(endDate)
                    list = dir(fullfile(mod09Folder, yrDirs{end}, ...
                        sprintf('MOD09GA.A*%s.%s*hdf', ...
                        tileID, versionStr)));
                    endDate = MODISData.getMod09gaDt({list(end).name});
                end
            end

            %% Allocate space for dates
            % Make a struct array with 1 record for each date
            ndays = days(endDate - beginDate) + 1;
            S = repmat(struct('dt', NaT, 'num', 0, 'files', []), ndays, 1);

            %% Loop for each date
            recNum = 1;
            for dt = beginDate:endDate
                S(recNum).dt = dt;
                S(recNum).num = 0;

                yyyyddd  = sprintf('%04d%03d', dt.Year, day(dt, 'dayofyear'));

                % Find all MOD09GA files for this date
                list = dir(fullfile(mod09Folder, '*', ...
                    sprintf('MOD09GA.A%s.%s.%s*hdf', ...
                    yyyyddd, tileID, versionStr)));
                if ~isempty(list)
                    S(recNum).num = length(list);
                    S(recNum).files = list;
                end

                recNum = recNum + 1;

            end
        end

        function numDupes = removeMod09gaDuplicates(S)
            %removeMod09gaDuplicates removes duplicate MOD09GA files
            %
            % Input
            %   S = mod09ga inventory cell array returned from 
            %       inventoryMod09ga
            %
            % Output
            %   numDupes - number of duplicates found and removed
            %
            % Notes
            %
            % Example
            %
            numDupes = 0;

            % Find duplicate MOD09GA files from input inventory
            idx = [S.num] > 1;
            
            subS = S(idx);

            for i=1:length(subS)
                fprintf("\n%s: multiple files found for : %s\n", ...
                    mfilename(), datestr(subS(i).dt, 'yyyy-mm-dd'));
                names = vertcat(subS(i).files.name);
                folders = vertcat(subS(i).files.folder);
                [numFiles, ~] = size(names);
                files = strings(numFiles, 1);
                for j=1:numFiles
                    files(j) = fullfile(folders(j,:), names(j,:));
                end
                files = sort(files, 'descend');
                
                % Delete all but the first one, sorting in descending order
                for j=1:length(files)
                    if 1 == j
                        fprintf("%s: keeping %s\n", mfilename(), files(j));
                    else
                        fprintf("%s: deleting %s...\n", ...
                            mfilename(), files(j));
                        
                        delete(files(j));
                        
                        % Delete any scag/drfs files found for this
                        % file also
                        list = MODISData.matchingFiles(files(j));
                        if ~isempty(list)
                            for k=1:length(list)
                                modisFile = fullfile(list(k).folder, ...
                                    list(k).name);
                                fprintf("%s: deleting %s...\n", ...
                                    mfilename(), modisFile);
                                delete(modisFile);
                            end
                        end
                        
                        numDupes = numDupes + 1;
                    end
                end
            end
        end
        
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
        
        function list = matchingFiles(mod09File)
            % matchingFiles finds any scag/drfs files that 
            % match this mod09ga file, including procID
            tokenNames = regexp(mod09File, ...
                ['MOD09GA.A(?<yyyy>\d{4})(?<doy>\d{3})\.' ...
                '(?<tileID>h\d{2}v\d{2})\.(?<version>\d{3})\.' ...
                '(?<procID>\d+)\.'], ...
                'names');
            [path, ~, ~] = fileparts(mod09File);
            parts = split(path, filesep);
            procMode = parts(end-3);
            topPath = join(parts(1:end-5), filesep);
            
            % Look for scag files
            versionStr = sprintf('v%s', tokenNames.version);
            
            list = [...
                dir(fullfile(topPath{1}, 'modscag', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('*%s*.dat', tokenNames.procID))); ...
                dir(fullfile(topPath{1}, 'modscag', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('*%s*.tif', tokenNames.procID))); ...
                dir(fullfile(topPath{1}, 'moddrfs', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('*%s*.dat', tokenNames.procID))); ...
                dir(fullfile(topPath{1}, 'moddrfs', procMode{1},...
                versionStr, tokenNames.tileID, tokenNames.yyyy,...
                sprintf('*%s*.tif', tokenNames.procID)))];
            
        end
        
        function years = getSubDirs(folder)
            % Returns a sorted cell array of the subdirs in folder
            list = dir(folder);
            
            list = list([list(:).isdir]==1);
            list = list(~ismember({list(:).name},{'.','..'}));
            
            years = sort({list.name});
            
        end
        
        function doy = doy(Dt)
           % Returns the day of year of the input datetime Dt
           % TODO: Make this work on an array of Dts
           % TODO: Move this to a date utility object
           jan1Dt = datetime(sprintf("%04d0101", year(Dt)), ...
               'InputFormat', 'yyyyMMdd');
           doy = days(Dt - jan1Dt + 1);
            
        end
        
        function idx = indexForYYYYMM(yr, mn, Dts)
            %indexForYYYYMM finds indices to Dts array for yr, mn
            %
            % Input
            %  yr: 4-digit year
            %  mn: integer month
            %  Dts: array of datetimes
            %
            % Output
            %  idx: array of indices into Dts for requested yr, mn
            %
            % Notes
            % Returns an empty array if no dates in Dts match yr, mn
            %
            
            superset = datenum(Dts);
            subset = datenum(yr, mn, 1):datenum(yr, mn, eomday(yr, mn));
            idx = datefind(subset, superset);
            
        end

        function [RefMatrix, umdays, NoValues, SensZ, SolZ, refl] = ...
                loadMOD09(files)
            %loadMOD09 loads the data from a list of MOD09 Raw cubes
            %
            % Input
            %   files: cell array of filenames
            %
            % Output
            %   concatenated data arrays read from filenames
            %
            % Notes: Returned RefMatrix is from final file loaded,
            % earlier ones are loaded and then replaced.

            NoValues = [];
            SensZ = [];
            SolZ = [];
            refl = [];
            umdays = [];
            for mn=1:size(files,2)
                [NoValuesT, SensZT, SolZT, reflT, RefMatrix] = ...
                    parloadMatrices(files{mn}, ...
                    'NoValues', 'SensZ', 'SolZ', 'refl', ...
                    'RefMatrix');
                [umdaysT] = parloadDts(files{mn}, 'umdays');
                if mn == 1
                    NoValues = NoValuesT; %cat was making this a double
                    umdays = umdaysT{1}';
                else
                    NoValues = cat(3, NoValues, NoValuesT);
                    umdays = [umdays umdaysT{1}'];
                end
                SensZ = cat(3, SensZ, SensZT);
                SolZ = cat(3, SolZ, SolZT);
                refl = cat(4, refl, reflT);
            end
            
            umdays = datenum(umdays);
            
        end
        
        function [RefMatrix, usdays, RawSnow, RawVeg, RawRock, ...
                RawDV, RawRF, RawGS_SCAG, RawGS_DRFS] = ...
                loadSCAGDRFS(files)
            %loadSCAGDRFS loads the data from a list of SCAGDRFS Raw cubes
            %
            % Input
            %   files: cell array of filenames
            %
            % Output
            %   concatenated data arrays read from filenames
            %
            % Notes: Returned RefMatrix is from final file loaded,
            % earlier ones are loaded and then replaced.
            
            usdays = [];
            RawSnow = [];
            RawVeg = [];
            RawRock = [];
            RawGS_SCAG = [];
            RawDV = [];
            RawRF = [];
            RawGS_DRFS = [];
            for mn=1:size(files, 2)
                [RawSnowT, RawVegT, RawRockT, RawDVT, RawRFT, ...
                    RawGS_SCAGT, RawGS_DRFST, RefMatrix] = ...
                    parloadMatrices(files{mn}, ...
                    'RawSnow', 'RawVeg', 'RawRock', 'RawDV', 'RawRF', ...
                    'RawGS_SCAG', 'RawGS_DRFS', 'RefMatrix');
                [usdaysT] = ...
                    parloadDts(files{mn}, ...
                    'usdays');
                if mn == 1
                    usdays = usdaysT{1}';
                else
                    usdays = [usdays usdaysT{1}'];
                end
                RawSnow = cat(3, RawSnow, RawSnowT);
                RawVeg = cat(3, RawVeg, RawVegT);
                RawRock = cat(3, RawRock, RawRockT);
                RawDV = cat(3, RawDV, RawDVT);
                RawRF = cat(3, RawRF, RawRFT);
                RawGS_SCAG = cat(3, RawGS_SCAG, RawGS_SCAGT);
                RawGS_DRFS = cat(3, RawGS_DRFS, RawGS_DRFST);
            end
            
            usdays = datenum(usdays);
            
        end

        function FP = loadFP(fpFile, dims)
            %loadFP loads a false positives mask
            %
            % Input
            %   fpFile: watermask filename
            %   dims: dimensions of expected mask
            %
            % Output
            %   If fpFile contains an FP array, use it,
            %   otherwise if it contains a watermask array, use that.
            %   if not, a mask of size dims with 0s is allocated and
            %   returned.
            %FIXME: if file exists but doesnt have FP or watermask,
            % nothing will be returned here.
            %
            % Load a false positives mask
            if isfile(fpFile)
                load(fpFile);
                if ~exist('FP', 'var')
                    FP = parloadMatrices(fpFile, 'watermask'); 
                    clear watermask;  %TODO: why did Karl do this?
                    fprintf('%s: Using watermask for FP from %s\n', ...
                        mfilename(), fpFile);
                else
                    fprintf('%s: using FP directly from %s\n', ...
                        mfilename(), fpFile);
                end
            else
                FP = false(dims);
                fprintf('%s: Using dummy false positives FP mask\n', ...
                    mfilename());
            end

        end

        function [ppl, ppt, thetad] = pixelSize(R, H, p, theta_s)
            %pixelSize calculate pixel sizes in along-track and cross-track directions
            % input
            %  (first 3 inputs must be in same units)
            %  R - Earth radius
            %  H - orbit altitude
            %  p - pixel size at nadir
            %  theta_s - sensor zenith angle (degrees, can be vector of arguments)
            %
            % output (same size as vector theta_s)
            %  ppl - pixel size in along-track direction
            %  ppt - pixel size in cross-track direction
            %  thetad - nadir sensor angle, degrees
            %
            
            theta=asin(R*sind(theta_s)/(R+H));
            ppl=(1/H)*(cos(theta)*(R+H)-R*sqrt(1-((R+H)/R)^2*(sin(theta)).^2));
            beta=atan(p/(2*H));
            ppt=(R/p)*(asin(((R+H)/R)*sin(theta+beta))-...
                asin(((R+H)/R)*sin(theta-beta))-2*beta);
            thetad=rad2deg(theta);
            ppl=ppl*p;
            ppt=ppt*p;
            
        end
	
    end

end
