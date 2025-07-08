# Daily job submission

This page presents the submission of the daily update of near-real-time (NRT) snow property data from the collection of input products to the export of output products for the Snow-Today web-app and for other users (netcdf data files).

## Run as a beginner.

The entry script to launch submission is `bash/submitNrt.sh`. This script submits a submit line using the script `bash/runSubmitter.sh` for a job to a slurm cluster. When slurm starts the job, `runSubmitter.sh` monitors the submission to slurm of a sequence of secondary, operational jobs to carry out the generation of data and achieve the full run ([code interactions](code_organization.md#Code_interactions_within_a_submission_to_Slurm)). This generation is carried out in a sequence of several steps, each step corresponding to a series of parallel jobs.

The near real time jobs use the same scripts for each step as for the [historic jobs](run_historic_step.md), with different parameters and in a automatized sequential way, which is not the case for the historics, which are run each step individually.

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


## Run for testing.

The production command launches a series of steps, which includes the update of the production archive and the production snow-today web-app with the output data.

For testing, the user should first `rsync` the folders `modis_ancillary`, `modis`, and `mod09ga` from the production archive (`$espArchiveDirOps` defined in `.bashrc`) to their scratch (`$espScratchDir` defined in `.bashrc`).

Then the user can execute:
`bash/submitNrt.sh -E SpiresV202410 -W 1 -y ${espScratchDir} -Z 1`.

With that command, the update of the production archive is neutralized (no rsync to there) and the output data are sent to the integration web-app (this may be an issue if another user works on integration too).


## Options and argument for submitNrt

We already saw that `submitNrt.sh` has 2 obligatory "options":
- `-E thisEnvironment`: String, obligatory. E.g. SpiresV202410, Dev. Gives the environment version, to distinguish between different version of the algorithm used to calculate snow properties.
- `-Z pipelineId`: Int, obligatory. E.g. 1. Should refer to a pipelineId defined in `configurationSpiresV202410.sh`.

Except for advanced use, the user does not have to change the values for these options. Here `-E SpiresV202410` indicates the code to take first any configuration that was updated specifically for this project. `-Z 1` indicates the code to take the pipeline configuration of pipeline `1` configured in `bash/configurationSpiresV202410`, which is the pipeline using SPIReS v2024.1.0 for the region westernUS.

For testing use, two other options are also used:
- `-y archivePath`: String, optional. Default `$espArchiveDirOps` defined in `.bashrc`. Directory path of the archive from which are collected the most up-to-date data of previous days to the scratch of the user, and to which output data are rsync from this scratch.
- `-W espWebExportConfId`: Int, optional. Configuration id of the target of web export server. 0: Prod (default), 1: Integration, 2: QA. So 

 So then, for testing we set `-W 1 -y ${espScratchDir}`, which means that the code will export the data to the integration website and will rsync the data from the user's scratch to the user's scratch, in short will not do any rsync.


Other optional options are available for various scenarios. 

Scenario 1: Imagine the pipeline run broke, and you need to resubmit it. If a part of the steps were correctly executed, you can resubmit the pipeline starting at a step farther in the pipeline than the first step (default). This is done by adding an argument:
- `scriptId`: String, optional. Default: First script of the pipeline. Code of the script to start the pipeline with. Should have values in `$pipeLineScriptIds${pipelineId}` defined in `configurationSpiresV202410.sh`.

For instance: `bash/submitNrt.sh -E SpiresV202410 -Z 1 daStatis`, to start at the generation of statistics step.

Scenario 2: If you want only to run one step and not the full pipeline, you can use:
- `-U thisStepOnly`: Int, optional. Default: 0, all steps after the script `scriptId` will be executed. 1: only the given step will be executed (=break the pipeline after the step).

Scenario 3: If you want to lower or increase the slurm wall-time of the pipeline:
- `-T controlTime`: String format 00:00:00, optional. Wall-time of the `runSubmitter.sh` execution, beyond which the monitoring of the pipeline will be stopped. By default, time indicated in `configurationSpiresV202410.sh` for the pipeline, $pipeLineControlTime1 for `$pipelineId` = 1.

Scenario 4: you want to automatize the launch of the script, for instance using a chron:
- `-v verbosity`: Int, optional. Default: 0, all logs, including prompts. 10: all logs,
  but no prompt, the script will execute until the end without waiting user's input.
    
## What the script does.    

The script starts by printing the current directory (working directory). Then it collects the option and argument values and print a synthesis, with default values if necessary.

Then it loads `bash/configurationSpiresV202401.sh`, `SpiresV202410` being the option `-E thisEnvironment` given to `submitNrt.sh`. That script first loads `env/.matlabEnvironmentVariablesSpiresV202410`, where all matlab paths are configured for this project. And then it instantiates the configuration of each step of the pipeline `1`, given by the parameter `-Z pipelineId`. The configuration includes the configuration of the pipeline itself, that is (1) the sequence of scripts to execute, given by `pipeLineScriptIds1` for pipelineId 1), (2) the big regions for which data will be generated (for SPIReS v2024.1.0 only `westernUS`), but also (3) individual slurm step submission options such as task number, memory, time-wall.

Once done, the script loads `bash/toolsRegion.sh`. That script instantiates all the region configuration, mainly from `conf/configuration_of_regions.csv`, with a few hard-coded variables.

Then, the script indicates where the pipeline will start, here it should indicate the first step, `mod09gaI`.

Then, the scripts shows the submitLine that will be submitted to slurm and ask confirmation:

```bash
sbatch   --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=spnr2410 --ntasks-per-node=1 --mem=1G --time=11:30:00 --array=1 bash/runSubmitter.sh "sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1"
Do you want to proceed? (y/n) y
```

In this submitLine 1, there is a part submitting `bash/runSubmitter.sh` with its options and another submitLine 2, which is the argument of `runSubmitter.sh`:
```bash
sbatch  --account=XX --qos=XX -o XX/slurm_out/%x_%a_%A.out --job-name=mod09gaI --cpus-per-task=1 --ntasks-per-node=1 --mem=1G --time=01:30:00 --array=292,293,328,329,364 ./bash/runGetMod09gaFiles.sh -A v3.1 -L v061 -O v061 -p mod09ga.061 -w 0 -x XX -y XX -Z 1
```

This second submitLine will be the submission of the first step of the pipeline. 

After the user's reply "y", `runSubmitter.sh` job is submitted. Once started, it will submit the submitLine 2, which will launch a set of jobs corresponding to the first step (or the step given in argument). Then, this step N will submit the next step N+1, with a dependency of the correct execution of step N. And so on sequentially. All along the execution, `runSubmitter.sh` monitors the correct execution of the jobs, update their last line once they achieved, to have a track that they correctly achieved, track that you can scan with the tips in [checking_log](checking_log.md). If a job failed, and if the failure belongs to a set of specific errors, `runSubmitter.sh` will automatically resubmit the job.

(Step 1) It starts by submitting the jobs to download the mod09ga files. Then it submits the 2 steps (Step 2 and Step 3) of the SPIReS v2024.0.1 algorithm in a row, generating 2 intermediary types of files (`spiFillC` and `spiSmooC`). Then (Steps 4 to 9), it submits the steps handling complementary calculation and the generation of the output files (netcdfs, statistics, web-app files). Last (step 10 and 11), it will submit the job rsyncing the output files to the archive and determine the regions to send to the web-app and send them the data.

## Requirements

- The submission should be done on a login node that can submit jobs to a slurm cluster (and not directly from a node of the cluster).

- The submission script **must** be executed once the user is at the root of the project.

- The user needs to have environment variable and alias definition files stored in their home directory: `~.bashrc`, `~.netrc`, `env/.matlabEnvironmentVariablesSpiresV202410`.

- For production (= data that have the potential to be published), the log directory should be unique among all users and users should have r/w access to it, see [installation](install.md#Initialize_the_environment_file_bashrc)

## Previous data generation requirements

The pipeline has some expectations over the input and intermediary data available.

- For a water year N (westernUS), the `spiFillC` data **must** have been generated starting Sept, N - 1 until date of today - 2 months. For instance, if date of today = 03/15/2025, the data must have been generated from 09/01/2024 to 01/31/2025.

- The `dailycsv` statistic files of previous years **must** have been generated, for a correct display on the snow-today website.

- The output .netcdf and `dailycsv` files are generated for the full ongoing water year, from 10/1 until date of today - 1. The geotiffs for the web-app are only generated for the last day.


## More advanced remarks

No other option or argument is available for this submission script. That implies that when specific changes of parametering should be done, either or both `bash/submitNrt.sh` and `bash/configurationSpiresV202410.sh` should be edited locally, as explained for the examples below.

(1) Occasionally, some nodes are to be excluded from the run because they don't work as expected, notably for access to scratch or some libraries or performance issues. For instance, if the nodes are toto and titi, this is done in the script `bash/submitNrt.sh` by changing the line `exclude="";` into `exclude="--exclude=toto,titi";`. The two nodes **must** be part of the slurm cluster.

(2) Some jobs associated to specific steps can occasionally be killed because their necessary execution time is longer than the expected time (wall-time) or they can run into an out of memory error. It's possible to edit the wall-time of a step by editing, in the script `bash/configurationSpiresV202410.sh`, the variable `pipeLineTimes1` (time in hours) and `pipeLineMems1`, respectively. **Important**: increasing memory often requires increasing the number of cpus.



<br><br><br>
