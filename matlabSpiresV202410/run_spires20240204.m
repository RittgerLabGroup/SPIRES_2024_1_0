function out=run_spires20240204(R0,R,solarZ,Ffile,mask,shade,...
    grain_thresh,dust_thresh,tolval,red_b,swir_b,bweights, fname, divisor, dtype, region)
% run LUT version of scagd for 4-D matrix R
% produces cube of: fsca, grain size (um), and dust concentration (by mass)
% input:
% R0 - background image (MxNxb). Recommend a sinle day with no clouds, 
% no snow and and low sensor zenith angle
% R - 4D cube of time-space smoothed reflectances (MxNxbxd) with
% dimensions: x,y,band,day
% solarZ: solar zenith angles (MxNxd) for R
% Ffile, location of griddedInterpolant object that produces reflectances
% for each band
% with inputs: grain radius (um), dust (ppmw), solar zenith angle (deg),
% band # (not necessarily in order of wavelength)
% mask - logical mask (MxN), true for areas to NOT process
% shade - scalar or vector, length of # bands
% grain_thresh - grain size threshold fsca value, e.g. 0.25
% dust_thresh - dust size threshold fsca value, e.g. 0.85
% tolval - unique row tolerance value, i.e. 0.05 - bigger number goes faster
% as more pixels are grouped together
% hdr - header struct w/ map info, see GetCoordinateInfo.m
% or RR - mapcellsref object with ProjectedCRS field
% red_b - red band, e.g. 3 for MODIS and L8
% swir_b - SWIR band, e.g. 6 for MODIS and L8
% bweights - band weights MxNxd, empty if not used

%output:
%   out - struct w fields
%   fsca: MxNxd
%   fshade: MxNxd
%   grainradius: MxNxd
%   dust: MxNxd

% Seb 20240304: Add saving in spires fill files of several variables, with arguments fname, divisor, dtype.

regionName = region.name;

outvars={'fsca','fshade','grainradius','dust', 'spatial_grain_size_s', 'spatial_dust_concentration_s'};

sz=size(R);


if length(sz) == 3
   sz(4)=1; % singleton 4th dimenson
end

%{
Seb 2024-03-12
if isstruct(hdr)
    %pix centers to be deprecated soon
    [X,Y]=pixcenters(hdr.RefMatrix,size(mask),'makegrid');
else %assume mapcellsreference
    [X,Y]=worldGrid(hdr,'fullgrid');
end
%}
[X,Y]=worldGrid(region.getMapCellsReference(),'fullgrid');

for i=1:length(outvars)
    out.(outvars{i})=NaN([sz(1)*sz(2) sz(4)]);
end

allNDSI=NaN([sz(1)*sz(2) sz(4)]);
allDaymask=NaN([sz(1)*sz(2) sz(4)]);
isNotNaNR=cast(all(~isnan(R), 3), 'uint8');
isNotNaNR0=cast(all(~isnan(R0), 3), 'uint8');

solarZ=reshape(double(solarZ),[sz(1)*sz(2) sz(4)]);
R=reshape(double(R),[sz(1)*sz(2) sz(3) sz(4)]);
R0=reshape(double(R0),[sz(1)*sz(2) sz(3)]);

if ~isempty(bweights)
   bweights=reshape(bweights,[sz(1)*sz(2) sz(4)]);
end

mask=reshape(mask,[sz(1)*sz(2) 1]);
X=reshape(X,[sz(1)*sz(2) 1]);
Y=reshape(Y,[sz(1)*sz(2) 1]);

% 2024-07-16 Seba. Restriction of x 100 only to Ned's R0 for westernUS.
if ismember(regionName, {'h08v04', 'h08v05', 'h09v04', 'h09v05', 'h10v04'})
    R0 = round(R0,2)*100;
end
    
