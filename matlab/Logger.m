classdef Logger < handle
% NB: Beware, some methods only works on Linux.
    properties
        name  % char. Name of the script to be included at the start of each 
              % logged line.
        ticStart % start of internal clock for this object.
    end
    methods
        function obj = Logger(name)
            % Parameters
            % ----------
            % name: char. Name of the script or class (or anything else) to log.
            %
            % Return
            % ------
            % obj: Logger object.
            obj.name = name;
            obj.ticStart = tic;
        end
        function printDurationAndMemoryUse(obj, thisDbStack)
            % Parameters
            % ----------
            % thisDbStack: struct. dbstack Matlab giving info on execution context.
            [~, totalMemory] = ...
                system('free -g -t | grep Total | awk ''{print $2}''');
            totalMemory = str2double(totalMemory);
            [~, usedMemory] = ...
                system('free -g -t | grep Total | awk ''{print $3}''');
            usedMemory = str2double(usedMemory);
            memoryUse = 0;
            if ~isempty(totalMemory) && ~isempty(usedMemory)
                memoryUse = cast(usedMemory / totalMemory * 100, 'uint8');
            end
            lineNumber = 0;
            if ~isempty(thisDbStack)
                lineNumber = thisDbStack(1).line;
            end
            fprintf("%sT%s; %s; L.%d; %d; %d; Duration (s) and Memory use (%%).\n", ...
                datetime('now', 'Format','MMdd'), ...
                datetime('now', 'Format', 'HH:mm'), obj.name, lineNumber, ...
                cast(toc(obj.ticStart), 'uint16'), memoryUse);
            obj.ticStart = tic;
        end
    end
end