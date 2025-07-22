#!/bin/bash
#
# Initialize variables used in the helpers of other scripts.for other scripts.

read -r -d '' defaultStringOfOptionsForStepScript << EOM
[-A versionOfAncillary] [-b firstToLastIndex] [c filterConfId] [-d dateOfToday]
[-D waterYearDateString] [-E thisEnvironment] [-h] [-i] [-I objectId] [-L inputLabel]
[-M thisMode]
[-n] [-o] [-O outputLabel] [-p inputProductAndVersion] [-q cellIdx] [-Q countOfCells]
[-r] [-R] [-x scratchPath] [-y archivePath] [-v verbosity] [-w parallelWorkersNb]
[-W espWebEsportConfId] [-z codePlatform] [-Z pipelineId]
EOM

defaultStringOfArgumentsForStepScript=""

read -r -d '' defaultDocumentationOfOptionsForStepScript << EOM
Options:
  -A versionOfAncillary: string, optional. Version of the ancillary data (e.g.
    elevation). If not
    given, takes the default in conf/configuration_of_regions.csv.
  -b firstToLastIndex: int, unused or obligatory. Indicates the index of the first cell
    to handle in the task.
    Used only for a few scripts, including bash/runUpdateDailyStatistics.sh.
  -c filterId: int, optional. Identifies the algorithm configuration and thresholds
    in shared/conf/configuration_of_filters.csv used by the algorithm.
    Default 0 indicates take the filter id of the region configuration, other value
    points to another specific filter configuration.
  -d dateOfToday, string, optional. YYYY-mm-dd. Force the date of today to be a date in
    the past.
    Only used for testing or near real time generation. Default: before 19:00 pm
    mountain time: actual date of today, after 19:00 pm: date of today + 1 day.
  -D waterYearDateString, string, optional. format yyyy-MM-dd-monthWindow. Date
    parameters
    allowing to determine override which period the script is run.
    E.g. 2024-03-26-1, which means runs the month of March 2024 from 1st to 26.
    The period ends by the date defined by yyyy-MM-dd, here
    2024-03-26, and monthWindow, the number of months before this date covering the
    period: 12: 1 full year period, 1: the month of the date, from 1 to the date,
    0: only the date. Default: date of today with monthWindow = 2.
    NB1: if dd > than the last day of the month, then code set it to last day.
    NB2: the water year date is capped by the date of today, no run can be carried
    out for a period in the future.
  -E thisEnvironment: string, obligatory. ESP Environment version. Determines which
    environment, configuration, and code files a job run selects for the project.
    For instance, thisEnvironment=SpiresV202501.
  -h: display help message and exit.
  -i: reserved.
  -I: objectId: int, optional. id of the tile to import, e.g. 292 for h08v04. Full list
    in conf/configuration_of_regions.csv.
    Default: 292 (h08v04). Value of array job overrides the
    value of this option.
  -L inputLabel: string, optional. e.g. v061 (for v6.1) or v2025.0.1. Indicates the
    version of
    the algorithm which was used to produce the input data of the job. This version
    label is included in the directory path of input data files.
  -M thisMode: int, optional. indicates which part of the matlab string is run.
    By default 0, run for all. Used in a few scripts only, including
    bash/runUpdateDailyStatistics.sh.
  -n: reserved.
  -o: reserved.
  -O outputLabel: string, optional. e.g. v2025.0.1. Indicates the version of
    the algorithm which is used by the script to produce the output data of the job.
    This version label is included in the directory path of output data files.
    If -O not precised, inputLabel is used for both input and output files.
  -p inputProductAndVersion: string, optional. Default mod09ga.061. Code of the remote
    sensing input product and its version, for the default MOD09GA, version 6.1.
    product in the production chain
  -q cellIdx: int, unused or obligatory. Index of the cell to handle in a tile.
    Only used for a few scripts.
  -Q countOfCells: int, unused or obligatory. Total number of cells, used in the same
    scripts as option -q.
  -r: reserved.
  -R: reserved.
  -v: reserved.
  -w parallelWorkersNb: int, optional. Number of parallel workers. By default affects 1
    parallel worker to each "physical" node in Matlab.
  -W espWebEsportConfId: int, optional. Default 0: export to production web-app for the
    Snow-Today website; 1: integration; 2: qualification platform.
  -x scratchPath: string, optional. scratch storage location. This temporary location is
    for increased read/write performance, compared to archive. The output
    files can later be sync back to archive. Logs are also stored in scratch.
    Default: environment variable $espScratchDir.
  -y archivePath: string, optional. permanent storage location.
    Default: environment variable $espArchiveDir.
  -z codePlatform: int, optional. Default: 0 production code, 1: development code. Only
    used for the generation of output to export to the webapp at the step webExpSn.
  -Z pipeLineId: int, optional. If set, takes the configuration of the near real-time
    pipeline in configuration${thisEnvironment}.sh to carry it out until the end.
