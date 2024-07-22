function out = saveVariableForSpiresSmooth20240204(idxInOutvars, outvars, outnames, outdtype, outdivisors, out, h5name, appendFlag, indicesToSave)
    tic;
    member=outnames{idxInOutvars};
    fprintf('Saving variable %d/%s...\n', idxInOutvars, member);
    %for idxInOutvars=1:length(outvars)
    
    Value=out.(outvars{idxInOutvars});
    Value = Value(:, :, indicesToSave);
    dS.(member).divisor=outdivisors(idxInOutvars);
    dS.(member).dataType=outdtype{idxInOutvars};
    dS.(member).maxVal=max(Value(:));
    dS.(member).FillValue=intmax(dS.(member).dataType);
    if ~strcmp(appendFlag, '-append') & isfile(h5name)
        delete(h5name);
    end
    writeh5stcubes20240227(h5name,dS,0,out.matdates,member,Value); % Seb 20240227. Remove hdr which doesn't mean something with cells.
    out.(outvars{idxInOutvars}) = [];
    fprintf('Saved variable %d in %f secs.\n', idxInOutvars, toc);
    %end
end
