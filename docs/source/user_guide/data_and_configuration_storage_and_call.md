# Data and parameter storage

This page develops the folder and file hierarchy used in ESP to store input, intermediary, and output data.

## Primary directories

ESP uses primary directories to store data and configuration:
- `archivePath`: Permanent archive of data. 
    - No direct use by the code, except for a few update scripts and several unit tests (ESPEnv, but @todo should be replaced). 
    - Unique for all users. 
    - Include data obtained with previous versions of the ESP code. 
    - Should not contain testing data, except in well labeled subfolders with possibly the date of the test indicated.
- `scratchPath`: Temporary location of data .
    - Used by the scripts for reading/writing during code execution.
    - 1 scratch per user. 
    - Optimized for data access by the code (compared to archive), data should not be stored for long-term here.
    - Before running a calculation script, .sh scripts sync a part of the input and configuration data from archive to scratch and after running, they sync back the output data from scratch to archive. This copy can be activated or deactivated (see the .sh scripts).
    - No sync is done when the destination file has a more recent modification date than source.
- `confDir`: Permanent archive of configuration parameters. 
    - Only small files there, typically tables of configuration parameters as region metadata, variable and filepath configuration. 
    - If a raster should be part of the configuration, this raster is rather stored in archive (see below).

NB: some older scripts use other directories, directly in the ESP code hierarchy, but we aim to replace these scripts to store all data and conf in the 3 directories above.

## Configuration parametering

ESP uses several types of configuration.

### Environment variables.

- USER (USERNAME in windows): mainly to determine the location of temporary files and logs.
- hostname: used in unit tests, mainly to prevent test run if not on RC. 
    - @todo: evolution on unit tests to remove this variable.
    
### Slurm sbatch options.

- `job-name`: char. The .sh scripts take this name to construct the log filename.
- `array`: int or int,int or int-int. For either 1 value, or 2, or a range of values.
    - for most of the scripts/*.sh, indicate wateryear or julian year.
    - for scripts/runSnowTodayStep0.sh and scripts/runSnowTodayStep1.sh, indicate `regionId`.
    - for a few scripts the option is not used.

When the .sh script is directly launched (i.e. not using sbatch), the options are not set. In that case, the .sh script can set a default value to this option (@todo not implemented for all .sh scripts).

### Bash script

#### Options

Most (but not all) .sh scripts have the options:
- `-L`: label version of the input and output data. E.g. `-L v2023.0`. Is included in the subfolders and filenames of the input and output files.
- `-A`: version of ancillary data (e.g. elevation, land mask). E.g. `-A v3.2`. Currently (2023-10-19), all ancillary data are version v3.2, except for the tiles of the region westernUS (h08v04, h08v05, h009v04, h09v05, h10v04) which are v3.1. The main difference between v3.1 and v3.2 is the source of elevation, and a possible slight offset in the position of the water mask. @todo: At some point in 2024, westernUS will transition to v3.2.
- `-i`: trigger sync from archive to scratch, for the files required by the .sh script.
- `-o`: trigger sync from scratch to archive, for the files produced by the .sh script.

NB: All these options allow to make some code modifications, or some tests without impacting the data reference archive. For instance `-L` allows to generate test files with a specific version label in the subfolders and filenames.

- `-n`: no pipeline. Used for the series of runSnowTodayStep0 to -4.sh scripts. If option absent, the .sh script will trigger the submission of the next step .sh script to slurm if the slurm job of the currently executing .sh script is successful. E.g. for runSnowTodayStep1.sh, trigger submission of runSnowTodayStep2.sh if the matlab code executing withing runSnowTodayStep2.sh is successful.
- `-t`: test. Used for runSnowTodayStep0.sh. If option absent, send an email to a emailing list at the end of runSnowTodayStep0.sh, otherwise only send the email to the user. NB: will be modified when developing ingestion of DAAC data @todo (2023-10-19).

- `-h`: help. don't run the matlab of the script, but rather displays doc how to call the .sh script and what's it use.

#### Arguments

TO FILL

### Matlab scripts configuration

#### Class constant properties

ESPEnv
MODISData
WaterYearDate

#### Metadata and parameter configuration files
Storage: 
- `confDir`, in .csv files.

Metadata associated to regions, subdivisions, variables, or parameters for the filepaths are stored in `confDir`

Configuration data are stored in:
- confDir: small size .csv files only.
    - NB: The .csv format was chosen because it was the simplest for the matlab code 2021b to import configuration data into matlab table objects; but a .sqlite database would have been cleaner.
    - List of files:
      - (would be nice to be automatically filled).
      - the biggest files are the files used to generate the land subdivisions and hierarchy for the website.

TO FILL        
  
 
### Raster and lookup table ancillary files

- archivePath/modis_ancillary/{versionOfAncillary}:

TO FILL

## Input data
All input data are stored in archive

TO FILL

## Intermediary data
All intermediary raw, gap and stc cube data are stored in archive

For the raw files, they are here: {archivePath}/modis/intermediary/mod09_raw_v2023.1/ (reflectance and a few other variables from mod09ga tiles) and {archivePath}/modis/intermediary/scagdrfs_raw_v2023.1/ (all the scag drfs variables). They are not the original files, but filtered from unrealistic values (e.g. snow fraction filtered between 0 and 100). The filters are in this file of the ESPEnv code: https://github.com/sebastien-lenard/esp/blob/master/tbx/ESPToolbox/readSCAGDRFSday.m

 

For the gap files, they are here:

{archivePath}/modis/intermediary/scagdrfs_gap_v2023.1/

for the different versions, you change _v2023.1 by _v2023.0, or _v03 or _v01

TO FILL

## Output data
All output data .mat and netcdf, geotiffs and statistic are stored in archive

TO FILL

Author: Sebastien Lenard
Date of modification: 2023/10/19
