classdef Mosaic
    % Handles the daily mosaic files that join tiles together
    % for an upper-level region and provide the values
    % for variables required to generate the data expected by the SnowToday
    % website
    properties
        regions     % Regions object pointing to the upper-level region, e.g.
                    % westernUS
    end

    methods
        function obj = Mosaic(regions)
            % Constructor
            %
            % Parameters
            % ----------
            % regions: Regions object
            %
            % Return
            % ------
            % obj: Mosaic object
            obj.regions = regions;
        end

        function writeFiles(obj, waterYearDate, availableVariables)
            % Generate and write the mosaic files over several months of a waterYear
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object
            %   waterYearDate for which generating the mosaics.
            % availableVariables: array of cells
            %   list of information about the variables to include in the mosaics
            %   filtered from the data obtained by espEnv.configurationOfVariables.
            
            % 1. Initialize
            %--------------
            tic;
            fprintf('%s: Start mosaic generation and writing\n', mfilename());
            espEnv = obj.regions.espEnv;
            modisData = obj.regions.modisData;
            regions = obj.regions;
            regionName = obj.regions.regionName;

            % Array of the tile regions that compose the upper-level region
            tileRegionsArray = obj.regions.getTileRegions();

            varIndexes = 1:size(availableVariables, 1);
            for varId=varIndexes
                varNameInfos = availableVariables(varId, :);
                varNames{varId} = varNameInfos.('output_name'){1};
            end

            % 2. Convert monthly STC data into daily Mosaic data and save
            %------------------------------------------------------------
            monthRange = waterYearDate.getMonthlyFirstDatetimeRange();

            % Start or connect to the local pool (parallelism)
            % Trial and error: this process is a real memory pig
            espEnv.configParallelismPool(5);

            parfor monthDatetimeIdx = 1:length(monthRange)
                % 2.1. Initialize the parfor variables
                %------------------------------------
                monthDatetime = monthRange(monthDatetimeIdx);
                % Stores data that will be saved in Mosaic files
                mosaicData = struct();
                % Stores data necessary to assemble the Mosaic from
                % the tiles (matrix assembly).
                mosaicDataForAllDays = struct();
                % Stores individual info on tiles to handle them before
                % assembly
                tileData = struct();

                % 2.2. Check that all tiles have the monthly STC file
                % And construct the list of days that have data on all tiles
                % and for which mosaic files could be generated.
                %
                % NB: Because of the way the STC cubes are constructed: if a
                % tile STC file exist, all days within it are continuous. The
                % last day present in the STC file is the last observation day.
                % Then if tile STC files A and B have 3 and 5 number of days
                % for the same month, it implies that the last observation in A
                % is the 3rd day of the month and the last in B is the 5th day
                % of the month. Then, only the mosaic files for the first 3 days
                % of the month will be constructed.
                %---------------------------------------------------------------
                if  month(monthDatetime) == month(waterYearDate.thisDatetime)
                    dayRange = monthDatetime:waterYearDate.thisDatetime;
                else
                    dayRange = monthDatetime:datetime(year( ...
                    monthDatetime), month(monthDatetime) + 1, 1) - days(1);
                end
                missingFileFlag = false;

                for tileId = 1:length(tileRegionsArray)
                    tileRegions = tileRegionsArray(tileId);
                    tileSTCFile = espEnv.SCAGDRFSFile(...
                        tileRegions, 'SCAGDRFSSTC', monthDatetime);
                    mosaicData.files{tileId, 1} = tileRegions.regionName;
                    mosaicData.files{tileId, 2} = tileSTCFile;
                    if ~isfile(tileSTCFile)
                        warning(['%s: Missing interp STC file %s. Mosaic files' ...
                            ' not generated for this month.\n'], mfilename(), ...
                            tileSTCFile);
                        missingFileFlag = true;
                        break;
                    end
                    tileDatetimes = datetime(load(tileSTCFile, 'datevals').datevals, ...
                        'ConvertFrom', 'datenum');
                    if daysdif(tileDatetimes(end), dayRange(end)) > 0
                        dayRange = dayRange(1):tileDatetimes(end);
                    end
                end
                if missingFileFlag == true
                    continue;
                end

                % Map projection information
                mstructFile = fullfile(espEnv.mappingDir, ...
                           'Sinusoidal_projection_structure.mat');
                mstructData = matfile(mstructFile);
                mosaicData.mstruct = mstructData.mstruct;

                % 2.3. Collect individual tile information (RefMatrix, rowNb,
                %  colNb) to construct the regional RefMatrix of the Mosaic
                % (previously BigRMap).
                % NB: RefMatrix is deprecated in Matlab and should be replaced
                % by another object.
                %-------------------------------------------------------------
                tileData.RefMatrices = zeros(length(tileRegionsArray), 3, 2);
                tileData.sizes = zeros(length(tileRegionsArray), 2);
                tileData.lr = zeros(length(tileRegionsArray), 2); % check what is exactly lr

                for tileId = 1:length(tileRegionsArray)
                    tileSTCFile = mosaicData.files{tileId, 2};
                    tileSTCData = matfile(tileSTCFile);

                    tileData.RefMatrices(tileId, :, :) = tileSTCData.RefMatrix;
                    tileData.sizes(tileId, :) = [size(tileSTCData, 'snow_fraction', 1) ...
                        size(tileSTCData, 'snow_fraction', 2)];
                    tileData.lr(tileId, :) = [tileData.sizes(tileId, :) 1] * ...
                        squeeze(tileData.RefMatrices(tileId, :, :));

                    % This indirection is due to matfile 7.3 limitation
                    % It won't allow us to directly index into 
                    % structure fields
                    thisSTC = tileSTCData.STC;
                    mosaicData.mindays(tileId) = {thisSTC.mindays};
                    mosaicData.zthresh(tileId) = {thisSTC.zthresh};
                end

                mosaicData.stcStruct = struct(regions.STC); % SIER_289
                mosaicData.RefMatrix = zeros(3,2);
                mosaicData.RefMatrix(3, 1) = min(tileData.RefMatrices(:, 3, 1));
                mosaicData.RefMatrix(2, 1) = tileData.RefMatrices(1, 2, 1); % pixel size
                mosaicData.RefMatrix(1, 2) = tileData.RefMatrices(1, 1, 2); % pixel size
                mosaicData.RefMatrix(3, 2) = max(tileData.RefMatrices(:, 3, 2));

                mosaicXy = [max(tileData.lr(:, 1)) min(tileData.lr(:, 2))];
                [mosaicRowNb, mosaicColNb] = map2pix(mosaicData.RefMatrix, mosaicXy);
                 % previously sBig
                 % NB: map2pix is a deprecated function

                % 2.4. Metadata of Variables and initialization of the assembly matrix
                % mosaicDataForAllDays to type int and no data values
                %---------------------------------------------------------------------
                for varIdx=varIndexes
                    varNameInfosForVarIdx = availableVariables(varIdx, :);
                    varName = varNames{varIdx};
                    mosaicData.([varName '_type']) = ...
                        varNameInfosForVarIdx.type_in_mosaics{1};
                    mosaicData.([varName '_units']) = ...
                        varNameInfosForVarIdx.units_in_mosaics{1};
                    mosaicData.([varName '_multiplicator_for_mosaics']) = ...
                        varNameInfosForVarIdx.multiplicator_for_mosaics;
                    mosaicData.([varName '_divisor']) = varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_min']) = varNameInfosForVarIdx.min * ...
                        varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_max']) = varNameInfosForVarIdx.max * ...
                        varNameInfosForVarIdx.divisor;
                    mosaicData.([varName '_nodata_value']) = ...
                        varNameInfosForVarIdx.nodata_value;
                    mosaicDataForAllDays.(varName) = ...
                        mosaicData.([varName '_nodata_value']) * ...
                        ones(round([mosaicRowNb mosaicColNb 31]), ...
                            varNameInfosForVarIdx.type_in_mosaics{1});
                end

                % 2.5. Insert the tile data values at the right position in the mosaic
                % with replacement of NaN by nodata_value and cast to int type
                %---------------------------------------------------------------------
                for tileId = 1:length(tileRegionsArray)
                    [tileX, tileY] = pix2map(squeeze(tileData.RefMatrices(tileId, :, :)), ...
                        [1 tileData.sizes(tileId, 1)], ...
                        [1 tileData.sizes(tileId, 2)]);
                    [tileRow, tileCol] = map2pix(mosaicData.RefMatrix, tileX, tileY);
                    tileRow = round(tileRow);
                    tileCol = round(tileCol);

                    tileSTCFile = mosaicData.files{tileId, 2};
                    tileSTCData = matfile(tileSTCFile);
                    tileSTCFieldnames = fieldnames(tileSTCData);
                    for varIdx = varIndexes
                        varNameInfosForVarIdx = availableVariables(varIdx, :);
                        varName = varNames{varIdx};
                        if ~ismember(varName, tileSTCFieldnames)
                            warning('%s: Missing variable %s in interp STC file %s\n', ...
                                mfilename(), varName, tileSTCFile);
                            continue;
                        end
                        varSTCData = tileSTCData.(varName) * ...
                            mosaicData.([varName '_multiplicator_for_mosaics']);
                        varSTCData(isnan(varSTCData)) = ...
                            mosaicData.([varName '_nodata_value']);
                        mosaicDataForAllDays.(varName)(tileRow(1):tileRow(2), ...
                                tileCol(1):tileCol(2), ...
                                1:size(varSTCData, 3)) = ...
                            cast(varSTCData, varNameInfosForVarIdx.type_in_mosaics{1});
                    end
                end
                
                % 2.6. Thresholding
                %------------------
                thresholds = regions.thresholdsForMosaics;
                for thresholdId = 1:size(thresholds, 1)
                    thresholdedVarname = thresholds{thresholdId, 'thresholded_varname'}{1};
                    thresholdValue = thresholds{thresholdId, 'threshold_value'};
                    replacedVarname = thresholds{thresholdId, 'replaced_varname'}{1};
                    valueForUnreliableData = availableVariables{ ...
                        find(strcmp(availableVariables.output_name, replacedVarname)), ...
                        'value_for_unreliable'};

                    mosaicDataForAllDays.(replacedVarname) ...
			(mosaicDataForAllDays.(thresholdedVarname) ...
                        < thresholdValue) = valueForUnreliableData;
                    % SIER_151 viewable_snow_fraction_status
                    if strcmp(replacedVarname, 'viewable_snow_fraction')
                        mosaicDataForAllDays.viewable_snow_fraction_status ...
			                (mosaicDataForAllDays.(thresholdedVarname) ...
                            < thresholdValue & ...
                            mosaicDataForAllDays.viewable_snow_fraction_status == ...
                            Variables.dataStatus.observed) = Variables.dataStatus.lowValue;
                    end
                end
                
                % 2.7. Generate and write the daily Mosaic Files
                %-----------------------------------------------
                for dayIdx = 1:length(dayRange)
                    thisDatetime = dayRange(dayIdx);
                    mosaicFile = espEnv.MosaicFile(regions, thisDatetime);
                    mosaicData.dateval = datenum(thisDatetime) + 0.5;
                    for varIdx = varIndexes
                        varName = varNames{varIdx};
                        mosaicData.(varName) = ...
                            mosaicDataForAllDays.(varName)(:, :, dayIdx);                        
                    end
                    % NB: Because of a 'Transparency violation error.' occuring 
                    % with the upper-level
                    % parfor loop, it is required to save the mosaic files using
                    % another function (in our Tools package).
                    Tools.parforSaveFieldsOfStructInFile(mosaicFile, ...
                        mosaicData, 'new_file');
                    fprintf('%s: Saved mosaic data to %s\n', mfilename(), ...
                        mosaicFile);
                end
            end % end parfor
            t2 = toc;
            fprintf('%s: Finished mosaic generation and writing in %s seconds.\n', ...
                mfilename(), num2str(roundn(t2, -2)));
        end

        function runWriteFiles(obj, waterYearDate)
            % Generation and write the mosaic files for a water year
            % with variables in configurationOfVariables.
            %
            % Parameters
            % ----------
            % waterYearDate: waterYearDate object
            %   waterYearDate for which generating the mosaics.

            espEnv = obj.regions.espEnv;

            % List of Variables
            %------------------
            confOfVar = espEnv.configurationOfVariables();
            availableVariables = confOfVar(find(confOfVar.write_mosaics == 1), :);
            obj.writeFiles(waterYearDate, availableVariables);
        end

    	function Dt = getMostRecentMosaicDt(obj, waterYearDate)
    	    % Gets the datetime of the most recent mosaic file 
	    % in this water year, or NaT if no mosaic file is found

    	    Dt = NaT;
    	    dateRange = waterYearDate.getDailyDatetimeRange();
    	    for i=length(dateRange):-1:1
        	mosaicFilename = obj.regions.espEnv.MosaicFile( ...
                    obj.regions, dateRange(i));
        	if isfile(mosaicFilename)
        	    Dt = dateRange(i);
        	    break;
        	end
    	    end

    	end
    end
end 
