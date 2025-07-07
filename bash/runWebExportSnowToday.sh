#!/bin/bash
#
# script to export landsubdivision metadata, shapefiles, geotiffs and plots to
# SnowToday web-app.

#SBATCH --export=NONE
#SBATCH --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS

# Functions.
########################################################################################
usage() {
  read -r -d '' thisUsage << EOM

  Usage: ${PROGNAME}
    [-h] [-i] [-L inputLabel]
    [-R] [-v] [-x scratchPath] [-y archivePath] [-Z]
    Imports mog09ga v6.1 tiles for a region and period.
  Options:
    -h: display help message and exit.
    -i: update input data from archive to scratch. Default: no update.
    -L inputLabel: string with version label for directories. For mod09ga, is v006 or
      v061, for version 6.0 or version 6.1 of the tiles. NB: v6.0 is deprecated and
      shouldnt be used in this script.
    -R: repeat the job later with same parameters. Default: no repeat. Option -D
      overrides this option and set the job to no repeat.
    -v verbosityLevel: int. Also called log level. Default: 0, all logs. Increased
      values: less logs.
    -x: scratchPath: string, scratch storage location. This temporary location is
      for increased performance in read/write, compared to archive. The output
      files can later be sync back to archive. Logs are also stored in scratch.
      Default: environment variable $espScratchDir.
      NB: the scratchPath is dependent on the cluster alpine or blanca, and each
      cluster cannot access to the scratch of the other cluster.
    -y: archivePath: string, permanent storage location.
      Default: environment variable $espArchiveDir.
    -Z: pipeLineId: if set, indicates that a next script will be launch when the array
      job is achieved in success. The next script and version are determined based on
      the pipelineId. If set to 0, no pipeline. Additionally, indicates the end of the
      list of options for the pipeline parser and MUST always be positioned at the end
      of options.
  Arguments:
    None
  Sbatch parameters:
    --account=${slurmAccount}: string, obligatory. Account used to connect to the
      slurm partitions. Differs from blanca to alpine.
    --constraint=spsc: optional. To avoid allocation on nodes having jumbo internet
      connections 9000 instead of the classic 1500, necessary to connect to the daac
      servers. Doesnt seem necessary on alpine nodes.
    --exclude=xxx. string list, optional. List nodes you dont want your job be
      allocated on. List is of one node, or several nodes stuck and separated with
      commas. Mostly used when some blanca nodes have problems to run your script
      correctly, because those nodes have a more heterogeneous configuration than on
      alpine.
    --export=NONE: to prevent local variables to override your environment variables.
      Important when using blanca to avoid the no matlab module error.
    --job-name=mod09ga-${objectId}-${waterYearDateString}: string. Name of the job.
      Should include the id the object and the date over which the script runs.
    --ntasks-per-node=1: number of cores to be allocated.
    --mail-type=FAIL,INVALID_DEPEND,TIME_LIMIT,REQUEUE,ARRAY_TASKS: sends e-mail when
      job in error or requeued by sys admin. ARRAY_TASKS indicates that one e-mail
      per array task id is sent. If want in all cases, add values BEGIN,END,STAGE_OUT.
      If want no e-mail, replace the full string by NONE.
    --mail-user=xxx  xxx: e-mail addresses to where the e-mails are sent. If not set,
      default to user e-mail.
    --mem=1G: memory to be allocated. On Alpine qos normal, memory is dependent on
      the number of cores, each core having 3.8G, and this parameter can override
      ntasks-per-node. E.g. here if I set --mem 5G, alpine will require 2 cores
      instead of 1. On Blanca qos preemptable, the 2 parameters are independent.
      NB: this mem is the peak of memory you will be allowed. If the script requires
      a higher peak at some point, slurm stops the job with an out of memory error.
    -o=${slurmLogDir}%x-%A_%a.out: string. Location of the log file. %x for the job
      name, %A for the id of the job and %a for the array task id.
      NB: This location should be on the correct scratch of the alpine or blanca
      cluster. Each cluster cannot access to the scratch of the other cluster.
      NB: the directory of the log file MUST exis otherwise slurm doesnt write the
      logs.
      NB: this output log filepath is not transferred to the script as a variable. So
      we have to redefine it in toolStart.sh as $THISSBATCH_OUTPUT. Keep the -o string
      to %x-%A_%a.out, or change both $THISSBATCH_OUTPUT and the -o string.
    --qos=${slurmQos}: string, obligatory. Indicates which pool of nodes you ask your
      allocation for. For alpine --qos=normal, for blanca --qos=preemptable. Other
      qos are also available.
    --time=HH:mm:ss: string format time, obligatory. Indicate the time at which slurm
      will automatically cancel the job.
    --array=5: list of only one objectId. (List of ids in toolsRegion.sh). This
      parameter override the -I script option. Variable SLURM_ARRAY_TASK_ID in the
      script. Not used presently.
  Output:
    Scratch and archive, subfolder modis/input/mod09ga/

EOM
  printf "$thisUsage\n" 1>&2
}