for i=1:sz(4) %for each day
    t1=tic;
    
    if ~isempty(bweights)
       %mask for weights < 1 in any band 
       bmask=bweights(:,i) < sz(3);
       daymask=mask | bmask;
    else
       daymask=mask;
    end
   
    thisR=squeeze(R(:,:,i));
    thissolarZ=squeeze(solarZ(:,i));
    
    NDSI=(thisR(:,red_b)-thisR(:,swir_b))./...
         (thisR(:,red_b)+thisR(:,swir_b));
    %include NDSI > thresh, not masked, and no NaNs in any bands for R & R0
    %
    t=NDSI > -0.5  & ~daymask & ~isnan(thissolarZ) & all(~isnan(thisR),2) & ...
        all(~isnan(R0),2);
    
    % 2024-07-15 Seba: R0 for tiles other than westernUS are uint8 percent interpolated, while
    % for westernUS Ned's R0 are double fraction with nodata.
    
    M=[round(thisR,2)*100 R0 round(thissolarZ)]; 
    
    %keep track of indices
    Rind=1:sz(3);
    R0ind=(Rind(end)+1):(Rind(end)+sz(3));
    sZind=R0ind(end)+1;
    
    M=M(t,:);
    XM=X(t); % X coordinates for M
    YM=Y(t); % Y coordinates for M
    tForUniqueTol = tic;
    if tolval>0
    [c,im,~]=uniquetol(M,tolval*100,'ByRows',true,'DataScale',1,...
        'OutputAllIndices',true);
       im1=zeros(size(im));
    else
       c=M;
       im=cell(size(c,1),1);
       for ii=1:size(c,1)
          im{ii}=ii; 
       end
    end
    fprintf('Unique tol with %d groups run in %.2f mins.\n', length(im), toc(tForUniqueTol) / 60);
    
    for k=1:length(im)
       im1(k)=im{k}(1); 
    end
        
    XC=XM(im1); %X coordinates for c
    YC=YM(im1); %Y coordinates for c
   
    % Copy the files from the archive if present in archive ...
    archiveFilePath = strrep( ...
        Ffile, region.espEnv.scratchPath, region.espEnv.archivePath);
    
    cmd = [region.espEnv.rsyncAlias, ' ', archiveFilePath, ' ', Ffile];
    fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
    [status, cmdout] = system(cmd);
    
    %first pass, solve for all
    temp=NaN(size(c,1),length(outvars));
    tForFirstParForPass = tic;
    parfor j=1:size(c,1) %solve for unique (w/ tol) rows
        pxR=c(j,Rind)/100; %rescale back
        if any(pxR>1)
           pxR=pxR./max(pxR); %normalize to 1 
        end
        pxR0=c(j,R0ind)/100;
        sZ=c(j,sZind);
        
        w=ones(length(pxR),1);

       o=speedyinvert(pxR,pxR0,sZ,Ffile,shade,1,1,w);
       o.x(5) = o.x(3);
       o.x(6) = o.x(4); % To save the original values grainradius and dust in positions 3 and 4, with positions 5 and 6 used for spatial grain size and dust. 20240614.
       %fsca too low for grain size, set for interpolation
       if o.x(1) < grain_thresh %|| o.x(2)>0.01
          o.x(5)=NaN;
       end

        %fsca too low or too dark for dust
        if o.x(1) < dust_thresh %|| o.x(2)>0.01 %can be solved for dust
           o.x(6)=NaN; 
        end
        
        temp(j,:)=o.x;
    end
    fprintf('First parfor pass run in %.2f mins.\n', toc(tForFirstParForPass) / 60);
    
    %second pass, use interpolated dust/grain sizes
    g=temp(:,5);
    d=temp(:,6);
    tt_grain=~isnan(g);
    tt_dust=~isnan(d);
    if nnz(tt_grain) > 0 && nnz(tt_dust) > 0 % if there are solved dust/grain values
        sgrain=g(tt_grain); %solved grain size values
        sdust=d(tt_dust); %solved dust values
        XCYCgrain=[XC(tt_grain),YC(tt_grain)];
        XCYCdust=[XC(tt_dust),YC(tt_dust)];
        tForSecondParForPass = tic;
        parfor j=1:size(c,1)
            
            if ~tt_grain(j)
                dist_grain=pdist2(XCYCgrain,[XC(j),YC(j)]);
                w_grain=1./dist_grain;
                G=(sum(w_grain.*sgrain))./(sum(w_grain));
            else
                G=g(j);
            end
            
            if ~tt_dust(j)
                dist_dust=pdist2(XCYCdust,[XC(j),YC(j)]);
                w_dust=1./dist_dust;
                D=(sum(w_dust.*sdust))./(sum(w_dust));
            else
                D=d(j);
            end

            fs=temp(j,:);
            
            temp(j,:)=[fs(1:4) G D];
        end
        fprintf('Second parfor pass run in %.2f mins.\n', toc(tForSecondParForPass) / 60);
    end

    repxx=NaN(size(M,1),length(outvars));
    for j=1:size(temp,1) % the unique indices
        idx=im{j}; %indices for each unique val
        for k=1:length(outvars)
            repxx(idx,k)=temp(j,k); %fsca,fshade,grain size,dust, spatial_grain_size_s, spatial_dust_concentration_s 20240624
        end
    end
    %now fill out all pixels
    
    for j=1:length(outvars)
        out.(outvars{j})(t,i)=repxx(:,j);
        tt=NDSI <= -0.5  & ~daymask & ~isnan(thissolarZ) & all(~isnan(thisR),2) & ...
        all(~isnan(R0),2);
        if strcmp(outvars{j}(1),'f') %set fsca/fshade to zero
            out.(outvars{j})(tt,i)=0;
        else
            out.(outvars{j})(tt,i)=NaN;%grain & dust to NaN
        end
    end
