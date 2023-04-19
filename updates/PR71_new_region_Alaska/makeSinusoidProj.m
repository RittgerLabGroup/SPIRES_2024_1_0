function [mstruct Rmap1km Rmap500m size1km size500m]=makeSinusoidProj(filename)
%[mstruct Rmap1km Rmap500m size1km size500m]=makeSinusoidProj(filename)
% get projection struction and referencing matrices for 500m & 1km MOD09GA
%
%INPUT
% filename - EOS MOD09GA hdf filename
%OUTPUT
% mstruct - projection structure
% Rmap1km - referencing matrix for 1km dataset
% Rmap500m - referencing matrix for the 500m dataset
% size1km - size of the 1km dataset
% size500m - size of the 500m dataset
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Karl Rittger
% Jet Propulsion Laboratory & Earth Research Institute, UCSB
% October 3, 2012
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% HDF-EOS info
S = hdfinfo(filename,'eos');

% projection structure 
mstruct = defaultm('sinusoid');
%mstruct.geoid = almanac('earth','wgs84','meters');%Commented out 20121023

% Using 0 for inverse flattening because its a sphere. Its not clear which
% of the zeros in the Projection.ProjParam to use
% Also the (1) is the 1km dataset. The same geoid is used for both 1km and
% 500m
mstruct.geoid = [S.Grid(1).Projection.ProjParam(1) 0];
mstruct = defaultm(mstruct);

% columns
cols1km = S.Grid(1).Columns;
cols500m = S.Grid(2).Columns;
rows1km = S.Grid(1).Rows;
rows500m = S.Grid(2).Rows;
size1km=[rows1km cols1km];
size500m=[rows500m cols500m];

% distance from outer edges of pixel (assuming x & y are same)
% These should be equal...
x1km = S.Grid(1).UpperLeft(2)-S.Grid(1).LowerRight(2);
x500m = S.Grid(2).UpperLeft(2)-S.Grid(2).LowerRight(2);

% Calculate size of pixel
dx1km = x1km/cols1km;%~926.6254
dx500m = x500m/cols500m;%~463.3127

% referencing matrix for 1km (shifting left and up half a pixel from edge)
% Although the files says "center" for upper left and lower right the
% webpage disagrees:
% https://lpdaac.usgs.gov/products/modis_overview
% Also this test shows they are same which (0 difference) which supports
% the webpage
Rmap1km = makerefmat(S.Grid(1).UpperLeft(1)+dx1km/2,...
S.Grid(1).UpperLeft(2)-dx1km/2,dx1km,-dx1km);

% referencing matrix for 500m (shifting left and up half a pixel from edge)
Rmap500m = makerefmat(S.Grid(2).UpperLeft(1)+dx500m/2,...
    S.Grid(2).UpperLeft(2)-dx500m/2,dx500m,-dx500m);

% Seba 230404 --------------------------------------------------------------------------
%R = maprefcells(xlimits, ylimits, xcellextent, ycellextent);

% this gives the identic object for tile h07v03 as:
% refmatToMapRasterReference(Rmap500m, [2400 2400]); 
R = maprefcells([S.Grid(2).UpperLeft(1) ...
    S.Grid(2).UpperLeft(1) + dx500m * cols500m], ...
    [S.Grid(2).UpperLeft(2) - dx500m * rows500m, ...
    S.Grid(2).UpperLeft(2)], ...
    dx500m, dx500m, 'ColumnsStartFrom','north'); 
% Add CRS

% From RasterProjection by Jeff Dozier (for Matlab>2020b):
% (MATLAB could use a more explicit method to create a custom projcrs)
% (the following gives the same result as the mstruct version)
wkt = "PROJCS[""MODIS Sinusoidal"",BASEGEOGCRS[""User"",DATUM[""World Geodetic Survey 1984"",SPHEROID[""Authalic_Spheroid"",6371007.181,0.0]],PRIMEM[""Greenwich"",0.0],UNIT[""Degree"",0.0174532925199433]],PROJECTION[""Sinusoidal""],PARAMETER[""False_Easting"",0.0],PARAMETER[""False_Northing"",0.0],PARAMETER[""Central_Meridian"",0.0],UNIT[""Meter"",1.0]]";
% create the projcrs from the edited wkt
R.ProjectedCRS = projcrs(wkt);
end