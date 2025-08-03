# Generation of output NetCDFs

This page gives information about the ouput NetCDF templates and the generation of the output NetCDF files for the users.

## Introduction

Every day [the NRT pipeline](run_nrt_pipeline.org) updates the near real-time (NRT) snow today data and the NetCDFs of the ongoing water year. The generation of NetCDFs is done at the step `daNetcdf` ([list of steps](run_nrt_pipeline.org#steps-and-scriptid)) and uses Netcdf templates stored in `template/`. The NetCDFs are then automatically pushed on the operational archive and then (manually) pushed on OneDrive.

The NetCDFs generated are Version 4, which uses the HDF5 storage format. They are not Version 4 Classic. They might therefore not be compatible with older software.

They are projected in the same MODIS sinusoidal projection as the input data, mod09ga. <https://modis-land.gsfc.nasa.gov/GCTP.html>. 

## Templates

For each version of the Snow-Today algorithm (STC or SPIReS), a .cdl template is designed by supplying variables (for example, snow_fraction) and their attributes (for example, type, comment) as well as the general attributes of the file (for example, authors). Then a NetCDF sample file (extension .nc) is generated from the .cdl. This .nc sample file is used by the class ESPNetCDF as a matrix to generate the NetCDFs.

A .cdl template can be generated from a .nc on a node of the supercomputer with the nco library*:
```bash
ml nco/4.8.1;
originalNetCdfFilePath=${thisEspProjectDir}template/outputnetcdf.v2024.1.0.nc # $thisEspProjectDir defined in env/.matlabEnvironmentVariablesSpiresV202410
cdlFilePath=${espScratchDir}outputnetcdf.v2024.1.0.cdl
ncdump -hcs $originalNetCdfFilePath > $cdlFilePath
```

The .cdl template can be edited with any text editor to add variables or properties.

The .nc sample file is generated from the .cdl on a compute node with:
```bash
ml nco/4.8.1;
cdlFilePath=${thisEspProjectDir}template/outputnetcdf.v2024.1.0.cdl
ncgen -o ${cdlFilePath/\.cdl/\.nc} -k 'netCDF-4' -x $cdlFilePath
```

Current available templates:
```bash
cdlFilePath=${espDevProjectDir}template/outputnetcdf.v2024.1.0.hist.cdl
  # Previously dubbed v2024.0d, Global mod09ga SPIReS (v1 (?) for NSIDC).
cdlFilePath=${espDevProjectDir}template/outputnetcdf.v2024.1.0.nrt.cdl
  # Same as above, for near real time data.
```

Templates are slightly different between near real-time and historicals (distinct DOI and dataset identifiers).

## Output data files

The metadata of the .nc output files can be checked on a compute node with:
```bash
ml nco/4.8.1;
ncFilePath=${espScratchDir}output/mod09ga.061/spires/v2024.1.0/netcdf/h07v03/2001/SPIRES_HIST_h07v03_MOD09GA061_20010101_V1.0.nc
ncks -M $ncFilePath # Print global metadata
ncks -m $ncFilePath # Print variable metadata
```


*More on the NCO library and the NCGen function:
<https://nco.sourceforge.net/nco.html>
<https://www.unidata.ucar.edu/software/netcdf/workshops/most-recent/utilities/Ncgen.html>