%{   
    % Seb 20240304 Addition of variables.
    allNDSI(:, i) = NDSI;
    allDaymask(:, i) = daymask;
%}    
    t2=toc(t1);
    fprintf('done w/ day %i in %g min\n',i,t2/60);  
end
%{
% Seb 20240304.
allNDSI = reshape(allNDSI, [sz(1) sz(2) sz(4)]);
saveVariableForSpiresFill20240204(fname, allNDSI, 'NDSI', 12, divisor, dtype, '-append');
allNDSI = [];
allDaymask = reshape(allDaymask, [sz(1) sz(2) sz(4)]);
saveVariableForSpiresFill20240204(fname, allDaymask, 'daymask', 13, divisor, dtype, '-append');
allDaymask = [];
saveVariableForSpiresFill20240204(fname, isNotNaNR, 'isNotNaNR', 14, divisor, dtype, '-append');
isNotNaNR = [];
saveVariableForSpiresFill20240204(fname, isNotNaNR0, 'isNotNaNR0', 15, divisor, dtype, '-append');
isNotNaNR0 = [];
%}
out.spatial_grain_size_s(out.fsca==0) = NaN; % Seb
out.spatial_dust_concentration_s(out.fsca==0) = NaN; % Seb

% SEB added save below.
for i=1:length(outvars)
    out.(outvars{i})=reshape(out.(outvars{i}),[sz(1) sz(2) sz(4)]);
    %{
     t=isnan(out.(outvars{i}));
    if i==3 || i==4  %grain size or dust
        t = (t | out.fsca==0);
    end
    out.(outvars{i})=cast(out.(outvars{i})*divisor(i),dtype{i});
    out.(outvars{i})(t)=intmax(dtype{i});
    %}
end

saveVariableForSpiresFill20240204(fname, out.fsca, 'fsca', 1, divisor, dtype, '-append');
out.fsca = [];
saveVariableForSpiresFill20240204(fname, out.fshade, 'fshade', 2, divisor, dtype, '-append');
out.fshade = [];
saveVariableForSpiresFill20240204(fname, out.grainradius, 'grainradius', 3, divisor, dtype, '-append');
out.grainradius = [];
saveVariableForSpiresFill20240204(fname, out.dust, 'dust', 4, divisor, dtype, '-append');
out.dust = [];
saveVariableForSpiresFill20240204(fname, out.spatial_grain_size_s, 'spatial_grain_size_s', 26, divisor, dtype, '-append');
out.spatial_grain_size_s = [];
saveVariableForSpiresFill20240204(fname, out.spatial_dust_concentration_s, 'spatial_dust_concentration_s', 27, divisor, dtype, '-append');
out.spatial_dust_concentration_s = [];


end