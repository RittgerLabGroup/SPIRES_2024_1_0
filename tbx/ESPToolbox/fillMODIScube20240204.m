function [R,solarZ,SensorZenith,weights]=...
    fillMODIScube20240204(tiles,rundates,thisHdfbasedir,net,red_b,swir_b, fname, divisor, dtype)
    %create gap filled (e.g. cloud-free) MOD09GA surface
    %reflectance

    %input:
    %tiles - tilenames,  cell vector, e.g. {'h08v05','h08v04','h09v04'};
    %rundates - rundates to process
    %hdfbasedir - where the MOD09GA HDF files live must have sub directories
    % that correspond to entries in tile, e.g. 'h08v04'
    %topofile - h5 target topo file name. This topography file contains the target
    %geographic information that everything will be tiled and
    %cropped/reprojected to
    %net - trained convolutional nueral network for cloud masking 
    %hdr - geog hdr struct
    %red_b - red band, e.g. 3 for MODIS and L8
    %swir_b - SWIR band, e.g. 6 for MODIS and L8
    %output:
    %filledCubeR: cube of MOD09GA values w/ NaNs for clouds
    %SolarZenith: solar zenith angles for cube
    %SensorZenith: sensor zenith angles for cube
    %pxweights: weight cube for each pixel (all bands together), 0-1

    % Seb 20240204: replace hdfbasedir by thisHdfbasedir. Limited to 1 tile only (because
    % the mod09ga are in directories that include a subfolder named the name of the tile)

    % Seb 20240223: the function generate a cube per month, containing all the days of the
    % month. The days without mod09ga files are filled by zero values.

    % Seb 20240304: Add saving in spires fill files of several variables, with arguments fname, divisor, dtype.

    nbands=7;
    % mask as cloud if swir band (6) is > than
    % swir_cloud_thresh=0.2;

    if ~iscell(tiles)
        tiles={tiles};
    end

    % get all raster info
    R=zeros([length(tiles),3,2]);
    lr=zeros(length(tiles),2);
    tsiz=zeros(length(tiles),2);

    for i=1:length(tiles)
        [r,mstruct,rr] = sinusoidProjMODtile(tiles{i});
        R(i,:,:)=r.RefMatrix_500m;
        lr(i,:)=[rr.RasterReference_500m.RasterSize 1]*r.RefMatrix_500m;
        tsiz(i,:)=rr.RasterReference_500m.RasterSize;
    end

    %create refmat for mosaic
    BigR=zeros(3,2);
    BigR(3,1)=min(R(:,3,1));
    BigR(2,1)=R(1,2,1); %assume same spacing for all pixels
    BigR(1,2)=R(1,1,2);
    BigR(3,2)=max(R(:,3,2));


    %compute size of mosaic
    %xy coords for lower rt corner
    xy=[max(lr(:,1)) min(lr(:,2))];
    sBig=map2pix(BigR,xy);
    sBig=round(sBig);

    sz=[sBig nbands];

    BigRR=refmatToMapRasterReference(BigR,sz(1:2));

    %allocate 3 & 4D cubes with measurements for all days
    %sz0=[hdr.RasterReference.RasterSize nbands length(rundates)]; Seb 20240312
    sz0=[2400 2400 nbands length(rundates)];

    FilledCubeR=NaN(sz0,'single'); % Seb 2024023: set NaN rather than 0.
    if 1 == 1
        solarZ=NaN([sz0(1) sz0(2) sz0(4)],'single'); % Seb 20240223: set NaN rather than 0.
        SensorZenith=NaN([sz0(1) sz0(2) sz0(4)],'single'); % Seb 20240223: set NaN rather than 0.

        weights=NaN([sz0(1) sz0(2) sz0(4)],'single'); % Seb 20240223: set NaN rather than 0.
