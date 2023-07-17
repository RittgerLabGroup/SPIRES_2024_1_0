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
            %
            % Parameters
            % ----------
            % tileFilePaths: cellarray(char). List of filepaths of the tiles.
            %   Should be .mat files.
            % tileMapCellsReferences: array(MapCellsReference obj). MapCellReference
            %   objects associated to the tiles.
            % filePath: char. FilePath of the tileset.
            %   Should be .mat file.
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
                tileData = load(tileFilePath);
                
                % 2.2. Get the metadata and instantiate the variables for
                % the tileset with info from tile #1.
                if fileIdx == 1
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
                        if strcmp(paramName, 'files')
                            data.(paramName) = cell(0, 2);
                        else
                            data.(paramName) = {};
                        end
                    end
                    for varIdx = 1:length(varNames)
                        varName = varNames{varIdx};
                        data.(varName) = ...
                            data.([varName '_nodata_value']) * ...
                            ones(mapCellsReference.RasterSize, ...
                                class(tileData.(varName)));
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
                for paramIdx = 1:length(paramNames)
                    paramName = paramNames{paramIdx};
                    if strcmp(paramName, 'files')
                        data.(paramName)(end + 1, 1:2) = tileData.(paramName);
                    else
                        data.(paramName)(end + 1) = tileData.(paramName);
                    end
                end
                for varIdx = 1:length(varNames)
                    varName = varNames{varIdx};                  
                    data.(varName)(uint16(yIntrinsic) : ...
                        uint16(yIntrinsic + tileMapCellsReference.RasterSize(2)) - 1, ...
                        uint16(xIntrinsic) : ...
                        uint16(xIntrinsic + tileMapCellsReference.RasterSize(1) - 1)) = ...
                        tileData.(varName);
                end
            end
            if missingTileFileFlag == 1
                warning('%s: No generation of tileset %s.\n', ...
                    mfilename(), filePath);
                tileSetIsGenerated = 0;
            else    
                % NB: Because of a 'Transparency violation error.' occuring 
                % with the upper-level
                % parfor loop, it is required to save the files using
                % another function (in our Tools package).
                % NB: Check whether still necessary                       @todo
                Tools.parforSaveFieldsOfStructInFile(filePath, ...
                            data, 'new_file');
                fprintf('%s: Saved tileset into %s.\n', ...
                    mfilename(), filePath);
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
            % appendFlag: bool
            %   If true, the data are saved by append
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
            value = thisArray(varargin{:});
        end
    end
end