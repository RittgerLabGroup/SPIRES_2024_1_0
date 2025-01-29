function output_cubes = smoothDataCube20241105(cubes, weight, isToInterpolate, smoothingParams, thresholdOfFirstVariableToSetSecondToZero)
    % Function simplified from smoothDataCube, without truncateLimits, which can
    % create issues when we divide a modis tile in 36 subtiles, by truncating to
    % min value.
    %
    % Parameters
    % ----------
    % cubes: cells of 3D array with time in 3rd D. Can't handle more than 2 cells right now. We assume that the arrays are in integer, for mem efficiency. Seba 20241114.
    % wieght: interpolating weights.
    % isToInterpolate: land mask
    % smoothingParams: array of single: param for function fit for smoothing spline, for each cube.
    % thresholdOfFirstVariableToSetSecondToZero: int, ex 300. Only used for grain_size to set dust_concentration to 0.
    % 
    % Return
    % ------
    % output_cube: time interpolated data. for snow fraction, [ viewable_snow_fraction, snow_fraction].
    %     For grain size/dust, [ grain_size, dust, radiative_forcing, deltavis, albedo, albedo_muZ].
    
    %% reshape and transpose cube to put time sequence next to each other in memory
    % (MATLAB is column-major order)
    output_cubes = {};
    if length(cubes) > 2
        error('smoothDataCube20241105 cannot handle more than 2 cubes now.\n');
    end
    N = size(cubes{1});
    cube1 = reshape(cubes{1},N(1)*N(2),N(3))';
    if length(cubes) > 1
      cube2 = reshape(cubes{2},N(1)*N(2),N(3))'; % Seba
    end
    
    weight = reshape(weight,N(1)*N(2),N(3))';
    isToInterpolate = reshape(isToInterpolate, N(1)*N(2), 1)';
    % boundaries of the isToInterpolate
    fcol = find(isToInterpolate, 1, 'first');
    if isempty(fcol) % if the isToInterpolate is all false
        output_cube1 = reshape(cube1',N(1),N(2),N(3));
        output_cubes = {output_cube1}
        if length(cubes) > 1
          output_cubes{2} = reshape(cube2',N(1),N(2),N(3));
        end
        return
    end
    lcol = find(isToInterpolate,1,'last');
    iCube1 = cube1(:,fcol:lcol); % double(cube(:,fcol:lcol)); Seba 20241114.
    if length(cubes) > 1
      iCube2 = cube2(:,fcol:lcol);
    end
    weight = weight(:,fcol:lcol); % double(weight(:,fcol:lcol)); Seba 20241114.
    isToInterpolate = isToInterpolate(fcol:lcol);
    % limits = [nanmin(iCube(:)) nanmax(iCube(:))];

    % by column
    sCube1 = zeros(size(iCube1), class(iCube1));
    if length(cubes) > 1
      sCube2 = zeros(size(iCube2), class(iCube2));
    end
    weight(weight == intmax(class(weight)) | weight == 0) = 1; % make sure we have enough weights. Nb weights from 1 to 100 Seba 20241114.
    x = double(1:size(iCube1, 1))';
    if ~exist('thresholdOfFirstVariableToSetSecondToZero', 'var')
        thresholdOfFirstVariableToSetSecondToZero = 0;
    end
    parfor c = 1:size(sCube1, 2)
        if isToInterpolate(c)
            y = iCube1(:, c);
            if sum(y > 0 & y ~= intmax(class(y))) >= 2
                t = y == intmax(class(y));
                y = double(y);
                thisWeight = double(weight(:,c));
                
                F = fit(x, y, 'smoothingspline', weights = thisWeight, ...
                    exclude = t, SmoothingParam = smoothingParams(1));
                tmp = F(x);
                % As for STC, 20241107.
                % For any fitted values past the last date with a 
                % measured value, the spline can produce a large "bullwhip"
                % artifact
                % Find fitted values after the last date with a measured value
                % and propagate the last "believable" fitted value to end
                % This overwrites the spline "bullwhip"
                lastIdxWithObservation = find(t == 0, 1, 'last');
                tmp(lastIdxWithObservation:length(tmp)) = tmp(lastIdxWithObservation);
                sCube1(:,c) = cast(tmp, class(y)); % Seba 20241114 cast back from double to int.
                
                if length(cubes) > 1
                    y = iCube2(:, c);
                    if sum(y > 0 & y ~= intmax(class(y))) >= 2
                        % dust could be zero or nodata not at the same places as grain_size?
                        % Set dust (when y is dust after interpolation of grain size) to 0
                        % for low grain size.
                        if thresholdOfFirstVariableToSetSecondToZero > 0
                            y(sCube1(:,c) < thresholdOfFirstVariableToSetSecondToZero) = 0;
                        end
                        t = y == intmax(class(y));
                        y = double(y);
                        F = fit(x, y, 'smoothingspline', weights = thisWeight, ...
                            exclude = t, SmoothingParam = smoothingParams(2));
                        tmp = F(x);
                        % As for STC, 20241107.
                        % For any fitted values past the last date with a 
                        % measured value, the spline can produce a large "bullwhip"
                        % artifact
                        % Find fitted values after the last date with a measured value
                        % and propagate the last "believable" fitted value to end
                        % This overwrites the spline "bullwhip"
                        lastIdxWithObservation = find(t == 0, 1, 'last');
                        tmp(lastIdxWithObservation:length(tmp)) = tmp(lastIdxWithObservation);
                        sCube2(:,c) = cast(tmp, class(y)); % Seba 20241114 cast back from double to int.
                    end
                end
            end
        end
    end
    % back into original
    cube1(:,fcol:lcol) = sCube1;
    output_cubes = {};
    output_cubes{1} = reshape(cube1',N(1),N(2),N(3));
    if length(cubes) > 1
        cube2(:,fcol:lcol) = sCube2;
        output_cubes{2} = reshape(cube2',N(1),N(2),N(3));
    end
end
