function out=smoothSPIREScube20240204(region, cellIdx, matdates, fshadeIsInterpolated)
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
    el_cutoff = 500; 
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
    rowStartId = uint32(mod(countOfPixels / sqrt(countOfCells) * (cellIdx - 1) + 1, countOfPixels));
    rowEndId = uint32(rowStartId + countOfPixels / sqrt(countOfCells) - 1);
    columnStartId = uint32(countOfPixels / sqrt(countOfCells) * (floor((cellIdx - 1) / sqrt(countOfCells))) + 1);
    columnEndId = uint32(columnStartId + countOfPixels / sqrt(countOfCells) - 1);
    
    regionName = region.name; % Seb 2024-03-02
    espEnv = region.espEnv;
    scratchPath = espEnv.scratchPath;
    if ismember(regionName, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'}) % Sen 2024-03-02 Special handling of westernUs with Ned's ancillaries.
        baseDir = [scratchPath, 'modis/input_spires_from_Ned_202311/Inputs/MODIS/'];
        maskfile = [baseDir, 'watermask/', regionName, 'watermask.mat'];
        mask = matfile(maskfile).mask;
        topofile = [baseDir, 'Z/', regionName, 'Topography.h5'];
        [Z,~]=GetTopography(topofile,'elevation'); % Seb 20240204 moved on top.
        % out.hdr=hdr; % Seb 20240227 unnecessary now.
        ccfile = [baseDir, 'cc/', 'cc_', regionName, '.mat'];
        cc = matfile(ccfile).cc;
        ficefile = [baseDir, 'fice/', regionName, '.mat'];
        fice = matfile(ficefile).fice;
    else
        mask = region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'water');
        cc = single(region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'canopycover') / 100);
        Z = region.espEnv.getDataForObjectNameDataLabel( ...
                    regionName, 'elevation');
    end                
    outloc = [scratchPath, 'modis/intermediary/spiressmooth_', ...
        region.espEnv.modisData.versionOf.modisspiressmooth, ...
        '/v006/', regionName];
    if exist(outloc, 'dir') == 0
        mkdir(outloc);
    end

    
    mask = mask(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    cc = cc(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    fice = fice(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    Z = Z(rowStartId:rowEndId, columnStartId:columnEndId); % Seb 20240227 cell handling.
    Zmask=Z < el_cutoff; % Seb 20240303 move on Top.
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    %0.75-1.5 hrfor Sierra Nevada with 60 cores
    time1=tic;
   
    fileName = ['spiressmooth_', regionName, '_', datestr(matdates(end),'yyyy'), ...
        '_', num2str(rowStartId), '_', num2str(rowEndId), '_', num2str(columnStartId), '_', num2str(columnEndId), '.', ...
        region.espEnv.modisData.versionOf.modisspiressmooth, '.h5']; % Seb 20240227 name.
    h5name=fullfile(outloc, fileName); % Seb 20240205 name.
    %create h5 cube in tmp then move to avoid network h5 write issues
    % h5tmpname=fullfile(tempdir, fileName); % Seb 20240204 name.
    
    % Seb 20240204 moved output metadata here and added weights sensorZ solarZ.
    %output variables
    outvars={'fsca','fshade','grainradius','dust','weights','sensorZ', 'solarZ', 'fsca_raw', 'albedo_s', 'fsca', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', 'tmask', 'fsca', 'fsca_raw', 'fsca', 'radiative_forcing_s', 'deltavis_s'};
    outnames={'snow_fraction','shade_fraction','grain_size','dust','weights','sensorZ', 'solarZ', 'raw_snow_fraction', 'albedo_s', 'gap_snow_fraction', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', 'cloudMaskMovingPersist', 'cc_snow_fraction', 'presmooth_raw_snow_fraction', 'presmooth_snow_fraction', 'radiative_forcing_s', 'deltavis_s'};
    outdtype={'uint8','uint8','uint16','uint16','uint8','uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'int16', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'uint16', 'uint8'};
    outdivisors=[100 100 1 10 100 1 1 100 100 100, ...
        1, 1, 1, 1, 100, 1, 1, 1, 1, 100, ...
        100, 100, 100, 100, 100, 100, 100, ...
        1, 1, 100, 100, 100, 1, 100];

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
    vars={'fsca','fshade','grainradius','dust','weights','sensorZ', 'solarZ', '', '', '', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', '', '', '', '', '', ''}; % Seb 20240205 added solarZ.
    divisor=[100 100 1 10 100 1 1, 0, 0, 0, ...
        1, 1, 1, 1, 100, 1, 1, 1, 1, 100, ...
        100, 100, 100, 100, 100, 100, 100, ...
        1, 0, 0, 0, 0, 0, 0];
    dtype={'uint8','uint8','uint16','uint16','uint8','uint8', 'uint8', '', '', '', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'int16', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'int16', '', '', '', '', '', ''};

    dv=datevec(matdates);
    dv=dv(dv(:,3)==1,:);
    %check that full set of matdates exists
    for i=1:size(dv,1)
        inloc = [scratchPath, 'modis/intermediary/spiresfill_', ...
            region.espEnv.modisData.versionOf.modisspiresfill, ...
            '/v006/', regionName, '/', datestr(dv(i,:),'yyyy'), '/']; 
            % Seb 20240204 location of input distinct from output.
        fname=fullfile(inloc,[regionName, '_', datestr(dv(i,:),'yyyymm'), ...
            '_', num2str(rowStartId), '_', num2str(rowEndId), '_', num2str(columnStartId), '_', num2str(columnEndId), '.mat']);
            % Seb 20240227: change of input filename (cell-dependent).
        %if fname doesn't exist,  delete lock, throw error
        if exist(fname,'file')==0
            %delete(lockname); %Seb 20240204
            error('matfile %s doesnt exist\n',fname);
        end
    end
    out = struct(); % Seb 20240204. Transfer reading variables to a function, and reading when necessary to reduce mem consumption.
    % Seb 20240204. Moved on top:
    out.matdates=matdates;
    
%{
    for i=1:size(dv,1)
        fprintf('Handling wateryear month %d...\n', i);
        inloc = [scratchPath, 'modis/intermediary/spiresfill_v2024.0/v006/', regionName, '/', datestr(dv(i,:),'yyyy'), '/']; 
            % Seb 20240204 location of input distinct from output.
        fname=fullfile(inloc,[regionName, '_', datestr(dv(i,:),'yyyymm'), '.mat']);
        m=matfile(fname);

        if i==1
            for j=1:length(vars)
                out.(vars{j})=zeros([size(m.(vars{j}),1) size(m.(vars{j}),2) ...
                    length(matdates)],'single');
            end
        end
        doy_start=datenum(dv(i,:))-datenum(dv(1,:))+1;
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

    % 2. - Loading of fsca and grainradius with the new function
    % loadVariableForSpiresSmooth20240204() to avoid to load all variables
    % simultaneously.
    % - Duplicate fsca into fsca_raw (=viewable).
    % - Application of a movingPersist() (not sure what is does) using all fsca and
    % grainradius above threshold to create a mask.
    % - all fsca is set to 0 when mask = 1.
    
    %store raw values before any adjustments
    out = loadVariableForSpiresSmooth20240204(1, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading fsca.
    % out.fsca_raw=out.fsca; moved down Seb 20240318.
    saveVariableForSpiresSmooth20240204(10, outvars, outnames, outdtype, outdivisors, out, h5name, '-new'); % Seb 20240204 save gap_fsca. dont take out, for which fsca_raw has been deleted.

    %run binary fsca mask through temporal filter
    out = loadVariableForSpiresSmooth20240204(3, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading grainradius.
    out.tmask=out.fsca>fsca_thresh & out.grainradius > mingrainradius;
    fprintf('Starting movingPersist...\n');
    tic
    out.tmask=movingPersist(out.tmask,windowSize,windowThresh);
    fprintf('Done movingPersist in %f secs.\n', toc);

    %create 2 smoothed versions: fsca (adjusted for cc,ice,shade,
    % elevation cutoff,watermask, fsca_min)
    %and fsca_raw (no cc,ice adj, or shade adj), but elevation cutoff, watermask, &
    %fsca_min applied)
    out.fsca(~out.tmask)=0;
    % out.fsca_raw(~out.tmask)=0; SEB 2024-03-18
    
    out = saveVariableForSpiresSmooth20240204(29, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save (and delete from out) cloudMaskMovingPersist (tmask).

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
    
    
    cc(isnan(cc))=0;
    t=out.fsca==0;

    %use GO model
    out = loadVariableForSpiresSmooth20240204(6, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading sensorZ.
    fprintf('Starting GOvgf...\n');
    tic;
    cc_adj=1-GOvgf(cc,0,0,out.sensorZ,0,b_R);
    fprintf('Done Govgf in %f secs.\n', toc);
    
    out = saveVariableForSpiresSmooth20240204(6, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove sensorZ.
    clear cc;
    
    fprintf('Loading fice...\n');
    fice(isnan(fice))=0;
    fice=repmat(fice,[1 1 size(out.fsca,3)]);
    
    out.fsca_raw=out.fsca; % Seb 2024-03-18. Moved down here to lower mem use.

    %combine cc and fshade adjustment
    out = loadVariableForSpiresSmooth20240204(2, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading fshade.
    tic;
    fprintf('Starting fice...\n');
    out.fsca=out.fsca./(1-cc_adj-out.fshade-fice);
    if ~fshadeIsInterpolated
        out = saveVariableForSpiresSmooth20240204(2, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove fshade.
    end
    out.fsca(out.fsca>1 | out.fsca<0)=1;
    %fix 0/0
    out.fsca(t)=0;
    fprintf('Done fice in %f secs.\n', toc);
    saveVariableForSpiresSmooth20240204(30, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save canopy corrected snow_fraction.

    %elevation filter
    % [Z,hdr]=GetTopography(topofile,'elevation'); %Seb20240204 moved on top of function.
    % Zmask=Z < el_cutoff; Seb 20240303 move on Top.
    Zmask=repmat(Zmask,[1 1 size(out.fsca,3)]);

    %masked area filter
    fprintf('Masking...\n');
    tic;
    bigmask=repmat(mask,[1 1 size(out.fsca,3)]);

    out.fsca(Zmask | bigmask) = 0;
    out.fsca_raw(Zmask | bigmask) = 0;
    clear Zmask; % Seb 20240204.
    fprintf('Done masking in %f secs.\n', toc);

    saveVariableForSpiresSmooth20240204(31, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save presmoothed raw snow_fraction.
    saveVariableForSpiresSmooth20240204(32, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save presmoothed snow_fraction.
    
    out = loadVariableForSpiresSmooth20240204(5, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading weights.
    newweights=out.weights;
    newweights(isnan(out.fsca))=0;

    %fill in and smooth NaNs

    fprintf('smoothing fsca,fsca_raw,fshade %s...%s\n',datestr(matdates(1)),...
        datestr(matdates(end)));
    tic;
    %smooth fully adj fsca
    out.fsca=smoothDataCube(out.fsca,newweights,'mask',~mask,...
        'method','smoothingspline','SmoothingParam',0.1);
    fprintf('Temp. interpolated fsca in %f sec.\n', toc);
    
    %smooth fsca_raw
    tic;
    out.fsca_raw=smoothDataCube(out.fsca_raw,newweights,'mask',~mask,...
        'method','smoothingspline','SmoothingParam',0.1);
    fprintf('Temp. interpolated fsca_raw in %f sec.\n', toc);
    
    %smooth fshade
    if fshadeIsInterpolated
        tic;
        out.fshade=smoothDataCube(out.fshade,newweights,'mask',~mask,...
            'method','smoothingspline','SmoothingParam',0.1);
        clear newweights; % Seb 20240204.
        fprintf('Temp. interpolated fshade in %f sec.\n', toc);
    end
    
    %get some small fsca values from smoothing - set to zero
    fprintf('Additional filtering...\n');
    tic;
    out.fsca(out.fsca<fsca_thresh)=0;
    out.fsca(bigmask)=NaN;
    fprintf('Filtered fsca in %d secs.\n', toc);

    %same for fsca_raw
    tic;
    out.fsca_raw(out.fsca_raw<fsca_thresh)=0;
    out.fsca_raw(bigmask)=NaN;
    fprintf('Filtered fsca_raw in %d secs.\n', toc);

    %same for fshade
    if fshadeIsInterpolated
        tic;
        out.fshade(out.fsca_raw<fsca_thresh)=0;
        out.fshade(bigmask)=NaN;
        clear bigmask; % Seb 20240204.
        out = saveVariableForSpiresSmooth20240204(2, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove fshade.
        fprintf('Filtered fshade in %d secs.\n', toc);
    end
    
    out = saveVariableForSpiresSmooth20240204(8, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove fsca_raw.
    
    
    %fix values below thresh to ice values
    tic;
    t=out.fsca<fice;
    out.fsca(t)=fice(t);
    clear fice; % Seb 20240204.
    out.fsca(out.fsca<fsca_thresh)=0;
    fprintf('Done additional filtering on fsca in %d secs.\n', toc);
    fprintf('finished smoothing fsca,fsca_raw,fshade %s...%s\n',datestr(matdates(1)),...
        datestr(matdates(end)));

    fprintf('smoothing grain radius and dust %s...%s\n',datestr(matdates(1)),...
        datestr(matdates(end)));

    %create mask of any fsca for interpolation
    
    anyfsca=any(out.fsca,3);
    
    out = loadVariableForSpiresSmooth20240204(4, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading dust.

    fprintf('Filtering on grainradius/dust...\n');
    tic;
    badg=out.grainradius<mingrainradius | out.grainradius>maxgrainradius | ...
        out.dust > maxdust ;

    %grain sizes too small or large to be trusted
    out.grainradius(badg)=NaN;
    out.dust(badg)=NaN;
    clear badg;

    %grain sizes after melt out
    out.dust(out.fsca==0)=NaN;
    fprintf('Done filtering on grainradius/dust in %f sec.\n', toc);
    %don't set out.grainradius to nan where fsca==0 until later
    %this helps maintain high grain size values

    % create new weights for grain size and dust
    newweights=out.weights;
    out = saveVariableForSpiresSmooth20240204(5, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove weights.
    newweights(isnan(out.grainradius) | out.fsca==0)=0;
    
    if size(out.grainradius, 3) < 365
      if ~ismember(datestr(matdates(end),'mm'), {'05', '06', '07', '08', '09'})
        fixpeak = 0; % Set temporarily for ongoing water year.
      else
        Nd = 0; % we peak fix but don't taper the values to minimum at the end of the
          % record. @warning
      end
    end
    
    if fixpeak % set values after peak grain radius to peak
        N=size(out.grainradius);
        %reshape to days x pixels
        grainradius=reshape(out.grainradius,N(1)*N(2),N(3))';
        dust=reshape(out.dust,N(1)*N(2),N(3))';
        fsca=reshape(out.fsca,N(1)*N(2),N(3))';
        weights=reshape(newweights,N(1)*N(2),N(3))';
        clear newweights; % Seb 20240204.
        tic;
        fprintf('Peak Fixing and smoothing grainradius and dust...\n');
        parfor i=1:size(grainradius,2)
            fscavec=squeeze(fsca(:,i));
            rgvec=squeeze(grainradius(:,i));
            weightsvec=squeeze(weights(:,i));

            %get rid of spikes & drops
            rgvec=hampel(rgvec,2,2);
            if max(fscavec)==0 %skip pixels w/ no snow
                continue;
            end
            t=fscavec>0;
            %last day with snow, or end of cube
            meltOutday=min(find(t,1,'last'),length(rgvec));
            
            %peak fixing cannot last more than N days from final peak
            %make a temp copy of rgvec
            rgvec_t=rgvec;
            maxFixedDays=40;%days
            %set all days prior to meltOutday-maxFixedDays to nan
            rgvec_t(1:(meltOutday-maxFixedDays))=nan;
            [~,maxDay]=max(rgvec_t,[],'omitnan');
            
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
            endDay=length(rgvec)-Nd;

            %set those days to (near) max grain size
            ind=maxDay:endDay;

            maxrg=rgvec(maxDay);
            rgvec(ind)=maxrg;

            %smooth up to maxDay
            ids=1:maxDay-1;
            
            %set 1st day to min, may be set to nan later, but helps w/
            %keeping spline in check
            rgvec(1)=mingrainradius;
            weightsvec(1)=1;

            rgvec(ids)=smoothVector(ids',rgvec(ids),weightsvec(ids),0.8);
            %taper vector to min value only for full waterYear Seb 20240523.
            if Nd ~= 0
              grainradius(:,i)=taperVector(rgvec,Nd,mingrainradius);
            else
              grainradius(:,i)=rgvec;
            end
            %dust: set dust for all days prior to 0 if below grain thresh
            dustvec=squeeze(dust(:,i));

            %all days with small grain sizes
            tt=rgvec<=dust_rg_thresh;

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
            dustvec(1)=0;
            weightsvec(1)=1;
            %smooth up until maxday
            dustvec(ids)=smoothVector(ids',dustvec(ids),...
                weightsvec(ids),0.1);
            % taper only for full waterYear Seb 20240523.
            if Nd ~= 0
              dust(:,i)=taperVector(dustvec,Nd,mindust);
            else
              dust(:,i)=dustvec;
            end
        end
        fprintf('Done smoothing grainradius and dust in %f secs.\n', toc);
        clear weights; % Seb 20240204.
        %put back into cube
        % out.fsca = reshape(fsca',N(1),N(2),N(3)); % Seb 20240204 useless.
        out.grainradius = reshape(grainradius',N(1),N(2),N(3));
        out.dust = reshape(dust',N(1),N(2),N(3));
        
    else %don't fix values after peak grain size
        out.grainradius=smoothDataCube(out.grainradius,newweights,'mask',anyfsca,...
            'method','smoothingspline','SmoothingParam',0.8);
        %assume zero dust for small grains
        out.dust(out.grainradius<dust_rg_thresh)=0;
        out.dust=smoothDataCube(out.dust,newweights,'mask',anyfsca,...
            'method','smoothingspline','SmoothingParam',0.1);
    end

    fprintf('finished smoothing grain radius and dust %s...%s\n',datestr(matdates(1)),...
        datestr(matdates(end)));
    fprintf('Filtering on grainradius...\n');
    tic;
    out.grainradius(out.grainradius<mingrainradius)=mingrainradius;
    out.grainradius(out.grainradius>maxgrainradius)=maxgrainradius;
    out.grainradius(out.fsca==0)=NaN;
    fprintf('Done filtering on grainradius in %f secs.\n', toc);
    saveVariableForSpiresSmooth20240204(3, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save grainradius but not remove.

    %clean up out of bounds splines
    fprintf('Filtering on dust...\n');
    tic;
    out.dust(out.dust>maxdust)=maxdust;
    out.dust(out.dust<mindust)=mindust;
    out.dust(out.fsca==0)=NaN;
    fprintf('Done filtering on dust in %f secs.\n', toc);
    saveVariableForSpiresSmooth20240204(4, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save dust but not remove.

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
    out = saveVariableForSpiresSmooth20240204(1, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); % Seb 20240204 save and remove fsca.
    
    out = loadVariableForSpiresSmooth20240204(7, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading solarZ.
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
    saveVariableForSpiresSmooth20240204(7, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); 
    % Seb 20240204 save and not remove solarZ. Not very performant since we convert back and forth to single, with a division...
    
    out = loadVariableForSpiresSmooth20240204(28, dv, region, vars, divisor, dtype, matdates, out, cellIdx); % Seb 20240204 Loading SolarAzimuth.
    % Seb 20240222 Interpolating temporally SolarAzimuth.
    out.(vars{28})(out.(vars{28}) > 180) = NaN;
    if any(isnan(out.(vars{28})), 'all')
        out.(vars{28}) = fillmissing(out.(vars{28}), 'linear', 3, EndValues = 'nearest'); % Seb 2024-03-19, in replacement of FillCubeDateLinear().
    end
    % out.(vars{28}) = FillCubeDateLinear(matdates, matdates, out.(vars{28}), 180); % Seb 20240222
    out = saveVariableForSpiresSmooth20240204(28, outvars, outnames, outdtype, outdivisors, out, h5name, '-append'); 
    % Seb 20240204 save and remove SolarAzimuth. Not very performant since we convert back and forth to single, with a division...
    
    % Albedo calculation. Seb 20240227:
    fprintf('%s: Calculating albedo...\n', mfilename()); 
    varName = 'albedo_s';
    out.(varName) = NaN(size(out.grainradius), 'double');
    Z = repmat(Z, [1 1 size(out.grainradius, 3)]); % Seb 20240228. Not sure performance.
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
            [], Z(indicesForNotNaN), LAPname = 'dust', ...
            LAPconc = out.dust(indicesForNotNaN) / 1000); % Seb 20240228. dust is in ppm while AlbedoLookup expects ppt (why??????) to check with Karl @warning.
            % AlbedoLookup in ParBal package.
%}
        % Dirty albedo and radiative forcing from Jeff lookup tables. 2024-05-10.
        albedoForcingCalculator = AlbedoForcingCalculator(region);
        [albedo, deltavis, radiativeForcing] = albedoForcingCalculator.getFromLookup(out.grainradius(indicesForNotNaN), ...
            out.dust(indicesForNotNaN), out.solarZ(indicesForNotNaN));
         out.(varName)(indicesForNotNaN) = albedo;
         varName = 'deltavis_s';
         out.(varName)(indicesForNotNaN) = deltavis;
         varName = 'radiative_forcing_s';
         out.(varName)(indicesForNotNaN) = radiativeForcing;
    end  
    out = saveVariableForSpiresSmooth20240204(9, outvars, outnames, outdtype, outdivisors, out, h5name, '-append');
    out = saveVariableForSpiresSmooth20240204(33, outvars, outnames, outdtype, outdivisors, out, h5name, '-append');
    out = saveVariableForSpiresSmooth20240204(34, outvars, outnames, outdtype, outdivisors, out, h5name, '-append');
    % End albedo calculation.
%{
    % Seb 20240304 Add and save additional variables to understand why there's no snow in north
    % western US for ongoing 2024 water year.
    for varIdx = 11:27
        try
            out = loadVariableForSpiresSmooth20240204(varIdx, dv, region, vars, divisor, dtype, matdates, out, cellIdx);
        catch e
            warning(e.message);
            continue;
        end
        out = saveVariableForSpiresSmooth20240204(varIdx, outvars, outnames, outdtype, outdivisors, out, h5name, '-append');
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
