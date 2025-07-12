# Requirements and install

This page gives information about the install step of the project. The software is provided "AS IS", without warranty of any kind.

After **forking** and cloning the code to your local repository, you need to configure environment variables and generate the netcdf templates locally.

[Got to install procedure](#install).

## Requirements

### User knowledge preferred requirements.

Based on feedback from early deployments, we kindly recommend that a new user gets familiar with these points.

#### Preamble.

Some pieces of advice for new users, who are kindly invited to refer to the rest of the documentation below and in other pages if necessary.

- Understand the platform the user will use.
- Understand how the user will monitor their job submissions and executions. The beginner user should always monitor the jobs they submit, not letting the job running without caring (because the user risks their access be removed in case of dysfunctionments and infinite loops).
- The user should get familiar enough with the documentation and understand where in the documentation the user will find the information you want to. But it's not necessary to read all the documentation before starting.
- Have a basic knowledge of linux, slurm.

#### Supercomputer resources.

**Login**. Create an account and login to the supercomputer. [For CU Boulder](https://curc.readthedocs.io/en/latest/getting_started/logging-in.html).

**Infrastructure and compute nodes**. Difference between visualization nodes, login nodes, compute nodes. [For CU Boulder](https://curc.readthedocs.io/en/latest/compute/node-types.html). How to start to use the compute nodes of the available slurm clusters without prior knowledge. For CU Boulder this project, we favored [cluster 2](https://curc.readthedocs.io/en/latest/clusters/blanca/blanca.html) and no full tests were achieved on [cluster 1](https://curc.readthedocs.io/en/latest/clusters/alpine/quick-start.html).

**Data spaces**. Different data spaces and file systems for distinct purposes: home, projects, scratch, archive. [For CU Boulder](https://curc.readthedocs.io/en/latest/compute/filesystems.html).

**File transfer**. Different way to transfer files. In this project, we favored the command `rsync` (details [here](run_nrt_pipeline.md#runrsync)), `wget`, and `sftp` transfer using or not Filezilla. More information [for CU Boulder](https://curc.readthedocs.io/en/latest/compute/data-transfer.html).

**Interactive sessions** The user can use interactive sessions through an internet browser rather than using a terminal. [For CU Boulder](https://curc.readthedocs.io/en/latest/open_ondemand/configuring_apps.html).

**User policies**. The user's access can be paused if the user does not respect them. [For CU Boulder](https://curc.readthedocs.io/en/latest/additional-resources/policies.html).

#### Bash/Linux knowledge.

Learning how to use these commands will help. We advice beginner users to regularly execute `pwd` to know where they are on the file system, since all scripts should be launched at the root of the local project directory.

*Files and reading*. `echo, ls, ls -las, cd, pwd, mkdir, mkdir -r, rm, rm -r, mv, touch, cat, head, tail, tail -f, tail -n 50, find -mtime -1, grep, grep -v`.

*Permissions*. `chmod, chgrp`.

*Networking*. `ssh, exit`.

*Additional commands*. `rsync, bc, wc, tr, du, alias, exit`

*Piping*. Helps log file investigation, by filtering using the symbol `|`. For instance: `tail -f my_log_file.out | grep "ERROR"`

#### Slurm knowledge.

Learning how to use these commands will help. More details in [CU Boulder RC](https://curc.readthedocs.io/en/latest/running-jobs/slurm-commands.html) and even more detailed in [Slurm doc](https://curc.readthedocs.io/en/latest/running-jobs/slurm-commands.html).

`ml slurm/XX, squeue, sacct, scontrol`.

*WARNING*. The command `scancel` also exist for emergencies. Understand that if the user cancels a job, some output files may be corrupted. Indeed, some file formats widely used in this project, such as `.mat` and `.nc`, allow (including for memory performance reasons) adding data to existing files, which in case of job killing during I/O risks to corrupt the files. The beginner user is advised to keep a copy of input files somewhere and delete any output files produced.

#### Git knowledge.

Learning how to use these commands (and other related to git/github system) helps.

`git status`, `git pull origin`.


### Hardware requirements.

The code makes a heavy use of parallelization, and store a number of big intermediary files, which makes the code is more appropriate to run on a supercomputer. But for testing, it's not impossible to run it partly on a personal laptop.

All tests before code delivery have been done on a supercomputer.

### Software requirements.

The code includes bash and matlab scripts.

Code tested on:
- Red Hat Enterprise Linux 8.10 with kernel Linux 4.18.0
- bash 4.4.20. Command:
```bash
bash --version
```
on a login node, returns `GNU bash, version 4.4.20(1)-release (x86_64-redhat-linux-gnu)`.
- with some commands installed such as bc, wget
- Slurm 24.11.5. Command:
```bash
ml slurm/$slurmName2
sinfo -V
```
on a login node, and also do it for `$slurmName1` (both variables point to slurm cluster names defined in the ~/.bashrc for this project,
returns `slurm 24.11.5`.
- Matlab R2021b. Command:
```bash
module avail
```
on a compute node,
returns include `matlab/R2021b`
- nco/4.8.1 (https://nco.sourceforge.net/). Command:
```bash
module avail
```
on a compute node,
returns include `matlab/R2021b`

Many matlab scripts should work on a laptop (mac OC or windows 11), with some environment variables set. But that wasn't tested extensively.

More info on code and ancillary data organization [here](code_organization.md).

## Install.

### Github.

1. Create a fork of the project https://github.com/RittgerLabGroup/SPIRES_2024_1_0.
2. Clone this fork locally (see https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).
3. Create a local copy of ParBal (https://github.com/edwardbair/ParBal).
4. Create a local copy of RasterReprojection (https://github.com/DozierJeff/RasterReprojection).
5. Create a local copy of SPIRES (https://github.com/edwardbair/SPIRES/). The code has been tested with the version of the 01/05/2024 https://github.com/edwardbair/SPIRES/tree/53bcc9cb8ad6cae2e20d848ff3db26867f05c2d4 and should also worked with the 2025 release https://github.com/edwardbair/SPIRES/releases/tag/v1.3.

### Initialize the environment file env/.matlabEnvironmentVariablesSpiresV202410.

Set up the variables in the `To edit to your configuration` part to your local configuration. This is where you can redefine paths to the code of this project (`$thisEspProjectDir`) and complementary matlab packages. 

A user should edit their `env/.matlabEnvironmentVariablesSpiresV202410` configuration file to make sure the paths for the SPIReS v2024.1.0, ParBal, RasterReprojection, and Edward Bair SPIReS version codes correspond to the paths on their project space (.bashrc environment variable `${projectDir}`).

### Initialize the environment file .netrc.
Copy the file .netrc from home/ to your home. Then edit the file with your login / password for earthdata.

### Initialize the environment file .bashrc.
Copy or merge the file .bashrc from home/ to your home or the .bashrc already present in your home.

You then need to edit the variables with your local values. Reach out to the developers of this project to help you for that task.

Beware of these specific variables:

- `$espLogDir`. This is location of all the logs of the project and has these obligatory requirements:
  - This location **must** be unique and accessible in read/write to all the users of the project for an institution/university. This is facilitated by the naming of a `$level3User` in the `~/.bashrc`.
  - This location **must** be on the resource which has the highest probability to always stay connected to the slurm cluster. In CU configuration, I chose the resource `projects`.
  - The non respect of these requirements was cause of either an absence of logging or a loss of log files in the past.
  - These requirements are not necessary for a run on personal laptop without sollicitating access with shared folders.

- `$nrt3ModapsEosdisNasaGovToken`. This is a token personal to the linux user. You should edit the value of $nrt3ModapsEosdisNasaGovToken to the personal token you will retrieve from earthdata, https://urs.earthdata.nasa.gov/profile, generate Token (06/23/2025). This token is temporary and you'll receive regular alerts from earthdata to replace it.

WARNING: The files in `env/` and `home/` are the only ones which should be edited for install. It is not recommended to edit other files, except for advanced use, outside of data production and release.

### Generate the netcdf templates.

The code include .cdl files for each version of the netcdf to be produced. For each of them, a .nc template file should be generated, following instructions in [Output netcdf](output_netcdf.md).


### Configure user's group and the scratch and archive folders.

**User group**. A user can operate for near real time and/or for historics.
If near real time and/or historics, the user should be part of the group of the user defined as `$level3User` in `~/.bashrc`.
If historics, the user should also be part of the group of the PI user owning the archive spaces.

For both case, the user should add user `$level3User` to their group.

**Archive space**. Archive space is only used for **permanent** storage. Details [here](run_nrt_pipeline.md#data-spaces-and-file-synchronization).

A user can operate for near real time and/or for historics.
If near real time only, the user should ask the PI owner of the archive data spaces to request adding the user to `$espArchiveDirOps` (variable defined in `~/.bashrc`).
If historics, the user should ask the PI owner of the archive to request adding the user to `$espArchiveDirOps` + `espArchiveDirNrt` (currently the storage for historics), both variables defined in `~/.bashrc`.

**Scratch space**. Scratch space is used for **intermediary** or **temporary** storage, variable `$espScratchDir` in `~/.bashrc`. Files there are automatically erased [after a certain time](run_nrt_pipeline.md#data-spaces-and-file-synchronization).

The user should create the following folders, having the group of the user `$level3User`, and with rights rwxrwsr-x:
- espJobs
- modis
- mod09ga.061
- modis_ancillary
- output

### Ancillary data.

Ancillary data, such as water masks, elevation files and lookup tables, are necessary for the code to run, but are not part of the repository.

The primary source of ancillary data is stored in `${espArchiveDirNrt}` (defined in `~/.bashrc`). A list of ancillary data and their relative paths is [here](#ancillary-data-files).

## Appendices.

### Ancillary data files.

List of the relative paths to ancillary data files as indicated in `conf/configuration_of_filepathsSpiresV202410.csv` [2025/07/10]:

| dataLabel | Description | Paths | Use in steps | Comment |
|---|---|---|---|---|
| aspectned | Aspect for albedo calculation | `modis/input_spires_from_Ned_202311/Inputs/MODIS/aspect/${regionName}_aspect_ned202311.mat` | spiSmooC | Path hard-coded |
|---|---|---|---|---|
| backgroundreflectanceformodisned | Background reflectance R0 | `modis/input_spires_from_Ned_202311/Inputs/MODIS/lut_modis_b1to7_3um_dust_2023.mat` | spiFillC | Path hard-coded |
|---|---|---|---|---|
| canopycover | Canopy cover (percent) | `modis/input_spires_from_Ned_202311/Inputs/MODIS/cc/cc_${regionName}.mat` | spiSmooC | Path hard-coded |
|---|---|---|---|---|
| cloudsnowneuralnetwork | Description | `modis/input_spires_from_Ned_202311/Inputs/MODIS/cloudsnowneuralnetwork/net.mat` | spiFillC | Path hard-coded |
|---|---|---|---|---|
| elevationned | Elevation (m) used as minimal elevation for snow | `modis/input_spires_from_Ned_202311/Inputs/MODIS/elevation/${regionName}_elevation_ned202311.mat` | spiSmooC, moSpires, scdInCub, daStatis | Path hard-coded in spiSmooC |
|---|---|---|---|---|
|
| icened | Description | `modis/input_spires_from_Ned_202311/Inputs/MODIS/ice/${regionName}.mat` | spiSmooC | Path hard-coded |
|---|---|---|---|---|
| slopened | Slope for albedo calculation | `modis/input_spires_from_Ned_202311/Inputs/MODIS/slope/${regionName}_slope_ned202311.mat` | spiSmooC | Path hard-coded |
|---|---|---|---|---|
| spiresmodelformodisned | Spectral unmixing lookup table for MODIS input, algorithm SPIReS, used to calculate snow fraction, grain size and dust concentration | `modis/input_spires_from_Ned_202311/Sierra/ExampleData/lut_modis_b1to7_3um_dust.mat` | spiFillC | Path hard-coded |
|---|---|---|---|---|
| waterned | Water mask, no snow in water | `modis/input_spires_from_Ned_202311/Inputs/MODIS/watermask/${regionName}watermask.mat` | spiFillC, spiSmooC | Path hard-coded |
|---|---|---|---|---|

where `${regionName}` is the name of the region or tile associated to the ancillary data file, for instance h08v04, if the ancillary data is different for each region. A definition and list of steps of the data nrt and historic production chains is [here](run_nrt_pipeline.md#preamble-and-vocabulary) and [here](run_nrt_pipeline.md#steps-and-scriptid).

For SPIReS v2024.1.0, all these files were calculated by Ned Bair and downloaded following indications in the original [SPIReS repository](https://github.com/edwardbair/SPIRES?tab=readme-ov-file) from [this source](https://snow.ucsb.edu/products/SPIRES/MODIS/Inputs/MODIS/), [this source](https://snow.ucsb.edu/products/SPIRES/MODIS/Sierra/ExampleData/) and [this source] by Timbo Stillinger (https://github.com/edwardbair/SPIRES/blob/master/MccM/).

<br><br><br>
