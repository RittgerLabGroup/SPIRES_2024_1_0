# Generation of output NetCdfs

This page gives information about the ouput NetCdf templates and the generation of the output NetCdf files for the users.

## Introduction

Every day runSubmitter.sh script updates near real time snow today data and the netcdfs of the ongoing water year. The generation of NetCdfs is done with the script runESPNetCDF.sh and use Netcdf templates stored in tbx/templates. The NetCdfs are then automatically pushed on the operational archive and then (manually) pushed on onedrive.

The NetCdfs generated are Version 4, which use HDF5 storage format. They are not Version 4 Classic. They might be therefore not compatible with older software.

They are projected in the same MODIS sinusoidal projection as the input data, mod09ga. <https://modis-land.gsfc.nasa.gov/GCTP.html>. 

## Templates

For each version of Snow-Today algorithm (STC or SPIReS), a .cdl template is designed by supplying variables (e.g. snow_fraction) and their attributes (e.g. type, comment) as well as the general attributes of the file (e.g. authors). Then a NetCdf sample file (extension .nc) is generated from the .cdl. This .nc sample file is used by the class ESPNetCDF as a matrix to generate the NetCdfs.

A .cdl template can be generated from a .nc on a node of the supercomputer with nco library*:
```
ml nco/4.8.1;
originalNetCdfFilePath=${thisEspProjectDir}template/outputnetcdf.v03.nc # $thisEspProjectDir defined in env/.matlabEnvironmentVariablesSpiresV202410
cdlFilePath=${espScratchDir}outputnetcdf.v03.cdl
ncdump -hcs $originalNetCdfFilePath > $cdlFilePath
```

The .cdl template can be edited with any text editor to add variables or properties.

The .nc sample file is generated from the .cdl on a compute node with:
```
ml nco/4.8.1;
cdlFilePath=${thisEspProjectDir}template/outputnetcdf.v03.cdl
ncgen -o ${cdlFilePath/\.cdl/\.nc} -k 'netCDF-4' -x $cdlFilePath
```

Current available templates:
```
cdlFilePath=${espDevProjectDir}template/outputnetcdf.v2024.1.0.hist.cdl
  # Previously dubbed v2024.0d, Global mod09ga SPIReS (v1 (?) for NSIDC).
cdlFilePath=${espDevProjectDir}template/outputnetcdf.v2024.1.0.nrt.cdl
  # Same as above, for near real time data.
```

Templates are slightly different for near real time vs historic data (distinct DOI and dataset identifiers).

## Output data files

The metadata of the .nc output files can be checked on a compute node with:
```
ml nco/4.8.1;
ncFilePath=${espScratchDir}output/mod09ga.061/spires/v2025.0.1/netcdf/h07v03/2001/SPIRES_HIST_h07v03_MOD09GA061_20010101_V2.0.nc
ncks -M $ncFilePath # Print global metadata
ncks -m $ncFilePath # Print variable metadata
```


*More on nco library and the ncgen function:
<https://nco.sourceforge.net/nco.html>
<https://www.unidata.ucar.edu/software/netcdf/workshops/most-recent/utilities/Ncgen.html>
