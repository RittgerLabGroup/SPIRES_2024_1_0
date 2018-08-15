# ESP

Earth Surface Properties Toolbox

A Matlab toolbox for creating and analyzing Earth Surface Properties (ESP) products.


## Development Notes

To create a new version of the Toolbox:

1.  Update the version number in the ESPToolbox.prj file:
    navigate to this file in the Current Folder, double-clicking and
    changing the version number.
2.  Open the release.m file in the project and run it in the
    IDE. This will produce a new .mltbx file in the releases
    directory. This runs automated tests.

To test a new Toolbox release:

1.  Remove the sandbox directories from the matlab path with rmsandbox().
2.  Check and remove any previous Toolbox paths from the matlab path.
3.  Double-click the new .mltbx file to add it to the path.