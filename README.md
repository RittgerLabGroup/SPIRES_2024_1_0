# ESP

Earth Surface Properties Toolbox

A Matlab toolbox for creating and analyzing Earth Surface Properties (ESP) products.

## Installation Notes

### Installing ESPToolbox as a proper toolbox

Normally, we should have a matlab toolbox built and ready for you to install.

However, Sebastien and I worked on a number of changes in Fall 2022 that broke
the automatic toolbox build functionality. We will need to fix that when he
comes back on the project. When that is done, you should be able to install it
directly from the .mltbx file:

To install the ESPToolbox:

1.  Download the file "ESPToolbox\ vX.Y.mltbx" to your ~/Documents/MATLAB
    directory
2.  Double-click it to add it to your matlab path.
3.  Get help with:

> >> doc ESPToolbox

### Installing ESPToolbox by cloning the git repo

In the meantime, the alternative is to clone the esp repository to your
/projects/$USER/ directory like this:

```
cd /projects/$USER
mkdir -p Documents/MATLAB
cd Documents/MATLAB
git clone git@github.com:mjbrodzik/esp.git
```

This will clone the project to the directory "esp".

## Install dependencies

### Define symlink for pathdef.m file

The system can be configured to run with different versions of Matlab. This is
controlled with a symlink that sets your processing to point to the version you
plan to run. The current system is tested for Matlab R2021b, so do this before 
you run Matlab (either directly or through the bash scripts) for the first time:

```
cd /projects/${USER}/Documents/MATLAB/esp
ln -s pathdef_esp_dev_R2021b.m pathdef.m
```

### Required Matlab toolboxes

The user of this toolbox will need to have a license to run:

* Financial Toolbox
* Mapping Toolbox

To check that these are installed in your version of Matlab:

