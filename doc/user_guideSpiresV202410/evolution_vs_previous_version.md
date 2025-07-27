# Evolution of SPIReS v2024.1.0 compared to SPIReS v1.

This page presents the main evolutions implemented to the [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021).


## Context.

SPIReS v2024.1.0 generates near real-time and historical gap-filled snow properties and albedo. I was designed, developed, and tested from January 2024 to July 2024. Because of the unavailability of the MODSCAD-DRFS product at that time, and an updated version of the (snow-today viewer)[(https://nsidc.org/snow-today/snow-viewer)] has been planned to be launched the first semester of 2024, we decided to use the SPIReS algorithm instead and we implemented a quick and dirty version able to provide data and historical statistics. SPIReS v2024.1.0 provide a geotiff and csv plots output used by the web-app running the snow viewer, as well as NETCdF files that can be used by water resource forecast in their models or for other purposes by researchers.

We used SPIReS v2024.1.0 to ingest MOD09GA v6.1 reflectance data files, while the data originally produced by [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021) were calculated using MOD09GA v6.0.

The development of SPIReS v2024.1.0 was iterative, with 6 distinct milestones, with the most prominent being the version used at the launch of the website in April 2024, and the version launched in May 2024 to correct incorrect near-real time albedos in the melting season, and the version launched in July 2024 to make it possible to run at the start of the waterYear (October 1st for SPIReS v2024.1.0).

We tried to adapt SPIReS v2024.1.0 for new regions and new sensors during the Summer 2024, but the necessity to implement new techniques for cloud detection for VIIRS, and the necessary work and tests were too extensive given the quick, dirty, and unflexible implementation of SPIReS v2024.1.0, and we decided a full redesign of the code into SPIReS v2025.0.1.

## List of evolutions compared to SPIReS v1.

### Evolutions of the production chain.

1. Implementation of a configurable, near-real time production pipeline that doesn't need the full water year of data to run.
2. Implementation of a production chain to generate historical data.
3. Adaptation for runs on supercomputers using Slurm, with specific tuning for Alpine and Blanca clusters at CURC.
4. Automation of the production pipeline.
5. Automatic monitoring with resubmission in case of error, both for near real-time and for historicals.
6. Automation of the import of MOD09ga data, either on a real-time basis, or for a full water year.
7. Implementation of snow cover days, radiative forcing, deltavis and albedo calculations (using ParBal).
8. Formatting of output data in NETCdF files, available per day and modis tile.
10. Formatting of output data in geotiff covering big regions, available in near real-time for the web-app ingest.
11. Implementation of the calculation of SPIReS statistics and generation of json and csv output files. Json files can be ingested by the web-app ingest.
11. Implementation of a data manager, handling filepaths for the varied types of files through a centralized configuration.

### Algorithmic evolutions.

Some important implementations of SPIReS v1 have been kept:
1. The complex and time-consuming spectral unmixing calculations are not carried out during the run and we rather use a lookup table that help to find optimal solutions to the spectral unmixing problem.
2. We also use the clustering of pixels for calculations.
3. We also kept all the ancillary data supplied along with SPIReS v1, notably the background (~snow-free) reflectance data.
4. We kept a part of the core code of the detection of false positives and generation of gap-filled snow properties without modification (this is why the installation of [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021) is necessary to run the code).
5. There's still an elevation threshold, 500 m.a.s.l, below which pixels are considered snow-free.
6. All pixels having a snow fraction below 10% are considered snow-free.
6. We kept the pseudo-spatial weighing scheme to calculate grain size and dust concentrations for the pixels having insufficient snow.

Keeping in mind that, to our knowledge, the last version of [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021) is not adapted to near real-time [07/27/2025], we carried out these evolutions:
1. Adaptation of the run window, from a full water year down to a part of the water year (obligatory for near real-time).
2. The handling of the melting season is now flexible for the calculation of grain size and dust concentration: for an historical water year, we handle the peak of grain size (as in [original SPIReS code](https://github.com/edwardbair/SPIRES) (Bair et al., 2021)), but for the near real-time, this correction is paused.
3. We include 3 months of record for the calculations at the start of the water year (October for SPIReS v2024.1.0) to avoid temporal interpolation over a window of a few days.
