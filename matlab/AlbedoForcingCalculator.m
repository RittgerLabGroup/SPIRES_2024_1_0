classdef AlbedoForcingCalculator < handle
  % Calculation of dirty albedo and radiative forcing.
  % Class designed from the code by Jeff Dozier
  % https://github.com/DozierJeff/LookupFunctionsSPIReS/blob/main/SnowAlbedoLookupSPIReS.m
  % https://github.com/DozierJeff/LookupFunctionsSPIReS/blob/main/DarkeningLookupSPIReS.m
  % retrieved 2024-05-10.
  properties
    deltavisGriddedInterpolant  % GridInterpolant obj. To allow lookup table search
      % of deltavis.
    dirtyAlbedoGriddedInterpolant  % GridInterpolant obj. To allow lookup table search
      % of dirty albedo.
    radiativeForcingGriddedInterpolant  % GridInterpolant obj. To allow lookup table
      % search of radiative forcing.
    region % Regions obj.
  end
  methods
    function obj = AlbedoForcingCalculator(region)
      obj.region = region;
      espEnv = obj.region.espEnv;
      fprintf('Loading albedo interpolant...\n');
      if isempty(obj.dirtyAlbedoGriddedInterpolant)
        thisFilePath = espEnv.getFilePathForObjectNameDataLabel('', 'albedolookup');
        
        rsyncDirectoryPath = regexprep(thisFilePath, '/[^/]*$', '/');
        % Copy the files from the archive if present in archive ...
        archiveDirectoryPath = strrep( ...
            rsyncDirectoryPath, region.espEnv.scratchPath, region.espEnv.archivePath);
        if isdir(archiveDirectoryPath)
          cmd = [region.espEnv.rsyncAlias, ' ', archiveDirectoryPath, ' ', rsyncDirectoryPath];
          fprintf('%s: Rsync cmd %s ...\n', mfilename(), cmd);
          [status, cmdout] = system(cmd);
        end
        obj.dirtyAlbedoGriddedInterpolant = load(thisFilePath, 'Fdirty').Fdirty;
      end
      fprintf('Loading radiative forcing and deltavis interpolant...\n');
      if isempty(obj.radiativeForcingGriddedInterpolant)
        thisFilePath = espEnv.getFilePathForObjectNameDataLabel('', 'radiativelookup');
        obj.deltavisGriddedInterpolant = load(thisFilePath, 'Fdarken').Fdarken;
        obj.radiativeForcingGriddedInterpolant = load(thisFilePath, 'Fforce').Fforce;
      end
      fprintf('AlbedoForcingCalculator initialization done.\n');
    end
    function [dirtyAlbedo, deltavis, radiativeForcing] = getFromLookup(obj, ...
      grainSize, dustConcentration, cosOfSolarZenith)
      % Parameters
      % ----------
      % grainSize: int(N dim). Grain size in microns.
      % dustConcentration: int(N dim). Dust concentration in ppm.
      % cosOfSolarZenith: double(N dim). Cosinus Solar zenith angle. (mu0 or muZ).
      %
      % Return
      % ------
      % dirtyAlbedo: uint8(N dim). Dirty albedo in percent.
      % deltavis: uint8(N dim). Deltavis or snow darkening, without units.
      % radiativeForcing: uin16(N dim). Radiative forcing in W/m2.
      dustFraction = double(dustConcentration) / 1000; % spires dust is in ppm while
        % AlbedoLookup expects ppt.
      sootFraction = zeros(size(dustConcentration), 'double');
      % cosOfSolarZenith = cosd(double(solarZenith));
      cosOfSolarZenith = double(cosOfSolarZenith);
      cosOfIllumination = cosOfSolarZenith; % based on Jeff ParBal package.
      dirtyAlbedo = obj.dirtyAlbedoGriddedInterpolant(cosOfSolarZenith, ...
        cosOfIllumination, sqrt(double(grainSize)), dustFraction, sootFraction);
        % cosOfSolarZenith: mu0, cosOfIllumination = muI, grainSize: radius,
        % dustFraction: LAPfraction(1) in Jeff function.

      deltavis = obj.deltavisGriddedInterpolant(cosOfSolarZenith, ...
        cosOfIllumination, sqrt(double(grainSize)), dustFraction, sootFraction);
      radiativeForcing = obj.radiativeForcingGriddedInterpolant(cosOfSolarZenith, ...
        cosOfIllumination, sqrt(double(grainSize)), dustFraction, sootFraction);
    end
  end
end