1. [Connect to the Matlab GUI from a viz node](#matlab-gui)

2. In the GUI Command Window, check for currently installed Toolboxes with the
'ver' command:

```
>> ver
```

3. [OPTIONAL] I think that the standard CURC matlab does activate these Toolboxes, but if
you find that you need to install some others, another way to get addon details is:

```
>> stuff = matlab.addons.installedAddons
```

this will populate a table with names and versions of all currently installed Toolboxes. In the Workspace Window, you can click on it to sort/see it.

3. [OPTIONAL] To install a new Toolbox:
   - in the GUI top nav "AddOns->Manage AddOns"
   - in Add-On Manager window, top right, "Get Add-Ons"
   - in the Add-On Explorer window, search for the toolbox you want
   - click "Add" and follow prompts (you will need to create a CU Mathworks account for this to work)

### Other Required Matlab packages

Go to the location where you have installed the esp repository and install the
following packages from github:

1. ParBal, for albedo calculations:
   - git clone git@github.com:edwardbair/ParBal.git
2. RasterReprojection, for reprojecting raster images:
   - git clone git@github.com:DozierJeff/RasterReprojection.git

These packages are assumed to be installed in the same location as "esp" (as sibling directories to your clone of "esp").  This
is controlled from the pathdef.m file.

### Test installation and dependencies

1. [Connect to the Matlab GUI from a viz node](#matlab-gui)
2. At the command window, type

```
>>> path
```

and confirm that the output includes your installed locations of ParBal and RasterReprojection.

### System dependencies

A working version of wget is required to run fetch routines from JPL.

In the past I have had to install my own copy of wget, but it looks like the
current Alpine system already has it configured.

If we find that wget is not available to you, we should contact
rc-help@colorado.edu for their recommendation on how to get it installed.

## Operational Notes

### The "scratch shuffle"

The STC pipeline is an I/O-intensive process that produces several versions of
data files at each step in the process:

1. The original input files from JPL are organized as daily MODIS tiles with
MOD09GA reflectances, MODSCAG output and MODDRFS output

2. "intermediary" files are monthly space-time MODIS tile cubes for 3 levels of
aggregation: so-called "raw", "gap" and "stc"

3. "variables" files are potentially multi-tile, daily mosaics, with
spatially-temporally complete layers of multiple variables, including
snow/rock/veg fraction and derived variables like radiative forcing and albedo;
"variables" files can be .mat format, and can also include geotiff renderings of
specific variables.

4. "regional_stats" files are statistics derived from variables files, and can
represent a long multi-year time series, or just the statistics for a single
water year

Our authoritative archive for all of these data is /pl/active/rittget_esp/.
This PetaLibrary storage is robust and reliable, but access times make
performance very slow.  As we have worked with the operational system, a review
of the PetaLibrary performance led the RC-help staff to recommend that we do our
daily processing on scratch storage. Scratch storage is temporary space and
should not be used for reliable long-term storage. Files are automatically set
to age off after residing on scratach for 90 days. The advantage to scratch is
that it is fast: processing times for the STC pipeline take only 10-20% of wall
time that they did when using petalibrary locations for data files.

I have designed what I call the "scratch shuffle" to handle the transfer of only
those files needed as input for each step (by tile/year/type) from PetaLibrary
to the user's scratch space, and then for transfer of only those new files
produced in that step back from scratch to PetaLibrary.  This has been tested
since November 2022, and is a new concept for this year's processing.  Each of
the flowcharts has gray arrows with general indications of what is needed for
the scratch shuffle to work for each step.

### File permissions

The pipeline will be reading and writing data on /pl/active/rittger_esp/. Anyone running the
pipeline should be a member of Karl Rittger's shared group: kari0458grp. The group sticky-bit for this
PetaLibrary location is set to kari0458grp, so files that you create/change should always be owned by kari0458grp (and
therefore accessible to the rest of us.

In addition, you should have your umask set to group read/write.  If your umask is not set to 0002, please
add this in your .bashrc:

```
umask u=rwx,g=rwx,o=rx
```
After setting this, calling umask at the command line should return 0002.

### Testing the Pipeline

The pipeline can be tested by using the -t option.  This will do the complete
pipeline Steps 0-3 but will not call Step4 (that pushes data to NSIDC). If -t is
set, Step0 for tomorrow will not be scheduled, and the email from Step0 will
only be sent to the caller.

When testing, set LABEL to something that is not the operational label,
e.g. your initials.

In order for Step3 to work properly for a test pipeline, be sure to copy the
historical statistics files to the test LABEL location where you are working.
Doing this on PetaLibrary will automatically be shuffled to scratch when it is
needed in Step3.  For example, if I'm running a test for LABEL=MJB, and I want
to see my test pipeline with the historical stats from current operational
processing LABEL=v2023.0, then I would do this before running the test pipeline:

```
cd /pl/active/rittger_esp/modis/regional_stats
mkdir -p scagdrfs_mat_MJB/v006/westernUS
cd scagdrfs_mat_MJB/v006/westernUS
cp ../../../scagdrfs_mat_v2023.0/v006/westernUS/2001*mat ./
```

Once you have seeded the historical stats in your regional_stats LABEL location,
then run the pipeline processing for today as a test, like this:

```
cd /projects/${USER}/Documents/MATLAB/esp/scripts
ml slurm/alpine
sbatch ./runSnowTodayStep0.sh -L <YOUR_INITIALS> -t
```

All outputs from this run will be put in directories with label=
"_<YOUR_INITIALS>". No outputs will be pushed to NSIDC.

### Operational Processing

Set up the pipeline to run daily.  From a login node, cd to the installed
scripts directory, choose the alpine cluster, and start Step0:

```
cd /projects/${USER}/Documents/MATLAB/esp/scripts
ml slurm/alpine
sbatch ./runSnowTodayStep0.sh -L <LABEL>
```

For WY2023, the current operational pipeline LABEL is "v2023.0"

### STC Pipeline Flowcharts

Flowcharts are managed lucidchart.com, available to anyone with access to the NSIDC group license.  When a chart must be changed, Publish it as a single page image, png, screen quality, and the links here should update automatically.

[Step0](https://lucid.app/publicSegments/view/cf39be50-0b9e-453e-a572-8616dd94cf29/image.png) fetches date from JPL to our Petalibrary archive.

[Step1](https://lucid.app/publicSegments/view/6f3526f7-6b0c-43e8-878e-c565b77ff596/image.png) updates monthly raw/gap/stc cubes for [thisMonth-2, thisMonth].

[Step2](https://lucid.app/publicSegments/view/cdc7144f-52c0-45c2-9eab-58c8d83371d2/image.png) updates daily multivariate mosaics for [thisMonth-2, thisMonth].

[Step3](https://lucid.app/publicSegments/view/a22598f5-ab9e-4b0c-a14f-c574d66ff5a5/image.png) updates regional (westernUS/States/HUC2) statistics, makes .csv versions and makes geotiffs of most recent day processed for all variables.

[Step4](https://lucid.app/publicSegments/view/a8596fbf-9d1a-4081-b375-3be2e7f396f4/image.png) pushes .csv statistics and most recent geotiffs to NSIDC.

## Development Notes

To create a new version of the Toolbox:

1.  Use unittests for automated testing. To run a given test
    manually, use runtests('testClassName/test_function').  To run all
    test functions in testClassName.m, use runtests('testClassName').
    To run all test functions, make sure tests directory is in
    path, and do runtests().
2.  Update automated documentation and Toolbox Contents.m file:
    navigate to the directory that contains the Contents.m file,
    which is tbx/ESPToolbox, make it the Current Folder. On the
    Current Folder bar, click the context menu (down triangle)
    and select Reports->Contents Report, follow prompts to
    add/delete items according to what you have changed. The Contents.m file
    controls what shows up when you type `help ESPToolbox`.
3.  Update the doc/*.html files and update the helpsearch file by
    calling `builddocsearchdb('/Users/brodzik/Documents/MATLAB/esp/tbx/doc')'
    Apparently this has to be done after the .mtlbx file has been installed
    (I'm not sure why)
    For new functions, add lines to functions.html and
    toolbox_overview.html.
    For new toolbox requirements, edit getting_started.html.
    To change left nav bar in help window, edit helptoc.xml.
    use 'help myfunc' to see output in Command Window
    use 'doc myfunc' to see output in popup window
4.  There is some way to build extra documentation by opening your .m
    file and doing "Publish"--this shows up in the documentation, but
    I'm not entirely sure what good it does.
5.  Update the version number in the ESPToolbox.prj file:
    navigate to this file in the Current Folder, double-clicking and
    changing the version number.
6.  Update the version number in the Contents.m file: You can do
    this from the Report Contents update, or manually.  The
    release will fail if the version in the ESPToolbox.prj and
    Contents.m files do not match.
7.  Make sure the project sandbox is on the path once and only once,
    and run `release()`.
    This will run all tests and produce a new .mltbx file in the releases
    directory. If you have updated the version number you should see a new
    .mltbx file, otherwise it will overwrite one that was already there.

To test a new Toolbox release:

1.  Remove the sandbox directories from the matlab path by closing
    the Project widget
2.  Check and remove any previous Toolbox paths from the matlab path.
3.  Double-click the new .mltbx file to add it to the path.

## For development only: Running matlab with a release-specific pathdef.m

The pathdef.m will be specific to a version of matlab, I have
saved multiple versions as pathdef_esp_dev_Ryyyyb.m.  You will
need to have a symlink that points pathdef.m to the
version-specific file if you are switching between different
matlab releases.

### Updating to a new version of Matlab for the first time

The first time running with a new version of matlab, remove the
symlink and start matlab -nodisplay to generate the valid base
version for this release. Then run:

>> restoredefaultpath
>> matlabrc
>> savepath /<tmp>/<path>/pathdef.m

then move this version-specific base pathdef.m to the top
directory where you will run matlab.  Give it the version number
and change the symlink to point to it when you want to work with
this version of Matlab.  Add entries for the ./tbx/ locations to the beginning of the p variable, like this:

```
p = [...
%%% BEGIN ENTRIES %%%
     './tbx:', ...
     './tbx/ESPToolbox:', ...
     './tbx/ESPToolbox/html:', ...
     './tbx/StudyExtents:', ...
     './tbx/colormaps:', ...
     './tbx/doc:', ...
     './tbx/doc/css:', ...
     './tbx/doc/helpsearch-v3:', ...
     './tbx/file_exchange:', ...
     './tbx/file_exchange/tight_subplot:', ...
     './tbx/file_exchange/MTL_parser:', ...
     './tbx/mapping:', ...
     <rest of version-specific path here>
```

## MathWorks File Exchange

I also needed a few extras from MathWorks File Exchange, which I have installed
in the tbx/file_exchange/ location:

MTL_parser: https://www.mathworks.com/matlabcentral/fileexchange/39073-landsat-mss-tm-etm-metadata-mtl-parser
   for reading Landsat MTL metadata
tight_subplot: https://??
   for producing nice plots

<a name="matlab-gui"></a>
## Running Matlab GUI

1. In your Web browser, connect to ondemand.rc.colorado.edu and authorize with identikey
2. Top nav, go to "Interactive Apps"→"Core Desktop"
3. Ask for hours/cores, leave account blank to use default, (default is ucb-general)
4. Once in the core desktop, open the Terminal app (small icon near the top left) (you are now on a viz node; you cannot schedule jobs on non-viz clusters directly from here, but you can do so from a login node, so next step is to ssh to login node)
5. Open a connection to a login node: ssh -X login.rc.colorado.edu and authorize with identikey
6. Request an Alpine interactive node with, for e.g.:
```
ml slurm/alpine
salloc --nodes=1 --time=04:00:00 --ntasks=20 --mem=50G --partition=amilan --account=ucb-general
```
7. Connect to the interactive node, with X-forwarding enabled (this is what gets you the GUI back to the viz node)

```
ssh -X $SLURM_NODELIST
```
8. On the interactive node, set up to start matlab (you may need to mkdir the directory you are using for TMP and TMPDIR here):
```
ml matlab/R2021b
export TMP=/scratch/alpine/${USER}/.matlabTmp
export TMPDIR=/scratch/alpine/${USER}/.matlabTmp
cd /projects/${USER}/Documents/MATLAB/esp
matlab
```

(You can define these little sets of commands as aliases in your .bashrc file)
The Matlab GUI should open up on the Core Desktop and be more responsive than other remote connections are.

## Annual Maintenance for upgrading Snow Today statistics files for complete historical record

The SnowToday plots expect to make "in Context" statistics relative
to the date of the current data. This requires the annual statistics files
be updated with the most recent water year (oct1-sep30) sometime after
Sep 30 each year.

The procedure for doing this is:

1) Fill in all/any holes in data from JPL by running SnowTodayStep0 -s yyyymmdd
   without starting any pipeline follow-ons

   See runSnowTodayStep0.sh

   This will fill any holes in the mod09ga/modscag/moddrfs archive on
   the archive location on PetaLibrary.  No changes are made to scratch.

2) Do the scratch shuffle TO scratch for the dates/tiles you plan to process.
   For the full record, do historical for 2000-2018 and nrt for 2018-current year:

   e.g. in oct 2022, do:

   cd scripts
   for type in mod09ga/historical modscag/historical moddrfs/historical; do
   for t in h08v04 h08v05 h09v04 h09v05 h10v04; do
   ./scratchShuffle.sh -b 2000 -e 2018 TO ${type} $t;
   done;
   done

   for type in mod09ga/NRT modscag/NRT moddrfs/NRT; do
   for t in h08v04 h08v05 h09v04 h09v05 h10v04; do
   ./scratchShuffle.sh -b 2018 -e 2022 TO ${type} $t;
   done;
   done

   This will make a mirrored copy of required inputs on scratch.
   
3) Update the monthly data cubes for the latest period, likely
   Oct of last year through Sep of this year. This needs to be
   done in 2 sets: first, update all the Raw Month cubes.

   See runUpdateRawMonthCubes.sh for each tile needed, for last year 10-12
   and this year 1-9. Use sbatch options for --job-name and --array.
   This updates tile-specific Raw monthly data cubes:

   e.g. to update Raw month cubes, for WY2022, do:
   
   for t in h08v04 h08v05 h09v04 h09v05 h10v04; do
   sbatch --job-name=Raw-${t} --array=2021 ./runUpdateRawMonthCubes.sh -L v2023.0 ${t} 10 12;
   done
   for t in h08v04 h08v05 h09v04 h09v05 h10v04; do
   sbatch --job-name=Raw-${t} --array=2022 ./runUpdateRawMonthCubes.sh -L v2023.0 ${t} 1 9;
   done

   Once all the Raw months are updated, do the STC Gap/Interp updates. The Gap/Interp
   cubes use a month window on either side of the month being processed.
      
   See runUpdateSTCMonthCubes.sh for each tile needed, for last year 10-12 and
   this year 1-9. Don't worry about Oct of this year, since the restarted
   pipeline will do Oct. Use sbatch options for --job-name and --array.  This
   updates tile-specific Gap and Interp monthly data cubes:

   e.g. to update Gap/STC month cubes for water year 2022, do:

   for t in h08v04 h08v05 h09v04 h09v05 h10v04; do
   sbatch --job-name=STC-${t} --array=2021 ./runUpdateSTCMonthCubes.sh -L v2023.0 ${t} 10 12;
   sbatch --job-name=STC-${t} --array=2022 ./runUpdateSTCMonthCubes.sh -L v2023.0 ${t} 1 9
   done

   Sometimes these jobs crash with out-of-memory errors when they are set up for
   12-month batchs. If this happens, take a look at how much completed and
   decide whether you can restart with monthstart set to the first month
   that needs to run for any of the tiles

   When the oom errors happen, I re-run them and they never recur on the
   same tile/time, so I can't predict when this will occur.
   
   Another potential error is timeouts (less on alpine than on the old summit
   nodes). When the cube is re-run with a longer --time value, it will usually
   finish in less than the original time. So this is another condition that I
   cannot predict or reliably repeat.

4) Once an entire water year (oct-sep) is available as STC cubes for a complete
   region, update the STC cubes with cumulative snow-covered-days:

   For the "westernUS" region:
   
   reg=westernUS;
   sbatch --job-name=SCD-${reg} --array=2022 ./runUpdateWaterYearSCD.sh -L v2023.0 ${reg}
   
5) Once you have all STC cubes updated for a given period, and updated with
   cumulative SCD, update the multi-variable mosaics for the new period

   Use runUpdateMosaic for this.
   reg=westernUS;
   sbatch --job-name=Mos-${reg} --array=2022 ./runUpdateMosaic.sh -L v2023.0 ${reg}

6) Update the long-term statistics for 2001-current year

   For current year= 2022:
   
   See runSnowTodayStep3Historical.sh.
   In Oct 2021, 2 hours was enough for array 10 and 12, but array 11
   timed out. Ran it again, it needed 3 hours.

7) All of the above steps have been done on scratch, which expires in 3 months.
   Do the scratchShuffle FROM scratch to PetaLibrary so that you don't lose all
   your work!  Be sure to shuffle all intermediary/variables/regional_stats.

8) re-start the daily pipeline. Each step of the daily pipeline will do the
   scratchShuffle TO/FROM only for the data that it needs and then what it produces.

## Fetching data for a new set of tiles

The fetch routines maintain and update a set of inventory files at
/pl/active/rittger_esp/modis/archive_status.  To fetch data for a new tile that
does not yet have inventory files, define a new region/set of tiles in
MODISData.m, for example, adding the 12 tiles that make up Alaska, and then use
scripts/runFetchTile.sh:

```
for i in $(seq 1 12); do jname=$(printf "AK%02dFetch" $i); echo $jname; sbatch --\
job-name=$jname --time=02:00:00 ./runFetchTile.sh -s 20000224 -e 20001231 -v historic Alaska $i; done 
```

On alpine, summer 2022, these jobs were taking about 1 hour per tile per year of data





