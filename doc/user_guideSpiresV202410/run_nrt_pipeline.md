# Daily job submission

This page presents the submission of the daily update of near-real-time (NRT) snow property data from the collection of input products to the export of output products for the Snow-Today web-app and for other users (NetCDF data files).

[Procedure for a submission in production](#run-as-a-beginner).
[Procedure for a submission as a new user and/or for testing](#run-for-testing).

## Preamble and vocabulary.

The NRT pipeline is a production chain which goal is to generate and deliver output data for a set of big regions. For SPIReS v2024.1.0, there's only one big region: `westernUS`.

Note that *NRT* in *NRT pipeline* is a label for the *daily* use of this pipeline to update data. It's not to be confused with the *NRT* and *historical* labels for the input data (e.g. MOD09GA data files), which are determined by the providers of remote sensing products. The NRT pipeline ingest both NRT and historical input data.

**Big regions** are arbitrary sets of tiles ([MODIS Tiles](https://modis-land.gsfc.nasa.gov/MODLAND_grid.html)) for which we run the production chain in parallel. Their definition is in the [regionConf](code_organization.md#list-of-configuration-files).

To carry out the work objectives of the pipeline, we submit a call to a virtual supervisor, named `runSubmitter.sh`. Once started through a Slurm job, this supervisor divides the workload of the pipeline into multiple tasks to carry out sequentially and/or parallelly, each task corresponding to an individual Slurm job. The `runSubmitter.sh` monitors the execution of these tasks as described [here](code_organization.md#code-interactions-within-a-submission-to-slurm). 

**Numerous jobs are run**. If a task fails, `runSubmitter.sh` will try to resubmit it automatically. This division into multiple tasks organically generates a lot of jobs. In particular, during the step of handling temporal interpolation of data, hundreds of jobs are generated. Jobs can also be multiplied not "naturally", in case of repetitive job failures, for instance because many nodes of the cluster have become temporarily defective or if the [configuration files are not properly set up](install.md). By default, Slurm will send an email to the user for each end of job. The user will receive numerous emails, and it's a practice to create a redirection rule to a specific folder of the user's email box.

First, the process divides the work into several tasks and executes them in a **sequence**. Each of these tasks is called here a **step**. The instructions of each step are coded in a dedicated bash script, referenced by a **scriptId**, for instance `daStatis`. [List of steps](#steps-and-scriptid).

Each step will generate data for a set of objects, referenced by **objectId** or **objectName**. Here, objects can be MODIS tiles, such as h08v04, big regions, such as westernUS, or land subdivisions, such as states or watersheds. [Not exhaustive list of objects](#objects-examples). Each step divides its tasks into subtasks dedicated to each object.

For each object to handle, the process launches as many parallel jobs as the number of objects given to the step. This corresponds to 1 job per object, except (1) for the step *daStatis*, for which it combines several objects in the same job, and (2) for the step *spiSmooC* (in SPIReS v2024.1.0), for which it divides the interpolation task into 36 jobs. If the pipeline handles the big region covering 5 tiles, this generates the submission of 5x36=180 parallel jobs, and more if job failure occurs. 

**WaterYearDate**. Each step runs over a [specific period of time](#steps-and-scriptid). To control that period of time, we designed the concept of WaterYearDate. This class allows the code to cover a period knowing (1) the last date of the period, and (2) the month window before this date. For instance, if I want to cover the ongoing WaterYear for the Western US and if today is 2025-07-10, the WaterYearDate will be set to the date of 2025-07-09, with a window of 12 months. The code automatically cuts the period at the start of the waterYear, and the WaterYearDate will cover only the period from 2024-10-01 to 2025-07-09, that is, 10 months, with the last month cut after the 10th day.

**WaterYear**. A water year is the period over which users tend to study the hydrology of snowy watersheds. The concept is designed to be certain that the peak of snow cover and snowmelt is not at the start or the end of the period. For SPIReS v2024.1.0, the water year N is coded to start (N-1)-10-01 and end N-09-30, for instance, 2024-10-01 to 2025-09-30 for water year 2025.


**Data, input data, intermediary data, output data, ancillary data**. In the scope of this project, data are discrete spatio-temporal information, either extracted from remote sensors, or calculated with the input of the data from remote sensors. Data can be temporal sequences of rasters for a specific region of the Earth, but also spatio-temporal statistics determined from these rasters, as displayed in the [snow-today website](https://nsidc.org/snow-today/snow-viewer).

To go back to the data production chain, at the step level, each step reads input data and after calculations, writes output data. At the production chain level, the chain takes input data, writes intermediary data at each step, and writes output data during the last steps.

For this project, input data are the NASA products that are downloaded and which information is ingested, on which the code applies the algorithms to produce output data forming a product that external users will use for their purposes. All the files generated in the middle of the chain contain data named intermediary data in the rest of the documentation.

Ancillary data are not considered as "data" in this project, but are necessary for several steps. They consist of water masks, elevation or ice data, territorial land subdivisions, lookup tables. See [install](install.md#ancillary-data).


**thisEnvironment, versionLabel, inputLabel, outputLabel, inputProductAndVersion, filterConfId, dataLabels**. All these terms refer to labels for versions of different things in the code of this project. Advanced level users may create new versions of these things for their purposes, but level 1 users only have to make sure that `thisEnvironment=SpiresV2024.1.0` (done during the submission of the NRT pipeline or the historic step), the rest of the parameters being automatically set. However, all these labels, except filterConfId, are important to identify so as to find the location of specific files, for instance, in the framework of [scratch to archive synchronization](#runrsync) for the historic production chain, or for data analyses and validation.

**thisEnvironment**. ESP Environment version. Determines which environment, configuration, and code files a job run selects for the project SPIRES_2025_0_1. For classic use, `thisEnvironment=SpiresV202501`.

**versionLabel, inputLabel, outputLabel**. Data product versions. At the step level, InputLabel is the versionLabel of the input data and outpuLabel is the versionLabel of the output data.

*For advanced users.* The same code can generate different values for data, depending on which thisEnvironment, inputProductAndVersion, and filterConfId the advanced user selects (by default the user does not have to select). To control this, the directories and filenames containing the data bear a versionLabel. Most of the time, the versionLabel is the same all along the production chain. Advanced users may want to reuse intermediary data of a certain version A with a new configuration to produce output data of another version B. 

**inputProductAndVersion**. This label identifies the input product at the start of the production chain. For SPIReS v2025.0.1, `$inputProductAndVersion=mod09ga.061`, which corresponds to the MOD09GA product version 6.1.

**filterConfId**. This label identifies the refined configuration setting of the algorithm encoded for the step. *Advanced users* may want to create a new configuration of the algorithm and use it.

**dataLabels**. Each step takes input data files and provides output data files. To manage the different types of files, we use the notion of dataLabel. Each dataLabel corresponds to a group of files generated for a specific step, a specific configuration, a specific object, and a specific period of time, among others. [List of dataLabels](#datalabels). These dataLabels point to a specific filepath string pattern, which encodes how the directory and filename are determined. [List of file locations](#data-file-location).



## Data spaces and file synchronization.

**File spaces** are organized in categories:
- home: mostly for the bash environment files, including `.bashrc`.
- code: code, including scripts and small-size configuration files, and logs.
- scratch: I/O operations during Slurm execution are optimized there. But space is limited and files are automatically erased after some time ([for CURC officially 90 days](https://curc.readthedocs.io/en/latest/compute/filesystems.html#scratch-filesystems)).
- archive: permanent storage space. Spaces for historical data are for data that are not updated once they are archived (except if there is an error), while space for NRT data is for data updated frequently.

A good practice for a user is to regularly check the storage space used in the user's scratch space and the authorized quota. This is particularly **IMPORTANT** for the users who [generate historical data](run_historic_step.md), which can represent a considerable amount of files.

For CU Boulder, this is done by the command `curc-quota` executed on a login node, see [here](https://curc.readthedocs.io/en/latest/compute/filesystems.html#monitoring-disk-usage). Similarly, the user should check the inodes used in the user's scratch space. Each file or directory has an associated inode in a Linux system. While archive space has a lot of margin for the quota of inodes, the scratch space has a limited quota. For CU Boulder, this is done by the command `curc-quota -i`.

Once the uses are checked and if they are close to quotas, the user may decide to archive a part of the scratch data to archive (see [synchronization](#runrsync)) and delete the archived data from the user's scratch to free space and inodes.

**Ancillary data** can form big files and are not part of the code, but have a permanent storage in the archive, with a synchronization to scratch.

[List of spaces](#data-spaces-and-rsync).

**Synchronization of files for beginner users of NRT**. This synchronization is carried out transparently for the user by automation coded in the scripts. 

The *sync from archive to scratch* is carried out so that the jobs:
- have up-to-date ancillary data,
- have data from the previous runs, in particular from those by other users,
- do not suffer from the automatic deletion of files on scratch.
The code automatically synchronizes the data when required, on the go.

The *sync from scratch to archive* is carried out to:
- deliver the data output to product users,
- keep a copy of some intermediary files, necessary for later runs, either by the user or another one.
The code carried out this task during the step `ftpExpor`.

For both cases, the synchronization only updates files when the source is more recent and ensures that file groups and rights are correctly set, if the receiving folders had been correctly set during [installation](install.md#configure-the-scratch-and-archive-folders).

**Synchronization in other cases**

For all other cases, such as [testing runs](#run-for-testing) or [runs of historics](run_historic_step.md), automatic rsync are considered too risky and the user needs to synchronize the files using the [procedure described here](#runrsync).


## Run as a beginner.

The entry script to launch submission is `bash/submitNrt.sh`. This script submits a job to a Slurm cluster, with a submit line including the script `bash/runSubmitter.sh`. When Slurm starts the job, `runSubmitter.sh` monitors the submission to Slurm of a sequence of secondary, operational jobs to carry out the generation of data and achieve the full run ([code interactions](code_organization.md#Code-interactions-within-a-submission-to-slurm)).

The near real-time jobs use the same scripts for each step as for the [historic jobs](run_historic_step.md), with different parameters and in an automatized sequential way, which is not the case for the historics, which are run each step individually.

To run the full pipeline in ***production***, the user first connects to a login node. After `cd` to the root of this project, the user executes:
```bash
thisEnvironment=SpiresV202410
pipelineId=1
bash/submitNrt.sh -E $thisEnvironment -Z $pipelineId
```

WARNING: This command is for production only. See the procedure for [testing in integration](#run-for-testing).

The script prints the options given and loads some configuration, and then it shows the submitLine that will be submitted to Slurm and asks for confirmation:

```
sbatch   --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=spnr2410 --ntasks-per-node=1 --mem=1G --time=11:30:00 --array=1 bash/runSubmitter.sh "sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1"
Do you want to proceed? (y/n)
```

The user confirms `y` and the script submits the job and prints:
```
Submission...
Submitted batch job 20164305
```

The user notes the job id of the `runSubmitter.sh`, here `20164305` and would<sup>*</sup> follow its execution:
- with the help of [slurm](https://slurm.schedmd.com/documentation.html) commands `squeue`, `sacct`, `scontrol`,
- and with the help of the [logs](checking_log.md).


To run it without the prompt:
```bash
thisEnvironment=SpiresV202410
pipelineId=1
bash/submitNrt.sh -E SpiresV202410 -v 10 -Z 1
```
The script will achieve this without waiting for the user's input and will submit the job.


## Run for testing.

The production command launches a series of steps, which includes the update of the production archive and the production snow-today web-app with the output data.

For testing, the user should first `rsync` the folders `modis_ancillary`, `modis`, and `mod09ga` from the production archive (`$espArchiveDirOps` defined in `.bashrc`) to their scratch (`$espScratchDir` defined in `.bashrc`). [Procedure indicated here](#runrsync).

Then the user can execute:
```bash
thisEnvironment=SpiresV202410
pipelineId=1
bash/submitNrt.sh -E SpiresV202410 -W 1 -y ${espScratchDir} -Z 1
```

`$espScratchDir` is defined in `~/.bashrc`

With that command, the update of the production archive is neutralized (no rsync scratch to archive there) and the output data are sent to the integration web-app (this may be an issue if another user works on integration too).


## Options and argument for submitNrt

We already saw that `submitNrt.sh` has 2 obligatory "options":
- `-E thisEnvironment`: String, obligatory. E.g. SpiresV202410, Dev. Gives the environment version, to distinguish between different versions of the algorithm used to calculate snow properties.
- `-Z pipelineId`: Int, obligatory. E.g. 1. Should refer to a pipelineId defined in `configurationSpiresV202410.sh`.

Except for advanced use, the user does not have to change the values for these options. Here `-E SpiresV202410` indicates the code to take first any configuration that was updated specifically for this project. `-Z 1` indicates the code to take the pipeline configuration of pipeline `1` configured in `bash/configurationSpiresV202410`, which is the pipeline using SPIReS v2024.1.0 for the region westernUS.

For testing use, two other options are also used:
- `-y archivePath`: String, optional. Default `$espArchiveDirOps` defined in `.bashrc`. Directory path of the archive from which are collected the most up-to-date data of previous days to the scratch of the user, and to which output data are rsync from this scratch.
- `-W espWebExportConfId`: Int, optional. Configuration id of the target of the web export server. 0: Prod (default), 1: Integration, 2: QA. So 

 So then, for testing we set `-W 1 -y ${espScratchDir}`, which means that the code will export the data to the integration website and will rsync the data from the user's scratch to the user's scratch, in short it will not do any rsync.


Other optional options are available for various scenarios. 

Scenario 1: Imagine the pipeline run broke, and you need to resubmit it. If a part of the steps was correctly executed, you can resubmit the pipeline starting at a step farther in the pipeline than the first step (default). This is done by adding an argument:
- `scriptId`: String, optional. Default: First script of the pipeline. Code of the script to start the pipeline with. Should have values in `$pipeLineScriptIds${pipelineId}` defined in `configurationSpiresV202410.sh`.

For instance, to start at the generation of statistics step:
```bash
thisEnvironment=SpiresV202410
pipelineId=1
bash/submitNrt.sh -E $thisEnvironment -Z $pipelineId daStatis
```

Scenario 2: If you want only to run one step and not the full pipeline, you can use:
- `-U thisStepOnly`: Int, optional. Default: 0, all steps after the script `scriptId` will be executed. 1: only the given step will be executed (=break the pipeline after the step).

Scenario 3: If you want to lower or increase the Slurm wall-time of the pipeline:
- `-T controlTime`: String format 00:00:00, optional. Wall-time of the `runSubmitter.sh` execution, beyond which the monitoring of the pipeline will be stopped. By default, time indicated in `configurationSpiresV202410.sh` for the pipeline, `$pipeLineControlTime1` for `$pipelineId` = 1.

Scenario 4: you want to automatize the launch of the script, for instance using a cron:
- `-v verbosity`: Int, optional. Default: 0, all logs, including prompts. 10: all logs,
  but no prompt, the script will execute until the end without waiting for the user's input.
    
## What the script does.    

The script starts by printing the current directory (working directory). Then it collects the option and argument values and prints a synthesis, with default values if necessary.

Then it loads `bash/configurationSpiresV202401.sh`, `SpiresV202410` being the option `-E thisEnvironment` given to `submitNrt.sh`. That script first loads `env/.matlabEnvironmentVariablesSpiresV202410`, where all matlab paths are configured for this project. And then it instantiates the configuration of each step of the pipeline `1`, given by the parameter `-Z pipelineId`. The configuration includes the configuration of the pipeline itself, that is (1) the sequence of scripts to execute, given by `pipeLineScriptIds1` for pipelineId 1), (2) the big regions for which data will be generated (for SPIReS v2024.1.0 only `westernUS`), but also (3) individual Slurm step submission options such as task number, memory, and time-wall.

Once done, the script loads `bash/toolsRegion.sh`. That script instantiates all the region configuration, mainly from `conf/configuration_of_regions.csv`, with a few hard-coded variables.

Then, the script indicates where the pipeline will start, here it should indicate the first step, `mod09gaI`.

Then, the scripts shows the submitLine that will be submitted to Slurm and ask for confirmation:

```
sbatch   --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=spnr2410 --ntasks-per-node=1 --mem=1G --time=11:30:00 --array=1 bash/runSubmitter.sh "sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1"
Do you want to proceed? (y/n) y
```

In this submitLine 1, there is a part submitting `bash/runSubmitter.sh` with its options and another submitLine 2, which is the argument of `runSubmitter.sh`:
```
sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1
```

This second submitLine will be the submission of the first step of the pipeline. 

After the user's reply "y", `runSubmitter.sh` job is submitted. Once started, it will submit the submitLine 2, which will launch a set of jobs corresponding to the first step (or the step given as argument). Then, this step N will submit the next step N+1, with a dependency on the correct execution of step N. And so on sequentially. All along the execution, `runSubmitter.sh` monitors the correct execution of the jobs, and updates their last line once they are achieved, to have a track that they were correctly achieved, a track that you can scan with the tips in [checking_log](checking_log.md). If a job failed, and if the failure belongs to a set of specific errors, `runSubmitter.sh` will automatically resubmit the job.

(Step 1) It starts by submitting the jobs to download the MOD09GA files. Then it submits the 2 steps (Step 2 and Step 3) of the SPIReS v2024.0.1 algorithm in a row, generating 2 intermediary types of files (`spiFillC` and `spiSmooC`). Then (Steps 4 to 9), it submits the steps handling complementary calculation and the generation of the output files (netcdfs, statistics, web-app files). Last (steps 10 and 11), it will submit the job rsyncing the output files to the archive and determine the regions to send to the web-app and send them the data.

## Requirements

- The submission should be done on a login node that can submit jobs to a Slurm cluster (and not directly from a node of the cluster).

- The submission script **must** be executed once the user is at the root of the project.

- The user needs to have environment variable and alias definition files stored in their home directory: `~/.bashrc`, `~/.netrc`, `env/.matlabEnvironmentVariablesSpiresV202410`.

- For production (= data that have the potential to be published), the log directory should be unique among all users and users should have r/w access to it, see [installation](install.md#Initialize-the-environment-file-bashrc)

## Previous data generation requirements

The pipeline has some expectations over the input and intermediary data available.

- For a water year N (`westernUS`), the `spiFillC` data **must** have been generated starting Sept, N - 1 until date of today - 2 months. For instance, if the date of today = 2025-03-15, the data must have been generated from 2024-09-01 to 2025-01-31.

- The `dailycsv` statistic files of previous years **must** have been generated, for a correct display on the snow-today website.

- The output `NetCDF` and `dailycsv` files are generated for the full ongoing water year, from 10/1 until the date of today - 1. The geotiffs for the web-app are only generated for the last day.

## Location of input, intermediary, and output data.

Filepaths are determined in a central way by a dedicated DataManager class, `ESPEnv`. `ESPEnv` also handles I/O operations. Each type of file has a specific label, `dataLabel`. The associated file path pattern is configured in `conf/configuration_of_filepathsSpiresV202410.csv`. And the DataManager transforms this pattern into an actual filepath by replacing the variables contained in the pattern by their value. This notably includes the region or tile, the date, the year, or the wateryear. For instance, respectively `h08v04`, `20250625` for the date `2025-06-25`, `2025`, `WY2025` for waterYear 2025.

For SPIReS v2024.1.0, three steps, `spiFillC`, `spiSmooC`, and `ftpExport` are not handled by `ESPEnv` and the files are hard-coded in the scripts.

[List of file locations](#data-file-location).

## More advanced remarks

No other option or argument is available for this submission script. That implies that when specific changes of parametering should be done, either or both `bash/submitNrt.sh` and `bash/configurationSpiresV202410.sh` should be edited locally, as explained for the examples below.

(1) Occasionally, some nodes are to be excluded from the run because they don't work as expected, notably for access to scratch or some libraries or performance issues. For instance, if the nodes are toto and titi, this is done in the script `bash/submitNrt.sh` by changing the line `exclude="";` into `exclude="--exclude=toto,titi";`. The two nodes **must** be part of the Slurm cluster.

(2) Some jobs associated with specific steps can occasionally be killed because their necessary execution time is longer than the expected time (wall-time) or they can run into an out-of-memory error. It's possible to edit the wall-time of a step by editing, in the script `bash/configurationSpiresV202410.sh`, the variables `pipeLineTimes1` (time in hours) and `pipeLineMems1`, respectively. **Important**: increasing memory often requires increasing the number of cpus.

A method to cleanly cancel (=kill) jobs is described [here](checking_log.md#cancel-jobs-during-execution).

## Appendices

### Steps and scriptId

Here are the NRT- and historic-generation steps for SPIReS v2024.1.0:

| # | scriptId | description | NRT | historical | period for NRT  | period for historicals |
|---|---|---|---|---|---|---|
| 1 | mod09gaI | Download mod09ga. | x | x | bimester | trimester |
|---|---|---|---|---|---|---|
| 2 | spiFillC | Generate intermediary gap files from mod09ga input. | x | x | bimester | trimester |
|---|---|---|---|---|---|---|
| 3 | spiSmooC | Generate gap-filled data files (without false positives) + temporal interpolation. | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 4 | moSpires | Generate daily .mat files (dubbed mosaics). | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 5 | scdInCub | Calculate snow cover days in daily .mat files. | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 6 | daNetCDF | Generate output NetCDF files. | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 7 | daMosBig | Generate output big mosaic .mat files. | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 8 | daGeoBig | Generate NRT geotiffs for website. | x |  | 1 day |  |
|---|---|---|---|---|---|---|
| 9 | daStatis | Generate .csv daily statistic files. | x | x | waterYear | waterYear |
|---|---|---|---|---|---|---|
| 10 | ftpExpor | Rsync NRT data from scratch to archive. | x|  | 2 years |  |
|---|---|---|---|---|---|---|
| 11 | webExpSn | Generate and export NRT data to website. | x |  | waterYear |  |
|---|---|---|---|---|---|---|

where:
- NRT checked indicates if the NRT sequence includes the step,
- historical checked indicates if this step should be carry out in the generation of historicals,
- the generation period indicates the period over which a single job should be run, each period starting on the 1st day of the month; for NRT, the period is cut to the day before today, except if the job is run after 7:00 pm Denver US time (currently hard-coded because the availability of NRT Modis tiles of the day is most of the time not available before that time).

### Objects, examples.

Here are a few examples of objects:

| objectId | objectName | type | configuration file |
|---|---|---|---|
| 5 | westernUS | bigRegion | regions |
|---|---|---|---|
| 292 | h08v04 | tile | regions |
|---|---|---|---|
| 293 | h08v05 | tile | regions |
|---|---|---|---|
| 328 | h09v04 | tile | regions |
|---|---|---|---|
| 329 | h09v05 | tile | regions |
|---|---|---|---|
| 364 | h10v04 | type | configuration file |
|---|---|---|---|
| 26000 | westernUS | subdivision groupadm0 | subdivisions |
|---|---|---|---|
| 11726 | Colorado | subdivision adm1 | subdivisions |
|---|---|---|---|
| 12513 | Upper Colorado HUC14 | subdivision huc2 | subdivisions |
|---|---|---|---|
| 12778 | Colorado Headwaters HUC1401 | subdivision huc4 | subdivisions |
|---|---|---|---|

Full list is in the regions file `conf/configuration_of_regionsSpiresV202410.csv` and the subdivisions file `conf/configuration_of_landsubdivisionsSpiresV202410.csv`.

### DataLabels

Here are the input and output dataLabels used for each step of the pipeline:

| # | scriptId | inputDataLabel | outputDataLabel |
|---|---|---|---|
| 1 | mod09gaI |  | mod09ga |
|---|---|---|---|
| 2 | spiFillC | mod09ga | modisspiresfill |
|---|---|---|---|
| 3 | spiSmooC | modisspiresfill | modisspiressmoothbycell |
|---|---|---|---|
| 4 | moSpires | modisspiressmoothbycell | VariablesMatlab |
|---|---|---|---|
| 5 | scdInCub | VariablesMatlab | VariablesMatlab |
|---|---|---|---|
| 6 | daNetCDF | VariablesMatlab | outputnetcdf |
|---|---|---|---|
| 7 | daMosBig | VariablesMatlab | VariablesMatlab |
|---|---|---|---|
| 8 | daGeoBig | VariablesMatlab | VariablesGeotiff |
|---|---|---|---|
| 9 | daStatis | VariablesMatlab | SubdivisionStatsDailyCsv |
|   |   |  | SubdivisionStatsAggregCsv |
|   |   |  | SubdivisionStatsWebJson |
|   |   |  | SubdivisionStatsWebCsvv20231 |
|---|---|---|---|
| 10 | ftpExpor |  | modisspiresfill |
|   |   |  | VariablesMatlab |
|   |   |  | outputnetcdf |
|   |   |  | VariablesGeotiff |
|   |   |  | SubdivisionStatsWebCsvv20231 |
|   |   |  | SubdivisionStatsAggregCsv |
|---|---|---|---|
| 11 | webExpSn | VariablesGeotiff |  |
|   |   | SubdivisionStatsWebJson |  |
|   |   | SubdivisionStatsWebCsvv20231 |  |
|---|---|---|---|

### Data spaces

The data spaces are:

| name | category | environment variable | configuration file | comment |
|---|---|---|---|---|
| `myHome` | home | ~/.bashrc | |
|---|---|---|---|---|
| `projectDir` | code | ~/.bashrc | |
|---|---|---|---|---|
| `thisEspProjectDir` | code | env/.matlabEnvironmentVariablesSpiresV202410 | other projects, such as external matlab packages are also defined in this file |
| `espLogDir` | code | ~/.bashrc | centralized location of logs. |
|---|---|---|---|---|
| `espScratchDir` | scratch | ~/.bashrc | variable `$slurmAlternativeScratchDir1` points to the same space, was added to handle directory links that matlab can sometimes not handle correctly. |
|---|---|---|---|---|
| `espArchiveDirEsp`  | archive | ~/.bashrc | legacy archive |
|---|---|---|---|---|
| `espArchiveDir` | archive | ~/.bashrc | default archive in code. |
|---|---|---|---|---|
| `espArchiveDirNrt`| archive | ~/.bashrc | archive for historic data |
|---|---|---|---|---|
| `espArchiveDirOps`| archive | ~/.bashrc | archive for NRT data |
|---|---|---|---|---|

### runRsync

**For one folder not that big**. `bash/runRsync.sh` executes the synchronization of 1 folder from one data space to the other. [file naming, organization](#data-spaces-and-rsync) and [location](#data-file-location). The user can go on any node, cd to the root of this project, and execute the command:
```bash
versionLabel=v2024.0.d
sourcePath=${espScratchDir}modis/subdivisionstats/scagdrfs_dailycsv_${versionLabel}/v006/
targetPath=${espArchiveDir}modis/subdivisionstats/scagdrfs_dailycsv_${versionLabel}/v006/

bash/runRsync.sh -x $sourcePath -y $targetPath
```
with the example of syncing the daily csv stats from the historic archive to the user's scratch space.

`$espScratchDir` and `$espArchiveDir` are environment variables defined in `~/.bashrc`.

**For parallel sync**. The following procedure is advised when (1) the folder is really big, or (2) the user only needs files for a specific big region and/or a range of years. Files in the folder need to be organized by region subfolder and year subfolder . The procedure allows submitting parallel rsync jobs to Slurm for the regions and years.

The user can go on any node, cd to the root of this project, and execute the command:
```bash
label=v2024.0d
bash/submitRSync.sh -B 5 -e 2024 -f 2025 -x $espScratchDir -y $espArchiveDir modis/variables/scagdrfs_mat_${label}/v006/
```
where options are:
- -B bigRegionId: int, obligatory. Identifying the big region (e.g. 5 for westernUS). Only one big region per run.
- -e startYear: int, optional. Smallest year of run, e.g. 2024. If not given, startYear = endYear.
- -f endYear: int, obligatory. Highest year of run, of year of run, e.g. 2025.
- -x: sourcePath: string, obligatory. Source data space base path.
- -y: targetPath: string, obligatory. Target data space base path.

and argument is
- thisFolder: String, obligatory. E.g. 'modis/variables/scagdrfs_mat_v2024.0d/v006/'.

The script asks for confirmation, the user enters 'y' and the jobs are submitted.

In addition to all this, note that a specific alias `rsync` is defined in `.bashrc` to ensure that group, rights of files are correctly set and that updates are only done if the source is more recent.

### Data file location

The current (2025-07-07) directories where the files are located are defined in `conf/configuration_of_filepathsSpiresV202410.csv` and are:

| dataLabel | directoryPath | comment |
|---|---|---|
| mod09ga | modis/input/mod09ga.061/v006/{objectName}/{thisYear}/ | |
|---|---|---|
| modisspiresfill | modis/intermediary/spiresfill_{versionLabel}/v006/{objectName}/{thisYear}/ | |
|---|---|---|
| modisspiressmoothbycell | modis/intermediary/spiressmooth_{versionLabel}/v006/{objectName}/ | |
|---|---|---|
| VariablesMatlab | modis/variables/scagdrfs_mat_{versionLabel}/v006/{objectName}/{thisYear}/ | on `$espArchiveDirOps`: output/mod09ga.061/spires/${versionLabel}/mat/ |
|---|---|---|
| outputnetcdf | output/{inputProduct}/{inputProductVersion}/{algorithm}/{versionLabel}/netcdf/{objectName}/{thisYear}/ | on `$espArchiveDirOps`: output/mod09ga.061/spires/${versionLabel}/netcdf/{objectName}/{thisYear}/ |
|---|---|---|
| VariablesGeotiff | modis/variables/scagdrfs_geotiff_{versionLabel}/v006/{objectName}/EPSG_3857/LZW/{thisYear}/ | on `$espArchiveDirOps`: output/mod09ga.061/spires/${versionLabel}/tif_EPSG3857/ |
|---|---|---|
| SubdivisionStatsDailyCsv | modis/subdivisionstats/scagdrfs_dailycsv_{versionLabel}/v006/{objectId_1000}/{thisYear}/ | |
|---|---|---|
| SubdivisionStatsAggregCsv | modis/subdivisionstats/scagdrfs_aggregcsv_{versionLabel}/v006/{objectId_1000} | on `$espArchiveDirOps`: output/mod09ga.061/spires/${versionLabel}/aggregcsv/ |
|---|---|---|
| SubdivisionStatsWebJson | modis/subdivisionstats/scagdrfs_webjson_{versionLabel}/v006/{objectId_1000}/{objectId}/{thisYear} | |
|---|---|---|
| SubdivisionStatsWebCsvv20231 | modis/regional_stats/scagdrfs_csv_{versionLabel}/v006/{sourceRegionName}/WY{thisYear}/ | on `$espArchiveDirOps`: output/mod09ga.061/spires/${versionLabel}/csv/ |
|---|---|---|

where:
- {algorithm} = spires
- {inputProduct} = mod09ga
- {inputProductVersion} = 061
- {objectId_1000} = 26, if objectId = 26014 (the objectIds are configured in `conf/configuration_of_landsubdivisionsSpiresV202410.csv`)
- {objectName} = h08v04 or westernUS
- {sourceRegionName} = westernUS
- {thisYear} = 2025
- {versionLabel} = v2024.0d or v2024.1.0

<br><br><br>