EOM

read -r -d '' defaultDocumentationOfArgumentsForStepScript << EOM
Arguments:
  None
EOM

read -r -d '' defaultDocumentationOfSbatchParametersForStepScript << EOM
Sbatch parameters:
  --account=${slurmAccount}: string, obligatory. Account used to connect to the
    slurm partitions. Depends on the slurm cluster.
  --constraint=spsc: optional. To avoid allocation on nodes having jumbo internet
    connections 9000 instead of the classic 1500, necessary to connect to the daac
    servers. Doesnt seem necessary on Cluster #1 nodes.
  --cpus-per-task=1, obligatory. This parameter ensures that the cores requested will be
    all physical cores. This option seems to reduce out-of-memory errors when using
    Matlab parallel toolbox.
  --exclude=xxx. string list, optional. List nodes you dont want your job be
    allocated on. List is of one node, or several nodes stuck and separated with
    commas. Mostly used when some nodes have problems to run your script
    correctly. In particular when a cluster has a heterogeneous configuration of nodes
    (cluster #2). Not used for clusters with homogenous nodes (Cluster #1).
  --export=NONE: to prevent local variables to override your environment variables.
    Important when using Cluster #2 to avoid the no matlab module error.
  --job-name=${scriptId}-${objectId}-${waterYearDateString}: string. Name of the job.
    Should include the id the object and the date over which the script runs.
  --ntasks-per-node=1: number of cores to be allocated.
  --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS: sends e-mail when
    job in error or requeued by sys admin. ARRAY_TASKS indicates that one e-mail
    per array task id is sent. If want in all cases, add values BEGIN,END,STAGE_OUT.
    If want no e-mail, replace the full string by NONE.
  --mail-user=xxx@xxx: e-mail addresses to where the e-mails are sent. If not set,
    default to user e-mail.
  --mem=1G: string, obligatory. Memory to be allocated. On Cluster #1 Qos #1, memory
    is dependent on the number of cores, each core having 3.8G, and this parameter can
    override ntasks-per-node. E.g. here if I set --mem 5G, qos #1 will require 2 cores
    instead of 1. On Cluster #2 Qos #2, the 2 parameters are independent.
    NB: this mem is the peak of memory you will be allowed. If the script requires
    a higher peak at some point, slurm stops the job with an out of memory error.
  -o=${slurmLogDir}%x-%A_%a.out: string, obligatory. Location of the log file. %x for
    the job name, %A for the id of the job and %a for the array task id.
    NB1: This location should NOT be on scratch and should be centralized on level 2 or
    3 project directory, with read access for all members of the project. Scratch has
    been to be occasionally unaccessible by some nodes.
    NB2: the directory of the log file MUST exist otherwise slurm doesnt write the logs.
    NB3: this output log filepath is not transferred to the script as a variable. So
    we have to redefine it in toolStart.sh as $THISSBATCH_OUTPUT. Keep the -o string
    to %x-%A_%a.out, or change both $THISSBATCH_OUTPUT and the -o string.
  --qos=${slurmQos}: string, obligatory. Indicates which pool of nodes you ask your
    allocation for.
  --time=HH:mm:ss: string format time, obligatory. Indicate the wall-time after which
    slurm will automatically cancel the job (kill signal).
    NB1: It's essential to have this time long enough when data are saved in a
    format prone to file corruption (e.g. .mat files when we add variables).
  --array=292,293: string, obligatory. List of objectIds, ob. Ids of the tiles on which
    the script should run. List of ids in shared/sh/toolsRegion.sh. This parameter
    override the -I script option. Variable $SLURM_ARRAY_TASK_ID in the script.
EOM

# Functions.
#---------------------------------------------------------------------------------------
usage() {
  source bash/configurationForHelp.sh
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    ${defaultStringOfOptionsForStepScript}
    ${defaultStringOfArgumentsForStepScript}
    Imports mog09ga v6.1 tiles for a region and period.
  ${defaultDocumentationOfOptionsForStepScript}
  ${defaultDocumentationOfArgumentsForStepScript}
  ${defaultDocumentationOfSbatchParametersForStepScript}

EOM
  printf "$thisUsage\n" 1>&2
}
