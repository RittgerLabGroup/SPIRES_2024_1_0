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

Run Requirements:

The user of this toolbox will need to have a license to run:

Financial Toolbox
Mapping Toolbox

A working version of wget is required to run fetch routines from JPL.
