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
originalNetCdfFilePath=${espDevProjectDir}/tbx/template/outputnetcdf.v03.nc
cdlFilePath=${espScratchDir}outputnetcdf.v03.cdl
ncdump -hcs $originalNetCdfFilePath > $cdlFilePath
```

The .cdl template can be edited with any text editor to add variables or properties.

The .nc sample file is generated from the .cdl on a node of the supercomputer with:
```
ml nco/4.8.1;
cdlFilePath=${espDevProjectDir}/tbx/template/outputnetcdf.v03.cdl
ncgen -o ${cdlFilePath/\.cdl/\.nc} -k 'netCDF-4' -x $cdlFilePath
```

Current available templates:
```
cdlFilePath=${espDevProjectDir}tbx/template/outputnetcdf.v03.cdl
  # v03, also dubbed v2022.0 HMA mod09ga STC 2000-2022 (v1 for NSIDC).
cdlFilePath=${espDevProjectDir}tbx/template/outputnetcdf.v2023.0.1.cdl
  # v2023.0.1, which combines v2023.0 2000-2022 and v2023.0e 2022-2023 Global mod09ga STC (v1 for NSIDC).
cdlFilePath=${espDevProjectDir}tbx/template/outputnetcdf.v2024.1.0.cdl
  # Previously dubbed v2024.0d, Global mod09ga SPIReS (v1 (?) for NSIDC).
cdlFilePath=${espDevProjectDir}tbx/template/outputnetcdf.v2025.0.1.cdl
  # Previously dubbed v2024.0d, Global mod09ga SPIReS (v2 (?) for NSIDC).
```


*More on nco library and the ncgen function:
<https://nco.sourceforge.net/nco.html>
<https://www.unidata.ucar.edu/software/netcdf/workshops/most-recent/utilities/Ncgen.html>



Author: Sebastien Lenard

Date of modification: 2025/01/28
