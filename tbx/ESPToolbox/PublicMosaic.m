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

        function publicMosaicData = getThresholdedData(obj, thisDatetime)
            % Provide the temporary public Mosaic data needed to generate
            % stats and geotiffs.
            % Public Mosaics are an update of the Mosaics: when some variables
            % are strictly below some thresholds, the values of other variables
            % are not considered reliable and replaced by a default value given
            % by regions.configurationOfVariables (file configuration_of_variables).
            %
            % Parameters
            % ----------
            % thisDatetime: datetime object
            %   Date over which mosaic data should be thresholded

            % 1. Initialization and configuration of variables
            %-------------------------------------------------

            espEnv = obj.regions.espEnv;
            modisData = obj.regions.modisData;
            regions = obj.regions;
            confOfVar = espEnv.configurationOfVariables();

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
            publicMosaicData.elevation = regions.getElevations();

            % 3. Thresholding and providing the Public Mosaic data
            %-----------------------------------------------------
            thresholds = regions.thresholdsForPublicMosaics;
            for thresholdId = 1:size(thresholds, 1)
                thresholdedVarname = thresholds{thresholdId, 'thresholded_varname'}{1};
                thresholdValue = thresholds{thresholdId, 'threshold_value'};
                replacedVarname = thresholds{thresholdId, 'replaced_varname'}{1};
                valueForUnreliableData = confOfVar{ ...
                    find(strcmp(confOfVar.output_name, replacedVarname)), ...
                    'value_for_unreliable'};

                publicMosaicData.(replacedVarname) ...
                    (publicMosaicData.(thresholdedVarname) < thresholdValue) ...
                        = valueForUnreliableData;
            end
        end
    end
end