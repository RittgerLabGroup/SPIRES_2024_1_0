function out = saveVariableForSpiresSmooth20240204(i, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag)
    tic;
    fprintf('Saving variable %d...\n', i);
    %for i=1:length(outvars)
    member=outnames{i};
    Value=out.(outvars{i});
    dS.(member).divisor=outdivisors(i);
    dS.(member).dataType=outdtype{i};
    dS.(member).maxVal=max(Value(:));
    dS.(member).FillValue=intmax(dS.(member).dataType);
    if ~strcmp(appendFlag, '-append') & isfile(h5name)
        delete(h5name);
    end
    writeh5stcubes20240227(h5name,dS,0,out.matdates,member,Value); % Seb 20240227. Remove hdr which doesn't mean something with cells.
    out.(outvars{i}) = [];
    fprintf('Saved variable %d in %f secs.\n', i, toc);
    %end
end
