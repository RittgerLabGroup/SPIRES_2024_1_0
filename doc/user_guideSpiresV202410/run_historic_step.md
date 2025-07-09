# Historic job submission

This page presents the submission of the update of historic snow property data from the collection of input products to the generation of output products for users (netcdf data files) and for the [daily near real time (NRT) update](run_nrt_pipeline.md) to the snow-today website (dailycsv statistic files for plots).

We advise to read the [Preamble of the NRT pipeline doc](run_nrt_pipeline.md#preamble-and-vocabulary) and more generally the NRT documentation of that page.

# Run as a beginner

The entry script to launch submission is `bash/submitHistoric.sh`. This script submits a job to a slurm cluster, with a submit line including the script `bash/runSubmitter.sh` (see [Run as a beginner for the NRT pipeline](run_nrt_pipeline.md#run_as_a_beginner) and [code interactions](code_organization.md#Code_interactions_within_a_submission_to_Slurm)). 

The historic jobs use the same scripts for each [step](run_nrt_pipeline.md#preamble-and-vocabulary) as for the [NRT jobs](run_nrt_pipeline.md). However, while the NRT pipeline has a automatized sequence of jobs from input to delivery of output data files, the user should follow a different procedure to run the historics:

1. The user submits each step at a time, according to instructions below,
2. The use monitors the execution of the step, using [checking log](checking_log.md),
3. Once the step has achieved correctly and generated the data files, the user can submit the next step.
4. Once all steps have been carried out, the user can check some of the output files and their content, and then rsync





To run the full pipeline in ***production***, the user first connect to a login node. After `cd` to the root of this project, the user executes:
`bash/submitNrt.sh -E SpiresV202410 -Z 1`.

WARNING: This command is for production only. See the procedure for [testing in integration](#run_for_testing).

The scripts prints the options given and load some configuration, and then it shows the submitLine that will be submitted to slurm and ask confirmation:

```bash
sbatch   --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=spnr2410 --ntasks-per-node=1 --mem=1G --time=11:30:00 --array=1 bash/runSubmitter.sh "sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1"
Do you want to proceed? (y/n)
```

The user confirms `y` and the script submits the job and prints:
```
Submission...
Submitted batch job 20164305
```

The user notes the job id of the `runSubmitter.sh`, here `20164305` and can follow its execution:
- with the help of [slurm](https://slurm.schedmd.com/documentation.html) commands `squeue`, `sacct`, `scontrol`,
- and with the help of the [logs](checking_log.md).

To run it without the prompt:
`bash/submitNrt.sh -E SpiresV202410 -v 10 -Z 1`. The script will achieve without waiting the user's input and will submit the job.



This list of steps is defined in `bash/configurationForHistoricsSpiresV202410.sh`, vawhere steps are automatically run in a sequential way, the user runs each step here individually. The user will run the next step of the process only after checking in the logs that the already run step has been executed correctly. The nextwith different parameters and in a automatized sequential way, which is not the case for the historics, which are run 





## Introduction

For this purpose, the operator executes a submission script `specific/sh/submitStcForHistorics.sh`, with specific options notably the step of the algorithm that should be executed (option -s scriptId, see below) but without arguments. This script detects the configuration of the step scriptId (in `specific/sh/submitStcForHistorics.sh`) and ask you confirmation to submit a monitoring job to the configured slurm cluster.

After your reply "Y", the monitoring job is submitted using the script `shared/sh/runSubmitter.sh`, and after being started, will monitor the execution of the step, including its resubmission in case of error.

The historic jobs use the same scripts for each step as for the near real time jobs, with different parameters and without any automatized sequentialization, contrary to near real time execution. Each step should be run indenpendently, in the order indicated by the variable `authorizedScriptIds` in `specific/sh/submitStcForHistorics.sh`.

File logs are accessible to monitor the execution of all the jobs, more info [here](checking_logs.md).

## Obligatory Options

`-s scriptId`: string, "id" of the step, to chose among the values in `authorizedScriptIds` in `specific/sh/submitStcForHistorics.sh`

**Obligatory if option -D absent**

`-C confOfMonthId`: int, identify the group of months that will be generated.
- 0: Parameter overriden by option -D.
- 10: Full year, by trimester. 
- 11: Full year, by month.
- 20: 10-12 by trimester. 
- 21: 10-12 by month. 
- 30: 1-9 by trimester. 
- 31: 1-9 by month. 
- 41: 6-9 by month.
- 51: Full water year from Oct to Sept.
- 120: 1-3 by trimester. 
- 121: 1-3 by month.
- 130: 4-12 by trimester. 
- 131: 4-12 by month. 
- 141: 12 by month.
NB: Must be accompanied with option `-f endYear` (and `-e startYear` if generation is over several years).
NB: This parameter should be set to 0 if a period misses input data in the first months, and overriden by an adequate waterYearDate.

`-f endYear`: int, highest year of run, of year of run, e.g. 2025.
NB: if we run 10/2024 for westernUS over a monthwindow of 1 month only, although this period is affected to water year 2025, endYear should be 2024 in that case.
Option overriden by -D.

**Obligatory if option -C confOfMonthId = 0 and/or -f endYear absent**
`-D waterYearDateString`: string, format yyyy-MM-dd-monthWindow. Gives the date window over which the generation is done. E.g. 2024-03-26-1. Activated only when option -C is set to 0. The period ends by the date defined by yyyy-MM-dd, here 2024-03-26, and monthWindow, the number of months before this date covering the period: 12: 1 full year period, 1: the month of the date, from 1 to the date, 0: only the date. Default: date of today with monthWindow = 2. NB: if dd > than the last day of the month, then code (in the called script) sets it to last day.

NB: if a water year misses input data in the first months, the monthwindow should be adapted so as not to include the missing months. For instance, if water year 2024 misses october, WaterYearDate covering the full wateryear should be set to 2024-09-30-11.

## Optional Options

Information about other, optional options and their default value are supplied by calling `specific/sh/submitStcForHistorics.sh -h`.

## Requirements

- The submission should be done on a login node that can submit jobs to a slurm cluster (and not directly from a node of the cluster).

- The submission script **must** be executed once the operator is at the root of the STC-MODSCAG-MODDRFS project. For instance: `cd ${projectDir}/STC-MODSCAG-MODDRFS; specific/sh/submitStcForHistorics.sh`.

- The operator needs to have environment variable and alias definition files stored in their home directory: `~.bashrc`, `~.netrc`, `~.matlabEnvironmentVariables`. For safety reasons, the content of these files is partly confidential and only the list of variables and explanation of their definitions is provided in `env/.bashrc`, `env/.netrc`, `env/.matlabEnvironmentVariables`, respectively. Note another environment variable file in `env/~.projectEnvironmentVariables`, that should stay in the folder `env`.


## Previous data generation requirements

The scripts have some expectations over the input and intermediary data available.

- For a month M (westernUS), the mod09ga and modscagdrfs data **must** be available to run the step stcRawCu.
- For a month M (westernUS), the mod09raw and scagdrfsraw data **must** have been generated from M - 1 to M + 1 to run stcStcCu.
- Step daMosaic requires scagdrfsstc data for the full water year.
- Step moDWoObs requires scadrfsmat data for the full water year.
- Step daNetCDF requires scadrfsmat data after step moDWoObs treatment for the full water year.
- Step daMosBig (mosaic of western US) requires scadrfsmat data after step moDWoObs treatment for the full water year.

- The output files are generated for the full water year N, from 10/01/N - 1 until 09/30/N.


## Examples of calls
```
versionOfAncillary=v3.1
bigRegion=5
scriptId=mod09gaI
slurmCluster=1
scratchPath=$slurmScratchDir1
archivePath=$espArchiveDirNrt

# 1. Mod09ga download.
scriptId=mod09gaI
confOfMonthId=10
endYear=2024
inputLabel=v061
outputLabel=v061

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -f $endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 2. Modscagdrfs download.
scriptId=mScagDrI
confOfMonthId=10
endYear=2024
inputLabel=v1
outputLabel=v1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -f $endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 3. Scagdrfsraw generation.
scriptId=stcRawCu
confOfMonthId=30
endYear=2024
inputLabel=v061 # Not directly used in this step.
outputLabel=v2025.0.1

# 4. Scagdrfsstc generation.
scriptId=stcStcCu
confOfMonthId=0
waterYearDateString=2025-01-31-2
inputLabel=v2025.0.1
outputLabel=v2025.0.1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -D waterYearDateString -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 5. Albedo and daily mat generation.
scriptId=daMosaic
confOfMonthId=51
endYear=2024
startYear=2022
inputLabel=v2025.0.1
outputLabel=v2025.0.1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -e startYear -f endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 6. Days without observation.
scriptId=moDWoObs
confOfMonthId=51
endYear=2024
inputLabel=v2025.0.1
outputLabel=v2025.0.1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -f endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 7. Netcdfs.
scriptId=daNetCDF
confOfMonthId=51
endYear=2024
inputLabel=v2025.0.1
outputLabel=v2025.0.1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -f endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath

# 8. Big mosaic.
scriptId=daMosBig
confOfMonthId=51
endYear=2024
inputLabel=v2025.0.1
outputLabel=v2025.0.1

specific/sh/submitStcForHistorics.sh -A $versionOfAncillary -B $bigRegion -C $confOfMonthId -f endYear -L $inputLabel -O $outputLabel -s $scriptId  -u $slurmCluster -x $scratchPath -y $archivePath
```

## Other functionalities

Occasionally, it might be useful to parameter the options:
- `-I $objectId`, which restricts the run for one tile, e.g. 292 for h08v04, list in `conf/configuration_of_regions.csv` (not possible for step daMosBig)
- `-t $lagTimeBetweenSubmissionOfYears`, which prevent the submission of plenty of jobs in a row and insert a time lag between each submission (handy if we submit 20 water years in the same time)
- `-U $slurmExecutionOptions`, to exclude specific, deficient nodes (e.g. `--exclude=toto,titi`, the two nodes **must** be part of the slurm cluster).

## More advanced remarks

In some problematic cases, `specific/sh/submitStcForHistorics.sh` should be edited, as explained for the example below.

Some jobs associated to specific steps can occasionally be killed because their necessary execution time is longer than the expected time (wall-time) or they can run into an out of memory error. It's possible to edit the wall-time of a step by editing, in the script `specific/sh/submitStcForHistorics.sh`, the variable `sbatchTimes` (time in hours) and `sbatchMems`, respectively. **Important**: increasing memory often requires increasing the number of cpus. The jobs can continue to run into out of memory issues if the number of parallel workers is kept by default the number of tasks. The protection techniques against that issue, are not uniformed among scripts. In particular, the steps stcRawCu, stcStcCu, daMos, daMosBig have their parallel workers still hard-coded and not configurable through the variable `scriptParallelWorkersNbs` in `specific/sh/submitStcForHistorics.sh`.



<br><br><br>
