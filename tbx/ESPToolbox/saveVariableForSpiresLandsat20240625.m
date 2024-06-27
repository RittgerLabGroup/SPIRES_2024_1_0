function saveVariableForSpiresLandsat20240625(outputFilePath, data, varId, appendFlag)
    % Save variables in spires landsat files. Very dirty on the model of saveVariableForSpiresSmooth20240204().
    tic
    
    varNames = {'gap_viewable_snow_fraction_s', 'gap_snow_fraction_s', 'gap_shade_s', 'gap_grain_size_s', 'gap_dust_concentration_s', 'gap_albedo_s', 'gap_radiative_forcing_s', 'gap_deltavis_s', 'gap_albedo_muZ_s', 'solar_zenith', 'solar_azimuth'};
    divisors = [100, 100, 100, 1, 10, 100, 1, 100, 100, 1, 1];
    theseTypes = {'uint8', 'uint8', 'uint8', 'uint16', 'uint16', 'uint8', 'uint16', 'uint8', 'uint8', 'uint8', 'int16'};
    varName = varNames{varId};
    fprintf('Saving variable %s in %s...\n', varName, outputFilePath);

    data = data * divisors(varId);
    data(isnan(data)) = intmax(theseTypes{varId});
    data = cast(data, theseTypes{varId});
    eval([varName, ' = data;']);

    if strcmp(appendFlag, '-append')
        save(outputFilePath, varName, '-append');
    else
        save(outputFilePath, varName, '-v7.3');
    end
    fprintf('Saved variable %s in %f secs.\n', varName, toc);
end
