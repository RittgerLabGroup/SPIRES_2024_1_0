function writeh5stcubes20240227(filename,dStruct,hdr,matdate,member,Value)
% write out spacetime h5 cubes for each endmemeber,
% based on Jeff Dozier's cube2file
% %input:
%filename - filename to write out, .h5 or .mat
% dStruct - struct w/ fields:
%   divisor - to convert  using offset + value/divisor
%   dataType - numeric type, e.g. 'uint16', 'int16', 'uint8', or 'int8'
%   maxVal - maximum value
%   FillValue (optional) - null value, scalar
%   units (optional) - units for Value, string
% hdr - header w/ geographic info, see GetCoordinateInfo % Seb20240227 not used because dont have for cells which split tiles.
% matdate - MATLAB datenums
% member - member name, string i.e. 'fsca', 'grainradius', or 'dust'
% Value - values of endmemeber

persistent already

if exist(filename,'file')==0
    % X.(member)=[];
    data = [];
    already=[];
end

% convert to scaled integer
D = dStruct;

if ismember(class(Value), {'single', 'double'})
    data = float2integer(Value,D.(member).divisor,0,...
        D.(member).dataType,0,D.(member).maxVal);
    if isfield(D.(member),'FillValue')
        if D.(member).FillValue~=0
            data(isnan(Value)) = D.(member).FillValue;
        end
    end
elseif strcmp(class(Value), 'logical')
    data = uint8(Value);
else
    data = Value;
end

% .h5 file

group = '/Grid/MODIS_GRID_500m'; % MODSCAG data at 500 m resolution
arraySize = size(Value);
% Case Start of the waterYear. 20241001. Seba
if numel(arraySize) == 2
    arraySize(3) = 1;
end
chunkSize = [arraySize(1) arraySize(2) 1];
deflateLevel = 9;
% write data to file
try
    h5info(filename, [group '/' member]);
catch
    % only create dataset if non existent.
    if isfield(D.(member),'FillValue')
        h5create(filename,[group '/' member],arraySize,...
            'Deflate',deflateLevel,...
            'ChunkSize',chunkSize,...
            'DataType',D.(member).dataType,...
            'FillValue',D.(member).FillValue)
    else
        h5create(filename,[group '/' member],arraySize,...
            'Deflate',deflateLevel,...
            'ChunkSize',chunkSize,...
            'DataType',D.(member).dataType)
    end
end
h5write(filename,[group '/' member], data)
h5writeatt(filename,[group '/' member],'divisor',D.(member).divisor)
if isfield(D.(member),'units')
    h5writeatt(filename,[group '/' member],'units',D.(member).units)
end

% initial values
if isempty(already)
    already = true;
    % referencing matrix and projection information
    % h5writeProjection(filename,'/Grid',hdr.ProjectionStructure) Seb 20240227. These values are now incorrect because of the split of tiles into cells.
    % h5writeatt(filename,group,'ReferencingMatrix',hdr.RefMatrix) Seb 20240227. These values are now incorrect because of the split of tiles into cells.
    % write dates
    ISOdates = datenum2iso(matdate,7);
    MATLABdates = matdate;
    h5writeatt(filename,'/','MATLABdates',MATLABdates);
    h5writeatt(filename,'/','ISOdates',ISOdates);
end
end