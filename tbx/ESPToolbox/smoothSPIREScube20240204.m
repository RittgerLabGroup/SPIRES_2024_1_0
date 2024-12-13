function out=smoothSPIREScube20240204(region, cellIdx, waterYearDate, fshadeIsInterpolated, thisMode)
    %function to smooth cube after running through SPIRES
    % nameprefix - name prefix for outputs, e.g. Sierra
    % outloc - output location, string
    % matdates - datenum vector for image days
    % windowSize - search window size for moving persistence filter, e.g. 45
    % windowThresh - threshold number of days w/ fsca in windows to avoid being
    % zeroed, e.g. 13
    % mingrainradius - min believable grain radius, um, e.g. 75 um
    % maxgrainradius - max believable grain radius, e.g. 1100 um
    % mindust - min dust content, e.g. 0 um
    % maxdust - max believable dust: max believable dust, e.g. 950 ppm
    % mask- logical mask w/ ones for areas to exclude
    % topofile - h5 file name from consolidateTopography, part of TopoHorizons
    % el_cutoff - min elevation for snow, m - scalar, e.g. 1000
    % fsca_thresh - min fsca cutoff, scalar e.g. 0.10
    % cc - static canopy cover, single or doube, same size as mask,
    % 0-1 for viewable gap fraction correction
    % fice - fraction of ice/neve, single or double, 0-1, mxn
    % b_R - b/R ratio for canopy cover, see GOvgf.m, e.g. 2.7
    % dust_rg_thresh, min grain radius for dust, e.g. 400 um
    % maxflag
    % fixpeak - boolean, true fixes grain and dust values at after peak at
    % peak value. Avoids physically impossible retrievals such as shrinking fsca
    % and grain size due to increasing SWIR reflectance
    % Nd - number of days from length(matdates) to stop fixing peak, ignored if
    % fixpeak is false
    
    % thisMode: int. 0: all smoothing. 1: only calculations of albedo_muZ.
    %
    %output: struct out w/ fields
    %fsca, grainradius, dust, and hdr (geographic info)

    % Seb 20240204
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %
    % fshadeIsInterpolated: int. 0: not interpolated (to gain time) and saved as such in smooth. 1: interpolated.
    %
    % NB: this function uses core/movingPersist.m, core/GOvgf.m, 
    % MODIS_HDF/GetTopography.m, TimeSpace/smoothDataCube.m, core/smoothVector.m,
    % core/taperVector.m, General/truncateLimits.m
    % core/writeh5stcubes.m, General/float2integer.m
    %
    % NB: I changed arguments into region (tile or prefix), matdates kept the same,
    % and cellIdx, id of the cell to make it possible to run it on a smaller part of the tile.
    % Seb 20240227.

    % 1. Initialization of files, constants, variable names and configuration,
    %   elevation (and coordinates), canopy covercc
    %   (is it the same as our canopy height?), ...
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Constants. Seb 20240302. Added here.
    windowSize = 40; %45 2021 IEEE value
    windowThresh = 20; %13 2021 IEEE value
    mindust = 0;
    maxdust = 950;
    mingrainradius = 40;
    maxgrainradius = 1190;
    
    regionName = region.name; % Seb 2024-03-02
    espEnv = region.espEnv;
    modisData = region.espEnv.modisData;
    
    % 2024-07-12. No elevation min for other regions than westernUS
    el_cutoff = 0;
    versionBeforeV20240d = ...
        ismember(regionName, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'}) && ...
        ismember(modisData.versionOf.modisspiressmoothbycell, {'v2024.0d'})
    if versionBeforeV20240d
      el_cutoff = 500;
    end
    fprintf('WARNING: Elevation threshold below which snow fraction = 0: %d m.\n', ...
        el_cutoff);

    fsca_thresh = 0.10;
    b_R = 2.7;
    dust_rg_thresh = 300;
    fixpeak = true;
    Nd = 7;
    
    % Seb 20240224. So-called filled data are divided spatially in cells and the script runs 1 cell at a time and save it in 1 file per cell, so
    % as to make smooth on each cell-file less memory consuming.
    % Merging of cells is done during daily mosaicing.

    countOfCells = 36;
    countOfPixels = 2400;
    
    rowCellIdx = cellIdx - (floor((cellIdx - 1) / sqrt(countOfCells)) * sqrt(countOfCells));
    columnCellIdx = floor((cellIdx - 1)/ sqrt(countOfCells)) + 1;
    rowStartId = uint32(mod(countOfPixels / sqrt(countOfCells) * (cellIdx - 1) + 1, countOfPixels));
    rowEndId = uint32(rowStartId + countOfPixels / sqrt(countOfCells) - 1);
    columnStartId = uint32(countOfPixels / sqrt(countOfCells) * (floor((cellIdx - 1) / sqrt(countOfCells))) + 1);
    columnEndId = uint32(columnStartId + countOfPixels / sqrt(countOfCells) - 1);

    scratchPath = espEnv.scratchPath;
    if versionBeforeV20240d % Sen 2024-03-02 Special handling of westernUs with Ned's ancillaries.
        baseDir = [scratchPath, 'modis/input_spires_from_Ned_202311/Inputs/MODIS/'];
        rsyncDirectoryPath = basedir;
        % Copy the files from the archive if present in archive ...
        archiveDirectoryPath = strrep( ...
            rsyncDirectoryPath, region.espEnv.scratchPath, region.espEnv.archivePath);
        if isdir(archiveDirectoryPath)
          cmd = [region.espEnv.rsyncAlias, ' ', archiveDirectoryPath, ' ', rsyncDirectoryPath];
          fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
          [status, cmdout] = system(cmd);
        end
        maskfile = [baseDir, 'watermask/', regionName, 'watermask.mat'];
        water = matfile(maskfile).mask;
        topofile = [baseDir, 'Z/', regionName, 'Topography.h5'];
        [elevation,~]=GetTopography(topofile,'elevation'); % Seb 20240204 moved on top.
        % out.hdr=hdr; % Seb 20240227 unnecessary now.
        ccfile = [baseDir, 'cc/', 'cc_', regionName, '.mat'];
        cc = matfile(ccfile).cc;
        cc(isnan(cc))=0; % Seb 20240917. Moved here.
        ficefile = [baseDir, 'fice/', regionName, '.mat'];
        fice = matfile(ficefile).fice;
        fice(isnan(fice))=0;
    else
        water = logical(region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'water'));
        %cc = single(region.espEnv.getDataForObjectNameDataLabel( ...
        %            regionName, 'canopycover') / 100);
        elevation = region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'elevation');
        fice = region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'ice'); % from 0 to 100.
    end    
    switch modisData.inputProduct
        case 'mod09ga'
            outloc = [scratchPath, 'modis/intermediary/spiressmooth_', ...
                region.espEnv.modisData.versionOf.modisspiressmoothbycell, ...
                '/v006/', regionName];
            if exist(outloc, 'dir') == 0
                mkdir(outloc);
            end
        case 'vnp09ga'
            outloc = [scratchPath, 'vnp09ga.002/intermediary/spiressmooth_', ...
                espEnv.modisData.versionOf.spiressmoothbycell, ...
                '/', regionName, '/'];
            if exist(outloc, 'dir') == 0
                mkdir(outloc);
            end
    end
 
    water = water(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    if versionBeforeV20240d
        cc = cc(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    end
    fice = fice(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    elevation = elevation(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    Zmask=elevation < el_cutoff; % Seb 20240303 move on Top.
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %0.75-1.5 hrfor Sierra Nevada with 60 cores
    time1=tic;
    
    theseDates = waterYearDate.getDailyDatetimeRange();
    matdates = arrayfun(@(x) datenum(x), theseDates);
   
    % 2024-07-03 wateryear rather than year
    firstMonthOfWaterYear= 10;
    waterYear = WaterYearDate.getWaterYearFromDate(datetime(matdates(end), ConvertFrom = 'datenum'), firstMonthOfWaterYear);
    fileName = ['spiressmooth_', regionName, '_', num2str(waterYear), ...
        '_', num2str(rowStartId), '_', num2str(rowEndId), '_', num2str(columnStartId), '_', num2str(columnEndId), '.', ...
        region.espEnv.modisData.versionOf.modisspiressmooth, '.h5']; % Seb 20240227 name.
    h5name=fullfile(outloc, fileName); % Seb 20240205 name.
    fprintf('Generation of file %s...\n', h5name);
    %create h5 cube in tmp then move to avoid network h5 write issues
    % h5tmpname=fullfile(tempdir, fileName); % Seb 20240204 name.
    
    % Seb 20240204 moved output metadata here and added weights sensorZ solarZ.
    %output variables
    outvars={'fsca_raw','fshade','grainradius','dust','weights','sensorZ', 'solarZ', 'fsca', 'albedo_s', 'fsca_raw', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', 'tmask', 'fsca', 'fsca_raw', 'fsca', 'radiative_forcing_s', 'deltavis_s', 'spatial_grain_size_s', 'spatial_dust_concentration_s', ...
        'albedo_muZ_s', 'grainradius', 'dust', 'fshade', 'grainradius', 'dust', 'snow_cover_days_s', 'days_without_observation_s', ...
        'days_with_snow_observed_s', 'days_with_absent_snow_observed_s'};
    outnames={'viewable_snow_fraction_s','shade_fraction_s','grain_size_s','dust_concentration_s','time_interp_weight_s','sensor_zenith', 'solar_zenith', 'snow_fraction_s', 'albedo_s', 'raw_viewable_snow_fraction_s', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'solar_azimuth', 'cloudMaskMovingPersist', 'raw_snow_fraction_s', 'gap_viewable_snow_fraction_s', 'gap_snow_fraction_s', 'radiative_forcing_s', 'deltavis_s', 'spatial_grain_size_s', 'spatial_dust_concentration_s', ...
        'albedo_muZ_s', 'raw_grain_size_s', 'raw_dust_concentration_s', 'raw_shade_fraction_s', 'gap_grain_size_s', 'gap_dust_concentration_s', 'snow_cover_days_s','days_without_observation_s', ...
        'days_with_snow_observed_s', 'days_with_absent_snow_observed_s'}; % raw_snow_fraction_s is formerly cc_snow_fraction
    outdtype={'uint8','uint8','uint16','uint16','uint8','uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'int16', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'uint16', 'uint8', 'uint16', 'uint16', ...
        'uint8', 'uint16', 'uint16', 'uint8', 'uint16', 'uint16', 'uint16', 'uint16', ...
        'uint16', 'uint16'};
    outdivisors=[100, 100, 1, 10, 100, 1, 1, 100, 100, 100, ...
        1, 1, 1, 1, 100, 1, 1, 1, 1, 100, ...
        100, 100, 100, 100, 100, 100, 100, ...
        1, 1, 100, 100, 100, 1, 100, 1, 10, ...
        100, 1, 10, 100, 1, 10, 1, 1, ...
        1, 1];



%{
    % Seb 20240204 Removed the no overwriting existing files.
    lockname=fullfile(outloc,[regionName datestr(matdates(end),'yyyy') '.h5lock']);

    if exist(h5name,'file')==2
        fprintf('%s exists, skipping\n',h5name);
    elseif exist(lockname,'file')==2
        fprintf('%s locked, skipping\n',lockname);
    else
        fid=fopen(lockname,'w');
        fclose(fid);
        %delete lockname on cleanup
        cleanup=onCleanup(@()CleanupFun(lockname));
%}
    fprintf('reading %s...%s\n',datestr(matdates(1)),datestr(matdates(end)));
    %int vars
    vars={'fsca_raw','fshade','grainradius','dust','weights','sensorZ', 'solarZ', 'fsca', '', '', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', '', '', '', '', '', '', 'spatial_grain_size_s', 'spatial_dust_concentration_s'}; % Seb 20240205 added solarZ. spatial_grain_size_s 20240614.
    varInSpiresDaily = {'raw_viewable_snow_fraction_s','raw_shade_fraction_s','raw_grain_size_s','raw_dust_concentration_s','time_interp_weight_s','sensor_zenith', 'solar_zenith', 'raw_snow_fraction_s', '', '', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'solar_azimuth', '', '', '', '', '', '', 'spatial_grain_size_s', 'spatial_dust_concentration_s'}; % Seb 20240916. For regions using modisspiresdaily.
    divisor=[100 100 1 10 100 1 1, 100, 0, 0, ...
        1, 1, 1, 1, 100, 1, 1, 1, 1, 100, ...
        100, 100, 100, 100, 100, 100, 100, ...
        1, 0, 0, 0, 0, 0, 0, 1, 10];
    dtype={'uint8','uint8','uint16','uint16','uint8','uint8', 'uint8', 'uint8', '', '', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'int16', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'int16', '', '', '', '', '', '', 'uint16', 'uint16'};

    firstDateOfMonthForSmoothing = datetime(matdates, convertFrom = 'datenum');
    
    % Smoothing includes the 3 months before start of the waterYear if we have less than 6 months of data for the waterYear. 2024-07-10.
    indicesToSave = 1:length(firstDateOfMonthForSmoothing);
    % if calmonths(between(datetime(matdates(1), convertFrom = 'datenum'), datetime(matdates(end), convertFrom = 'datenum'))) <= 6
    % Above Doesn't exactly work as expected
    if split(between(datetime(matdates(1), convertFrom = 'datenum'), datetime(2024, 10, 1, 12, 0, 0), 'Months'), {'months'}) <= 6
        datesToAdd = (datetime(matdates(1), convertFrom = 'datenum') - calmonths(3)) : (datetime(matdates(1), convertFrom = 'datenum') - caldays(1));
        firstDateOfMonthForSmoothing = [datesToAdd, firstDateOfMonthForSmoothing];
        indicesToSave = (length(datesToAdd) + 1) : length(firstDateOfMonthForSmoothing);    
    end
    firstDateOfMonthForSmoothing = firstDateOfMonthForSmoothing(day(firstDateOfMonthForSmoothing) == 1);
    
    % WaterYearDate determination for regions outside westernUS 20240916.
    extendedDates = firstDateOfMonthForSmoothing(1):datetime(matdates(end), convertFrom = 'datenum');
    extendedWaterYearDate = WaterYearDate(extendedDates(end), modisData.getFirstMonthOfWaterYear(regionName), length(firstDateOfMonthForSmoothing), overlapOtherYear = 1);

    %check that full set of matdates exists
    % 2024-07-10. Simplify use of date functions of firstDateOfMonthForSmoothing (former dv).
    % Addition case modisspiresdaily for regions outside westernUS. 20240916.
    if versionBeforeV20240d
      for i=1:length(firstDateOfMonthForSmoothing)
          inloc = [scratchPath, 'modis/intermediary/spiresfill_', ...
              region.espEnv.modisData.versionOf.modisspiresfill, ...
              '/v006/', regionName, '/', char(firstDateOfMonthForSmoothing(i), 'yyyy'), '/']; 
              % Seb 20240204 location of input distinct from output.
          fname=fullfile(inloc,[regionName, '_', char(firstDateOfMonthForSmoothing(i), 'yyyyMM'), ...
              '_', num2str(rowStartId), '_', num2str(rowEndId), '_', num2str(columnStartId), '_', num2str(columnEndId), '.mat']);
              % Seb 20240227: change of input filename (cell-dependent).
          % If file absent on scratch, try rsync from archive. Seba 20240910.
          if exist(fname, 'file') == 0
              archiveFilePath = strrep(fname, espEnv.scratchPath, espEnv.archivePath);
              cmd = [espEnv.rsyncAlias, ' ', archiveFilePath, ' ', fname];
              fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
              [status, cmdout] = system(cmd);
          end
          %if fname doesn't exist,  delete lock, throw error
          if exist(fname,'file')==0
              %delete(lockname); %Seb 20240204
%{
              % This doesnt work and should be removed.                            @todo
              % f we are not in the last month and today is the first day of this month, there might be a lag with a run just after midnight while
              % the spires inversion was before midnight. 20241001.
              if i == length(firstDateOfMonthForSmoothing) && day(waterYearDate.dateOfToday) == 1
                  firstDateOfMonthForSmoothing = firstDateOfMonthForSmoothing(1:end - 1);
                  warning(['Lag from 30/31 spires fill run to 1st of month spires ', ...
                      'smooth: Removed the last month %d.\n'], ...
                      month(firstDateOfMonthForSmoothing(i)));
              else
%}
                  % Otherwise error, the spires inversor files should always be there.
                  error('matfile %s doesnt exist\n',fname); % NB: There's a problem here, this error is raised but not reported at the end of the script log runSmooth...sh.                                                      @todo
              %end
          end
      end
    else
      % Check is done with espEnv.getDataForWaterYearDateAndVarName(). 20240916.
    end
    
    out = struct(); % Seb 20240204. Transfer reading variables to a function, and reading when necessary to reduce mem consumption.
    % Seb 20240204. Moved on top:
    out.matdates=matdates;
    
%{
    for i=1:size(firstDateOfMonthForSmoothing,1)
        fprintf('Handling wateryear month %d...\n', i);
        inloc = [scratchPath, 'modis/intermediary/spiresfill_v2024.0/v006/', regionName, '/', datestr(firstDateOfMonthForSmoothing(i,:),'yyyy'), '/']; 
            % Seb 20240204 location of input distinct from output.
        fname=fullfile(inloc,[regionName, '_', datestr(firstDateOfMonthForSmoothing(i,:),'yyyymm'), '.mat']);
        m=matfile(fname);

        if i==1
            for j=1:length(vars)
                out.(vars{j})=zeros([size(m.(vars{j}),1) size(m.(vars{j}),2) ...
                    length(matdates)],'single');
            end
        end
        doy_start=datenum(firstDateOfMonthForSmoothing(i,:))-datenum(firstDateOfMonthForSmoothing(1,:))+1;
        doy_end=doy_start+size(m.fsca,3)-1;

        %convert to single and scale
        for j=1:length(vars)
            fprintf('Handling variable %d...\n', i);
            tt=m.(vars{j})==intmax(dtype{j});
            v=single(m.(vars{j}));
            v(tt)=NaN;
            v=v/divisor(j);
            out.(vars{j})(:,:,doy_start:doy_end)=v;
        end
    end
%}
    fprintf('finished reading %s...%s\n',datestr(matdates(1)),...
        datestr(matdates(end)));
    

    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % classic full smoothing and albedo calculation, done by default.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    if thisMode == 0
        appendFlag = '-new';
        % classic full smoothing and albedo calculation, done by default.

        % 2. - Loading of fsca and grainradius with the new function
        % loadVariableForSpiresSmooth20240204() to avoid to load all variables
        % simultaneously.
        % - Duplicate fsca into fsca_raw (=viewable).
        % - Application of a movingPersist() (not sure what is does) using all fsca and
        % grainradius above threshold to create a mask.
        % - all fsca is set to 0 when mask = 1.
        
        if versionBeforeV20240d
          out = loadVariableForSpiresSmooth20240204(8, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading fsca in spiresfill (which is fsca_raw).
          out.fsca_raw = out.fsca;
          indicesToSave = intersect(indicesToSave, 1:size(out.fsca_raw, 3));
          %store raw values before any adjustments
          % out.fsca_raw=out.fsca; moved down Seb 20240318.
          saveVariableForSpiresSmooth20240204(10, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204-0624 save raw_viewable_snow_fraction_s (formerly gap_fsca). dont take out, for which fsca_raw has been deleted.
          appendFlag = '-append';
          out.fsca = [];
        else
          out = loadVariableForSpiresSmooth20240204(1, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading fsca_raw in spires daily.
          indicesToSave = intersect(indicesToSave, 1:size(out.fsca_raw, 3));
        end
        %run binary fsca mask through temporal filter
        
        if versionBeforeV20240d
          % grainradius
          out = loadVariableForSpiresSmooth20240204(3, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240624 Loading grainradius.
          out = saveVariableForSpiresSmooth20240204(38, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save raw_grain_size_s (initially calculated grainradius) and remove it from out.
        end
        
        out = loadVariableForSpiresSmooth20240204(35, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240624 Loading spatial_grain_size_s.
        out.grainradius = out.spatial_grain_size_s; % grainradius for the smoothing is spatial_grain_size_s.
        
        if versionBeforeV20240d
          out = saveVariableForSpiresSmooth20240204(35, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save spatial_grain_size_s and remove it from out.
        else
          out.spatial_grain_size_s = [];
        end

        % Filtering clouds, low ndsi, water, elevation ...
        if versionBeforeV20240d
          out.tmask=out.fsca_raw > fsca_thresh & out.grainradius > mingrainradius;
          fprintf('Starting movingPersist...\n');
          tic
          out.tmask=movingPersist(out.tmask,windowSize,windowThresh); 
          fprintf('Done movingPersist in %f secs.\n', toc);

          %create 2 smoothed versions: fsca (adjusted for cc,ice,shade,
          % elevation cutoff,watermask, fsca_min)
          %and fsca_raw (no cc,ice adj, or shade adj), but elevation cutoff, watermask, &
          %fsca_min applied)
          out.fsca_raw(~out.tmask)=0;
          % out.fsca_raw(~out.tmask)=0; SEB 2024-03-18

          out = saveVariableForSpiresSmooth20240204(29, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save (and delete from out) cloudMaskMovingPersist (tmask).
        else
          objectName = region.name;
          inputDataLabel = 'modspiresdaily';
          varName = 'daily_nodata_filter_s';
          
          complementaryLabel = '';
          force = struct();
          optim = struct();
          optim.countOfCellPerDimension = [sqrt(countOfCells), sqrt(countOfCells)];
          optim.cellIdx(1) = cellIdx - floor((cellIdx - 1) / optim.countOfCellPerDimension(1)) ...
              * optim.countOfCellPerDimension(1);
          optim.cellIdx(2) = floor((cellIdx - 1) / optim.countOfCellPerDimension(1)) + 1;
          
          dailyNoDataFilter = espEnv.getDataForWaterYearDateAndVarName( ...
            objectName, inputDataLabel, extendedWaterYearDate, varName, force = force, ...
            optim = optim);
            
          varName = 'daily_zero_filter_s';
          dailyZeroFilter = espEnv.getDataForWaterYearDateAndVarName( ...
            objectName, inputDataLabel, extendedWaterYearDate, varName, force = force, ...
            optim = optim);
            
%{
          raw_viewable_snow_fraction (=fsca_raw) is nodata in spiresdaily in these cases:
          daily_nodata_filter: uint8, position 1: hasNoInput, 2: neuralCloud,
            3: background reflectance nodata, 4: rareObservation (4 not implemented now 20241026).
            This daily_nodata_filter is applied before computing the spires inversion, and 
            the values of raw_viewable_snow_fraction in spires daily are nodata.
          raw_viewable_snow_fraction (=fsca_raw) should be set to 0 in these cases:
          daily_zero_filter: uint8, Bit, position 1: NeuralNeither, excluding
            state_1km.clouds and including state_1km.saltpans, 2: NDSIBelowMinus005,
            3: rawSnowBelow10, 4: rawGrainBelow40, 5: lowElevation, 6: waterBody.
            4: rawGrainBelow40: may indicate rather a icecloud, so it should be set to nodata... (set to 0 in Ned's code).
            The daily_zero_filter 1,2,6 is applied before computing the spires inversion,
            the values of raw_viewable_snow_fraction in spires daily are nodata.
            > smoothSPIRES must then take 1,2,3,6 (imagining there's no elevation filter)
            and set raw_viewable_snow_fraction to zero before smoothing.
%}

          % Additional cloud filter inspired from the STC cloud filter.
          %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          fprintf('Calculation of isCloudRgb...\n');
          isCloudRgb = ones(size(out.fsca_raw), 'logical');
          cloudReflectanceMinValues = [35 35 31 31 30 22]; % NB: 6 thresholds, but there are 7 reflectance bands...
          reflectance = zeros([size(out.fsca_raw), 6], 'uint8');
          for varIdx = 1:length(cloudReflectanceMinValues) %7 %length(DailyDataVisualizer.reflectanceBandsForRGB)
            varName = SpiresInversor.reflectanceNames{varIdx}; % varIdx from 1 to 7.
            varData = ...
              espEnv.getDataForWaterYearDateAndVarName(objectName, ...
                inputDataLabel, extendedWaterYearDate, varName, force = force, ...
            optim = optim);
            % Beware for VIIRS, needs to imresize(min(varData, obj.maximalReflectanceValueForRGB), ...
            %  [thisSize(1), thisSize(2)], imresizeMethod);                        @todo
            isCloudRgb = isCloudRgb & varData > cloudReflectanceMinValues(varIdx);
            reflectance(:, :, :, varIdx) = varData;
          end
          varData = [];

          % Enlargement of cloud filter based on close clouds at same elevation.
          %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          % For this, we calculate a ratio of cloudy pixels around 1 pixel, these cloudy
          % pixels having the same elevation as the pixel.
          % Filters by elevation.
          fprintf('Spatial extension of cloud filter...\n');
          % window, get all in the elevation range.
          windowSize = 11; % 5 km. Tested filters 15 and 29 km (size 33 and 63), but cover many areas without clouds...
          minRatioOfCloudsAroundPixel = 1; % if pixel has a ratio
          % we use 2 sets of ranges, to avoid threshold issues, for instance: some dry lakes can be at 910 and a sink down to 890 the pixels 
          % si une majorite est no data, place le pixel en tant que no data.
          elevationStepRanges = {[-500, 0:100:5000, 5500, 6000, 9000], ...
            [-500, -50:100:5050, 5500, 6000, 9000]};
            
          n = (windowSize - 1)/2;
          [X, Y] = meshgrid(-n:n);
          weights = 1 ./ (sqrt(X.^2 + Y.^2) + 1);
      
          thisCloud = isCloudRgb | bitget(dailyNoDataFilter, 2);
            % the neural cloud filter also includes very dark pixels (reflectance < 10).
            % This should be corrected.                                            @todo
          thisCloud = imfilter(double(thisCloud), ones(5, 5)) > 3 & thisCloud;
          % before calculating the enlargement, we remove areas of 2.5 km with only
          % 3 pixels of cloud. NB: these pixels are still included in the final mask.
          ratioOfCloudsAroundPixel = zeros(size(thisCloud), 'uint8');

          % Repmat over time (because we're doing it here and not in SpiresInversor, where there's only 1 day at a time.
          elevationOverTime = repmat(elevation, [1, 1, size(out.fsca_raw, 3)]);
          for elevationStepRangeIdx = 1:length(elevationStepRanges)
            elevationSteps = elevationStepRanges{elevationStepRangeIdx};
            for elevationIdx = 1:(length(elevationSteps) - 1)
              fprintf('elevationStep %d -%d...\n', ...
                elevationSteps(elevationIdx), elevationSteps(elevationIdx + 1));
              isElevation = elevationOverTime >= elevationSteps(elevationIdx) & ...
                elevationOverTime < elevationSteps(elevationIdx + 1);
              thatCloud = uint8(100 * ...
                imfilter(double(thisCloud & isElevation), weights) ./ ...
                imfilter(double(isElevation), weights));
                  % NB: weights should be only 2D if we don't want to include the other
                  % days.
              ratioOfCloudsAroundPixel(isElevation) = ...
                  max(ratioOfCloudsAroundPixel(isElevation), thatCloud(isElevation));
              % we want proportion cloud vs all others (including water) no data / 0 /
              % others.
            end
          end
          thisCloud = ratioOfCloudsAroundPixel > minRatioOfCloudsAroundPixel;
          
          
          snowIsNoData = dailyNoDataFilter | isCloudRgb | thisCloud | ...
            (out.fsca_raw > 0 & out.fsca_raw <= (fsca_thresh * 100)) | ...
            (out.fsca_raw > (fsca_thresh * 100) & out.grainradius <= mingrainradius);
            % No data: no input data, clouds (neural network and STC filter),
            % extended areas around clouds, pixels having snow lower than 10, which
            % could be clouds too, pixels having snow > 10 but grain size lower than 40
            % could be clouds too!
          isCloudRgb = [];
          thisCloud = [];
          ratioOfCloudsAroundPixel = [];
          weights = [];
            
          snowIsZero = bitget(dailyZeroFilter, 1) | bitget(dailyZeroFilter, 2) | ...
            bitget(dailyZeroFilter, 5) | bitget(dailyZeroFilter, 6) | out.fsca_raw == 0;
          
          dailyNoDataFilter = [];
          dailyZeroFilter = [];
          
          
          out.fsca_raw(snowIsNoData) = intmax('uint8');
          out.fsca_raw(snowIsZero & ~snowIsNoData) = 0;
          
          % Removal of saltpans and occasional clouds at low elevation or bright buildings.
          %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          fprintf('Removal of saltpans...\n');
          canopyCover = espEnv.getDataForObjectNameDataLabel(objectName, 'canopycover');
          canopyCover = canopyCover(rowStartId:rowEndId, columnStartId:columnEndId);
          canopyCoverOverTime = repmat(canopyCover, [1, 1, size(out.fsca_raw, 3)]);
          snowCouldBeSaltPan = out.fsca_raw > 0 & canopyCover < 30;

          windowSize = 400; % 200 km. 
            % for the biggest salt lake, at salt lake city. 
            % This corresponds to the size of interpolated 36th subtiles.

          elevationSteps = [-50:10:5400]';
          isToSetToNoData = zeros(size(out.fsca_raw), 'logical');
          percentOfPixelsWithSnow = NaN([size(elevationSteps, 1), size(out.fsca_raw, 3)]);

          for elevationStepIdx = 1:length(elevationSteps) - 1
              isElevation = elevationOverTime >= elevationSteps(elevationStepIdx) & ...
                  elevationOverTime < elevationSteps(elevationStepIdx + 1);
              thatCountOfPixels = squeeze(sum(isElevation & canopyCoverOverTime < 30 & out.fsca_raw ~= intmax('uint8'), [1, 2]))';
              thatCountOfPixels(thatCountOfPixels < 25) = NaN; 
                  % we assume that below 25 pixels it's too risky to make an assumption.
              percentOfPixelsWithSnow(elevationStepIdx, :) = ...
                  100 * squeeze(sum(snowCouldBeSaltPan & isElevation, [1, 2]))' ./ ...
                  thatCountOfPixels;   
          end

          for elevationStepIdx = 1:(length(elevationSteps) - 40)
              isElevation = elevationOverTime >= elevationSteps(elevationStepIdx) & ...
                  elevationOverTime < elevationSteps(elevationStepIdx + 1);
              setToNoData = zeros([1, size(out.fsca_raw, 3)], 'uint8');
              % we scan the landscape in the 400 m included and above, by slices of 10 m.
              % NB: this won't work well if the saltpan is at the margin of the 36th
              % subtile.
              for elevationStepIdx2 = (elevationStepIdx):(elevationStepIdx + 40)
                % if on more than 25 pixels with that elev, there is less than 5%
                % that has snow, we suppose there is no snow.
                setToNoData = setToNoData + ...
                    uint8(~isnan(percentOfPixelsWithSnow(elevationStepIdx2, :)) & ...
                    percentOfPixelsWithSnow(elevationStepIdx2, :) < 5);

                if sum(setToNoData < 5) == 0
                    % We have reached 5 levels for all dates.
                    break;
                end
              end
              % if we found 5 times no snow, we suppose it's too low for snow.
              setToNoData = setToNoData >= 5;
              tmp = ones(1, 1, size(out.fsca_raw, 3));
              tmp(1, 1, :) = setToNoData;
              setToNoData = tmp;
              isToSetToNoData(snowCouldBeSaltPan & isElevation & repmat(setToNoData, ...
                  [size(out.fsca_raw, 1), size(out.fsca_raw, 2), 1])) = logical(1);
          end
          out.fsca_raw(isToSetToNoData) = intmax('uint8');
          snowIsNoData = out.fsca_raw == intmax('uint8');
          snowIsZero = out.fsca_raw == 0;
          
          % Temporal sliding window to determine if we have enough pixels for smoothing
          %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
          fprintf('Temporal filter to filter periods with enough observations...\n');
          % If not enough pixels, suggest cloudy period.
          isData = ones(size(out.fsca_raw), 'int16');
          isData(snowIsNoData) = intmax('int16');
          isData(snowIsZero) = 0;
          out.days_with_snow_observed_s = zeros(size(out.fsca_raw), 'uint16');
          out.days_with_absent_snow_observed_s = zeros(size(out.fsca_raw), 'uint16');
          out.days_without_observation_s = zeros(size(out.fsca_raw), 'uint16');
          
          % 3D to 2D Reshaping to improve reading performance of matrix
          isData = reshape(isData, ...
            [size(out.fsca_raw, 1) * size(out.fsca_raw, 2), size(out.fsca_raw, 3)]);
          daysWithSnowObserved = zeros(size(isData), 'uint16');
          daysWithAbsentSnowObserved = zeros(size(isData), 'uint16');
          daysWithoutObservation = zeros(size(isData), 'uint16');
          tic
          parfor pixelIdx = 1:size(isData, 1)
            thisIsData = isData(pixelIdx, :)';
            % Periods of days with snow observed.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisDaySinceObservationZero  = ones(size(thisIsData), 'int16');
              % int16 to make diff, which can be negative.
            thisDaySinceObservationZero(thisIsData == intmax('int16') | thisIsData ~= 0) = 0;

            indicesForPeriods = cumsum([1; abs(diff(thisDaySinceObservationZero, 1, 1))]);

            isEqualSuccessiveIndicesForPeriods = ...
              int16([1; indicesForPeriods(1:end - 1, :)] == indicesForPeriods);

            thisDaySinceObservationZeroWithOne = thisIsData; % zeros(size(z));
            thisDaySinceObservationZeroWithOne(thisDaySinceObservationZeroWithOne == intmax('int16')) = 0; % thisDaySinceObservationZeroWithOne(1) = isnan(z(1)) | z(1) ~= 0;
            for rowIdx = 2:size(thisDaySinceObservationZeroWithOne, 1)
              thisDaySinceObservationZeroWithOne(rowIdx) = ...
                thisDaySinceObservationZeroWithOne(rowIdx) ...
                + isEqualSuccessiveIndicesForPeriods(rowIdx) * ...
                thisDaySinceObservationZeroWithOne(rowIdx -1);
              %thisDaySinceObservationZeroWithOne(rowIdx) = isEqualSuccessiveIndicesForPeriods(rowIdx) ...
              %   .* thisIsData(rowIdx) + isEqualSuccessiveIndicesForPeriods(rowIdx) * thisDaySinceObservationZeroWithOne(rowIdx -1);
            end

            thisDayWithSnowObserved = thisDaySinceObservationZeroWithOne;
            for rowIdx = size(thisDayWithSnowObserved, 1) - 1: -1: 1
              thisDayWithSnowObserved(rowIdx) = ...
                isEqualSuccessiveIndicesForPeriods(rowIdx + 1) ...
                .* thisDayWithSnowObserved(rowIdx + 1) + ...
                int16(~isEqualSuccessiveIndicesForPeriods(rowIdx + 1)) ...
                .* thisDayWithSnowObserved(rowIdx);
            end
            daysWithSnowObserved(pixelIdx, :) = uint16(thisDayWithSnowObserved);

            % Periods with absent snow observed.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisDaySinceObservationSnow  = ones(size(thisIsData), 'int16');
              % int16 to make diff, which can be negative.
            thisDaySinceObservationSnow(thisIsData == intmax('int16') | thisIsData ~= 1) = 0;

            indicesForPeriods = cumsum([1; abs(diff(thisDaySinceObservationSnow, 1, 1))]);

            isEqualSuccessiveIndicesForPeriods = ...
              int16([1; indicesForPeriods(1:end - 1, :)] == indicesForPeriods);

            thisDaySinceObservationSnowWithAbsent = zeros(size(thisIsData));
            thisDaySinceObservationSnowWithAbsent(thisIsData == 0) = 1;
            thisDaySinceObservationSnowWithAbsent(thisIsData == 1) = 0;
            thisDaySinceObservationSnowWithAbsent(thisIsData == intmax('int16')) = 0;
            for rowIdx = 2:size(thisDaySinceObservationSnowWithAbsent, 1)
              thisDaySinceObservationSnowWithAbsent(rowIdx) = ...
                thisDaySinceObservationSnowWithAbsent(rowIdx) + ...
                isEqualSuccessiveIndicesForPeriods(rowIdx) * ...
                thisDaySinceObservationSnowWithAbsent(rowIdx -1);
            end

            thisDayWithAbsentSnowObserved = thisDaySinceObservationSnowWithAbsent;
            for rowIdx = size(thisDayWithAbsentSnowObserved, 1) - 1: -1: 1
              thisDayWithAbsentSnowObserved(rowIdx) = ...
                isEqualSuccessiveIndicesForPeriods(rowIdx + 1) ...
                .* thisDayWithAbsentSnowObserved(rowIdx + 1) + ...
                int16(~isEqualSuccessiveIndicesForPeriods(rowIdx + 1)) ...
                .* thisDayWithAbsentSnowObserved(rowIdx);
            end
            daysWithAbsentSnowObserved(pixelIdx, :) = ...
              uint16(thisDayWithAbsentSnowObserved);

            % Periods with no observation.
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            thisDaySince = ones(size(thisIsData), 'int16');

            % Determine which day is without observation.
            thisDaySince(thisIsData ~= intmax('int16')) = 0;
              
            indicesForPeriods = cumsum([1; abs(diff(thisDaySince, 1, 1))]);
            isEqualSuccessiveIndicesForPeriods = ...
              int16([1; indicesForPeriods(1:end - 1, :)] == indicesForPeriods);
            indicesForPeriods = [];

            for rowIdx = 2:size(thisDaySince, 1)
              thisDaySince(rowIdx) = isEqualSuccessiveIndicesForPeriods(rowIdx) ...
                .* thisDaySince(rowIdx - 1) + thisDaySince(rowIdx);
            end

            thisDayWithout = thisDaySince;
            for rowIdx = size(thisDayWithout, 1) - 1: -1: 1
              thisDayWithout(rowIdx) = ...
                isEqualSuccessiveIndicesForPeriods(rowIdx + 1) ...
                .* thisDayWithout(rowIdx + 1) + ...
                int16(~isEqualSuccessiveIndicesForPeriods(rowIdx + 1)) ...
                .* thisDayWithout(rowIdx);
            end
            daysWithoutObservation(pixelIdx, :) = ...
              uint16(thisDayWithout);
          end % parfor pixelIdx
          toc
          
          isData = [];
          out.days_with_snow_observed_s = reshape(daysWithSnowObserved, size(out.fsca_raw));
          out.days_with_absent_snow_observed_s = reshape(daysWithAbsentSnowObserved, size(out.fsca_raw));
          out.days_without_observation_s = reshape(daysWithoutObservation, size(out.fsca_raw));
          
          fprintf('Saving days without observations...\n');
          % 2. take the number of days with observations how many observations > 10
          % after the last 0 observed do we have in the last weeks.
            % for each day, calculate the number of days with snow between 2 zeros.
            % NB: in Ned's model, all these pixels are set to 0, including those with
            % ice clouds
          % No application of moving Window as a test but let appear a lot of snow which
          % are actually clouds. Seb 20241026.
          out.fsca_raw(out.days_with_snow_observed_s < 3 & ...
              out.days_with_snow_observed_s > 0) = intmax('uint8');
            % all periods when there are less than 5 days of observed snow are set to no data.
          out.fsca_raw(out.days_with_absent_snow_observed_s < 3 & ...
              out.days_with_absent_snow_observed_s > 0) = intmax('uint8');
            % all periods when there are less than 3 days of observed absent snow are set to no data.
            % NB: There's a problem here with false absent snow linked to the application of ndsi, which doesnt work well with reflectance values below 10.
            
          out = saveVariableForSpiresSmooth20240204(44, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save days_without_observation_s.
          appendFlag = '-append';
          out = saveVariableForSpiresSmooth20240204(45, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save days_with_snow_observed_s.
          out = saveVariableForSpiresSmooth20240204(46, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save days_with_absent_snow_observed_s.
          
          snowIsNoData = out.fsca_raw == intmax('uint8');
          snowIsZero = out.fsca_raw == 0;

        end % if versionBeforeV20240d cloud calculations.
        % 3. - Load sensor_zenith,
        % - Calculate canopy correction factor with canopy cover, sensor_zenith, using GOvgf
        %   function (same function as for STC).
        % - save sensorZ. NB: sensorZ was never interpolated.
        % - load ice, fshade.
        % - apply ice, fshda + canopy correction to fsca.
        % - set fsca = 1 if out of 0-1 range and = 0 if initially fsca was 0.
        % - set fsca and fsca_raw = 0 if < 500 m or water.
        % - load weights, and set weights = 0 where fsca = 0.
        % - smoothDataCube using smoothingspline() and weights of fsca, fsca_raw and fshade
        % - set their values to 0 where initial fsca/fsca_raw < 0.1.
        % - save fsca_raw and fshade.
        % - set fsca = fice, except where fsca < 0.1.
        % - load dust, and set dust/grainradius = NaN if out of expected ranges and
        %   dust = NaN if fsca = 0.
        % - set weights = 0 where grainradius = NaN, save original weights.
        % - interpolate each pixel and their temporal series for grainradius and dust.
        % - cap grainradius/dust to the expected range and set to NaN where fsca = 0.
        % - save fsca, grainradius, dust.
        % - [seb] ongoing work to add solar_zenith FillCubeDateLinear() and save (for albedo calculation)

        t=out.fsca_raw==0;
        
        fprintf('Loading fice...\n');
        fice=repmat(fice,[1 1 size(out.fsca_raw,3)]); % Moved above. 20240917.

        if versionBeforeV20240d
            %use GO model
            out = loadVariableForSpiresSmooth20240204(6, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading sensorZ.
            fprintf('Starting GOvgf...\n');
            tic;
            cc=repmat(cc,[1 1 size(out.fsca_raw,3)]); % Moved above. 20240917.
            cc_adj=1-GOvgf(cc,0,0,out.sensorZ,0,b_R);
            fprintf('Done Govgf in %f secs.\n', toc);
            
            out = saveVariableForSpiresSmooth20240204(6, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove sensor_zenith (formerly sensorZ).
            clear cc;
            
            out.fsca = out.fsca_raw; % Seb 2024-03-18. Moved down here to lower mem use. 20240917: inversed the use of fsca_raw and fsca.

            %combine cc and fshade adjustment
            out = loadVariableForSpiresSmooth20240204(2, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading fshade.
            tic;
            fprintf('Starting fice...\n');
            out.fsca=out.fsca./(1-cc_adj-out.fshade-fice);
            if ~fshadeIsInterpolated
                out = saveVariableForSpiresSmooth20240204(40, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove raw_shade_fraction_s (formerly fshade).
            end
            out.fsca(out.fsca>1 | out.fsca<0)=1;
            %fix 0/0
            out.fsca(t)=0;
            fprintf('Done fice in %f secs.\n', toc);
            saveVariableForSpiresSmooth20240204(30, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save canopy corrected raw_snow_fraction_s, formerly cc_snow_fraction.
        else
            out = loadVariableForSpiresSmooth20240204(8, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240917 Loading fsca, calculated in spiresInversor.
            out.fsca(snowIsZero) = 0;
            out.fsca(snowIsNoData) = intmax('uint8');
        end
        
        

        %masked area filter
        fprintf('Masking...\n');
        tic;
        bigwater=repmat(water,[1 1 size(out.fsca,3)]);
        
        if versionBeforeV20240d
            %elevation filter
            % [elevation,hdr]=GetTopography(topofile,'elevation'); %Seb20240204 moved on top of function.
            % Zmask=elevation < el_cutoff; Seb 20240303 move on Top.
            Zmask=repmat(Zmask,[1 1 size(out.fsca,3)]);
            out.fsca(Zmask | bigwater) = 0;
            out.fsca_raw(Zmask | bigwater) = 0;
            clear Zmask; % Seb 20240204.
            fprintf('Done masking in %f secs.\n', toc);
        end
        
        saveVariableForSpiresSmooth20240204(31, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save gap_viewable_snow_fraction_s (formerly presmoothed raw snow_fraction).
        saveVariableForSpiresSmooth20240204(32, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save gap_snow_fraction_s (formerly presmoothed snow_fraction).
    
        out = loadVariableForSpiresSmooth20240204(5, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading weights.
        newweights=out.weights;
        if versionBeforeV20240d
            newweights(isnan(out.fsca))=0; % Assume here fsca_raw is 0 at locations where fsca is 0.
        else
            newweights(out.fsca == intmax('uint8'))=1;
        end
        %fill in and smooth NaNs

        fprintf('smoothing fsca,fsca_raw,fshade %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));
        
        %smooth fully adj fsca
        if versionBeforeV20240d
            tic;
            out.fsca=smoothDataCube(out.fsca,newweights,'mask',~water,...
                'method','smoothingspline','SmoothingParam',0.1);
            fprintf('Temp. interpolated fsca in %f sec.\n', toc);
        end

        %smooth fsca_raw
        tic;
        isToInterpolate = ~water;
        if versionBeforeV20240d
            out.fsca_raw=smoothDataCube(out.fsca_raw,newweights,'mask',~water,...
                'method','smoothingspline','SmoothingParam',0.1);
            fprintf('Temp. interpolated fsca_raw in %f sec.\n', toc);
        else
            % Call a method that doesn't use truncateLimits, which artificially cap
            % the lowest values for small 36th subtile of the big modis tile.
            % this method also save 1 parfor loop.
            smoothingParams = [0.1, 0.1];
            output_cubes = smoothDataCube20241105( ...
                {out.fsca_raw, out.fsca}, newweights, isToInterpolate, smoothingParams);
            out.fsca_raw = output_cubes{1};
            out.fsca = output_cubes{2};
            output_cubes = [];
            fprintf('Temp. interpolated fsca_raw and fsca in %f sec.\n', toc);
        end

        %smooth fshade
        if fshadeIsInterpolated
            tic;
            out.fshade=smoothDataCube(out.fshade,newweights,'mask',~water,...
                'method','smoothingspline','SmoothingParam',0.1);
            clear newweights; % Seb 20240204.
            fprintf('Temp. interpolated fshade in %f sec.\n', toc);
        end
        
        %get some small fsca values from smoothing - set to zero
        fprintf('Additional filtering...\n');
        tic;
        if versionBeforeV20240d
            out.fsca(out.fsca<fsca_thresh)=0;
            out.fsca_raw(out.fsca_raw<fsca_thresh)=0;
            % truncateLimits called in smoothDataCube cap the min/max values.
            
            out.fsca(bigwater) = NaN;
            out.fsca_raw(bigwater)=NaN;
            
            out.fsca(out.fsca > 1) = 1;
            out.fsca_raw(out.fsca_raw > 1) = 1;

        else
            out.fsca(out.fsca_raw < fsca_thresh * 100) = 0;
            out.fsca_raw(out.fsca_raw < fsca_thresh * 100) = 0;
            out.fsca(out.fsca > 100) = 100;
            out.fsca_raw(out.fsca_raw > 100) = 100;
            
            out.fsca(bigwater) = intmax('uint8');
            out.fsca_raw(bigwater) = intmax('uint8');
        end

        fprintf('Filtered fsca and fsca_raw in %d secs.\n', toc);

        %same for fshade. NB: shouldn't be used in v2024.0f and above.
        if fshadeIsInterpolated
            tic;
            out.fshade(out.fsca_raw<fsca_thresh)=0;
            out.fshade(bigwater)=NaN;
            clear bigwater; % Seb 20240204.
            out = saveVariableForSpiresSmooth20240204(2, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove fshade.
            fprintf('Filtered fshade in %d secs.\n', toc);
        end
        
        % Calculation of snowCoverDays for regions outside westernUS 20240917.
        % NB: no elevation threshold, but fsca_thresh applied before.
        if ~versionBeforeV20240d
          out.snow_cover_days_s = cumsum(uint16(out.fsca_raw > 0 & out.fsca_raw ~= intmax('uint8')), 3);
          out = saveVariableForSpiresSmooth20240204(43, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save snow_cover_days_s and remove it from out.
        end

        %fix values below thresh to ice values
        tic;
        t = out.fsca < fice; % for v2024.0d, from 0 to 1, for v2024.0f from 0 to 100.
        out.fsca(t) = fice(t);
        clear fice; % Seb 20240204.
        if versionBeforeV20240d
            out.fsca(out.fsca<fsca_thresh)=0;
        else
            out.fsca(out.fsca_raw < fsca_thresh * 100) = 0;
        end
        out = saveVariableForSpiresSmooth20240204(1, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove viewable_snow_fraction_s (formerly fsca_raw). Updated varId 20240917.
        
        fprintf('Done additional filtering on fsca in %d secs.\n', toc);
        fprintf('finished smoothing fsca,fsca_raw,fshade %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));

        fprintf('smoothing grain radius and dust %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));

        %create mask of any fsca for interpolation
        
        if versionBeforeV20240d
          anyfsca=any(out.fsca,3);
        else
          isToInterpolate = sum(uint16(out.fsca > 0 & out.fsca ~= intmax('uint8')) > 0, 3) > 0;
        end
        
        if versionBeforeV20240d
          out = loadVariableForSpiresSmooth20240204(4, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240624 Loading initial dust.
          out = saveVariableForSpiresSmooth20240204(39, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save raw_dust_concentration_s (initially calculated dust) and remove it from out.
        end
        
        out = loadVariableForSpiresSmooth20240204(36, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204-0624 Loading spatialdust (formerly dust).
        out.dust = out.spatial_dust_concentration_s; % dust for smoothing is spatial_dust_concentration_s.
        
        if versionBeforeV20240d
          out = saveVariableForSpiresSmooth20240204(36, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save spatial_dust_concentration_s and remove it from out.
        else
          out.spatial_dust_concentration_s = [];
        end
        
        fprintf('Filtering on grainradius/dust...\n');
        tic;
        if versionBeforeV20240d
            badg = out.grainradius < mingrainradius | out.grainradius > maxgrainradius | ...
                out.dust > maxdust ;

            %grain sizes too small or large to be trusted
            out.grainradius(badg)=NaN;
            out.dust(badg)=NaN;
            
            %grain sizes after melt out
            out.dust(out.fsca==0) = NaN;
        else
            badg = out.grainradius < mingrainradius | out.grainradius > maxgrainradius | ...
                out.dust > maxdust * 10;

            %grain sizes too small or large to be trusted
            out.grainradius(badg) = intmax(class(out.grainradius));
            out.dust(badg | out.fsca == 0 | out.fsca == intmax('uint8')) = intmax(class(out.dust)); % and grain sizes after melt out
        end
        clear badg;

        
        fprintf('Done filtering on grainradius/dust in %f sec.\n', toc);
        %don't set out.grainradius to nan where fsca==0 until later
        %this helps maintain high grain size values
        % Save gap_grain_size_s and gap_dust_concentration_s 20240624.
        saveVariableForSpiresSmooth20240204(41, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save gap_grain_size_s (presmoothed grain size) and not remove it from out.
        saveVariableForSpiresSmooth20240204(42, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save gap_dust_concentration_s (presmoothed dust) and not remove it from out.

        % create new weights for grain size and dust
        newweights = out.weights;
        if versionBeforeV20240d
            out = saveVariableForSpiresSmooth20240204(5, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove time_interp_weight_s (formerly weights).
            newweights(isnan(out.grainradius) | out.fsca==0)=0;
        else
            newweights(out.grainradius == intmax(class(out.grainradius)) | ...
                out.fsca == 0 | out.fsca == intmax('uint8')) = 1; % for v2024.0f weights are from 1 to 100.
        end
        
        if size(out.grainradius, 3) < 365
          if ~ismember(datestr(matdates(end),'mm'), {'05', '06', '07', '08', '09'})
            fixpeak = 0; % Set temporarily for ongoing water year.
          else
            Nd = 0; % we peak fix but don't taper the values to minimum at the end of the
              % record. @warning
          end
        end
        
        if fixpeak % set values after peak grain radius to peak
            N = size(out.grainradius);
            %reshape to days x pixels
            grainradius=reshape(out.grainradius,N(1)*N(2),N(3))';
            dust=reshape(out.dust,N(1)*N(2),N(3))';
            out.fsca = reshape(out.fsca,N(1)*N(2),N(3))';
            weights=reshape(newweights,N(1)*N(2),N(3))';
            clear newweights; % Seb 20240204.
            out.grainradius = [];
            out.dust = [];
            
            tic;
            fprintf('Peak Fixing and smoothing grainradius and dust...\n');
            parfor i=1:size(grainradius,2)
                fscavec = squeeze(out.fsca(:,i));
                if sum(fscavec(fscavec ~= 0 & fscavec ~= intmax('uint8')), 'all') == 0 %skip pixels w/ no snow
                    continue;
                end
                t = fscavec > 0 & fscavec ~= intmax('uint8');
                
                rgvec=squeeze(grainradius(:,i));
                weightsvec=squeeze(weights(:,i));

                if ~versionBeforeV20240d
                    rgVecIsNoData = rgvec == intmax(class(rgvec));
                    rgvec = double(rgvec);
                    rgvec(rgVecIsNoData) = NaN;
                end
                %get rid of spikes & drops
                rgvec=hampel(rgvec, 2, 2);

                
                %last day with snow, or end of cube
                meltOutday=min(find(t,1,'last'),length(rgvec));
                
                %peak fixing cannot last more than N days from final peak
                %make a temp copy of rgvec
                rgvec_t = rgvec;
                maxFixedDays = 40;%days
                %set all days prior to meltOutday-maxFixedDays to nan
                rgvec_t(1:(meltOutday-maxFixedDays)) = nan;
                [~,maxDay] = max(rgvec_t,[],'omitnan');
                
                % Seb 2024-05-23: peak for NRT. Cannot work as for historic because when
                % there is still snow on the last day of NRT record, we don't know if it's
                % the last day of snow.   
%{            
                if length(rgvec) < 365 && meltOutday == length(rgvec)
                    x = maxDay:length(rgvec);
                    y = fscavec(maxDay:length(rgvec));
                    coeff = polyfit(x, y, 1);
                    X = maxDay:365;
                    Y = polyval(coeff, X);
                    meltOutday = min(find(Y >= fsca_thresh, 1, 'last'), 365);
                end 
%}            
                endDay = length(rgvec) - Nd;

                %set those days to (near) max grain size
                ind = maxDay:endDay;

                maxrg = rgvec(maxDay);
                rgvec(ind) = maxrg;

                %smooth up to maxDay
                ids = 1:maxDay-1;
                
                %set 1st day to min, may be set to nan later, but helps w/
                %keeping spline in check
                rgvec(1) = mingrainradius;
                weightsvec(1) = 1;

                rgvec(ids) = smoothVector(ids', rgvec(ids), double(weightsvec(ids)), 0.8);
                %taper vector to min value only for full waterYear Seb 20240523.
                if Nd ~= 0
                  rgvec = taperVector(rgvec, Nd, mingrainradius);
                end
                %dust: set dust for all days prior to 0 if below grain thresh
                dustvec = squeeze(dust(:,i));
                
                if ~versionBeforeV20240d
                    dustvecIsNoData = dustvec == intmax(class(dustvec));
                    dustvec = double(dustvec);
                    dustvec(dustvecIsNoData) = NaN;
                end

                %all days with small grain sizes
                tt= rgvec <= dust_rg_thresh;

                %all days prior to max grain size
                ttstart=false(size(tt));
                ttstart(1:maxDay-1)=true;

                %all days prior to max grain size with small grains
                tt=ttstart & tt;

                %set dust on those days to zero
                dustvec(tt)=0;

                %use dust value from max rg day
                dval=dustvec(maxDay);

                %set dust after those days to value on maxday
                dustvec(ind)=dval;
     
                %set dust to zero on day 1
                dustvec(1) = 0;
                weightsvec(1) = 1;
                %smooth up until maxday
                dustvec(ids)=smoothVector(ids', dustvec(ids),...
                    double(weightsvec(ids)), 0.1);
                % taper only for full waterYear Seb 20240523.
                if Nd ~= 0
                  dustvec = taperVector(dustvec,Nd,mindust);
                end
                weightsvec=squeeze(weights(:,i));
                
                if ~versionBeforeV20240d
                  rgvec = cast(rgvec, 'uint16'); % class(grainradius) doesnt work with parfor here.
                  dustvec = cast(dustvec, 'uint16');
                end
                grainradius(:,i) = rgvec;
                dust(:, i) = dustvec;
            end
            fprintf('Done smoothing grainradius and dust in %f secs.\n', toc);
            clear weights; % Seb 20240204.
            %put back into cube
            % out.fsca = reshape(fsca',N(1),N(2),N(3)); % Seb 20240204 useless.
            out.grainradius = reshape(grainradius',N(1),N(2),N(3));
            out.dust = reshape(dust',N(1),N(2),N(3));
            grainradius = [];
            dust = [];
            
            out.fsca = reshape(out.fsca', N(1),N(2),N(3));  
            
        else %don't fix values after peak grain size
            if versionBeforeV20240d
                tic;
                out.grainradius=smoothDataCube(out.grainradius,newweights,'mask',anyfsca,...
                    'method','smoothingspline','SmoothingParam',0.8);
                fprintf('Done smoothing grainradius without peak handling in %f secs.\n', toc);
                %assume zero dust for small grains
                out.dust(out.grainradius<dust_rg_thresh)=0;
                tic;
                out.dust=smoothDataCube(out.dust,newweights,'mask',anyfsca,...
                    'method','smoothingspline','SmoothingParam',0.1);
                fprintf('Done smoothing dust without peak handling in %f secs.\n', toc);
            else
                tic;
                thresholdOfFirstVariableToSetSecondToZero = dust_rg_thresh;
                smoothingParams = [0.8, 0.1];
                output_cubes = smoothDataCube20241105( ...
                    {out.grainradius, out.dust}, newweights, isToInterpolate, [0.8, 0.1], thresholdOfFirstVariableToSetSecondToZero);
                    % %assume zero dust for small grains: done now in smoothDataCube20241105().
                out.grainradius = output_cubes{1};
                out.dust = output_cubes{2};
                output_cubes = [];
                fprintf('Done smoothing grainradius and dust without peak handling in %f secs.\n', toc);
            end
        end % end if fixpeak.

        fprintf('finished smoothing grain radius and dust %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));
        fprintf('Filtering on grainradius...\n');
        tic;
        out.grainradius(out.grainradius < mingrainradius) = mingrainradius;
        out.grainradius(out.grainradius > maxgrainradius & ...
            out.grainradius ~= intmax(class(out.grainradius))) = maxgrainradius;
        if versionBeforeV20240d
            out.grainradius(out.fsca == 0) = NaN;
        else
            out.grainradius(out.fsca == 0) = intmax(class(out.grainradius));
        end
        fprintf('Done filtering on grainradius in %f secs.\n', toc);
        saveVariableForSpiresSmooth20240204(3, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save smoothed grainradius but not remove.

        %clean up out of bounds splines
        fprintf('Filtering on dust...\n');
        tic;
        if versionBeforeV20240d
            out.dust(out.dust > maxdust) = maxdust;
            out.dust(out.dust < mindust) = mindust;
            out.dust(out.fsca == 0) = NaN;
        else
            out.dust(out.dust > maxdust * 10 & out.dust ~= intmax(class(out.dust))) = maxdust * 10;
            out.dust(out.dust < mindust * 10) = mindust * 10;
            out.dust(out.fsca == 0) = intmax(class(out.dust));
        end
          
        fprintf('Done filtering on dust in %f secs.\n', toc);
        saveVariableForSpiresSmooth20240204(4, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save dust but not remove.

        fprintf('finished smoothing dust %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));

        %write out h5 cubes
%{  
        % Seb 20240204. Moving this on top of function.
        out.matdates=matdates;
        out.hdr=hdr;
%}
        fprintf('writing cubes %s...%s\n',datestr(matdates(1)),...
            datestr(matdates(end)));

        out = saveVariableForSpiresSmooth20240204(8, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); % Seb 20240204 save and remove snow_fraction_s (formerly fsca). 20240917. Updated varId.
        
        if versionBeforeV20240d
            out = loadVariableForSpiresSmooth20240204(7, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading solarZ.
            % for v2024.0f, int, capped to 0-90 and already fillmissed in the previous script.
            
        
            % Seb 20240222 Interpolating temporally solarZ.
            out.(vars{7})(out.(vars{7}) > 90) = NaN;

            %% If the matrix contains any NaNs, do linear interpolation
            %% along dimension 3 (across missing slices), also fills
            %% missing end values with nearest non-NaN.
            % fillmissing() doesn't need double precision and we use only single precision.
            if any(isnan(out.(vars{7})), 'all')
                out.(vars{7}) = fillmissing(out.(vars{7}), 'linear', 3, EndValues = 'nearest'); % Seb 2024-03-19, in replacement of FillCubeDateLinear().
            end
            %out.(vars{7}) = FillCubeDateLinear(matdates, matdates, out.(vars{7}), 90); % Seb 20240222
            saveVariableForSpiresSmooth20240204(7, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); 
            % Seb 20240204 save and not remove solar_zenith (formerly solarZ). Not very performant since we convert back and forth to single, with a division...
        
            out = loadVariableForSpiresSmooth20240204(28, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, extendedWaterYearDate, varInSpiresDaily); % Seb 20240204 Loading SolarAzimuth.
            % for v2024.0f, int, capped to -180-180 and already fillmissed in the previous script.

            % Seb 20240222 Interpolating temporally SolarAzimuth.
            out.(vars{28})(out.(vars{28}) > 180) = NaN;
            if any(isnan(out.(vars{28})), 'all')
                out.(vars{28}) = fillmissing(out.(vars{28}), 'linear', 3, EndValues = 'nearest'); % Seb 2024-03-19, in replacement of FillCubeDateLinear().
            end
            % out.(vars{28}) = FillCubeDateLinear(matdates, matdates, out.(vars{28}), 180); % Seb 20240222
            saveVariableForSpiresSmooth20240204(28, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave); 
            % Seb 20240204 save and remove solar_azimuth (formerly SolarAzimuth). Not very performant since we convert back and forth to single, with a division...

            tic;
            % Albedo calculation. Seb 20240227:
            fprintf('%s: Calculating albedo...\n', mfilename()); 
            varName = 'albedo_s';
            out.(varName) = NaN(size(out.grainradius), 'double');
            % elevation = repmat(elevation, [1 1 size(out.grainradius, 3)]); % Seb 20240228. Not sure performance.
        
            indicesForNotNaN = find(~isnan(out.grainradius) & ...
                ~isnan(out.dust) & ...
                ~isnan(out.solarZ));
       
            varName = 'deltavis_s';
            out.(varName) = NaN(size(out.grainradius), 'double');
            
            varName = 'radiative_forcing_s';
            out.(varName) = NaN(size(out.grainradius), 'double');
            varName = 'albedo_s';
            if numel(indicesForNotNaN) ~= 0
    %{
                out.(varName)(indicesForNotNaN) = ...
                    AlbedoLookup(out.grainradius(indicesForNotNaN), ...
                        cosd(out.solarZ(indicesForNotNaN)), ...
                    [], elevation(indicesForNotNaN), LAPname = 'dust', ...
                    LAPconc = out.dust(indicesForNotNaN) / 1000); % Seb 20240228. dust is in ppm while AlbedoLookup expects ppt (why??????) to check with Karl @warning.
                    % AlbedoLookup in ParBal package.
    %}
                if ~versionBeforeV20240d
                    out.grainradius = double(out.grainradius);
                    out.dust = double(out.dust) / 10;
                    out.solarZ = double(out.solarZ);
                end
                % Dirty albedo and radiative forcing from Jeff lookup tables. 2024-05-10.
                albedoForcingCalculator = AlbedoForcingCalculator(region);
                [albedo, deltavis, radiativeForcing] = albedoForcingCalculator.getFromLookup(out.grainradius(indicesForNotNaN), ...
                    out.dust(indicesForNotNaN), cosd(out.solarZ(indicesForNotNaN)));
                 out.(varName)(indicesForNotNaN) = albedo;
                 varName = 'deltavis_s';
                 out.(varName)(indicesForNotNaN) = deltavis;
                 varName = 'radiative_forcing_s';
                 out.(varName)(indicesForNotNaN) = radiativeForcing;
            end
            fprintf('%s: Calculated albedo in %f sec.\n', mfilename(), toc);
            
            out = saveVariableForSpiresSmooth20240204(9, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave);
            out = saveVariableForSpiresSmooth20240204(33, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave);
            out = saveVariableForSpiresSmooth20240204(34, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave);
        end % if versionBeforeV20240d, calculations for albedos.
    end % if thisMode == 0
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 20240624 albedo_muZ_s (quick and dirty implementation)
    if thisMode == 1
        %Tweak to regenerate only albedo_muZ_s without touching other variables 20240811.
        objectName = region.name;
        dataLabel = 'modisspiressmoothbycell';
        thisDate = theseDates(end);
        varName = '';
        complementaryLabel = '';
        optim = struct(cellIdx = [rowCellIdx, columnCellIdx, 1], ...
            countOfCellPerDimension = [sqrt(countOfCells), sqrt(countOfCells), 1], ...
            countOfPixelPerDimension = ...
                [modisData.sensorProperties.tiling.rowPixelCount, ...
                    modisData.sensorProperties.tiling.columnPixelCount, 1]);
        force = struct(type = 'double');
        [filePath, fileExists, lastDateInFile, waterYearDate, metaData] = ...
            espEnv.getFilePathForWaterYearDate( ...
            objectName, dataLabel, waterYearDate, optim = optim);
        indicesToSave = 1:length(waterYearDate.getDailyDatetimeRange());
        fprintf('Running only albedo_muZ_s, extracting data from %s...\n', filePath{1});
        
        varNames = {'grain_size_s', 'dust_concentration_s', 'solar_azimuth', ...
            'solar_zenith'};
        scriptVarNames = {'grainradius', 'dust', 'SolarAzimuth', 'solarZ'};
        for varIdx = 1:length(varNames)
            varName = varNames{varIdx};
            force.divisor = 1;
            if strcmp(varName, 'dust_concentration_s')
                force.divisor = 10;
            end
            out.(scriptVarNames{varIdx}) = espEnv.getDataForWaterYearDateAndVarName( ...
                objectName, dataLabel, waterYearDate, varName, force = force, ...
                optim = optim);
        end
        indicesForNotNaN = find(~isnan(out.grainradius) & ...
            ~isnan(out.dust) & ...
            ~isnan(out.solarZ));
            
        albedoForcingCalculator = AlbedoForcingCalculator(region);
    end % if thisMode == 1
    
    % NB: A bit silly to require the 3rd dim here...
    if versionBeforeV20240d
        tic
        fprintf('%s: Calculating albedo_muZ...\n', mfilename()); 
        varName = 'albedo_muZ_s';
        out.(varName) = NaN(size(out.grainradius), 'double');
        if numel(indicesForNotNaN) ~= 0  
             
              % out.grainradius, dust, solarZ converted to double above, for v2024.0f.
              mu0 = cosd(out.solarZ);
              mu0(isnan(out.solarZ)) = NaN;
              out.solarZ = [];

              % phi0: Normalize stored azimuths to expected azimuths
              % stored data is assumed to be -180 to 180 with 0 at North
              % expected data is assumed to be +ccw from South, -180 to 180
              phi0 = 180. - out.SolarAzimuth;
              out.SolarAzimuth = [];
              phi0(phi0 > 180) = phi0(phi0 > 180) - 360;

              [slope, ~, ~] = ...
                    espEnv.getDataForObjectNameDataLabel(regionName, 'slope');
              slope = repmat(cast(slope(rowStartId:rowEndId, columnStartId:columnEndId), 'double'), [1, 1, size(phi0, 3)]);
              [aspect, ~, ~] = ...
                  espEnv.getDataForObjectNameDataLabel(regionName, 'aspect');
              aspect = repmat(cast(aspect(rowStartId:rowEndId, columnStartId:columnEndId), 'double'), [1, 1, size(phi0, 3)]); % Slope and aspect are input of cosd within ParBal.sunslope, which only accept double.
                % Aspect for westernUS tiles is stored 
                
              % Based on conversation with Dozier, Aug 2023:
              % N.B.: phi0 and aspect must be referenced to the same
            % angular convention for this function to work properly
              muZ = sunslope(mu0, phi0, slope, aspect);
              muZ(muZ > 1.0) = 1.0; % 2024-01-05, occasionally ParBal.sunslope()
                  % returns a few 10-16 higher than 1 (h24v05, 2011/01/08)
                  % Patch should be inserted in ParBal.sunslope().
              [albedo, ~, ~] = albedoForcingCalculator.getFromLookup(out.grainradius(indicesForNotNaN), ...
                out.dust(indicesForNotNaN), muZ(indicesForNotNaN));
              out.(varName)(indicesForNotNaN) = albedo;
        end
        fprintf('%s: Calculated albedo_muZ in %f sec.\n', mfilename(), toc);
        out = saveVariableForSpiresSmooth20240204(37, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % End albedo calculation.
    end % if versionBeforeV20240d.
%{
    % Seb 20240304 Add and save additional variables to understand why there's no snow in north
    % western US for ongoing 2024 water year.
    for varIdx = 11:27
        try
            out = loadVariableForSpiresSmooth20240204(varIdx, firstDateOfMonthForSmoothing, region, vars, divisor, dtype, matdates, out, cellIdx, waterYearDate, varInSpiresDaily);
        catch e
            warning(e.message);
            continue;
        end
        out = saveVariableForSpiresSmooth20240204(varIdx, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave);
    end
%}
%{
    % Seb 20240204 move this on top of function.
    %output variables
    outvars={'fsca_raw','fsca','fshade','grainradius','dust'};
    outnames={'raw_snow_fraction','snow_fraction','shade_fraction','grain_size','dust'};
    outdtype={'uint8','uint8','uint8','uint16','uint16'};
    outdivisors=[100 100 100 1 10];
%}
%{
    %create h5 cube in tmp then move to avoid network h5 write issues
    h5tmpname=fullfile(tempdir,[regionName, '_', datestr(matdates(end),'yyyy') '.h5']); % Seb 20240204 name and moved above.
%}
%{
    % Seb 20240204: replaced this one shot save by regular saving over the script progress using saveVariableForSpiresSmooth20240204()
    for i=1:length(outvars)
        member=outnames{i};
        Value=out.(outvars{i});
        dS.(member).divisor=outdivisors(i);
        dS.(member).dataType=outdtype{i};
        dS.(member).maxVal=max(Value(:));
        dS.(member).FillValue=intmax(dS.(member).dataType);
        writeh5stcubes(h5tmpname,dS,out.hdr,out.matdates,member,Value);
    end
%}
    %system(['mv ' h5tmpname ' ' h5name]); Seb 20240312
    % delete(lockname); %  Seb 20240204
    time2=toc(time1);
    fprintf('completed in %5.2f hr\n',time2/60/60);
    %end
end

%{
% Seb 20240204 Removed the no overwriting existing files.
function CleanupFun(lockname)
    if exist(lockname,'file')==2
        fprintf('cleaning up %s\n',lockname)
        delete(lockname)
    end
end
%}

% MAYBE ADD a cleanup of temp files in function is stopped unexpectedly? Code Won't be able to overwrite h5 file...
% Or update the function writeh5 if in error, doesn't create but just write?
