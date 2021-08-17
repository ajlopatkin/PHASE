classdef DataForAnalysis < DataExperiment & matlab.mixin.Copyable
    properties (SetAccess = protected)
        RowLabels
        ColumnLabels % These get shifted with day centering and are minute labels of each data column
        BinCenters % These are the x-axis values for plotting bins. They always start at 0, regardless of day-centering
        Days = 1
        AveragingMode = Averaging.Days
        BinSize
        IsSleep
        NormalizeActivity = false
        Title % This will be in the file names and/or plot titles
        AnalysisLightStart % This is ZT0, shifted with the data when day-centering
        AnalysisLightStop % This is shifted with the data when day-centering
        AnalysisLightMask % Shifted to match data for day centering, # of days of un-averaged, un-binned data
        AnalysisOutputDays
        AnalysisPlotLightMask % Shifted to match data, # of days of averaged data
        PlotData % This is the analysis data, binned, day-centered and arranged for averaging/plotting
        AveragedData % This is the day-centered analysis data after the specified averaging

        DeadFlies = '' % Message indicating whether flies with no activity were found in the selected days
        
        PlotFunction % This needs to be a function that takes two inputs, data & plotSettings, and returns figure handle and filename
    end
    
    properties (Dependent)
        % This is the experiment data for just the specified analysis days, not binned or centered
        AnalysisData
        NormalizedAveragedData % This is AveragedData, normalized to bin size or counts per day
        NormalizedPlotData % This is PlotData, normalized to bin size or counts per day
    end
    
    methods
        function obj = DataForAnalysis(varargin)
            % varargin should contain isSleep, averaging, binSize, days
            %   binSize (int) - Data bin size, in minutes. This is the number of
            %                   minutes represented by each plot point, used in
            %                   calculating the number of points per day. If
            %                   obj.reBinData was called prior to this function, this
            %                   will be the same bin size; if not, it should be
            %                   obj.DataInterval.
            
            p = inputParser();
            p.addRequired('expData', @(x) isa(x, 'DataExperiment'));
            p.addParameter('days', [], @isnumeric);
            p.addParameter('averaging', [], @(x) isa(x, 'Averaging'));
            p.addParameter('binSize', [], @isnumeric);
            p.addParameter('title', '', @(x) ischar(x) || isstring(x));
            p.addParameter('isSleep', false, @(x) islogical(x) || (isnumeric(x) && (x==1 || x==0)));
            p.addParameter('normalizeActivity', false, @(x) islogical(x) || (isnumeric(x) && (x==1 || x==0)));
            p.KeepUnmatched = true;
            p.parse(varargin{:});
            propList = meta.class.fromName('DataExperiment').PropertyList;
            for propIdx = 1:numel(propList)
                if ~propList(propIdx).Dependent
                    obj.(propList(propIdx).Name) = p.Results.expData.(propList(propIdx).Name);
                end
            end
            if ~isempty(p.Results.days)
                obj.Days = p.Results.days;
            end
            if ~isempty(p.Results.averaging)
                obj.AveragingMode = p.Results.averaging;
            end
            if ~isempty(p.Results.binSize)
                obj.BinSize = p.Results.binSize;
            else
                obj.BinSize = obj.DataInterval;
            end
            obj.Title = p.Results.title;
            obj.IsSleep = p.Results.isSleep;
            obj.NormalizeActivity = p.Results.normalizeActivity;
            % use the DataExperiment input object to build the superclass parts of this new object
            % obj = copyObject(expData, obj); 
            
            obj.AnalysisLightStart = obj.LightsOn;
            obj.AnalysisLightStop = obj.LightsOn + obj.LightHours;
            obj.AnalysisOutputDays = numel(obj.Days);
            % obj.AnalysisLightMask = obj.reBinData(obj.makeDayNightMask(numel(obj.Days)));
            obj.AnalysisLightMask = obj.makeDayNightMask(numel(obj.Days));
            obj.AnalysisPlotLightMask = obj.reBinData(obj.makeDayNightMask(obj.AnalysisOutputDays));
            
            % These calculations are the same regardless of analysis type.
            binData = obj.reBinData(obj.AnalysisData);
            % binData = obj.normalizeData(binData);
            [plotData, rowLabels, colLabels] = obj.layerDataForAveraging(binData);
            obj.RowLabels = rowLabels;
            obj.ColumnLabels = colLabels;
            
            % plotData = obj.layerDataForAveraging(obj.AnalysisData);
            % layerDataForAveraging also updates RowLabels and ColumnLabels
            obj.PlotData = obj.calcDayCentered(plotData);
            % obj.PlotData = plotData;
            binHours = obj.BinSize/60;
            obj.BinCenters = binHours/2 : binHours : binHours*size(obj.PlotData,2) ;
            % calcDayCentered updates ColumnLabels
            obj.AveragedData = obj.calcAveraged(obj.PlotData);
        end
        
        function dataOut = get.AnalysisData(obj)
            %dataOut = obj.reBinData(obj.getAnalysisData());
            [dataOut, obj.DeadFlies] = obj.getAnalysisData();
        end
        
        function plotData = get.NormalizedPlotData(obj)
            % Recalculate with normalized data
            binData = obj.reBinData(obj.AnalysisData);
            useData = obj.normalizeData(binData);
            % useData = obj.AnalysisData ./ obj.BinSize;
            [plotData, rowLabels, colLabels] = obj.layerDataForAveraging(useData);
            obj.RowLabels = rowLabels;
            obj.ColumnLabels = colLabels;
            plotData = obj.calcDayCentered(plotData);
        end
        
        function dataOut = get.NormalizedAveragedData(obj)
            dataOut = obj.calcAveraged(obj.NormalizedPlotData);
        end
        
        function deadFliesMessage = get.DeadFlies(obj)
            deadFliesMessage = obj.DeadFlies;
        end
   
        
        function plotFormatFunction(obj, ax, plotSettings) %#ok<INUSD>
            % If a subclass needs to do specific formatting to the plots
            % after they're generated, override this function.
            % Take plotSettings as an input in case the function to
            % execute is somehow dependent on the plot settings.
        end
        
        function [fh, filenameOut] = plotData(obj, plotSettings)
            % varargin to allow additional specification inputs for
            % subclass functions
            %             % Take plotData as an input, to allow plotting different sets
            % of object data
            plotter = PageMultiPlots('save', true, 'folderOut', plotSettings.folderOut);
            fh = [];
            % plotSettings = obj.buildPlotSettings();
            for pIdx = 1:size(obj.PlotData,3)
                plotSettings.boardAndChannel = obj.RowLabels{pIdx};
                % TODO: Figure out how to put a hook in here so I can
                % change labels on the plots from the caller functions
                for pFuncIdx = 1:numel(obj.PlotFunction)
                    % Include the plot function itself in the settings, in
                    % case there are multiple potential plot functions and the
                    % formatting functions are different for different
                    % functions.
                    plotSettings.plotFunction = obj.PlotFunction{pFuncIdx};
                    % Also include the pIdx so we have a way to get default
                    % data when necessary (in latency plots, for example,
                    % that always do a bar plot in the background with the
                    % plot data).
                    plotSettings.pIdx = pIdx;
                    % If there's more than one plot function for this
                    % object, all the plot functions in succession to keep
                    % like plots next to each other.
                    [fh, ax, filenameOut] = plotter.doPlots(fh, obj.PlotFunction{pFuncIdx}, ...
                        plotSettings);
                    obj.plotFormatFunction(ax, plotSettings);
                    plotter.savePlotPage(fh);
                    
                end
            end
            plotter.closePlots(fh);
        end
        
    end
    
    methods (Access=protected)
        
        function plotPointIndex = getPlotIndexFromOriginalIndex(obj, origIdx)
            % Given a data index from the original data, find where that
            % falls in the current plot data
            plotPointIndex = find(obj.ColumnLabels == origIdx);
        end
    end
    
    methods (Abstract)
        writeDataToFile(obj);
        % plotData(obj, plotSettings);
    end
    
    methods (Static)
        function [xSpace, ySpace] = getLabelSpacing(ax)
            % Given an axis, get a reasonable spacing to use to put labels
            % near but not exactly on a point
            yrange = get(ax, 'YLim');
            yrange = yrange(2) - yrange(1);
            ySpace = yrange/20;
            xrange = get(ax, 'XLim');
            xrange = xrange(2) - xrange(1);
            xSpace = -xrange/30;
        end
        
        function [fh, ax] = makeAxis(plotSettings)
            if (~isfield(plotSettings,'fh') || ~isfield(plotSettings, 'ax'))
                if isfield(plotSettings, 'plotVisible')
                    pVis = plotSettings.plotVisible;
                else
                    pVis = true;
                end
                fh = figure('visible', pVis);
                ax = axes(fh);
            else
                fh = plotSettings.fh;
                set(0, 'CurrentFigure', fh);
                ax = plotSettings.ax;
                set(fh, 'CurrentAxes', ax);
            end
        end
        
    end
    
end
