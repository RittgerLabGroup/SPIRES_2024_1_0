function saveVariableForSpiresFill20240204(fname, data, varName, varIdx, divisor, dtype, appendFlag)
    % Save variables in split spires fill files.
    tic;
    fprintf('Saving variable %s in %s...\n', varName, fname);

    if ~isempty(varIdx)
        data = data * divisor(varIdx);
        data(isnan(data)) = intmax(dtype{varIdx});
        data = cast(data, dtype{varIdx});
    end        
        
    % Seb 20240224. Dividing data spatially in cells and save 1 file per cell, so
    % as to make smooth on each cell-file less memory consuming.
    countOfCells = 36;
    countOfPixels = 2400;
    for cellIdx = 1:countOfCells
        rowStartId = uint32(mod(countOfPixels / sqrt(countOfCells) * (cellIdx - 1) + 1, countOfPixels));
        rowEndId = uint32(rowStartId + countOfPixels / sqrt(countOfCells) - 1);
        rowIds = rowStartId : rowEndId;
        columnStartId = uint32(countOfPixels / sqrt(countOfCells) * (floor((cellIdx - 1) / sqrt(countOfCells))) + 1);
        columnEndId = uint32(columnStartId + countOfPixels / sqrt(countOfCells) - 1);
        columnIds = columnStartId : columnEndId;
        thisFilePath = replace(fname, '.mat', ...
            ['_', num2str(rowStartId), '_', num2str(rowEndId), '_', ...
            num2str(columnStartId), '_', num2str(columnEndId), '.mat']);
        if ~isempty(varIdx)
            thisData = data(rowStartId:rowEndId, columnStartId:columnEndId, :);
            eval([varName, ' = thisData;']);
            thisdata = [];
        else
            eval([varName, ' = data;']);
        end
        if strcmp(appendFlag, '-append')
            save(thisFilePath, varName, '-append');
        else
            save(thisFilePath, varName, '-v7.3');
        end
    end
    fprintf('Saved variable %s in %f secs.\n', varName, toc);
end
