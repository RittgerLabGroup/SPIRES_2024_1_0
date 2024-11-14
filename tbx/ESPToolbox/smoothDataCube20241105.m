function output_cube = smoothDataCube20241105(cube, weight, mask, SmoothingParam)
    % Function simplified from smoothDataCube, without truncateLimits, which can
    % create issues when we divide a modis tile in 36 subtiles, by truncating to
    % min value.
    %
    % Parameters
    % ----------
    % cube: 3D array with time in 3rd D
    % wieght: interpolating weights.
    % mask: water mask
    % SmoothingParam: single: param for function fit for smoothing spline.
    % 
    % Return
    % ------
    % output_cube: time interpolated data.
    N = size(cube);
    %% reshape and transpose cube to put time sequence next to each other in memory
    % (MATLAB is column-major order)
    cube = reshape(cube,N(1)*N(2),N(3))';
    weight = reshape(weight,N(1)*N(2),N(3))';
    mask = reshape(mask,N(1)*N(2),1)';
    % boundaries of the mask
    fcol = find(mask,1,'first');
    if isempty(fcol) % if the mask is all false
        output_cube = reshape(cube',N(1),N(2),N(3));
        return
    end
    lcol = find(mask,1,'last');
    iCube = double(cube(:,fcol:lcol));
    weight = double(weight(:,fcol:lcol));
    mask = mask(fcol:lcol);
    limits = [nanmin(iCube(:)) nanmax(iCube(:))];

    % by column
    sCube = zeros(size(iCube));
    weight(isnan(weight) | weight==0) = .01; % make sure we have enough weights
    x = (1:size(iCube,1))';
    parfor c = 1:size(sCube, 2)
        if mask(c)
            y = iCube(:, c);
            if sum(y > 0) >= 2
                t = isnan(y);
                F = fit(x, y, 'smoothingspline', weights = weight(:,c), ...
                    exclude = t, SmoothingParam = SmoothingParam);
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
                sCube(:,c) = tmp;
            end
        end
    end

    % back into original
    cube(:,fcol:lcol) = sCube;

    output_cube = reshape(cube',N(1),N(2),N(3));
end
