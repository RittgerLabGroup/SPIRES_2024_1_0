# Checking logs and incident analysis.

This page explains how to check the correct execution of the submitted jobs by investigaeting logs.

Note that slurm's exit status for a job is not a guarantee that the job correctly executed, in part because of the complexity of the scripts.

## Preamble.

All monitoring and step jobs have log files centralized in a location determined by the environment variable `$espLogDir` in `~.bashrc` (see [here](install.md)

Given a slurm cluster, this location **must** be the same for all users of the project.

This project has three types of jobs/scripts:
- submission scripts. Written in bash and run on a login node, with an output on the shell.
- monitoring script. Written in bash and run on slurm cluster, with 2 log file output for all regions covered, per period requested.
- step script. Written in bash, Matlab, with .csv configuration files and .nc templates, run on slurm cluster, with 1 log file output per region and period requested.

More info on [code organization](code_organization.md)

## Submission scripts.

The submission scripts [run_nrt_pipeline](run_nrt_pipeline.md) and [run_historic_step](run_historic_step.md) display their info on the shell. If the submission to slurm is successful, they'll display the jobIds of the monitoring job(s) they submitted to slurm:
```
2024
Submitted batch job 19647584
14:04:59: DONE submission.
```
Here the jobId of the monitoring job is `19647584`.

For historic runs, the year of data generated is also indicated (or water year, depending the step), here `2024`.

## Monitoring scripts (runSubmitter.sh).

Monitoring jobs are submitted using the submission scripts above. One main script `bash/runSubmitter.sh` is used for these jobs, with ancillary scripts of filepath pattern `bash/tools***.sh`.

### Real time.

The real time monitoring of a monitoring script job can be carried out with:
```gLog # alias in .bashrc going to the log directory.
tail -f *19647584*.out
```
if the jobId is `19647584`.

This log records the status of the step jobs submitted for each tile, typically:
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
Which here indicates that for the step mod09gaI, 3 step jobs are been achieved and 2 jobs are still in execution.

### After execution.

Once the monitoring job has successfully achieved the full sequential series of steps (for the near-real-time pipeline) or the group of jobs associated to a specific step (for historic runs), the log file displays:
```
#############################################################################
Absence of begin in submit line. No submit schedule for repeated job.
#############################################################################
```

Note that in some rare cases, this line can be displayed even if a step job has been in error.

When not displayed, the monitoring can be affected by an issue by repeatingly resubmitting a job in error, with the new iteration falling back again in error either because of a bug in the project code, or of a hardware/software issue with the slurm cluster, notably with connections. While the code handles many cases now, there's still some work in progress.

A .csv file lists all the jobs executed and their result. To read it:
```gLog
cat *19647584*.csv
```


### After execution for historics.

When you run historics, if you submit a lot of monitoring jobs, you can see their results rapidly using the commands above on a **login** node, and after going to the root of the project and loading the slurm cluster tool module:
```
cd ${thisEspProjectDir} # $thisEspProjectDir defined in .matlabEnvironmentVariableV, either in env/, or in your home.
ml slurm/xxx
source shared/sh/toolsJobs.sh
get_log_status_for_submit_historics sCRa5 1964
```
which will give the output:
```
xxx/sCRa524_1_19640553.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa524_1_19647665.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa524_1_19649865.out; COMPLETED; Jobs done: 5/5.
xxx/sCRa525_1_19649915.out; COMPLETED; Jobs done: 5/5.
```
Here we asked the result for all monitoring job having a job name containing the pattern `sCRa5` (list of monitoring jobnames in variable `$submitScriptIdJobNames` in `bash/submitHistoric.sh`) and with monitoring jobId starting by `1964`. The output shows that all jobs have been successfully achieved.

## Step scripts.

The same log file is used by the bash and matlab code.

### Real time.

The real time monitoring of a step script job can be carried out with:
```
gLog
tail -f *292*19647585*.out
```
if the arrayJobId is `19647585` and the id of the region/tile is `292` (list of ids in `conf/configuration_of_regions${thisEnvironment}.csv` or by default in `conf/configuration_of_regions.csv`), with `$thisEnvironment=SpiresV202410`.

Note that the filename includes that arrayJobId and not the jobId (the jobId appears in the column `job` of the array listing the status of every job. 

The list of step arrayJobIds is available in the log file of the monitoring job (see above), in lines:
`Creation of arrayJobIds with parent 19647585`, if the arrayJobId is `19647585`.

A list of jobs in execution is also available using on a login node, after loading the slurm cluster tool module:
```
ml slurm/xxx
squeue # alias defined in .bashrc
```

For scripts calling Matlab, it's possible to get the set of instructions given to Matlab using:
```
gLog
cat *292*19647585*.out | grep "Matlab string" -A 50
```
Convenient to debug the code on a Matlab interactive session.

### After execution.

After execution, an array synthetizing the achievement status is displayed at the end of the log.
```
Date      ; dura.; script  ; job     ; obj.; cel.; date         ; status   ; hostname       ; CPU%; mem%; cores; totalMem; message
.....................................................................
0430T11:16; 00:03; daMosaic; 19650471;  328;     ; 2025-01-31-4 ; end:DONE ; bmem-rico1     ; 11%; 26%; 32; 120 GB; Exit=0, matlab=0, Matlab executed.
```
for instance for a jobId `19650471`.

The status `end:DONE` is what confirms that the job correctly exectuted. This array is get by the monitoring script/job to synthesize the status of all the jobs.

## Archiving of logs.

It is advised that logs older than 1 month be archived in a permanent location having enough space, for instance `$espArchiveDirNrt/logs`, with `$espArchiveDirNrt` an archive location defined in `.bashrc`. 

## Incident analysis through log investigation

Production incident 06/27/2025
Procedure to identify the step triggering the incident and collect a level 2 information.
```
# 1. Get runSubmitter logs for the last 24 h.
gLog # cd to the central location of the logs.
find . -mtime -1 | grep stnr

>./stnr2410_1_20178646.out
# NB: this can show several logs if several runSubmitter executed.

# 2. Get the exit result of the runSubmitter log.
runSubmitterLogPath=stnr2410_1_20178646.out
tail -n 20 ${runSubmitterLogPath}

> [...]
> 0627T06:54; 00:00; webExpSn; 20181932;    5;     ; 2025-06-26-12; end:ERROR; bgpu-casa1     ; 49%; 44%; 2; 3 GB; Exit=1, matlab=ExporterToWebsite:systemCmdError, Line 50: Matlab.
> [...]
> slurmstepd: error: *** JOB 20178646 ON bgpu-casa1 CANCELLED AT 2025-06-27T07:01:09 DUE TO TIME LIMIT ***
# Here the runSubmitter job failed on step webExpSn. The line job CANCELLED suggests that the runSubmitter job resubmitted the step webExpSn multiple times, following multipe failures on this step webExpSn.

# 3. Get the first time in runSubmitter log that the step webExpSn failed. This is to be sure that we catch the original error, because steady resubmission of the step can lead to other errors over time.
thisError='webExpSn.*ERROR'; grep -C 10 -E "$thisError" ${runSubmitterLogPath} | head -n 21

> [...]
> FAILED                                                  ; 1:0 
> /projects/sele7124/slurm_out/webExpSn_5_2025_06_26_12_20179776.out
> [...]
# Here we get the log of the slurm job for the step itself, the first time it was executed.

# 4. Check the end of the log of the job of step webExpSn the first time it was executer to see if there are details on the error.
stepLogPath=webExpSn_5_2025_06_26_12_20179776.out
tail -n 500 ${stepLogPath}

> instantiation: ExporterToWebsite: Sending cmd scp -q -i /home/julo9057/.ssh/id_rsa /scratch/alpine/julo9057/modis_ancillary/v3.1/landsubdivision/metadata/26000_subdivisions_202309.json julo9057@nusnow.colorado.edu:/share/apps/snow-today/production/incoming/snow-surface-properties/regions/26000.json ...
> ExporterToWebsite:systemCmdError: ExporterToWebsite: Failed cmd, error 1: scp: /share/apps/snow-today/production/incoming/snow-surface-properties/regions/26000.json: Permission denied
> [...]
> 0626T23:26; 00:01; webExpSn; 20179776;    5;     ; 2025-06-26-12; end:ERROR; blanca-g4-u14-3; 35%; 39%; 1; 3 GB; Exit=1, matlab=ExporterToWebsite:systemCmdError, Line 50: Matlab.
# Here we see that the step fails on a permission denied from the nusnow server. This might be linked to either (1) bad credentials for the user, (2) saturated storage space on the nusnow server, or (3) transient/permanent connection issues in the nusnow server.
```

So, here, for this incident, the level 2 information could be synthesized as following:
Near real time pipeline failed repeatedly on step `webExpn` last night. The issue is a permission denied from the nusnow server, which needs further investigation from Level 1 or other at NSIDC (check if they scp something to the nusnow with their credentials + storage space on nusnow + issues in the nusnow server).