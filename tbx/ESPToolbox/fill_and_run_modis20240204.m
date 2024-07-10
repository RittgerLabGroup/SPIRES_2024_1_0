function [out,fname,vars,divisor,dtype]=fill_and_run_modis20240204(region, matdates)

    % fills input (mod09ga) and runs spires
    %input:

    % tiles - - tilenames,  cell vector, e.g. {'h08v05','h08v04','h09v04'};
    % if tile is a cell vector, assumption is made to mosaic multiple tiles
    % together then crop/reproject to topofile. watermask, R0,& dustmask will
    % all be assumed to match topofile hdr for spatial info
    % R0, background mult-band image
    % matdates - matdates for cube
    % hdfbasedir - where the MOD09GA HDF files live
    % must have sub directories that correspond to entries in tile, e.g. h08v04
    % topofile- h5 file name from consolidateTopography, part of TopoHorizons
    % mask- logical mask w/ ones for pixels to exclude (like water)
    % Ffile- location of griddedInterpolant object that produces
    % reflectances for each band
    % with inputs: grain radius, dust, cosZ, i.e. the look up table, band
    % shade -, scalar or vector, length of # bands
    % grain_thresh - min fsca value for grain size retrievals , e.g. 0.50
    % dust_thresh - min fsca value for dust retrievals, e.g. 0.95
    % tolval - threshold for uniquetol spectra, higher runs faster, 0 runs all
    % pixels - scalar e.g. 0.05
    % outloc - path to write output
    % nameprefix - name prefix for outputs, e.g. Sierra
    % net - trained conv. NN for cloud masking
    %output:
    %   out:
    %   fsca: MxNxd
    %   grainradius: MxNxd
    %   dust: MxNxd
    %also writes 1 month .mat files with those outputs
    %fname - output filename
    % vars - cell, variable list
    % divisor - divisors for variables
    % dtype - datatype for each variable

    % Seb 20240204
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%{
    % NB: this function usescore/fillMODIScube20240204.m, core/run_spires.m 
    % (which uses,core/speedyinvert.m, core/cloudMarkForRefl.m (from Karl STC),
    % RasterReprojection/rasterReprojection.m, MODIS_HDF/weightMOD09.m, 
    % MODIS_HDF/GetMOD09GA.m, MccM/pxFeatures.m, Mappping/sinusoidProjMODtile.m
    % , General/strfindi.m, MODIS_HDF/GetTopography.m
    % MATLABFileExchange/Inpaint_nans/inpaint_nans.m
%}

    % 1. Initialization of variables, filenames, constants and get elevations...
    % NB: elevations are not used, it's only the coordinates which are used if several
    % tiles.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    regionName = region.name;
    scratchPath = region.espEnv.scratchPath;
    baseDir = [scratchPath, 'modis/input_spires_from_Ned_202311/Inputs/MODIS/'];
    
    hdfbasedir = [scratchPath, 'modis/input/mod09ga/v006/'];
    % topofile = [baseDir, 'Z/', regionName, 'Topography.h5']; Seb 2024-03-12
    if ismember(regionName, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'})
        R0file = [baseDir, 'R0/', regionName, 'R0.mat'];
        R0 = matfile(R0file).R0;
        maskfile = [baseDir, 'watermask/', regionName, 'watermask.mat'];
        mask = matfile(maskfile).mask;
    else
        R0FilePath = region.espEnv.getFilePathForObjectNameDataLabel( ...
            regionName, 'backgroundreflectance');
        R0 = load(R0FilePath).R0;
        mask = region.espEnv.getDataForObjectNameDataLabel( ...
            regionName, 'water');
    end
    Ffile = [scratchPath, 'modis/input_spires_from_Ned_202311/Sierra/ExampleData/lut_modis_b1to7_3um_dust.mat'];
    shade = 0;
    grain_thresh = 0.30;
    dust_thresh = 0.90;
    tolval = 0.05;
    outloc = [scratchPath, 'modis/intermediary/spiresfill_', ...
        region.espEnv.modisData.versionOf.modisspiresfill, ...
        '/v006/', regionName, '/'];
    if exist(outloc, 'dir') == 0
        mkdir(outloc);
    end
    codePath = '/projects/sele7124/MATLAB/SPIRES/';
    mccmfile = [codePath, 'MccM/net.mat'];
    net = matfile(mccmfile).net;
    tiles = {regionName};
    nameprefix = regionName;
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    red_b=3;
    swir_b=6;
    %intermediate variables
    vars={'fsca','fshade','grainradius','dust','weights','sensorZ', 'solarZ', ...
        'saltpan', 'neuralSnow', 'neuralCloud', 'stateCloud', 'NDSI', 'daymask', 'isNotNaNR', 'isNotNaNR0', 'STCCloud', 'STCNDSI', ...
        'reflectanceBand1', 'reflectanceBand2', 'reflectanceBand3', 'reflectanceBand4', 'reflectanceBand5', 'reflectanceBand6', 'reflectanceBand7', ...
        'SolarAzimuth', 'spatial_grain_size_s', 'spatial_dust_concentration_s'}; % Seb 20240204 solarZ.
    divisor=[100, 100, 1, 10, 100, 1, 1, ...
        1, 1, 1, 1, 100, 1, 1, 1, 1, 100, ...
        1, 1, 1, 1, 1, 1, 1, ...
        1, 1, 10]; % Seb 20240204 solarZ.
    dtype={'uint8','uint8','uint16','uint16','uint8','uint8', 'uint8', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'int16', 'uint8', 'uint8', 'uint8', 'uint8', 'int16', ...
        'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', 'uint8', ...
        'int16', 'uint16','uint16'}; % Seb 20240204 solarZ.

    t1=tic;

    %run in one month chunks and save output
    dv=datevec(matdates);
    m=unique(dv(:,2),'stable');
    % [~,hdr]=GetTopography(topofile,'elevation'); Seb 2024-03-12
    
    % 2. Generate a "gap" cube for each month:
    % 2.1. Function fillMODIScube20240204():
    % - Load reflectance, solar_zenith, sensor_zenith, state (saltpan, cloud),
    %   band weights,  
    %   of all days mod09ga.
    % - some days don't have files or have corrupted files: they are skipped and the 
    %   values of the variables are set to 0.
    % - solar_zenith, sensor_zenith, state reinterpolated (with resize() method bicubic).
    % - removal of clouds with state + neural network (= reflectance set to NaN).
    
    % 2.2. Function run_spires() [use parfor]:
    % - instantiate fsca, fshade, grainradius, dust with NaN.
    % For each day:
    %       - determination mask band weight < 1 + use of water mask.
    %       - calculation of ndsi.
    %       - grouping pixels having same reflectance, R0, and solar_zenith within all
    %       tolerance (uniquetol()). I call these groups triplets.
    %       - For each triplet refl, R0, solar_zenith:
    %           - 2.3. Function speedy_invert():
    %               - load a file lut_dust (is it the lookup table?) as persistent
    %               - inititiating the solver fmincon using optimoptions().
    %               - hard-coded constants.
    %               - 2 optimizations of fsca, fshade, radius, dust with the
    %                   SnowCloudDiff()
    %                   function using fmincon().
    %                   SnowCloudDiff() use the values of lut_dust file, reflectances,
    %                   solar_zenith and R0. What's minimised is the Euclidian norm
    %                   (norm()) of the difference between modeled reflectance and
    %                   observed reflectance.
    %                   - 1 optimization with a no-background,
    %                   - 1 optimization with a background
    %           - application of fsca thresholds to set dust and grain_size to no data.
    %       - if dust/grain solutions different from 0 were found, we have a second
    %       round: 
    %           - we take the coordinates of grain size and dust not NaN.
    %           - For each triplet, each of the 2 variables (either grain size or dust):
    %               - we calculate the pdist2() between the coordinates of the no NaN
    %               grainsize (or dust) pixels and the coordinates of pixels belonging
    %               to the triplet.
    %               - we determine a weight = inverse of this distance.
    %               - the grainsize/dust value of the triplet = weighted average of
    %               all triplets with solutions (that is spatial interpolation).
    %       - propagate the values to each pixel.
    %       - if the pixel is noise
    %       (ndsi <= -0.5 or clouds or refl, R0, solar zenith = NaN), then fsca = fshade
    %       = 0 and grainsize/dust = NaN.
    
    for i=1:length(m)
        idx=dv(:,2)==m(i);
        rundates=matdates(idx);
        fname=fullfile(outloc, datestr(rundates(end),'yyyy'), [nameprefix , '_', datestr(rundates(1),'yyyymm') '.mat']); % Seb 20240204
        %lockname=fullfile(outloc,[nameprefix '_', datestr(rundates(1),'yyyymm') '.matlock']); % Seb 20240204

        % Seb 20240204
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        thisHdfbasedir = fullfile(hdfbasedir, regionName, datestr(rundates(1),'yyyy'));   
%{        
        if 1 ~= 1
            matdate = rundates;
            sz0=[2400 2400 7 length(rundates)];
            save(fname, matdate, '-v7.3');
            outFileObject = matfile(fname, 'Writable', true);
            parfor varIdx = length(vars)
                outFileObject.(vars{varIdx}) = intmax(dtype{varIdx}) * ones([sz0(1) sz0(2) sz0(4)], dtype{varIdx}); GENERATE ERROR PARFOR.
            end
            outFileObject = [];
        else
%}
            saveVariableForSpiresFill20240204(fname, rundates, 'matdates', '', '', '', '');
%       end
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %{
        % Seb 20240204 Removed the no overwriting existing files.
        if exist(fname,'file')==0 && exist(lockname,'file')==0 %don't overwrite existing files
            fid=fopen(lockname,'w');
            fclose(fid);
            %delete lockname on cleanup
            cleanup=onCleanup(@()CleanupFun(lockname));
    %}
        [R,solarZ,~,~]=...
            fillMODIScube20240204(tiles,rundates,thisHdfbasedir,net,red_b,swir_b, fname, divisor, dtype);
            % thisHdfbasedir. Seb 20240204.
        bweights = [];
        out=run_spires20240204(R0,R,solarZ,Ffile,mask,shade,...
            grain_thresh,dust_thresh,tolval,red_b,swir_b,bweights, fname, divisor, dtype, region);
            % NB: Seb 2024-02-24: Run over a full month (although no temporal interpolation).

        %write out these variables
        % out.weights=weights; 
        % out.sensorZ=SensorZenith; 
        %out.solarZ=SolarZenith; % Seb 20240204 solarZ.

%{
       % We move all the saving to places when we need to save and free memory, variable
       % by variable. Seb 20240304.
       
        % mfile=matfile(fname,'Writable',true); Seb 20240224: replace by 9 smaller cell files.
        
        for j=1:length(vars)
            t=isnan(out.(vars{j}));
            if j==3 || j==4  %grain size or dust
                t=t | out.fsca==0 ; % Seb 20240223: what exactly this line does?
            end
            out.(vars{j})=cast(out.(vars{j})*divisor(j),dtype{j});
            out.(vars{j})(t)=intmax(dtype{j});
            % mfile.(vars{j})=out.(vars{j}); Seb 20240224.
        end
        
        
        

        
        % Seb 20240224. Dividing data spatially in cells and save 1 file per cell, so
        % as to make smooth on each cell-file less memory consuming.
        countOfCells = 9;
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
            mfile=matfile(thisFilePath,'Writable',true);
            
            
            for j=1:length(vars)
                mfile.(vars{j})=out.(vars{j})(rowIds, columnIds, :);
            end
            
            % Seb 20240304 Add STC Variables
            
            
            % mfile.matdates=rundates; % Move at start Seb 20240304.
            fprintf('wrote %s \n',thisFilePath);
            clear mfile;
        end
        
        % mfile.matdates=rundates; Seb 20240224
        % fprintf('wrote %s \n',fname); Seb 20240224
    %{
            delete(lockname);
        elseif exist(fname,'file')==2
            fprintf('%s already exists, skipping \n',fname);
        elseif exist(lockname,'file')==2
            fprintf('%s locked, skipping \n',fname);
        end
    %}
        % clear mfile out % Seb 20240224
        clear out
%}
    end
    t2=toc(t1);
    fprintf('completed in %5.2f hr\n',t2/60/60);
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