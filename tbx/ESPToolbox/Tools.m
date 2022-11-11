classdef Tools
    % Provides tools, including for handling parallelism

    methods(Static)
        function parforSaveFieldsOfStructInFile(filename, myStruct, appendFlag)
            % Save fields of structure to bypass the Transparency violation error
            % that occurs by calls to save and eval in the parfor loop
            %
            % Parameters
            % ----------
            % filename: array(char)
            %   Filename where the data are saved.
            % myStruct: struct
            %   Struct with fields which values are to be saved
            % appendFlag: bool
            %   If true, the data are saved by append
            if strcmp(appendFlag, 'new_file')
                save(filename, '-struct', 'myStruct', '-v7.3');
            elseif strcmp(appendFlag, 'append')
                save(filename, '-struct', 'myStruct', '-append');
            end
        end
    end

end