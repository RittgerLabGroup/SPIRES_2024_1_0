function thisPStart = pStart()
% Return
% ------
% Info to display at start of a fprintf line.
thisPStart = sprintf("%sT%s", char(datetime, 'MMdd'), char(datetime, 'HH:mm'));