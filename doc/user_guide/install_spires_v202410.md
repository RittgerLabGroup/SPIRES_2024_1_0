# Install

This page gives information about the install step of the project.

After cloning the code to your local repository, you need to configure environment variables and generate the netcdf templates.

## Requirements

### Hardware requirements.

The code makes a heavy use of parallelization, and store a number of big intermediary files, which makes the code is more appropriate to run on a supercomputer. But for testing, it's not impossible to run it partly on a personal laptop.

All tests before code delivery have been done on a supercomputer.

### Software requirements.

The code includes bash and matlab scripts.
Code tested on:
- Red Hat Enterprise Linux 8.10 with kernel Linux 4.18.0
- bash 4.4.20, with some commands installed such as bc, wget
- Slurm 23.02.8
- Matlab R2021b, nco/4.8.1 (https://nco.sourceforge.net/)

Many matlab scripts should work on a laptop (mac OC or windows 11), with some environment variables set. But that wasn't tested extensively.

More info on code and ancillary data organization [here](code_organization_spires_v202410.md).

## Install.

### Github.

1. Create a fork of the project https://github.com/RittgerLabGroup/SPIRES_2024_1_0.
2. Clone this fork locally (see https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).
3. Create a local copy of ParBal (https://github.com/edwardbair/ParBal).
4. Create a local copy of RasterReprojection (https://github.com/DozierJeff/RasterReprojection).
5. Create a local copy of SPIRES (https://github.com/edwardbair/SPIRES/). The code has been tested with the version of the 01/05/2024 https://github.com/edwardbair/SPIRES/tree/53bcc9cb8ad6cae2e20d848ff3db26867f05c2d4 and should also worked with the 2025 release https://github.com/edwardbair/SPIRES/releases/tag/v1.3.

### Initialize the environment file env/.matlabEnvironmentVariablesv202410.

Set up the variables in the `To edit to your configuration` part to your local configuration. This is where you can redefine paths to the code of this project and complementary matlab packages.

### Initialize the environment file .netrc.
Copy the file from home/ to your home. Then edit the file with your login / password for earthdata.

### Initialize the environment file .bashrc.
Copy or merge the file from home/ to your home or the .bashrc already present in your home.

You then need to edit the variables with your local values. Reach out to the developers of this project to help you for that task.

Beware of these specific variables:

- `$espLogDir`. This is location of all the logs of the project and has these obligatory requirements:
  - This location **must** be unique and accessible in read/write to all the users of the project for an institution/university. This is facilitated by the naming of a `$level3User` in the `~.bashrc`.
  - This location **must** be on the resource which has the highest probability to always stay connected to the slurm cluster. In CU configuration, I chose the resource `projects`.
  - The non respect of these requirements was cause of either an absence of logging or a loss of log files in the past.
  - These requirements are not necessary for a run on personal laptop without sollicitating access with shared folders.

- `$nrt3ModapsEosdisNasaGovToken`. This is a token personal to the linux user. You should edit the value of $nrt3ModapsEosdisNasaGovToken to the personal token you will retrieve from earthdata, https://urs.earthdata.nasa.gov/profile, generate Token (06/23/2025). This token is temporary and you'll receive regular alerts from earthdata to replace it.

### Generate the netcdf templates.

The code include .cdl files for each version of the netcdf to be produced. For each of them, a .nc template file should be generated, following instructions in [Output netcdf](output_netcdf_v202410.md).




<br><br><br>
