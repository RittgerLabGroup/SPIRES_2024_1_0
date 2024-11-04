# RC 20240513

# Parameters and aliases specific to the platform.
########################################################################################

# Source global definitions.
# HIDDEN
# HIDDEN
# HIDDEN

# Supercomputer environment parameters.
export archiveDir= # HIDDEN
export archiveDir1= # HIDDEN
export archiveDir2= # HIDDEN
export myHome= # HIDDEN
export projectDir= # HIDDEN 
export slurmName1= # HIDDEN
export slurmName2= # HIDDEN
export slurmAccount1= # HIDDEN
export slurmAccount2= # HIDDEN
export slurmPartition1= # HIDDEN
export slurmPartition2=
export slurmQos1= # HIDDEN
export slurmQos2= # HIDDEN
export slurmAlternativeQos2= # HIDDEN
export slurmScratchDir1= # HIDDEN
export slurmAlternativeScratchDir1= # HIDDEN
export slurmScratchDir2= # HIDDEN
export loginNodeDomain= # HIDDEN

# ESP earthData NRT token wget Modis tiles
export nrt3ModapsEosdisNasaGovToken= # HIDDEN

# ESP web export to the web-app environment parameters.
export espWebExportDomain= # HIDDEN
export espWebExportRootDir= # HIDDEN
export espWebExportRootDirForProd=${espWebExportRootDir}production/incoming/
export espWebExportRootDirForIntegration=${espWebExportRootDir}integration/incoming/
export espWebExportRootDirForQA=${espWebExportRootDir}qa/incoming/
export espWebExportSshKeyFilePath=  # HIDDEN
# Replace by the path to your ssh key file.
export espWebExportUser=  # HIDDEN

# Other parameters and aliases.
########################################################################################
# Prompt display time.
PS1="[\A \u@\h \W]\$ "
# File rights
umask u=rwx,g=rwx,o=rx

# ESP environment variables
export espArchiveDir=${archiveDir1}
export espArchiveDirNrt=${archiveDir2}
export espProjectDir=${projectDir}MATLAB/esp/
export espDevProjectDir==${projectDir}dev/esp/
export slurmLogDir1=${slurmScratchDir1}slurm_out/
export slurmLogDir2=${slurmScratchDir2}slurm_out/
export espScratchDir=${slurmScratchDir1}
export espScratchDirAlias=${slurmAlternativeScratchDir1}
export espLogDir=${projectDir}slurm_out/
export espLogSnDir=${projectDir}slurm_out_SnowToday/

# User specific aliases and functions
alias gEspArchive="cd ${espArchiveDirNrt}"
alias gEsp="cd ${espProjectDir}"
alias gDevEsp="cd ${espDevProjectDir}"
alias gEspScratch="cd ${espScratchDir}"
alias gHome="cd ${myHome}"
alias gLog="cd ${espLogDir}"
alias sshLogin="ssh -X ${loginNodeDomain}"
alias sshSlurm="ssh -X $SLURM_NODELIST"
alias startAlpine="ml slurm/${slurmName1}; salloc --nodes=1 --time=18:00:00 --ntasks=2 --partition=${slurmPartition1} --account=${slurmAccount1};"
alias startQgis='module purge; module load mambaforge; conda activate qgis.3.36.0; qgis;'
alias scancelDepN="squeue -h -t PD -O jobid,reason | awk '/DependencyNeverSatis/ {print \$1}' | xargs scancel"
alias scancelInt="squeue -h -t R -O jobid,name | awk '/interactive/ {print \$1}' | xargs scancel"

alias squeue='squeue -u ${USER}'
alias rm='rm -i'
alias rsync='/bin/rsync -HpvxrltoDu --chmod=ug+rw,o-w,+X,Dg+s'
alias watchq='ml slurm/${slurmName1}; watch -d -n 2 "squeue --user=${USER} --long"'
alias iAlpineBig="ml slurm/${slurmName1}; salloc --nodes=1 --time=04:00:00 --ntasks=20 --mem=50G --partition=${slurmPartition1} --account=${slurmAccount1}"
alias iAlpineSmall="ml slurm/${slurmName1}; salloc --nodes=1 --time=10:00:00 --ntasks=2 --partition=${slurmPartition1} --account=${slurmAccount1}"
alias iBlancaSmall="ml slurm/${slurmName2}; salloc --nodes=1 --time=10:00:00 --ntasks=2 --mem=60G --qos ${slurmQos2} --account ${slurmAccount2}"
alias iBlancaBig="ml slurm/${slurmName2}; salloc --nodes=1 --time=10:00:00 --ntasks=20 --mem=180G --qos ${slurmQos2} --account ${slurmAccount2}"
alias iBlancaBigOld="ml slurm/${slurmName2}; salloc --nodes=1 --time=10:00:00 --ntasks=32 --mem=188G --qos ${slurmAlternativeQos2} --account ${slurmAccount2}"
alias startMatlab="source ~/.matlabEnvironmentVariables; gEsp; ml gcc/11.2.0; ml gdal/3.5.0; ml matlab/R2021b; export TMP=${espScratchDir}; export TMPDIR=${espScratchDir}; matlab"
alias startDevMatlab="source ~/.matlabDevEnvironmentVariables; gDevEsp; ml gcc/11.2.0; ml gdal/3.5.0; ml matlab/R2021b; export TMP=${espScratchDir}; export TMPDIR=${espScratchDir}; matlab"
