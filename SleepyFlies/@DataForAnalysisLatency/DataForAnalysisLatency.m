classdef DataForAnalysisLatency < DataForAnalysisSmoothed
    properties (SetAccess=protected)
        WindowMinutes
        WindowZTs
        Latencies % struct with fields rowLabel, latency, time, auc (area under curve), and slope
    end
    
    methods
        function obj = DataForAnalysisLatency(varargin)
            %There must be a better way to dole these inputs out to the
            %different class levels
            obj = obj@DataForAnalysisSmoothed(varargin{:});
            p = inputParser;
            p.KeepUnmatched = true;
            p.addParameter('windowMinutes', 180, @isnumeric);
            p.addParameter('windowZTs', [0 12], @isnumeric);
            p.parse(varargin{2:end});
            obj.WindowMinutes = p.Results.windowMinutes;
            obj.WindowZTs = p.Results.windowZTs;

            obj.PlotFunction = {@obj.plotLatency};
            if ~obj.IsSleep && obj.NormalizeActivity
                % For activity data, plots should be done with normalized
                % data. This is only for averaged analysis; normalized
                % analysis does its own separate normalization.
                obj.PlotData = obj.NormalizedPlotData;
            end
            
        end
        
        function writeDataToFile(obj, folderOut)
            calcLatencies(obj);
            % Jenna wants the outputs on separate sheets for each latency
            % interval now, but I don't want to completely wipe out the old
            % way, so setting input option 'separateSheets' to try
            % indicates to put each interval on its own sheet.
            obj.writeLatencyData('folderOut', folderOut, 'separateSheets',true);
        end
        
        function [a0, a1] = calcSlope(obj, dataIn)
            % This is used in calcLatencies and for plotLatencies.
            % Define it once here, in case it ever needs to change.
            % x values just need to be an array with binSize spacing,
            % y values are the raw data
            
            % AJL: changed this to be consistent with plotSlope.m method of
            % calculating slope- i.e., use binned, not raw, data
            
%             x=1:obj.BinSize:obj.BinSize*numel(dataIn);
%             y=dataIn;
%             X=[x',ones(numel(x),1)];
%             a = (X'*X)\(X'*y');
%             a = polyfit(x,y,1);
%             a0=a(1);
%             a1=a(2);
            plotBinMinutes = 30;
            binHours=plotBinMinutes/60;
            ptsPerBin = plotBinMinutes/obj.DataInterval;
            totalBins = floor(size(dataIn, 2)/ptsPerBin);
            dataPts = dataIn(1:ptsPerBin*totalBins);
            dataPts = reshape(dataPts, ptsPerBin, totalBins, size(dataPts,1), []);
            x = binHours/2 : binHours : binHours*size(dataPts,2) ;
            dataPts = sum(dataPts, 1); 
        	p = polyfit(x, dataPts, 1);
            a0 = p(1);
            a1 = p(2);
        end
        
        function [fh, filenameOut] = plotData(obj, plotSettings)
            % First do the regular latency plots -- superclass function works
            % for this
            plotData@DataForAnalysis(obj,plotSettings);
            % Now also do the slope plots -- one plot per latency interval
            latencyInts = obj.getLatencyIntervals();
            plotter = PageMultiPlots('save', true, 'folderOut', plotSettings.folderOut);
            fh = [];
            for lIdx = 1:size(latencyInts, 1)
                plotSettings.latencyInterval = latencyInts(lIdx,:);
                plotSettings.latencyZT = obj.WindowZTs(lIdx);
                [fh, ~, filenameOut] = plotter.doPlots(fh, @obj.plotSlope, plotSettings);
                plotter.savePlotPage(fh);                
            end
            plotter.closePlots(fh);
        end
    end
end
