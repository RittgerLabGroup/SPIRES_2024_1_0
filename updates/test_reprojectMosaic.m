classdef test_reprojectMosaic < matlab.unittest.TestCase
%test_reprojectMosaic unit test
%
    properties
        topPath
        testPath
        onRC
    end

    methods (TestMethodSetup)
        function getContext( testCase )
            path = fileparts(mfilename('fullpath'));
            parts = split(path, filesep);
            path = join(parts(1:end-1), filesep);
            testCase.topPath = path{1};
            testCase.testPath = fullfile(testCase.topPath, ...
                'tests', 'test_files');
            
            [~, name] = system('hostname');
            if (contains(name, ["rc.int", "bnode"]))
                testCase.onRC = true;
            else
                testCase.onRC = false;
            end
        end
    end

    methods (TestMethodTeardown)

        function cleanUpDisplays( testCase )
	    close all;
        end

    end

    methods (Test)

        function test_bogusFile( testCase )
            
            myEnv = ESPEnv();
            mosaicFile = 'bogus.mat';
            testCase.verifyError(@()readMosaic(...
                mosaicFile, 'STc'), ...
                'readMosaic:FileError');
            
        end
        
        function test_mosaicToSSN( testCase )

            if testCase.onRC
                
                myEnv = ESPEnv();
                
                m = myEnv.colormap('cmap_fractions');
                m.cmap_sca(1, :) = [0.5 0.5 0.5]; %set first color to grey
                Brewer = myEnv.colormap('Brewer_colormaps');
                
                dimcols = 300;
                dimrows = 300;
                
                nrows = 2;
                ncols = 3;
                figure('units', 'pixels', ...
                    'position', [10 10 ncols*dimcols nrows*dimrows]);
                
                % Read comparison data
                % WY2012 runs from 01 Oct 2011 to 31 Sep 2012, so
                %origFile = ['/pl/active/SierraBighorn/scag/MODIS/' ...
                %    'gapfilled_SN_2000-2012/SN_WY2012.mat'];
                %MODIScube = cube(origFile);
                %orig = MODIScube.getSlice(92, 'scaAdjusted');
                yr = 2011;
                mm = 12;
                dd = 31;
                ssnPath = fullfile(testCase.testPath, 'SSN');
                ssnFile = sprintf(...
                    'SSN.SN_WY*_%04d%02d%02d.Terra-MODIS.snow_cover_percent.v01.tif', ...
                    yr, mm, dd);
                list = dir(fullfile(ssnPath, ssnFile));
                origFile = fullfile(list(1).folder, list(1).name);
                fprintf('%s: origFile=%s\n', mfilename(), origFile);
                orig = geotiffread(origFile);
                ax1 = subplot(nrows, ncols, 1);
                imagesc(orig, [0 100]);
                axis image;
                colormap(ax1, m.cmap_sca);
                colorbar(ax1);
                title(sprintf('Original SSN (%04d-%02d-%02d)', yr, mm, dd));
                
                modisPath = fullfile(testCase.testPath, 'westernUS');
                modisFile = sprintf('westernUS*%04d%02d%02d*', yr, mm, dd);
                list = dir(fullfile(modisPath, modisFile));
                mosaicFile = fullfile(list(1).folder, list(1).name);
                fprintf('%s: mosaicFile=%s\n', mfilename, mosaicFile);
                
                varName = 'viewable_snow_fraction';
                src = readMosaic(mosaicFile, varName);
                
                methods =  {'nearest', 'bilinear'};
                extent = studyExtent('SouthernSierraNevada');
                for i = 1:length(methods)
                    S = reprojectToStudyExtent(src, varName, ...
                        'MODIS', extent, 'method', methods{i});
                    
                    ax = subplot(nrows, ncols, 1 + i);
                    imagesc(S.data, [0 100]);
                    axis image;
                    colormap(ax, m.cmap_sca);
                    colorbar(ax);
                    title(sprintf('from Mosaic(%s)', methods{i}));
                    
                    diff = single(S.data) - single(orig);
                    fprintf('%s: diff min/max = %.1f, %.1f, mean=%.1f\n', ...
                        mfilename(), min(diff(:)), max(diff(:)), mean(diff(:)));
                    diffax = subplot(nrows, ncols, ncols + 1 + i);
                    imagesc(diff, [-100 100]);
                    axis image;
                    colormap(diffax, Brewer.divergingBrBG);
                    colorbar(diffax);
                    title(sprintf('Mosaic(%s) - orig', methods{i}));
                    
                end
                
            else
            
                fprintf(['%s: not on RC, ' ...
                    'skipping test_mosaicToSSN\n'], ...
                    mfilename());
                
            end
            
        end

    end

end
