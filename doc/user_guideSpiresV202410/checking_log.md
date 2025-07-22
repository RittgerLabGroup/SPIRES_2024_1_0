# Checking logs and incident analysis.

This page explains how to check the correct execution of the submitted jobs by investigating logs.

Note that Slurm's exit status for a job is not a guarantee that the job was correctly executed, in part because of the complexity of the scripts.

## Preamble.

All monitoring and step jobs have log files centralized in a location determined by the environment variable `$espLogDir` in `~/.bashrc` (see [here](install.md)

Given a Slurm cluster, this location **must** be the same for all users of the project.

This project has three types of jobs/scripts:
- submission scripts. Written in Bash and run on a login node, with an output on the shell.
- monitoring script. Written in Bash and run on the Slurm cluster, with 2 log file outputs for all regions covered, per period requested.
- step script. Written in Bash, Matlab, with .csv configuration files and .nc templates, run on the Slurm cluster, with 1 log file output per region and period requested.

More info on [code organization](code_organization.md)

## Submission scripts.

The submission scripts [run_nrt_pipeline](run_nrt_pipeline.md) and [run_historic_step](run_historic_step.md) display their info on the shell. If the submission to Slurm is successful, they'll display the jobIds of the monitoring job(s) they submitted to Slurm:
```
2024
Submitted batch job 19647584
14:04:59: DONE submission.
```
Here the jobId of the monitoring job is `19647584`.

For historical runs, the year of data generated is also indicated (or water year, depending on the step), here `2024`.

## Monitoring scripts (runSubmitter.sh).

Monitoring jobs are submitted using the submission scripts above. One main script `bash/runSubmitter.sh` is used for these jobs, with ancillary scripts of filepath pattern `bash/tools***.sh`.

### Real time.

The real-time monitoring of a monitoring script job can be carried out with:

*Commands*

```bash
gLog # alias in .bashrc going to the log directory.
tail -f *19647584*.out
```
if the jobId is `19647584`.

This log records the status of the step jobs submitted for each tile, typically:

*Output*

```
Synthesis:
date      ; dura.; script  ; job     ; obj.; cell; date         ; status   ; hostname       ; CPU%; mem%; cores; totalMem; message
.....................................................................
0429T20:45; 00:04; mod09gaI; 19649891;  292;     ; 2025-04-29-2 ; end:DONE ; bgpu-ivc2      ; 1%; 2%; 1; 1 GB; Exit=0, matlab=0, Matlab executed.
0429T20:42; 00:01; mod09gaI; 19649892;  293;     ; 2025-04-29-2 ; start    ; bgpu-ivc2      ; ; ; 1; 1 GB; 
0429T20:42; 00:01; mod09gaI; 19649893;  328;     ; 2025-04-29-2 ; start    ; bgpu-ivc2      ; ; ; 1; 1 GB; 
0429T20:44; 00:03; mod09gaI; 19649894;  329;     ; 2025-04-29-2 ; end:DONE ; bgpu-ivc2      ; 1%; 2%; 1; 1 GB; Exit=0, matlab=0, Matlab executed.
0429T20:48; 00:07; mod09gaI; 19649890;  364;     ; 2025-04-29-2 ; end:DONE ; bgpu-ivc2      ; 1%; 2%; 1; 1 GB; Exit=0, matlab=0, Matlab executed.

Jobs done: 3/5.
```
Which here indicates that for the step mod09gaI, 3 step jobs have been achieved and 2 jobs are still in execution.

### Cancel jobs during execution.

If something goes wrong during the execution and there's for instance an infinite sequences of resubmissions, the user can take advantage of the following procedure to cancel the jobs in a clean way.

First cancel the main monitoring job running the script `runSubmitter.sh`, using the slurm command `scancel`. This will prevent the automatic resubmission of jobs.

Then, list the jobs to be cancelled. For each of them, create an empty file (with command touch) in the user's `$espScratchDir` (defined in `.bashrc`), folder `espJobs`. Each file should have a filename in the format `${slurmJobId}_scancel.txt`, where `${slurmJobId}` is the job id, for instance `${espScratchDir}espJobs/19938144_1093_scancel.txt` for the job `19938144_1093`. 

Once done, the matlab central Data Manager class (`espEnv`) will check if this file exist and if yes will trigger an error that will cancel the job.

Some jobs do not use directly matlab, steps `mod09ga` and `daGeoBig` [at the date of 2025-07-21]. You can cancel these jobs using the slurm command `scancel`.

Last, if you don't have any running job and still see with the command/alias `squeue` some jobs blocked by a dependency, you can execute the alias `scancelDepN` to cancel them all (alias defined in `.bashrc`).

### After execution.

Once the monitoring job has successfully achieved the full sequential series of steps (for the near-real-time pipeline) or the group of jobs associated with a specific step (for historic runs), the log file displays:


*Output*

```
#############################################################################
Absence of begin in submit line. No submit schedule for repeated job.
#############################################################################
```

Note that in some rare cases, this line can be displayed even if a step job has been in error.

When not displayed, the monitoring can be affected by an issue by repeatedly resubmitting a job in error, with the new iteration falling back again in error either because of a bug in the project code or a hardware/software issue with the Slurm cluster, notably with connections. While the code handles many cases now, there's still some work in progress.

A .csv file lists all the jobs executed and their result. To read it:

*Command*

```bash
gLog
cat *19647584*.csv
```


### After execution for historics.

When you run historics, if you submit a lot of monitoring jobs, you can see their results rapidly using the commands above on a **login** node, and after going to the root of the project and loading the Slurm cluster tool module:

*Command*

```bash
cd ${thisEspProjectDir} # $thisEspProjectDir defined in .matlabEnvironmentVariableV, either in env/, or in your home.
ml slurm/xxx
source bash/toolsJobs.sh
get_log_status_for_submit_historics sCRa5 1964
```
which will give the output:

*Output*

```
xxx/sCRa524_1_19640553.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa524_1_19647665.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa524_1_19649865.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa525_1_19649915.out; COMPLETED; Jobs done: 5/5.
```
Here we asked for the result for all monitoring jobs having a job name containing the pattern `sCRa5` (list of monitoring job names in variable `$submitScriptIdJobNames` in `bash/submitHistoric.sh`) and with a monitoring job jobId starting with `1964`. The output shows that all jobs have been successfully achieved.

## Step scripts.

The same log file is used by the Bash and MATLAB code.

### Real time.

The real-time monitoring of a step script job can be carried out with:

*Command*

```bash
gLog
tail -f *292*19647585*.out
```
if the arrayJobId is `19647585` and the id of the region/tile is `292`.
(list of ids in `conf/configuration_of_regionsSpiresV202410.csv`).

Note that the filename includes that arrayJobId and not the jobId (the jobId appears in the column `job` of the array listing the status of every job). 

The list of step arrayJobIds is available in the log file of the monitoring job (see above), in lines:
`Creation of arrayJobIds with parent 19647585`, if the arrayJobId is `19647585`.

A list of jobs in execution is also available on a login node after loading the Slurm cluster tool module:

*Command*

```bash
ml slurm/xxx
squeue # alias defined in .bashrc
```

For scripts calling Matlab, it's possible to get the set of instructions given to Matlab using:

*Command*

```bash
gLog
cat *292*19647585*.out | grep "Matlab string" -A 50
```
Convenient to debug the code on a Matlab interactive session.

### After execution.

After execution, an array synthesizing the achievement status is displayed at the end of the log.

*Output*

```
Date      ; dura.; script  ; job     ; obj.; cel.; date         ; status   ; hostname       ; CPU%; mem%; cores; totalMem; message
.....................................................................
0430T11:16; 00:03; daMosaic; 19650471;  328;     ; 2025-01-31-4 ; end:DONE ; bmem-rico1     ; 11%; 26%; 32; 120 GB; Exit=0, matlab=0, Matlab executed.
```
for instance, for a jobId `19650471`.

The status `end:DONE` is what confirms that the job was correctly executed. This array is obtained by the monitoring script/job to synthesize the status of all the jobs.

## Archiving of logs.

It is advised that logs older than 1 month be archived in a permanent location having enough space, for instance `$espArchiveDirNrt/logs`, with `$espArchiveDirNrt` an archive location defined in *.bashrc*. 

## Incident analysis through log investigation

Production incident 06/27/2025
Procedure to identify the step triggering the incident and collect a Level 2 information ([list of support levels](#levels-of-it-support)).

*Command*

```bash
# 1. Get runSubmitter logs for the last 24 h.
gLog # cd to the central location of the logs.
find . -mtime -1 | grep stnr
```

*Output*

```
>./stnr2410_1_20178646.out
# NB: this can show several logs if several runSubmitter executed.
```

*Command*

```bash
# 2. Get the exit result of the runSubmitter log.
runSubmitterLogPath=stnr2410_1_20178646.out
tail -n 20 ${runSubmitterLogPath}
```

*Output*

```
> [...]
> 0627T06:54; 00:00; webExpSn; 20181932;    5;     ; 2025-06-26-12; end:ERROR; bgpu-casa1     ; 49%; 44%; 2; 3 GB; Exit=1, matlab=ExporterToWebsite:systemCmdError, Line 50: Matlab.
> [...]
> slurmstepd: error: *** JOB 20178646 ON bgpu-casa1 CANCELLED AT 2025-06-27T07:01:09 DUE TO TIME LIMIT ***
# Here the runSubmitter job failed on step webExpSn. The line job CANCELLED suggests that the runSubmitter job resubmitted the step webExpSn multiple times, following multipe failures on this step webExpSn.
```

*Command*

```bash
# 3. Get the first time in runSubmitter log that the step webExpSn failed. This is to be sure that we catch the original error, because steady resubmission of the step can lead to other errors over time.
thisError='webExpSn.*ERROR'; grep -C 10 -E "$thisError" ${runSubmitterLogPath} | head -n 21
```

*Output*

```
> [...]
> FAILED                                                  ; 1:0 
> ${espLogDir}webExpSn_5_2025_06_26_12_20179776.out
> [...]
# Here we get the log of the Slurm job for the step itself, the first time it was executed.
```

*Command*

```bash
# 4. Check the end of the log of the job of step webExpSn the first time it was executer to see if there are details on the error.
stepLogPath=webExpSn_5_2025_06_26_12_20179776.out
tail -n 500 ${stepLogPath}
```

*Output*

```
> instantiation: ExporterToWebsite: Sending cmd rsync -q -i /home/julo9057/.ssh/id_rsa /scratch/alpine/julo9057/modis_ancillary/v3.1/landsubdivision/metadata/26000_subdivisions_202309.json julo9057@nusnow.colorado.edu:/share/apps/snow-today/production/incoming/snow-surface-properties/regions/26000.json ...
> ExporterToWebsite:systemCmdError: ExporterToWebsite: Failed cmd, error 1: rsync: /share/apps/snow-today/production/incoming/snow-surface-properties/regions/26000.json: Permission denied
> [...]
> 0626T23:26; 00:01; webExpSn; 20179776;    5;     ; 2025-06-26-12; end:ERROR; blanca-g4-u14-3; 35%; 39%; 1; 3 GB; Exit=1, matlab=ExporterToWebsite:systemCmdError, Line 50: Matlab.
# Here we see that the step fails on a permission denied from the nusnow server. This might be linked to either (1) bad credentials for the user, (2) saturated storage space on the nusnow server, or (3) transient/permanent connection issues in the nusnow server.
```

So, here, for this incident, the level 2 information could be synthesized as follows:
The near real-time pipeline failed repeatedly on step `webExpn` last night. The issue is a permission denied from the nusnow server, which needs further investigation from Level 1 or others at NSIDC (check if they rsync something to the nusnow with their credentials + storage space on nusnow + issues in the nusnow server).

## Appendices.

### Levels of IT support.

For this project, three levels of support have been defined in 2024 by the PI and NSIDC:

Level 1: Basic understanding of Linux/Bash, Slurm, and logs. Able to run the code, check logs, and identify possible issues based on the synthesis they can see at the end of the log files.

Level 2: Intermediate to good knowledge of Linux/Bash, Slurm, and MATLAB. Comfortable navigating the code structure, understanding how components interact, interpreting logs, and fixing issues that don’t touch the core components—for example, correcting data mismatches or calculation errors.

Level 3: Advanced level with deep knowledge of the full codebase and infrastructure. Can independently understand and debug complex interactions, including core components and environment-level issues.

Technically, in production, the project only allows one Level 3 user because we decided to centralize log writing in the project directory of the Level 3 user (`$level3User` defined in *.bashrc*). Initially, these logs were written in the user's scratch directory, which led to several issues of absence of logs, for instance, when the nodes disconnect from scratch, and a potential low reactivity to share the logs with other users. Sharing is eased here since all users should be part of the group of the level 3 user.

