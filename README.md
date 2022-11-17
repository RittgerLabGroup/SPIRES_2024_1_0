# ESP

Earth Surface Properties Toolbox

A Matlab toolbox for creating and analyzing Earth Surface Properties (ESP) products.


## Installation Notes

To install the ESPToolbox:

1.  Download the file "ESPToolbox\ vX.Y.mltbx" to your ~/Documents/MATLAB
    directory
2.  Double-click it to add it to your matlab path.
3.  Get help with:

> >> doc ESPToolbox

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

## Run Requirements:

The user of this toolbox will need to have a license to run:

Financial Toolbox
Mapping Toolbox

## For development only: Running matlab with a release-specific pathdef.m

The pathdef.m will be specific to a version of matlab, I have
saved multiple versions as pathdef_esp_dev_Ryyyyb.m.  You will
need to have a symlink that points pathdef.m to the
version-specific file if you are switching between different
matlab releases.

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

## Additional GitHub dependencies

This toolbox depends on the following GitHub packages which should be
explicitly listed in the pathdef.m file:

ParBal (git@github.com:edwardbair/ParBal.git) - for albedo calculations
plotboxpos (https://github.com/kakearney/plotboxpos-pkg.git) - for plotting routines
RasterReprojection (https://github.com/DozierJeff/RasterReprojection.git) - for
		   reprojecting raster images

## MathWorks File Exchange

Plus a few extras from MathWorks File Exchange, which I have installed
in the tbx/file_exchange/ location:

MTL_parser: https://www.mathworks.com/matlabcentral/fileexchange/39073-landsat-mss-tm-etm-metadata-mtl-parser
   for reading Landsat MTL metadata
tight_subplot: https://??
   for producing nice plots

## System dependencies

A working version of wget is required to run fetch routines from JPL.

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

6) Once you have all the initial mosaic files for a given water year (starts in Oct),
   update the cumulative snow_cover_days (SCD) variables in all the new files:

7) Update the long-term statistics for 2001-current year

   For current year= 2022:
   
   See runSnowTodayStep3Historical.sh.
   In Oct 2021, 2 hours was enough for array 10 and 12, but array 11
   timed out. Ran it again, it needed 3 hours.

5) All of the above steps have been done on scratch, which expires in 3 months.
   Do the scratchShuffle FROM scratch to PetaLibrary so that you don't lose all
   your work!

5) re-start the daily pipeline. Each step of the daily pipeline will do the
   scratchShuffle TO/FROM only for the data that it needs and then what it produces.

## Fetching data for a new set of tiles

The fetch routines maintain and update a set of inventory files at /pl/active/rittger_esp/modis/archive_status.
To fetch data for a new tile that does not yet have inventory files, define a new region/set of tiles in MODISData.m, for example, adding the 12 tiles that make up Alaska, and then use scripts/runFetchTile.sh:

```
for i in $(seq 1 12); do jname=$(printf "AK%02dFetch" $i); echo $jname; sbatch --\
job-name=$jname --time=02:00:00 ./runFetchTile.sh -s 20000224 -e 20001231 -v historic Alaska $i; done 
```

On alpine, summer 2022, these jobs were taking about 1 hour per tile per year of data





