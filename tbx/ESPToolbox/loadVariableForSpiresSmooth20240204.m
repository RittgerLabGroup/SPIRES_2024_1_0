% Seb 20240204 Additional functions to load variables and save the output var by var to lower consumption.
function out = loadVariableForSpiresSmooth20240204(j, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx)
    scratchPath = region.espEnv.scratchPath;
    regionName = region.name;
    fprintf('Loading variable %d...\n', j);
    tic;
    
    % Seb. 20240227. Handling of file per cell (to lower mem consumption.
    countOfCells = 36;
    countOfPixels = 2400;
    rowStartId = uint32(mod(countOfPixels / sqrt(countOfCells) * (cellIdx - 1) + 1, countOfPixels));
    rowEndId = uint32(rowStartId + countOfPixels / sqrt(countOfCells) - 1);
    columnStartId = uint32(countOfPixels / sqrt(countOfCells) * (floor((cellIdx - 1) / sqrt(countOfCells))) + 1);
    columnEndId = uint32(columnStartId + countOfPixels / sqrt(countOfCells) - 1);
    
    % 2023-07-10. change dv into firstDateOfMonthForSmoothing and simplify use of date functions.
    for i=1:length(firstDateOfMonthForSmoothing)
        fprintf('Handling wateryear month %d...\n', i);
        inloc = [scratchPath, 'modis/intermediary/spiresfill_', ...
            region.espEnv.modisData.versionOf.modisspiresfill, ...
            '/v006/', regionName, '/', char(firstDateOfMonthForSmoothing(i), 'yyyy'), '/']; 
            % Seb 20240204 location of input distinct from output.
        fname=fullfile(inloc,[regionName, '_', char(firstDateOfMonthForSmoothing(i), 'yyyyMM'), ...
            '_', num2str(rowStartId), '_', num2str(rowEndId), '_', num2str(columnStartId), '_', num2str(columnEndId), '.mat']);
        m=matfile(fname);

        if i==1
            %for j=1:length(vars)
            out.(vars{j})=zeros([size(m.(vars{j}),1) size(m.(vars{j}),2) ...
                length(matdates)],'single');
            %end
        end
        doy_start = daysdif(firstDateOfMonthForSmoothing(1), firstDateOfMonthForSmoothing(i)) + 1;
        doy_end = doy_start + size(m.fsca, 3) - 1;

        %convert to single and scale
        %for j=1:length(vars)
        tt=m.(vars{j})==intmax(dtype{j});
        v=single(m.(vars{j}));
        v(tt)=NaN;
        v=v/divisor(j);
        out.(vars{j})(:,:,doy_start:doy_end)=v;
        %end
    end
    fprintf('Loaded variable %d in %f secs.\n', j, toc);
end