%{
        % Add variables Seb 20240304.
        saltpan=255 * ones([sz0(1) sz0(2) sz0(4)],'uint8');
        neuralSnow=255 * ones([sz0(1) sz0(2) sz0(4)],'uint8');
        neuralCloud=255 * ones([sz0(1) sz0(2) sz0(4)],'uint8');
        stateCloud=255 * ones([sz0(1) sz0(2) sz0(4)],'uint8');
        STCCloud=NaN([sz0(1) sz0(2) sz0(4)],'single');
        STCNDSI=NaN([sz0(1) sz0(2) sz0(4)],'single');
        for bandIdx = 1:7
            eval(['reflectanceBand', num2str(bandIdx), ' = 255 * ones([sz0(1) sz0(2) sz0(4)], ''uint8'');']);
        end
%}
        SolarAzimuth = NaN([sz0(1) sz0(2) sz0(4)],'single');
    else
        outFileObject = matfile(fname, 'Writable', true);
    end
    % Seb 20240223: These initializations were 0, I set them to NaN rather than 0.
    % In run_spires, the implicit calculation (on 0) may hide errors   @todo


    parfor dateIdx=1:length(rundates) % this parfor cannot work because second parfor in semanticseg? @warning

        isodate=datenum2iso(rundates(dateIdx),7);
        %allocate daily cubes

        filledCube_=NaN(sz,'single');
        origSr = NaN(sz,'single');
        SolarZenith_=NaN([sz(1) sz(2)],'single');
        SensorZenith_=NaN([sz(1) sz(2)],'single');
        pxweights_=zeros([sz(1) sz(2)],'single');
%{
        % Add Seb 20240304
        saltpan_=255 * ones([sz(1) sz(2)],'uint8');
        neuralSnow_=255 * ones([sz(1) sz(2)],'uint8');
        neuralCloud_=255 * ones([sz(1) sz(2)],'uint8');
        stateCloud_=255 * ones([sz(1) sz(2)],'uint8');
        STCCloud_=255 * ones([sz(1) sz(2)],'uint8');
        STCNDSI_=NaN([sz(1) sz(2)],'single');
%}
%{
        reflectanceBand1_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand2_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand3_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand4_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand5_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand6_ = 255 * ones([sz(1) sz(2)], 'uint8');
        reflectanceBand7_ = 255 * ones([sz(1) sz(2)], 'uint8');
%}
        SolarAzimuth_ = NaN([sz(1) sz(2)],'single');

        %load up each tile
        % for k=1:length(tiles)
            %tile=tiles{k};
            tile = tiles{1}
            %get full directory listing for tile
            d=dir(fullfile(thisHdfbasedir,['*.' tile '.*.hdf'])); % Seb 20240204 thisHdfbasedir.
            fileNameList = sortrows({d.name})'; 
            fileNameList = flipud(fileNameList);
            % Seb 20240229. Sorted descending creation timestamp date (which is included
            % in filename). To be sure only the most recent file is taken below.
            % NB: I tried on d.datenum but harsh and couldn't make it work.

            % d=struct2cell(d); Seb 20240229
            % d=d(1,:);
            assert(~isempty(fileNameList),'%s empty\n',thisHdfbasedir); % Seb 20240229 thisHdfbasedir.
            % m=regexp(filePathList,['^MOD09GA.A' num2str(isodate) '\.*'],'once'); % Seb 20240229
            m = cell2mat( ...
            cellfun(@(x) size(regexp(x, ...
                ['^MOD09GA.A', num2str(isodate), '\.*'], 'once', 'match'), 1), ...
                fileNameList, UniformOutput = false));
            % Seb 20240229 replace d by fileNameList.
            % We convert the result of regexp with size, otherwise impossible to get
            % the indices.
            m=find(m == 1); %~cellfun(@isempty,m); % Seb 20240229

            if any(m)
                % [x,y]=pixcenters(squeeze(R(k,:,:)),tsiz(k,:));
                % [r,c]=map2pix(BigR,x,y);
                % r=round(r);
               %  c=round(c);
                f=fullfile(thisHdfbasedir,fileNameList{m(1)}); % Seb 20240204 thisHdfbasedir.
                fprintf('Getting vars from %s...\n',f);

                %some of the hdf files are corrupt and need to be skipped
                try
                    [~,pxweights_,~] = weightMOD09(f);
                catch
                    fprintf('could not open %s, skipping\n',f)
                    continue
                end

                x = pxweights_;
                varIdx = 5;
