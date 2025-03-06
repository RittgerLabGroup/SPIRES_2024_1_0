addpath(genpath('/projects/sele7124/MATLAB/SPIRES/core')); addpath(genpath('/projects/sele7124/MATLAB/SPIRES/MODIS_HDF')); addpath(genpath('/projects/sele7124/MATLAB/SPIRES/TimeSpace')); addpath(genpath('/projects/sele7124/MATLAB/SPIRES/General'));

addpath(genpath('/projects/sele7124/MATLAB/SPIRES/SunPosition')); % azimuthPreference, sunslope
addpath(genpath('/projects/sele7124/MATLAB/SPIRES/TopographicHorizons/viewFactor')); % topographicSlope

% use sunslope in parbal package.


%example script for running SPIReS with Landsat 8

% Bair, E.H., Stillinger, T., and Dozier, J. (2021) 
% Snow Property Inversion from Remote Sensing (SPIReS), 
% IEEE Transactions on Remote Sensing and Geoscience, 
% doi: 10.1109/TGRS.2020.3040328

%unzip example files
%unzip('L8example.zip')

% Instantiation of whatever region to make work the AlbedoForcingCalculator class.
label = 'v2024.0d';
versionOfAncillary = 'v3.1'; % Only for initiating the exporter.
scratchPath = '/rc_scratch/sele7124/'; % getenv('espArchiveDir');
regionName = 'h08v04'; 
modisData = MODISData(label = label, versionOfAncillary = versionOfAncillary);
espEnv = ESPEnv(modisData, scratchPath = scratchPath);
region = Regions(regionName, [regionName, '_mask'], espEnv, modisData);

inputDirectoryPath = '/rc_scratch/sele7124/landsat8/input_spires_from_Ned_202311/TCD_fSCA_validation_2022/';
ouputDirectoryPath = '/rc_scratch/sele7124/landsat8/output_test/';
outputFilePath = fullfile(ouputDirectoryPath, 'LC08_L2SP_042034_20160426_20200907_02_T1.mat');
nedFilePath = '/rc_scratch/sele7124/landsat8/input_spires_from_Ned_202311/example/LC08_L2SP_042034_20160426_20200907_02_T1.mat';
%files
r0dir = fullfile(inputDirectoryPath, 'R0'); %snow/ice minima background,  p42r34 20201014
rdir = fullfile(inputDirectoryPath, 'R'); %snow covered scene,  p42r34 20160426
demfile = fullfile(inputDirectoryPath, 'DEM', 'p042r034.mat'); % DEM for p42r34 - extraneous 
%if terrain correction set to false & el_cutoff  =  0 m
Ffile = fullfile(inputDirectoryPath, 'Ffile', 'lut_oli_b1to7_3um_dust.mat'); % look up tables
%Mie-RT calcs for snow for L8 bands 1-7 w/ 3 um dust
CCfile = fullfile(inputDirectoryPath, 'CC', 'p042r034.mat'); % canopy cover percent file,  NLCD
WaterMaskfile = fullfile(inputDirectoryPath, 'watermask', 'p042r034.mat'); %watermask file,  NLCD
fIcefile = fullfile(inputDirectoryPath, 'fice', 'p042r034.mat'); %fractional ice,  derived from
%Randolph Glacier Inventory

CloudMaskfile = fullfile(inputDirectoryPath, 'cloudmask', 'p042r034.mat');

%parameters
shade = 0; % ideal shade endmember, fraction 0-1
tolval = 0.05; % tolerance value for uniquetol for grouping spectra,  fraction 0-1
fsca_thresh = 0.07; % 0.10; %minimum fsca value,  fraction 0-1
dust_rg_thresh = 300; %minimum dirty snow grain size,  um
el_cutoff = 0; %minimum elevation for snow,  m,  in this case 0 m ignores
subset = [1052 3032; 1471 3529]; %bounding box in pixel coordinates for subset 
% of scene 

grain_thresh = 0.9;
dust_thresh = 0.9;

%takes 2.09 min running w/ 50 cores
out = run_spires_landsat_20240625(r0dir, rdir, demfile, Ffile, shade, tolval, ...
    fsca_thresh, dust_rg_thresh, grain_thresh, dust_thresh, CCfile, ...
    WaterMaskfile, CloudMaskfile, fIcefile, ...
    el_cutoff, subset, false, region, outputFilePath);

% save(outputFilePath, '-struct', 'out', '-v7.3');