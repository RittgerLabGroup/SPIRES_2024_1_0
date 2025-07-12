# Requirements and installation.

This page gives information about the install step of the project. The software is provided "AS IS", without warranty of any kind.

After **forking** and cloning the code to your local repository, you need to configure environment variables and generate the NetCDF templates locally.

**WARNING**: We kindly recommend users to think twice before editing configuration outside of the editing described below and strictly necessary to install the code. Some additional editing, not described here, is necessary in the `~/.bashrc` file for users outside CU, who are advised to consult the project members. As the documentation hints to a bit everywhere, the code makes a substantial use of configuration files (list [here](code_organization.md#list-of-configuration-files)), with hundreds of configuration variables. We designed it that way to make the code highly flexible, and ease the development of new versions.

[Got to installation procedure](#install).

## Requirements

### User knowledge preferred requirements.

Based on feedback from early deployments, we kindly recommend that a new user get familiar with these points.

#### Preamble.

Some pieces of advice for new users, who are kindly invited to refer to the rest of the documentation below and on other pages if necessary.

- Understand the platform the user will use.
- Understand how the user will monitor their job submissions and executions. The beginner user should always monitor the jobs they submit, not letting the job run without caring (because the user risks their access being removed in case of dysfunctions and infinite loops).
- The user should get familiar enough with the documentation and understand where in the documentation the user will find the information you want to. But it's not necessary to read all the documentation before starting.
- Have a basic knowledge of Linux and Slurm.

#### Supercomputer resources.

**Login**. Create an account and log in to the supercomputer. [For CU Boulder](https://curc.readthedocs.io/en/latest/getting_started/logging-in.html).

**Infrastructure and compute nodes**. Difference between visualization nodes, login nodes, and compute nodes. [For CU Boulder](https://curc.readthedocs.io/en/latest/compute/node-types.html). How to start to use the compute nodes of the available Slurm clusters without prior knowledge. For CU Boulder, we favored [cluster 2](https://curc.readthedocs.io/en/latest/clusters/blanca/blanca.html) and no full tests were achieved on [cluster 1](https://curc.readthedocs.io/en/latest/clusters/alpine/quick-start.html).

**Data spaces**. Different data spaces and file systems for distinct purposes: home, projects, scratch, and archive. [For CU Boulder](https://curc.readthedocs.io/en/latest/compute/filesystems.html).

**File transfer**. Different ways to transfer files. In this project, we favored the command `rsync` (details [here](run_nrt_pipeline.md#runrsync)), `wget`, and `sftp` transfer using or not using Filezilla. More information [for CU Boulder](https://curc.readthedocs.io/en/latest/compute/data-transfer.html).

**Interactive sessions** The user can use interactive sessions through an internet browser rather than using a terminal. [For CU Boulder](https://curc.readthedocs.io/en/latest/open_ondemand/configuring_apps.html).

**User policies**. The user's access can be paused if the user does not respect them. [For CU Boulder](https://curc.readthedocs.io/en/latest/additional-resources/policies.html).

#### Bash/Linux knowledge.

Learning how to use these commands will help. We advise beginner users to regularly execute `pwd` to know where they are in the file system, since all scripts should be launched at the root of the local project directory.

*Files and reading*. `echo, ls, ls -las, cd, pwd, mkdir, mkdir -r, rm, rm -r, mv, touch, cat, head, tail, tail -f, tail -n 50, find -mtime -1, grep, grep -v`.

*Permissions*. `chmod, chgrp`.

*Networking*. `ssh, exit`.

*Additional commands*. `rsync, bc, wc, tr, du, alias, exit`

*Piping*. Helps log file investigation by filtering using the symbol `|`. For instance: `tail -f my_log_file.out | grep "ERROR"`

#### Slurm knowledge.

Learning how to use these commands will help. More details in [CU Boulder RC](https://curc.readthedocs.io/en/latest/running-jobs/slurm-commands.html) and even more detailed in [the Slurm doc](https://curc.readthedocs.io/en/latest/running-jobs/slurm-commands.html).

`ml slurm/XX, squeue, sacct, scontrol`.

*WARNING*. The command `scancel` also exists for emergencies. Understand that if the user cancels a job, some output files may be corrupted. Indeed, some file formats widely used in this project, such as `.mat` and `.nc`, allow (including for memory performance reasons) adding data to existing files, which in the case of job killing during I/O risks corrupting the files. The beginner user is advised to keep a copy of input files somewhere and delete any output files produced.

#### Git knowledge.

Learning how to use these commands (and others related to the Git/GitHub system) helps.

`git status`, `git pull origin`.


### Hardware requirements.

The code makes heavy use of parallelization and stores a number of big intermediary files, which makes the code more appropriate to run on a supercomputer. But for testing, it's not impossible to run it partly on a personal laptop.

All tests before code delivery have been done on a supercomputer.

### Software requirements.

The code includes Bash and MATLAB scripts.

Code tested on:
- Red Hat Enterprise Linux 8.10 with kernel Linux 4.18.0
- bash 4.4.20. Command:
```bash
bash --version
```
on a login node, returns `GNU bash, version 4.4.20(1)-release (x86_64-redhat-linux-gnu)`.
- with some commands installed, such as bc and wget
- Slurm 24.11.5. Command:
```bash
ml slurm/$slurmName2
sinfo -V
```
on a login node, and also do it for `$slurmName1` (both variables point to Slurm cluster names defined in the ~/.bashrc for this project).
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

Many MATLAB scripts should work on a laptop (Mac OS or Windows 11), with some environment variables set. But that wasn't tested extensively.

More info on code organization [here](code_organization.md).

## Install.

### Github.

For SPIReS v2024.1.0, the remote repository is https://github.com/RittgerLabGroup/SPIRES_2024_1_0.

1. Create a fork of the project of the remote repository.
2. Clone this fork locally (see https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository).
3. Create a local copy of ParBal (https://github.com/edwardbair/ParBal).
4. Create a local copy of RasterReprojection (https://github.com/DozierJeff/RasterReprojection).
5. Create a local copy of the original SPIReS (https://github.com/edwardbair/SPIRES/). The code has been tested with the version of 01/05/2024 https://github.com/edwardbair/SPIRES/tree/53bcc9cb8ad6cae2e20d848ff3db26867f05c2d4 and should also work with the 2025 release https://github.com/edwardbair/SPIRES/releases/tag/v1.3.

For the rest of the installation, the user should go to the root of the user's local repository (using `cd $whateverThisLocalRepositoryIs`, the user replacing $whateverThisLocalRepositoryIs by the path they decided).

### Initialize the environment file matlabEnvironmentVariables.

For SPIReS v2024.1.0, *matlabEnvironmentVariables* is the file `env/.matlabEnvironmentVariablesSpiresV202410`.

Set up the variables in the `To edit to your configuration` part to your local configuration. This is where you can redefine paths to the code of this project (`$thisEspProjectDir`) and complementary MATLAB packages. 

A user should edit their *matlabEnvironmentVariables* configuration file to make sure the paths for the SPIReS v2024.1.0, ParBal, RasterReprojection, and Edward Bair SPIReS version codes correspond to the paths on their project space (.bashrc environment variable `${projectDir}`).

### Initialize the environment file .netrc.
Copy the file .netrc from home/ to the user's home.
```bash
cp home/.netrc ~/.netrc
```
Then the user should edit the file with the user's login/password for Earthdata.

### Initialize the environment file .bashrc.

For the CU Boulder users, a dedicated version of the .bashrc is available [here](https://github.com/RittgerLabGroup/documentation-esp-specific-CU-Boulder/blob/main/.bashrc), this is that version the user should copy and not the version `home/.bashrc`.

If the user is a new user of the supercomputer, the user copies the file `home/.bashrc` to the user's home directory on Linux:
```bash
cp home/.bashrc ~/.bashrc
```
If the user already has a `~/.bashrc`, the user should merge the files manually, with care.

You then need to edit the variables with your local values. Reach out to the developers of this project to help you with that task.

Beware of these specific variables:

- `espLogDir`. This is the location of all the logs of the project and has these obligatory requirements:
  - This location **must** be unique and accessible in read/write to all the users of the project for an institution/university. This is facilitated by the naming of a `$level3User` in the *.bashrc* ([Levels of IT Support](checking_log.md#levels-of-it-support)).
  - This location **must** be on the resource that has the highest probability of always staying connected to the Slurm cluster. In CU configuration, I chose the resource `projects`.
  - The non-respect of these requirements was the cause of either an absence of logging or a loss of log files in the past.
  - These requirements are not necessary for a run on a personal laptop without requesting access to shared folders.

- `nrt3ModapsEosdisNasaGovToken`. This is a personal token personal for the linux user. You should edit the value of $nrt3ModapsEosdisNasaGovToken to the personal token you will retrieve from Earthdata, https://urs.earthdata.nasa.gov/profile, generate Token (06/23/2025). This token is temporary, and you'll receive regular alerts from Earthdata to replace it.

- `espWebExportSshKeyFilePath`. This is the path to the user's private ssh key (see generation procedure [below](#generate-a-ssh-key)) and, except cases described in the procedure, does not need to be edited.

WARNING: The files in `env/` and `home/` are the only ones that should be edited for install. It is not recommended to edit other files, except for advanced use, outside of data production and release.

### Generate a SSH key.

This is currently required only for users running the [NRT pipeline](run_nrt_pipeline.md), which exports output data to the remote server of the web-app running the Snow-Today website.

If the user already has this file and that it is not protected with passphrase, the user can skip the creation part and goes to the "Append the key to the remote server".

The user used to log in to this remote server is 

**Create the SSH rsa key:**

*Commands*:
```bash
cd ~
ssh-keygen -t rsa
```
The commands asks you the file path where the user wants to save it and if they want a passphrase. We do not recommend a passphrase :

*Output*:
```
Generating public/private rsa key pair.
Enter file in which to save the key (~/.ssh/id_rsa_nusnow):
```
```bash
~/.ssh/id_rsa_nusnow
```
```
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```
```
Your identification has been saved in ~/.ssh/id_rsa_nusnow.
Your public key has been saved in ~/.ssh/id_rsa_nusnow.pub.
The key fingerprint is:
SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx ${espWebExportUser}@mycolorado.edu
The key's randomart image is:
+---[RSA 2048]----+
|.  oo*%=+o..     |
|.++.oX+=. .      |
|..+ooo=. .       |
|   E.+. .o.      |
|    +   S..+     |
|     . +. =      |
|      o  = o     |
|      .o+ +      |
|       +o.       |
+----[SHA256]-----+
```
The command creates both a private (stored locally) and a public key.

**Append the key to the remote server**. The user appends the public key to the remote server `.ssh/authorized_key` file:

*Command*:
```bash
ssh-copy-id -i /.ssh/id_rsa_nusnow.pub ${espWebExportUser}@${espWebExportDomain}
```
Both the `espWebExportUser` and `espWebExportDomain` are defined in the *bashrc*.

The command asks the user to continue connecting, the user replies yes and then enter the user's password to the remote server.

*Output*:
```
/usr/bin/ssh-copy-id: INFO: Source of key(s) to be installed: "~/.ssh/id_rsa_nusnow.pub"
The authenticity of host '10.176.18.15 (10.176.18.15)' can't be established.
ECDSA key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.

Are you sure you want to continue connecting (yes/no)? 
```
```bash
yes
```
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
${espWebExportUser}@${espWebExportDomain}'s password:
```
```bash
password
```
```
Number of key(s) added: 1

Now try logging into the machine, with:   "ssh '$${espWebExportUser}@${espWebExportDomain}'"
and check to make sure that only the key(s) you wanted were added.
```

**Check**. Then, the user logs in to the server to check if the key has been correctly copied:
```bash
ssh ${espWebExportUser}@${espWebExportDomain}
```
If the server does not prompt a password, the procedure is achieved.


### Generate the NetCDF templates.

The code includes .cdl files for each version of the NetCDF to be produced. For each of them, a .nc template file should be generated, following instructions in [Output NetCDF](output_netcdf.md).


### Configure the user's group and the scratch and archive folders.

**User group**. A user can operate for near real time and/or for historicals.
If near real time and/or historicals, the user should be part of the group of the user defined as `$level3User` in *.bashrc*.
If historicals, the user should also be part of the group of the PI user owning the archive spaces.

For both cases, the user should add user `$level3User` to their group.

**Archive space**. Archive space is only used for **permanent** storage. Details [here](run_nrt_pipeline.md#data-spaces-and-file-synchronization).

A user can operate for near real time and/or for historicals.
If near real time only, the user should ask the PI owner of the archive data spaces to request adding the user to `$espArchiveDirOps` (variable defined in *.bashrc*).
If historicals, the user should ask the PI owner of the archive to request adding the user to `$espArchiveDirOps` + `espArchiveDirNrt` (currently the storage for historicals), both variables defined in *.bashrc*.

**Scratch space**. Scratch space is used for **intermediary** or **temporary** storage, variable `$espScratchDir` in *.bashrc*. Files there are automatically erased [after a certain time](run_nrt_pipeline.md#data-spaces-and-file-synchronization).

The user should create the following folders, having the group of the user `$level3User`, and with rights rwxrwsr-x:
- `espJobs`
- `modis`
- `mod09ga.061`
- `modis_ancillary`
- `output`

### Ancillary data.

Ancillary data, such as water masks, elevation files, and lookup tables, are necessary for the code to run but are not part of the repository.

The primary source of ancillary data is stored in `${espArchiveDirNrt}` (defined in *.bashrc*). A list of ancillary data and their relative paths is [here](#ancillary-data-files).

## Appendices.

### Ancillary data files.

For SPIReS v2024.1.0, we set the list of the relative paths to ancillary data files [in this file](conf/configuration_of_filepathsSpiresV202410.csv) [2025/07/10].

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
| spiresmodelformodisned | Spectral unmixing lookup table for MODIS input, algorithm SPIReS, used to calculate snow fraction, grain size, and dust concentration | `modis/input_spires_from_Ned_202311/Sierra/ExampleData/lut_modis_b1to7_3um_dust.mat` | spiFillC | Path hard-coded |
|---|---|---|---|---|
| waterned | Water mask, no snow in water | `modis/input_spires_from_Ned_202311/Inputs/MODIS/watermask/${regionName}watermask.mat` | spiFillC, spiSmooC | Path hard-coded |
|---|---|---|---|---|

where:
- `${regionName}` is the name of the region or tile associated with the ancillary data file, for instance, h08v04, if the ancillary data is different for each region.
A definition and list of steps of the data nrt and historic production chains is [here](run_nrt_pipeline.md#preamble-and-vocabulary) and [here](run_nrt_pipeline.md#steps-and-scriptid).

For SPIReS v2024.1.0, all these files were calculated by Ned Bair and downloaded following indications in the original [SPIReS repository](https://github.com/edwardbair/SPIRES?tab=readme-ov-file) from [this source](https://snow.ucsb.edu/products/SPIRES/MODIS/Inputs/MODIS/), [this source](https://snow.ucsb.edu/products/SPIRES/MODIS/Sierra/ExampleData/) and [this source] by Timbo Stillinger (https://github.com/edwardbair/SPIRES/blob/master/MccM/).

<br><br><br>