%{
                if 1 ~= 1
                    x = x * divisor(varIdx);
                    x(isnan(x)) = intmax(dtype{varIdx});
                    outFileObject.weights(:, :, dateIdx) = cast(x, dtype{varIdx});
                end
%}
                varIdx = 6;
                x=single(GetMOD09GA(f,'SolarZenith'));

                if any(isnan(x(:)))
                    x = inpaint_nans(double(x),4);
                end
                x=imresize(x, [2400 2400]); % NB: Seb, 2024-02-24 solar_zenith, sensor_zenith,
                    % are interpolated to get a 2xhigher resolution with bicubic method.
                if 1 == 1
                    SolarZenith_= x;
                else
                    x = x * divisor(varIdx);
                    x(isnan(x)) = intmax(dtype{varIdx});
                   % outFileObject.solarZ(:, :, dateIdx) = cast(x, dtype{varIdx});
                end

                % Seb 20240305. Solar azimuth, if we need it later.
                varIdx = 25;
                x=single(GetMOD09GA(f,'SolarAzimuth'));

                if any(isnan(x(:)))
                    x = inpaint_nans(double(x),4);
                end
                x=imresize(x,[2400 2400]); % NB: Seb, 2024-02-24 solar_zenith, sensor_zenith,
                    % are interpolated to get a 2xhigher resolution with bicubic method.
                if 1 == 1
                    SolarAzimuth_ = x;
                else
                    x = x * divisor(varIdx);
                    x(isnan(x)) = intmax(dtype{varIdx});
                   % outFileObject.SolarAzimuth(:, :, dateIdx) = cast(x, dtype{varIdx});
                end
                
                % sensor zenith, and pixel sizes
                varIdx = 6;
                x = single(GetMOD09GA(f,'sensorzenith'));
                if any(isnan(x(:)))
                    x = inpaint_nans(double(x),4);
                end
                x = imresize(x,[2400 2400]);
                SensorZenith_ = x;
                if 1 ~= 1
                    x = x * divisor(varIdx);
                    x(isnan(x)) = intmax(dtype{varIdx});
                  %  outFileObject.sensorZ(:, :, dateIdx) = cast(x, dtype{varIdx});
                end

                %get all band reflectance
                sr=GetMOD09GA(f,'allbands');
                origSr = uint8(sr * 100);
%{
                % SEb 20240304 Add STCNDSI/STCCloud
                STCCloud_ = cloudMaskForRefl(sr * 100);
                STCNDSI_ = (single(sr(:, :, 4)) - ...
                                single(sr(:, :, 6))) ./ ...
                            (single(sr(:, :, 4)) + ...
                                single(sr(:, :, 6)));
%}                               
                sr(isnan(sr))=0;

                %create cloud mask
                S=GetMOD09GA(f,'state');
                %expansive 
                stateCloud_=imresize(S.cloud,[2400 2400]);       % Seb 20240304 var name  
                MOD35cm= (stateCloud_ == 1 | stateCloud_ == 2); % Seb 20240305. %imresize(S.cloud==1 | S.cloud==2,[2400 2400]);

                %new MccM approach
                I=pxFeatures(sr,nbands);
                %scale to integers for CNN
                scaleFactor=10000;
                I=int16(I.*scaleFactor);
                %GPU runs out of memory
                C = semanticseg(I,net,'ExecutionEnvironment','cpu');
                cm = C == 'cloud' ;
                
                %gets brightest part, but not full dry lake area
                saltpan_=imresize(S.saltpan,[2400 2400]);       % Seb 20240304 var name          


                cloudOrsnowMask = cm | C=='snow' | MOD35cm & ~saltpan_; % Seb 20240304 var name

                %set surf reflectance b1 to NaN in areas w/ chosen cloud mask
                % will be ignored in run_spires, then gap filled in
                % smoothSPIREScube
                sr(cm)=NaN;
                neuralCloud_ = cm;
                neuralSnow_ = C=='snow';

                % for areas that we know are NOT snow or clouds
                % (~cloudOrsnowMask), set NDSI to -1

                sr_red_b=sr(:,:,red_b);
                sr_red_b(~cloudOrsnowMask)=0;
                sr(:,:,red_b)=sr_red_b;

                sr_swir_b=sr(:,:,swir_b);
                sr_swir_b(~cloudOrsnowMask)=1;
                sr(:,:,swir_b)=sr_swir_b;

                filledCube_=sr;

                fprintf('loaded, corrected, and created masks for tile:%s date:%i \n',...
                    tile,isodate);
            else
                fprintf('MOD09GA for %s %i not found,skipped\n',tile,isodate);
            end % if any m
        % end % for tile
        %{
        % Seb 20240305. Not necessary for 1 tile.
        filledCube_=rasterReprojection(filledCube_,BigRR,'InProj',mstruct,...
        'OutProj',hdr.ProjectionStructure,'rasterref',hdr.RasterReference,...
        'fillvalue',nan);
        SolarZenith_=rasterReprojection(SolarZenith_,BigRR,'InProj',mstruct,...
        'OutProj',hdr.ProjectionStructure,'rasterref',hdr.RasterReference,...
        'fillvalue',nan);
        SensorZenith_=rasterReprojection(SensorZenith_,BigRR,'InProj',mstruct,...
        'OutProj',hdr.ProjectionStructure,'rasterref',hdr.RasterReference,...
        'fillvalue',nan);
        pxweights_=rasterReprojection(pxweights_,BigRR,'InProj',mstruct,...
        'OutProj',hdr.ProjectionStructure,'rasterref',hdr.RasterReference,...
        'fillvalue',nan);
        %}

        FilledCubeR(:,:,:, dateIdx)=filledCube_;
        solarZ(:,:, dateIdx)=SolarZenith_;
        SensorZenith(:,:, dateIdx)=SensorZenith_;
        weights(:,:, dateIdx)=pxweights_;
