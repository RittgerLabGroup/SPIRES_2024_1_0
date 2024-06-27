# Daily job submission

This page develops the submission of the daily update of nrt snow property data from modis to the website snow-today, using a version of spires. The controling script for this submission is scripts/runSubmitter.sh.

## Introduction

Every day runSubmitter.sh script is launched to submit the series of scripts that forms the import, snow property calculation, and production of output files, which are transferred to the website, and also should be transferred to the ftp (To be implemented 2024-06-27). In other words, the job submitted launching runSubmitter.sh manages the jobs of the pipeline.

runSubmitter.sh will run enough time to launch the successive scripts as slurm jobs, to capture the exit status of the jobs, and in case of error, resubmit the job.

The output of runSubmitter.sh is a synthetic file placed in the log directory and named ${submitterSlurmFullJobId}_${jobName}_${thatArrayJobId}_job_synthesis.csv, with:
- submitterSlurmFullJobId: the id of the job submitted to run runSubmitter.sh
- jobName: the name of the first job of the pipeline
- thatArrayJobId: the slurm arrayJobId of the first job of the pipeline.

## General working of runSubmitter.sh

runSubmitter.sh first submits the first script/job of the pipeline. A submitLine is given as argument of runSubmitter.sh and this submitLine contains the sbatch command with the parameters to launch the first script of the pipelin. This job is split in several tasks, corresponding to the sensor tiles. The first task submits the second script of the pipeline, with a dependency on the successful exit code of the first series of job/tasks.

Then it regularly scans the log file of this job/tasks. If the log indicates a job for a specific task in error, runSubmitter.sh resubmit a similar job for the task. If the first task is in error, runSubmitter.sh cancels the full job and launch a new full submission (this because the first task is needed to run to have the next script of the pipeline submitted to the slurm scheduler).

runSubmitter.sh continues its scan until all task/tiles have been handled correctly, with a job status done. Given the error handling, some tasks can have several jobs, if it's the case, all of them except one are in status error, and one only is in status done.

Once all the tasks have the job status done, slurm automatically starts the next series of jobs/tasks. To prevent the block of this automatic start, runSubmitter.sh removes the job dependency if one task of the initial submission was in error and all the tasks.

runSubmitter.sh repeat this handling for each step of the pipeline, until the achievement of the last script of the pipeline.

For the first step, the tasks are split among the sensor (modis) tiles. But the split can be different for other steps:
- we cut the tiles into cells of lower size to improve parallelization and reduce cpu/memory consumption for each job. This was obligatory to use on a daily basis CU supercomputer.
- we regroup the tiles into 1 big region, for instance westernUS.
- we cut the big region into land subdivisions, which can correspond to states/provinces or watersheds.
- 
The ids of tiles and big regions are stored in `tbx/conf/configuration_of_regions.csv` (field: id) and the ids of all land subdivisions are stored in `tbx/conf/configuration_of_landsubdivisions.csv` (field: id). All ids are unique, and a tile id cannot be the same as a land subdivision id. These ids are given as task ids in the argument --array of the sbatch command.

## Cases/Fails/Errors not handled in runSubmitter.sh

**Dual cancel error**

This case happens when a sub-job (spiFillC or others) is cancelled because of time-limit and the job updating the status line in the log of that sub-job (endlogxxx) is cancelled too.

Rarely, the Alpine or Blanca clusters shut down or the nodes are set in unstable state, which make the sub-jobs (spiFillC, etc...) stagnating until they are cancelled due to time limit. In that case, the jobs updating the status end line of the logs of thesub-jobs (endlogxxx) can also be cancelled due to time limit and not update the status end-line of the sub-jobs. In that case, runSubmitter runs until time-limit without getting the final status of the sub-jobs. This error can be compensated by:
- cancelling all the submitted/running jobs for Snow-Today.
- resubmitting from start runSubmitter.sh.

## Spires pipeline scripts

The most recent series of scripts are in scripts/configuration.sh. These scripts are called main scripts and technically, they generate the string of matlab call which will be executed by a call to scripts/toolsStop.sh.

At date of writing (2024-06-27), the scripts are launched in the following order:

- mod09gaI, `./scripts/runGetMod09gaFiles.sh`: import of the daily mod09ga tiles, historic and if absent, nrt tiles. TaskIds: tiles.
- spiFillC, `./scripts/runSpiresFill.sh`: generation of the monthly spires gap files. TaskIds: tiles. Output consists of files corresponding to a cell cutting of each tile
- spiSmooC, `./scripts/runSpiresSmooth.sh`: generation of the wateryear spires interpolation files. Also filters and calculates corrected snow fraction, radiative forcing and albedo. TaskIds: cells.
- moSpires, `./scripts/runUpdateMosaicWithSpiresData.sh`: generation of the spires daily .mat files. TaskIds: tiles.
- scdInCub, `./scripts/runUpdateWaterYearSCD.sh`: calculation of snow cover days into the daily .mat files. TaskIds: tiles.
- daNetCDF, `./scripts/runESPNetCDF.sh`: generation of the daily NetCdf files. TaskIds: tiles.
- daMosBig, `./scripts/runUpdateMosaicBigRegion.sh`: generation of the daily big region .mat file. TaskId: big region.
- daGeoBig, `./scripts/runUpdateGeotiffBigRegion.sh`: generation of the geotiffs of the big region for the last available day. TaskId: big region.
- daStatis, `./scripts/runUpdateDailyStatistics.sh`: generation of statistics files. TaskId: land subdivisions.
- webExpSn, `./scripts/runWebExportSnowToday.sh`: generation of .json files and transfer to the snow-today web-app. TaskId: big region.

