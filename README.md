# Introduction.

This code generates snow properties by applying the SPIReS algorithm v2024.1.0, derived from the [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021) to the MOD09GA product (Vermotte and Wolfe, 2021).

The algorithm produces daily raster images of snow cover and snow surface properties. The algorithm unmix Snow cover, grain size and dust concentration from the daily reflectance of the MOD09GA Terra Collection 6 v061 (Vermote and Wolfe, 2021) using this adapted version of the SPIReS algorithm (Bair et al., 2021) that we named SPIReS v2024.1.0, with a removal of clouds and data errors. Then the data are temporally interpolated to fill the cloudy days, and the snow cover duration is calculated from the start of the water year (October 1st). Deltavis, radiative forcing, and albedos are calculated using an adaptation of the ParBal algorithm (Bair et al., 2018), that we included in SPIReS v2024.1.0.

For this purpose, the code first downloads the MOD09GA files for the western US region (modis tiles h08v04, h08v05, h09v04, h09v05, h10v04). Then, it carried out the different steps of the SPIReS algorithm v2024.1.0. The output files consist of netcdf files with values for snow variables per modis tile and day, and statistic files used by the [snow-today website](https://nsidc.org/snow-today/snow-viewer).

# Installation and code organization.

[Install and requirements](doc/user_guide/install_spires_v202410.md)
with [output netcdf specifities](doc/user_guide/output_netcdf_v202410.md)

[Code and ancillary data organization](doc/user_guide/code_organization_spires_v202410.md). This page also briefly presents the diversity of the code blocks and how each block interacts with another within the use of a HPC environment and [Slurm](https://slurm.schedmd.com/documentation.html).


# Run in historics or near real time.

[SPIReS v2024.1.0 Algorithm near-real time (NRT) run](doc/user_guide/spires_v202410_run_nrt_pipeline.md)

[SPIReS v2024.1.0 Algorithm historic (HIST) run](doc/user_guide/spires_v202410_run_historics.md)

[Checking logs and job result](doc/user_guide/checking_logs.md)

# Complementary documentation.

[Data file organization](doc/user_guide/data_organization_spires_v202410.md)



# References in alphabetic order.

- Bair, E. H., Abreu Calfa, A., Rittger, K., & Dozier, J. (2018). Using machine learning for real-time estimates of snow water equivalent in the watersheds of Afghanistan. The Cryosphere 12(5), 1579-1594, doi: 10.5194/tc-12-1579-2018. https://github.com/edwardbair/ParBal. 
- Bair, E. H., Rittger, K., Davis, R. E., Painter, T. H., & Dozier, J. (2016). Validating reconstruction of snow water equivalent in California\'s Sierra Nevada using measurements from the NASA Airborne Snow Observatory. Water Resources Research 52, doi: 10.1002/2016WR018704. 
- Bair, E.H., Stillinger, T., & Dozier, J. (2021). Snow Property Inversion from Remote Sensing (SPIReS): A generalized multispectral unmixing approach with examples from MODIS and Landsat 8 OLI. IEEE Transactions on Geoscience and Remote Sensing 59(9), 7270-7284, doi: 10.1109/TGRS.2020.3040328. https://github.com/edwardbair/SPIRES. 
- Palomaki, R. T., Rittger, K., Lenard, S. J. P., Bair, E. H., Dozier, J., Skiles, M., & Painter, T. H. (2025). Assessment for mapping snow albedo from MODIS. Remote Sensing of Environment 326, 114742, https://doi.org/10.1016/j.rse.2025.114742.
- Rittger, K., Bair, E.H., Kahl, A., & Dozier, J. (2016). Spatial estimates of snow water equivalent from reconstruction. Advances in Water Resources 94, 345-363, doi: 10.1016/j.advwatres.2016.05.015.
- Stillinger, T., Rittger, K., Raleigh, M.S., Michell, A., Davis, R.E., & Bair, E.H. (2023). Landsat, MODIS, and VIIRS snow cover mapping algorithm performance as validated by airborne lidar datasets. The Cryosphere 17, 567-590, doi: 10.5194/tc-17-567-2023.
- Vermote, E., & Wolfe, R. (2021). MODIS/Terra Surface Reflectance Daily L2G Global 1km and 500m SIN Grid V061. Distributed by NASA EOSDIS Land Processes Distributed Active Archive Center, doi: 10.5067/MODIS/MOD09GA.061.MODIS.
      








<br><br><br>