export SLURM_EXPORT_ENV=ALL

# Core script.
########################################################################################
# Main script constants.
# Can be overriden by pipeline parameters in configuration.sh, itself can be overriden
# by main script options.
scriptId=webExpSn
defaultSlurmArrayTaskId=5
expectedCountOfArguments=
inputDataLabels=(VariablesGeotiff SubdivisionStatsWebJson SubdivisionStatsWebCsvv20231)
outputDataLabels=
filterConfLabel=
mainBashSource=${BASH_SOURCE}
mainProgramName=${BASH_SOURCE[0]}
  # overriden by slurm in toolsStart.sh
beginTime=

# Following can be overriden by pipeling configuration.sh
thisRegionType=10
thisSequence=
thisSequenceMultiplierToIndices=
thisMonthWindow=12

source bash/toolsStart.sh
if [ $? -eq 1 ]; then
  exit 1
fi

# Argument setting.
# None.

source bash/toolsMatlab.sh

# Matlab.
########################################################################################
read -r -d '' matlabString << EOM

clear;
try;
  % Generate the landsubdivision metadata to be transferred to SnowToday web-app.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  % NB: the shapefiles are not generated here (but aside, occasionally, with a qgis
  % routine.
  toBeUsedFlag = 1; % Use a higher value when you want to export a restricted set of
    % subdivisions, based on isUsed field in espEnv.myConf.landsubdivision and
    % espEnv.myConf.landsubdivisionlink.
  uncondensedJson = 1;
  includeSubdivisionTypeInJson = 0;
  ${packagePathInstantiation}
  ${modisDataInstantiation}
  ${waterYearDateInstantiation}
  ${espEnvWOFilterInstantiation}
  dateOfToday = datetime(${dateOfTodayString});

  % Get the subdivision names and source regions (to get ancillary version) and
  % the hierarchy from the configuration.
  espEnvWOFilter.setAdditionalConf('landsubdivision', ...
    confFieldNames = {'name', 'id', 'code', 'subdivisionType', 'sourceRegionId', ...
    'sourceRegionName', 'used', 'root', 'CRS', 'firstMonthOfWaterYear', ...
    'version', 'versionOfAncillary'});
  espEnvWOFilter.setAdditionalConf('landsubdivisionlink');
  espEnvWOFilter.setAdditionalConf('landsubdivisiontype');
  espEnvWOFilter.setAdditionalConf('webname');

  ancillaryOutput = AncillaryOutput(espEnvWOFilter, ...
    includeSubdivisionTypeInJson = includeSubdivisionTypeInJson, ...
    toBeUsedFlag = toBeUsedFlag, uncondensedJson = uncondensedJson);

  ancillaryOutput.writeSubdivisionTypes();
  % No ancillaryOutput.writeVariables() because variables are stored in static (github).
  rootSubdivisionTable = ancillaryOutput.writeRootSubdivisions(dateOfToday = dateOfToday);
    % NB: Dont forget to update configuration_of_landsubdivisions with the correct
    % version (e.g. v2025.0.1) for the root subdivisions.                       @warning
  subdivisionTable = ancillaryOutput.writeSubdivisionLinks();
  ancillaryOutput.writeSubdivisionMetadata(subdivisionTable);

  % Transfer the metadata and shapefiles to SnowToday web-app.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  versionOfAncillariesToExport = {'v3.1', 'v3.2'}; % all these versions are exported.
  dataLabels = {'landsubdivisioninjson', ...
    'landsubdivisionlinkinjson', 'landsubdivisionrootinjson', ...
    'landsubdivisionshapeingeojson', 'landsubdivisiontypeinjson'};
      % 'webvariableconfinjson' not necessary because
      % stored as a static file.
  thisDate = '';
  varName = '';
  complementaryLabel = '';
  % setenv('espWebExportRootDir', getenv('espWebExportRootDirForIntegration'));
  % setenv('espWebExportRootDir', getenv('espWebExportRootDirForQA'));
  % setenv('espWebExportRootDir', getenv('espWebExportRootDirForProd'));
  exporter = ExporterToWebsite(espEnvWOFilter, versionOfAncillariesToExport, ...
    toBeUsedFlag = toBeUsedFlag);
  for dataLabelIdx = 1:length(dataLabels);
    dataLabel = dataLabels{dataLabelIdx};
    exporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, varName, ...
      complementaryLabel);
  end;

  for rootIdx = 1:height(rootSubdivisionTable);
    % Transfer the geotiffs to SnowToday web-app.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % Don't forget to generate the geotiffs and stats before.
    % NB: some root subdivisions share the same geotiffs (USAlaska and Western Canada).
    % NB: Automatically transfer the last available geotiffs. The root region json file
    % also has its last date of data set to the data date of the last available
    % geotiffs.

    complementaryLabel = ['EPSG_', num2str(Regions.webGeotiffEPSG)];
    regionName = '';
    originalEspEnv = exporter.espEnv;
    version = rootSubdivisionTable.version{rootIdx};
    versionOfAncillary = rootSubdivisionTable.versionOfAncillary{rootIdx};

    thisEspEnv = ESPEnv.getESPEnvForRegionNameFromESPEnv(regionName, ...
      originalEspEnv, version = version, ...
      versionOfAncillary = versionOfAncillary);
    if ismember(thisEspEnv.modisData.versionOf.VariablesGeotiff, {'v2024.0d', 'v2024.1.0'});
      dataLabel = 'VariablesGeotiff';
    else;
      dataLabel = 'spiresdailytifproj';
    end;
    thisExporter = ExporterToWebsite(thisEspEnv, versionOfAncillariesToExport, ...
      toBeUsedFlag = toBeUsedFlag);
    varNames = unique(thisEspEnv.myConf.variableregion( ...
      thisEspEnv.myConf.variableregion.writeGeotiffs == 1, :).output_name);

    for varIdx = 1:length(varNames);
      varName = varNames{varIdx};
      thisExporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, ...
          varName, complementaryLabel);
    end;

    % Transfer the .json plots to SnowToday web-app.
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    dataLabel = 'SubdivisionStatsWebJson';
    complementaryLabel = '';
    varNames = unique(thisEspEnv.myConf.variableregion( ...
        thisEspEnv.myConf.variableregion.writeStats == 1, :).output_name);
    for varIdx = 1:length(varNames);
      varName = varNames{varIdx};
      thisExporter.exportFileForDataLabelDateAndVarName(dataLabel, thisDate, ...
        varName, complementaryLabel);
    end;
  end;

  % Trigger web-app ingest.
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
  exporter.generateAndExportTrigger(); % Beware this will launch ingestion.

${catchExceptionAndExit}

EOM

# Launch Matlab and terminate bash script.
source bash/toolsStop.sh
