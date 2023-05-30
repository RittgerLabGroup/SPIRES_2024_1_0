classdef PublicMosaic
    % Handles filtering or reliability checks of data
    % for their public release to the website
    properties
        region     % Regions object pointing to the upper-level region, e.g.
                    % westernUS
    end

    methods
        function obj = PublicMosaic(region)
            % Constructor
            %
            % Parameters
            % ----------
            % regions: Regions object
            %
            % Return
            % ------
            % obj: PublicMosaic object
            obj.region = region;
        end

        function publicMosaicData = getThresholdedData(obj, varName, thisDatetime, ...
            publicMosaicData)
            % Provide the temporary public Mosaic data for the variable
            % varName needed to generate stats and geotiffs.
            % Public Mosaics are an update of the Mosaics: when some variables
            % are strictly below some thresholds, the values of other variables
            % are not considered reliable and replaced by a default value given
            % by region.configurationOfVariables (file configuration_of_variables).
            %
            % NB: Should be called first to fill the publicMosaicData argument with
            % variables used for thresholding, e.g. snow_fraction or 
            % viewable_snow_fraction. SIER_163.
            %
            % Parameters
            % ----------
            % varName: char
            %   Name of the variable (should be checked in writeGeotiffs
            %   of configurationOfVariables)
            % thisDatetime: datetime object
            %   Date over which mosaic data should be thresholded
            % publicMosaicData: struct(elevation=array(doublexdouble), 
            %   viewable_snow_fraction=array(uint8xuint8)).
            %   Previous publicMosaicData if already called, otherwise struct().

            % 1. Initialization and configuration of variables
            %-------------------------------------------------

            thisRegion = obj.region;
            confOfVar = thisRegion.espEnv.configurationOfVariables();
            varIndex = find(strcmp(confOfVar.output_name, varName));
            varNameInfos = confOfVar(varIndex, :);

            % 2. Mosaic data and elevation
            %-----------------------------

            mosaicFile = thisRegion.espEnv.MosaicFile(thisRegion, thisDatetime);
            if ~isfile(mosaicFile)
                warning('%s: Missing mosaic file %s\n', mfilename(), ...
                    mosaicFile);
                publicMosaicData = struct();
                return;
            end
            fields = fieldnames(publicMosaicData);
            if ~ismember(varName, fields)
                varData = load(mosaicFile, varName).(varName);
            end
            if ~ismember('elevation', fields)
                publicMosaicData.elevation = thisRegion.getElevations();
            end
                        
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
            % NB. SIER_163 optim, only works for thresholds based on elevation
            % and snow_fraction.
            %---------------------------------------------------------------------------
            publicMosaicData.(varName) = varData;            
            thresholds = thisRegion.thresholdsForPublicMosaics;
            for thresholdId = 1:size(thresholds, 1)
                replacedVarname = thresholds{thresholdId, 'replaced_varname'}{1};
                if strcmp(varName, replacedVarname)
                    thresholdedVarname = thresholds{thresholdId, ...
                        'thresholded_varname'}{1};
                    thresholdValue = thresholds{thresholdId, 'threshold_value'};
                        % the threshold value must be the threshold value in Mosaic file
                        %    (and not the threshold value as viewed by Public)
                    
                    valueForUnreliableData = varNameInfos.('value_for_unreliable_web');
                    publicMosaicData.(replacedVarname) ...
                        (publicMosaicData.(thresholdedVarname) < thresholdValue) ...
                            = valueForUnreliableData;
                end
            end            
        end
    end
end