%{
        % Seb 20240304. Add variables to better understand why nrt doesn't work as expected
        % in north westernUS.
        % NB: broke the rasterReprojection (which is not necessary for one tile...)
        saltpan(:,:, dateIdx)=saltpan_;
        neuralSnow(:,:, dateIdx)=neuralSnow_;
        neuralCloud(:,:, dateIdx)=neuralCloud_;
        stateCloud(:,:, dateIdx)=stateCloud_;
        STCCloud(:,:, dateIdx)=STCCloud_;
        STCNDSI(:,:, dateIdx)=STCNDSI_;
        reflectanceBand1(:, :, dateIdx) = origSr(:, :, 1);
        reflectanceBand2(:, :, dateIdx) = origSr(:, :, 2);
        reflectanceBand3(:, :, dateIdx) = origSr(:, :, 3);
        reflectanceBand4(:, :, dateIdx) = origSr(:, :, 4);
        reflectanceBand5(:, :, dateIdx) = origSr(:, :, 5);
        reflectanceBand6(:, :, dateIdx) = origSr(:, :, 6);
        reflectanceBand7(:, :, dateIdx) = origSr(:, :, 7);
%}
%{
    % Parfor doesn't like eval....
        for bandIdx = 1:7
            eval(['reflectanceBand', num2str(bandIdx), '(:, :, ', num2str(i), ') = origSr(:, :, ', num2str(bandIdx), ');']);
        end
%}
        SolarAzimuth(:,:, dateIdx)=SolarAzimuth_;
    end %parfor day

    R = FilledCubeR;
    FilledCubeR = [];
%{
    saveVariableForSpiresFill20240204(fname, saltpan, 'saltpan', 8, divisor, dtype, '-append');
    saltpan = [];
    saveVariableForSpiresFill20240204(fname, neuralSnow, 'neuralSnow', 9, divisor, dtype, '-append');
    neuralSnow = [];
    saveVariableForSpiresFill20240204(fname, neuralCloud, 'neuralCloud', 10, divisor, dtype, '-append');
    neuralCloud = [];
    saveVariableForSpiresFill20240204(fname, stateCloud, 'stateCloud', 11, divisor, dtype, '-append');
    stateCloud = [];
    saveVariableForSpiresFill20240204(fname, STCCloud, 'STCCloud', 16, divisor, dtype, '-append');
    STCCloud = [];
    saveVariableForSpiresFill20240204(fname, STCNDSI, 'STCNDSI', 17, divisor, dtype, '-append');
    STCNDSI = [];
%}
    saveVariableForSpiresFill20240204(fname, SensorZenith, 'sensorZ', 6, divisor, dtype, '-append');
    SensorZenith = [];

    saveVariableForSpiresFill20240204(fname, weights, 'weights', 5, divisor, dtype, '-append');
    weights = [];

    saveVariableForSpiresFill20240204(fname, solarZ, 'solarZ', 7, divisor, dtype, '-append');
%{
    for bandIdx = 1:7
        saveVariableForSpiresFill20240204(fname, eval(['reflectanceBand', num2str(bandIdx)]), ...
        ['reflectanceBand', num2str(bandIdx)], 18 + bandIdx, divisor, dtype, '-append');
        eval(['reflectanceBand', num2str(bandIdx), ' = [];']);
    end
%}
    saveVariableForSpiresFill20240204(fname, SolarAzimuth, 'SolarAzimuth', 25, divisor, dtype, '-append');
end