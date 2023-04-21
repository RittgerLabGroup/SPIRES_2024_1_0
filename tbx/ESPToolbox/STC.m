classdef STC < handle
    %STC - algorithms for spatially and temporally complete variables
    %   This class contains functions and thresholds to calculate
    %   STC variables (snow, albedo, etc)
    properties      % public properties
        % Various thresholds used in STC processing
        % (calling routine is indicated in parentheses)

        % allowable data ranges of values (rovs) for input (raw)
        % SCAGDRFS variables: [min max] range of values, 
        % any inputs outside these ranges are set to nodata in raw cubes
        % (readSCAGDRFSday, from mosaicTilesDATpad, from
        % mosaicSubsetSCAGDRFS)
        rawRovDV % units percent
        rawRovRF % units W/m2

        % allowable data ranges of values (rovs) for temporal
	    % interpolation of SCAGDRFS variables
        % [min max] range of values 
        % spline interpolation will be allowed to "ring" to these limits
        % (FillCubeDate)
        temporalRovDV % units percent
        temporalRovRF % units W/m2

        % minimum days available in the 3-month period
        % for temporal interpolation to be done on a pixel
        % (FillZero3, from Filter_SCAGDRFS)
        mindays

        % viewable snow fraction (0.0-1.0) below which GS is 
        % considered unreliable
        % these locations will be replaced with interpolated values
        % (used in Filter_SCAGDRFS and FillNaN3)
        sthreshForGS

        % viewable snow fraction (0.0-1.0) below which RF/DV 
        % are considered unreliable
        % these locations will be replaced with interpolated values
        % (used in Filter_SCAGDRFS and FillNaN3)
        sthreshForRF
    	
    	% 2-element array, North and South elevation gradient (m)
        % below which we filter spurious snow (assumed to be cloud)
        % (adjust_CloudFilter)
        zthresh

        % Canopy adjustment thresholds
    	% minSnowForVegAdjust - snow threshold (0.0 and 1.0)
    	%    below which we will not do a canopy adjustment, since that would
    	%    unrealistically increase snow
    	% canopyToTrunkRatio - ratio used limit fSCA to a maximum value in
    	%    heavily forested areas, typical ROV is 0.01 - 0.05
    	% minZForNonForestedAdjust - elevation (m) threshold above which
    	%    non-forested areas will be linearly increased
    	% nonForestedScaleFactor - fraction to use for linear interpolation
    	%    to bump Sgap and SgapV a little higher in non-forested locations
        % (Filter_SCAGDRFS)
        minZForNonForestedAdjust
        nonForestedScaleFactor
        minSnowForVegAdjust
        canopyToTrunkRatio

    end

    % properties(Constant)
    % end

    methods         % public methods

        function obj = STC(varargin)
            % Initializes thresholds to operational defaults

            p = inputParser;

            defaultRawRovDV = [ 0 50 ];
            addOptional(p, 'rawRovDV', defaultRawRovDV);

            defaultRawRovRF = [ 0 375 ];
            addOptional(p, 'rawRovRF', defaultRawRovRF);

            defaultTemporalRovDV = [ 0 70 ];
            addOptional(p, 'temporalRovDV', defaultTemporalRovDV);

            defaultTemporalRovRF = [ 0 500 ];
            addOptional(p, 'temporalRovRF', defaultTemporalRovRF);

            defaultMindays = 10;
            addOptional(p, 'mindays', defaultMindays);

            defaultSthreshForGS = 0.3;
            addOptional(p, 'sthreshForGS', defaultSthreshForGS);

            defaultSthreshForRF = 0.3;
            addOptional(p, 'sthreshForRF', defaultSthreshForRF);

            defaultZthresh = [ 800 800 ];
            addOptional(p, 'zthresh', defaultZthresh);

            defaultCanopyAdj = [ 800 0.08 0.07 0.08 ];
            addOptional(p, 'canopyAdj', defaultCanopyAdj);

            p.KeepUnmatched = false;
            parse(p, varargin{:});

            obj.set_rawRovDV(p.Results.rawRovDV);
            obj.set_rawRovRF(p.Results.rawRovRF);
            obj.set_temporalRovDV(p.Results.temporalRovDV);
            obj.set_temporalRovRF(p.Results.temporalRovRF);
            obj.set_mindays(p.Results.mindays);
    	    obj.set_sthresh(p.Results.sthreshForGS, p.Results.sthreshForRF);
            obj.set_zthresh(p.Results.zthresh);
            obj.set_canopyAdj(p.Results.canopyAdj);

        end

        function set_mindays(obj, mindays)

            % limit to 3 months
            checkMindays = @(x) 0 < x & x < 93;

            if checkMindays(mindays)
                obj.mindays = mindays;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: mindays should be < 3 months\n', mfilename());
                error(errorStruct);
            end

        end

        function set_sthresh(obj, forGS, forRF)

            checkFraction = @(x) isfloat(x) & 0.0 <= x & x <= 1.0;

            if checkFraction(forGS) && checkFraction(forRF)
                obj.sthreshForGS = forGS;
                obj.sthreshForRF = forRF;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: sthresh should be fraction\n', mfilename());
                error(errorStruct);
            end

        end

        function set_rawRovDV(obj, rov)

            % DeltaVis units percent
            checkRov = @(x) length(x) == 2 & ...
                all(0 <= x) & all(x <= 100);

            if checkRov(rov)
                obj.rawRovDV = rov;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: rawRovDV should have 2 items in [0 100]\n', ...
                    mfilename());
                error(errorStruct);
            end

        end

        function set_rawRovRF(obj, rov)

            % Radiative Forcing units W/m^2
            checkRov = @(x) length(x) == 2 & ...
                all(0 <= x) & all(x <= 500);

            if checkRov(rov)
                obj.rawRovRF = rov;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: rawRovRF should have 2 items in [0 500]\n', ...
                    mfilename());
                error(errorStruct);
            end

        end

        function set_temporalRovDV(obj, rov)

            % DeltaVis units percent
            checkRov = @(x) length(x) == 2 & ...
                all(0 <= x) & all(x <= 100);

            if checkRov(rov)
                obj.temporalRovDV = rov;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: temporalRovDV should have 2 items in [0 100]\n', ...
                    mfilename());
                error(errorStruct);
            end

        end

        function set_temporalRovRF(obj, rov)

            % Radiative Forcing units W/m^2
            checkRov = @(x) length(x) == 2 & ...
                all(0 <= x) & all(x <= 500);

            if checkRov(rov)
                obj.temporalRovRF = rov;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: temporalRovRF should have 2 items in [0 500]\n', ...
                    mfilename());
                error(errorStruct);
            end

        end

        function set_zthresh(obj, z)

            checkZthresh = @(x) length(x) == 2;

            if checkZthresh(z)
                obj.zthresh = z;
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: zthresh should have 2 items\n', mfilename());
                error(errorStruct);
            end

        end

        function set_canopyAdj(obj, canopyAdj)
            % [minZForNonForestedAdjust, nonForestedScaleFactor,
            %  minSnowForVegAdjust, canopyToTrunkRatio]

            checkFraction = @(x) isfloat(x) & 0.0 <= x & x <= 1.0;
            checkElevation = @(x) 0 <= x;

            checkCanopyAdj = @(x) length(x) == 4 ...
                & checkElevation(x(1)) ...
                & checkFraction(x(2)) ...
                & checkFraction(x(3)) ...
                & checkFraction(x(4));

            if checkCanopyAdj(canopyAdj)
                obj.minZForNonForestedAdjust = canopyAdj(1);
                obj.nonForestedScaleFactor = canopyAdj(2);
                obj.minSnowForVegAdjust = canopyAdj(3);
                obj.canopyToTrunkRatio = canopyAdj(4);
            else
                errorStruct.identifier = 'STC:IOError';
                errorStruct.message = sprintf(...
                    '%s: canopyAdj error\n', mfilename());
                error(errorStruct);
            end

        end

    end

end
