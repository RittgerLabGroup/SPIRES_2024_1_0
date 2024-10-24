classdef Tools
    % Provides tools, including for handling parallelism

    methods(Static)
        function tileSetIsGenerated = buildTileSet(tileFilePaths, tileMapCellsReferences, ...
            filePath, mapCellsReference)
            % Aims to assemble tile files into a mosaic "assembled" big file. 
            % Record the metadata of
            % the first file of the list, generates the proper RefMatrix, and assemble
            % data associated to the variables into a unique mosaic and save the 
            % result into the output file.
            % NB: if a tile lacks, the tileset is not constructed and function ends.
            % NB: Currently don't aggregate 1200x1200 variables that is for spires
            %   excludes solar/sensor zenith/azimuth. 20241008.                    @todo
            %
            % Parameters
            % ----------
            % tileFilePaths: cellarray(char). List of filepaths of the tiles.
            %   Should be .mat or .tif files, with all files the same extension.
            % tileMapCellsReferences: array(MapCellsReference obj). MapCellReference
            %   objects associated to the tiles. Not used for geotiffs (the 
            %   mapCellsReference in the .tif file is used).
            % filePath: char. FilePath of the tileset.
            %   Should be .mat or .tif file, same extension as tileFilePaths.
            % mapCellsReference: MapCellsReference obj. Associated to the
            %   tileset assembled from the tiles.
            %
            % Return
            % ------
            % tileSetIsGenerated: int. 1 if tileset generated, 0 otherwise.
            
            % 1. Initialize, with tileset RefMatrix (this latter is @deprecated).
            fprintf('%s: Start tileset generation and writing into %s ...\n', ...
                mfilename(), filePath);
            tileSetIsGenerated = 1;
            data = struct();
            data.RefMatrix = [[0, -mapCellsReference.CellExtentInWorldX]; ...
                [mapCellsReference.CellExtentInWorldX, 0]; ...
                [mapCellsReference.XWorldLimits(1) - ...
                    mapCellsReference.CellExtentInWorldX / 2, ...
                    mapCellsReference.YWorldLimits(2) + ...
                    mapCellsReference.CellExtentInWorldY / 2]]; 
                    % Code identic to ESPEnv.projInfoFor(). Mutualizing?           @todo
                    % RefMatrix is the only field of data not derived from tiles fields.
            data.mapCellsReference = mapCellsReference;
            missingTileFileFlag = 0;
            tileFieldNames = {}; % tile fields. 
                % Include paramNames, varNames and metadata like variable type and nodata_value.
            paramNames = {'files', 'mindays', 'zthresh'}; % parameters from each tile.
            varNames = {}; % variables contained in each tile.
            
            % 2. Read each tile and assemble into tileset.
            for fileIdx = 1:length(tileFilePaths)
                % 2.1. Read tile. If unavailable, the tileset is not built.
                tileFilePath = tileFilePaths{fileIdx};
                tileMapCellsReference = tileMapCellsReferences(fileIdx);
                if ~isfile(tileFilePath)
                    warning('%: Missing tile file %s', tileFilePath);
                    missingTileFileFlag = 1;
                    break;
                end
                if strcmp(tileFilePath(end - 3:end), '.mat')
                    tileData = load(tileFilePath);
                elseif strcmp(tileFilePath(end - 3:end), '.tif')
                    [tileData, tileMapCellsReference] = ...
                        readgeoraster(tileFilePath); % tileMapCellsReference replace 
                            % the argument tileMapCellsReference (awkward, to improve) @todo
                end
                % NB: We should store and call tileMapReferences in tile .mat or .tif
                % files rather than having them as arguments                       @todo
                
                % 2.2. Get the metadata and instantiate the variables for
                % the tileset with info from tile #1.
                if fileIdx == 1 & isstruct(tileData) % .mat files.
                    tileFieldNames = fieldnames(tileData);
                    for fieldIdx = 1:length(tileFieldNames)
                        tileFieldName = tileFieldNames{fieldIdx};
                        if size(tileData.(tileFieldName), 1) == 1 & ...
                            ~ismember(tileFieldName, fieldnames(data)) & ...
                            ~ismember(tileFieldName, paramNames)
                            data.(tileFieldName) = tileData.(tileFieldName);
                        elseif size(tileData.(tileFieldName), 1) > 1 & ...
                            ~strcmp(tileFieldName, 'RefMatrix')
                            varNames{end + 1} = tileFieldName;
                        end
                    end
                    for paramIdx = 1:length(paramNames)
                        paramName = paramNames{paramIdx};
                        if ismember(paramName, tileFieldNames) % spires. 2024-02-18.
                            if strcmp(paramName, 'files')
                                data.(paramName) = cell(0, 2);
                            else
                                data.(paramName) = {};
                            end
                        end
                    end
                    for varIdx = 1:length(varNames)
                        % NB: we exclude the 1200x1200 variables in the big mosaic,
                        % excluding then all solar/sensor zenith and azimuth.
                        % 20241008.                                             @warning
                        varName = varNames{varIdx};
                        if ~isequal(size(tileData.(varName)), ...
                            tileMapCellsReference.RasterSize)
                            continue;
                        end
                        if ismember([varName '_nodata_value'], tileFieldNames)
                            thisNoDataValue = data.([varName '_nodata_value']);
                        else
                            thisNoDataValue = intmax(class(tileData.(varName)));
                        end
                        data.(varName) = ...
                            thisNoDataValue * ...
                            ones(mapCellsReference.RasterSize, ...
                                class(tileData.(varName)));
                    end
                elseif fileIdx == 1 & ismatrix(tileData) % .tif files.
                    if isinteger(tileData)
                        data.data = intmax(class(tileData)) * ...
                            ones(mapCellsReference.RasterSize, ...
                                class(tileData));
                    else
                       data.data = NaN * ...
                            ones(mapCellsReference.RasterSize, ...
                                class(tileData));
                    end
                end
                % 2.3/ Fill the variables at the right location within the tileset
                % For this we need the intrisic coordinates in the tileset, of
                % the NW corner of the tile.
                [xWorld, yWorld] = intrinsicToWorld(tileMapCellsReference, ...
                    0.5, 0.5);
                [xIntrinsic, yIntrinsic] = worldToIntrinsic( ...
                    mapCellsReference, xWorld, yWorld);
                xIntrinsic = xIntrinsic + 0.5;
                yIntrinsic = yIntrinsic + 0.5;
                
                if isstruct(tileData) % .mat files.
                    for paramIdx = 1:length(paramNames)
                        paramName = paramNames{paramIdx};
                        if ismember(paramName, fieldnames(data))
                            if strcmp(paramName, 'files')
                                data.(paramName)(end + 1, 1:2) = tileData.(paramName);
                            else
                                data.(paramName)(end + 1) = tileData.(paramName);
                            end
                        end
                    end
                    for varIdx = 1:length(varNames)
                        varName = varNames{varIdx}; 
                        if ~isequal(size(tileData.(varName)), ...
                            tileMapCellsReference.RasterSize)
                            continue;
                            % NB: we could improve that by limiting varNames to the
                            % vars being on 2400x2400.                             @todo
                        end               
                        data.(varName)(uint16(yIntrinsic) : ...
                            uint16(yIntrinsic + ...
                                tileMapCellsReference.RasterSize(2)) - 1, ...
                            uint16(xIntrinsic) : ...
                            uint16(xIntrinsic + ...
                                tileMapCellsReference.RasterSize(1) - 1)) = ...
                            tileData.(varName);
                    end
                elseif ismatrix(tileData) % .tif files.
                    data.data(uint16(yIntrinsic) : ...
                        uint16(yIntrinsic + ...
                            tileMapCellsReference.RasterSize(2)) - 1, ...
                        uint16(xIntrinsic) : ...
                        uint16(xIntrinsic + ...
                            tileMapCellsReference.RasterSize(1) - 1)) = ...
                        tileData;
                end
            end
            if ~missingTileFileFlag 
                if strcmp(filePath(end - 3:end), '.mat')    
                    % NB: Because of a 'Transparency violation error.' occuring 
                    % with the upper-level
                    % parfor loop, it is required to save the files using
                    % another function (in our Tools package).
                    % NB: Check whether still necessary                       @todo
                    Tools.parforSaveFieldsOfStructInFile(filePath, ...
                        data, 'new_file');                
                elseif strcmp(filePath(end - 3:end), '.tif')
                    writegeotiff(filePath, data.data, data.mapCellsReference);
                end
                fprintf('%s: Saved tileset into %s.\n', mfilename(), filePath);
            else
                warning('%s: No generation of tileset %s due to missing tile.\n', ...
                    mfilename(), filePath);
                tileSetIsGenerated = 0;
            end
        end
        function fileExtension = getFileExtension(fileName)
            % Parameters
            % ----------
            % fileName: char.
            %
            % Return
            % ------
            % fileExtension: char. Extension beginning by a '.'.
            fileExtension = ['.', ...
                char(Tools.valueAt(flip(strsplit(fileName, '.')), 1))];
        end
        function parforSaveAsFieldInFile(filePath, varName, varData, appendFlag)
            % Save structure as a field in a .mat file to bypass the Transparency
            % violation error
            % that occurs by calls to save and eval in the parfor loop
            %
            % Parameters
            % ----------
            % filePath: array(char). Filepath where the data are saved.
            % varName: char. Name of the field saved.
            % varData: anything. The data that are saved.
            % appendFlag: char. new_file: New file, append: existing file.
            eval([varName, ' = varData; ']);
            if strcmp(appendFlag, 'new_file')
                save(filePath, varName, '-v7.3');
            elseif strcmp(appendFlag, 'append')
                save(filePath, varName, '-append');
            end
        end
        function parforSaveFieldsOfStructInFile(filename, myStruct, appendFlag)
            % Save fields of structure to bypass the Transparency violation error
            % that occurs by calls to save and eval in the parfor loop
            %
            % Parameters
            % ----------
            % filename: array(char)
            %   Filename where the data are saved.
            % myStruct: struct
            %   Struct with fields which values are to be saved
            % appendFlag: char. new_file: New file, append: existing file.
            if strcmp(appendFlag, 'new_file')
                save(filename, '-struct', 'myStruct', '-v7.3');
            elseif strcmp(appendFlag, 'append')
                save(filename, '-struct', 'myStruct', '-append');
            end
        end
        function value = valueAt(thisArray, varargin)
            % Parameter
            % ---------
            % thisArray: Array or Cell Array of any dimension.
            % varargin: uint. Indices separated by ,
            %
            % Return
            % ------
            % value: any type. the Value at the indices yielded in varargin.
            %
            % Use case
            % --------
            % thisValue = Tools.valueAt(dec2bin(bitset(3, [3 4], [0 1])), 2, ':').
            value = thisArray(varargin{:});
            % Case when return 1 cell only: convert to string.
            if iscell(value) & numel(value) == 1
                value = string(value);
            end
        end
        function value = valueInTableForThisField(thisTable, comparedField, ...
            comparedValue, returnedField)
            % Parameter
            % ---------
            % thisTable: Table of any dimension.
            % comparedField: char. Name of the field where compareValue will be looked
            %   for.
            % comparedValue: char or numeric. Value that comparedField should equal.
            %   NB: this value should be unique in Table/comparedField.
            % returnedField: char. Name of the field for which the value is returned.
            % 
            % Return
            % ------
            % value: char or numeric. the value looked in the table at the line for
            %   which the value of comparedField is expected to equal the value of
            %   argument compared value.
            if ischar(comparedValue)
                value = thisTable( ...
                    strcmp(thisTable.(comparedField), comparedValue), :). ...
                    (returnedField);
            else
                value = thisTable( ...
                    thisTable.(comparedField) == comparedValue, :). ...
                    (returnedField);
            end
            if iscell(value)
                value = value{1};
            end
        end
    end
end