## Ancillary scripts

Ancillary scripts groups pre- and post-processing common for all scripts, including the capture of arguments and options:
- `scripts/toolsStart.sh`: Handle all the pre-processing, including the capture of arguments/options, pretests on the node (failed identity mapping) and calculation of parameters / strings used to construct the matlab call, submit the post-processing job, and the next job of the pipeline.
- `scripts/toolsMatlab.sh`: Creation of matlab temporary directories.
- `scripts/toolsStop.sh`: Executes the matlab command string constructed in the main script
- `scripts/configuration.sh`: Pipeline configuration and ancillary data version for tiles (this latter is used outside of matlab, but is a copy of info in `tbx/conf/configuration_of_regions.csv`). Important: the label version (v2024.0d, ...) of data is configured here for pipeline
- `scripts/toolsJobs.sh`: Some functions.
- `scripts/toolsRegions.sh`: Region configuration (outside matlab) and functions for regions.
- `scripts/toolsJobsAchieved.sh`: Update of the log status end line with performance stats.

## Submission code for daily runs

Start at the first script/ingest of the pipeline:
`ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirNrt};
scratchPath=${slurmScratchDir2}; slurmLogDir=${slurmLogDir2}; slurmQos=${slurmQos2};
inputLabel=v061; objectId=292,293,328,329,364; regionName=westernUS; 
scriptId=mod09gaI; slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmLogDir}%x_%a_%A.out --job-name=submitte --ntasks-per-node=1 --mem=1G --time=23:30:00 --array=1 --exclude=bmem-rico1 ./scripts/runSubmitter.sh "sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=mod09gaI --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=${objectId}  ./scripts/runGetMod09gaFiles.sh -A v3.1 -L ${inputLabel} -O ${inputLabel} -w 0 -x ${scratchPath} -y ${archivePath} -Z 1"`

The -Z 1 argument is to be kept if you want the full pipeline execute after the run of this script.

Start at gap files
`ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirNrt};
scratchPath=${slurmScratchDir2}; slurmLogDir=${slurmLogDir2}; slurmQos=${slurmQos2};
inputLabel=v2024.0d; outputLabel=v2024.0d; objectId=292,293,328,329,364; regionName=westernUS; 
scriptId=spiFillC; slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmLogDir}%x_%a_%A.out --job-name=submitte --ntasks-per-node=1 --mem=1G --time=23:30:00 --array=1 --exclude=bmem-rico1 ./scripts/runSubmitter.sh "sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --ntasks-per-node=18 --mem=140G --time=02:15:00 --array=${objectId} ./scripts/runSpiresFill.sh -A v3.1 -L ${inputLabel} -O ${outputLabel} -x ${scratchPath} -y ${archivePath} -Z 1"`

Start at interpolated files
`ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirNrt};
scratchPath=${slurmScratchDir2}; slurmLogDir=${slurmLogDir2}; slurmQos=${slurmQos2};
inputLabel=v2024.0d; outputLabel=v2024.0d; objectId=292001-292036,293001-293036,328001-328036,329001-329036,364001-364036; regionName=westernUS;
scriptId=spiSmooC; slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmLogDir}%x_%a_%A.out --job-name=submitte --ntasks-per-node=1 --mem=1G --time=23:30:00 --array=1 --exclude=bmem-rico1 ./scripts/runSubmitter.sh "sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --ntasks-per-node=10 --mem=30G --time=02:30:00 --array=${objectId} ./scripts/runSpiresSmooth.sh -A v3.1 -L ${inputLabel} -O ${outputLabel} -x ${scratchPath} -y ${archivePath} -Z 1"`

Start at daily .mat files.
`ml slurm/${slurmName2}; slurmAccount=${slurmAccount2}; archivePath=${espArchiveDirNrt};
scratchPath=${slurmScratchDir2}; slurmLogDir=${slurmLogDir2}; slurmQos=${slurmQos2};
inputLabel=v2024.0d; outputLabel=v2024.0d; objectId=292,293,328,329,364; regionName=westernUS;
scriptId=moSpires; slurmOutputPath=${slurmLogDir}%x_%a_%A.out;
sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmLogDir}%x_%a_%A.out --job-name=submitte --ntasks-per-node=1 --mem=1G --time=23:30:00 --array=1 --exclude=bmem-rico1 ./scripts/runSubmitter.sh "sbatch --account=${slurmAccount} --qos=${slurmQos} -o ${slurmOutputPath} --job-name=${scriptId} --ntasks-per-node=10 --mem=90G --time=00:30:00 --array=${objectId} ./scripts/runUpdateMosaicWithSpiresData.sh -A v3.1 -L ${inputLabel} -O ${outputLabel} -x ${scratchPath} -y ${archivePath} -Z 1"`

Author: Sebastien Lenard

Date of modification: 2024-06-27
