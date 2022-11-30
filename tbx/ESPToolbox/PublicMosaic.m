classdef PublicMosaic
    % Handles filtering or reliability checks of data
    % for their public release to the website
    properties
        regions     % Regions object pointing to the upper-level region, e.g.
                    % westernUS
    end

    methods
        function obj = PublicMosaic(regions)
            % Constructor
            %
            % Parameters
            % ----------
            % regions: Regions object
            %
            % Return
            % ------
            % obj: PublicMosaic object
            obj.regions = regions;
        end

        function publicMosaicData = getThresholdedData(obj, varName, thisDatetime)
            % Provide the temporary public Mosaic data for the variable
            % varName needed to generate stats and geotiffs.
            % Public Mosaics are an update of the Mosaics: when some variables
            % are strictly below some thresholds, the values of other variables
            % are not considered reliable and replaced by a default value given
            % by regions.configurationOfVariables (file configuration_of_variables).
            %
            % Parameters
            % ----------
            % varName: char
            %   Name of the variable (should be checked in writeGeotiffs
            %   of configurationOfVariables)
            % thisDatetime: datetime object
            %   Date over which mosaic data should be thresholded

            % 1. Initialization and configuration of variables
            %-------------------------------------------------

            espEnv = obj.regions.espEnv;
            modisData = obj.regions.modisData;
            regions = obj.regions;
            confOfVar = espEnv.configurationOfVariables();
            varIndex = find(strcmp(confOfVar.output_name, varName));
            varNameInfos = confOfVar(varIndex, :);

            % 2. Mosaic data and elevation
            %-----------------------------

            mosaicFile = espEnv.MosaicFile(regions, thisDatetime);
            if ~isfile(mosaicFile)
                warning('%s: Missing mosaic file %s\n', mfilename(), ...
                    mosaicFile);
                    publicMosaicData = struct();
                    return;
            end
            publicMosaicData = load(mosaicFile);
            varData = publicMosaicData.(varName);
                        
            % 3. Rescale variables to match web precision (eg 1 unit)
            % and cast
            % ----------------------------------------------------
            % Nb: divisor ~= 1 only for albedos
            varData = single(varData);
            varData(varData == varNameInfos.('nodata_value')) = NaN;
            varData = varData / varNameInfos.('divisor');
            varData(isnan(varData)) = ...
                varNameInfos.('nodata_value_web');
            varData = cast(varData, varNameInfos.('type_web'){1});

            % 4. Thresholding and providing the Public Mosaic data
            %-----------------------------------------------------
            publicMosaicData.(varName) = varData;
            publicMosaicData.elevation = regions.getElevations();
            thresholds = regions.thresholdsForPublicMosaics;
            for thresholdId = 1:size(thresholds, 1)
                replacedVarname = thresholds{thresholdId, 'replaced_varname'}{1};
                if strcmp(varName, replacedVarname)
                    thresholdedVarname = thresholds{thresholdId, 'thresholded_varname'}{1};
                    thresholdValue = thresholds{thresholdId, 'threshold_value'};
                        % the threshold value must be the threshold value in Mosaic file
                        %    (and not the threshold value as viewed by Public)
                    
                    valueForUnreliableData = varNameInfos.('value_for_unreliable_web');
                    publicMosaicData.(replacedVarname) ...
                        (publicMosaicData.(thresholdedVarname) < thresholdValue) ...
                            = valueForUnreliableData;
                end
            end
            fields =fieldnames(publicMosaicData);
            fieldsToRemove = fields(~ismember(fields, {varName}));
            publicMosaicData = rmfield(publicMosaicData, [fieldsToRemove]);
        end
    end
end
