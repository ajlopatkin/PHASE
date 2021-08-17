classdef DataForAnalysisAS < DataForAnalysis
    % Data for Activity or Sleep analysis
    
%     properties (Dependent)
%         NormalizedAveragedData %This is AveragedData, normalized to bin size or counts per day
%         NormalizedPlotData % This is PlotData, normalized to bin size or counts per day
%     end
    
    methods
        function obj = DataForAnalysisAS(varargin)
            obj = obj@DataForAnalysis(varargin{:});
            if nargin>0
                if ~obj.IsSleep 
                    % For activity data, plots should be done with normalized
                    % data. This is only for averaged analysis; normalized
                    % analysis does its own separate normalization.
                    %
                    % AJL: the below data is not "normalized" in the sense
                    % of other normalization- it's just divided by BinSize.
                    obj.PlotData = obj.NormalizedPlotData;
                end
            end
        end
        
%         function plotData = get.NormalizedPlotData(obj)
%             % Recalculate with normalized data
%             binData = obj.reBinData(obj.AnalysisData);
%             useData = obj.normalizeData(binData);
%             % useData = obj.AnalysisData ./ obj.BinSize;
%             [plotData, rowLabels, colLabels] = obj.layerDataForAveraging(useData);
%             obj.RowLabels = rowLabels;
%             obj.ColumnLabels = colLabels;
%             plotData = obj.calcDayCentered(plotData);
%         end
%         
%         function dataOut = get.NormalizedAveragedData(obj)
%             dataOut = obj.calcAveraged(obj.NormalizedPlotData);
%         end
%         
        function writeDataToFile(obj, folderOut)
            % This should be broken out more.
            % Right now, sleep analysis will write raw statistics;
            % activity analysis will write both raw and normalized statistics.
            % If the normalize flag is false, the experiment statistics use
            % obj.AnalysisData. 
            stats = obj.experimentStatistics(false);
            outfile = obj.writeExperimentData(stats, obj.AveragedData, 'folderOut', folderOut, ...
                'rawData', true);
            if ~obj.IsSleep
                stats = obj.experimentStatistics(true);
                obj.writeExperimentData(stats, obj.NormalizedAveragedData, 'rawData', false, 'outfile', outfile);
            end
        end
        
        function plotData(obj, plotSettings)
            obj.PlotFunction = {};
            plotType = plotSettings.plotType;
            if plotType == PlotType.Bars || plotType == PlotType.Both
                obj.PlotFunction{end+1} = @obj.plotBars;
            end
            if plotType == PlotType.Lines || plotType == PlotType.Both
                obj.PlotFunction{end+1} = @obj.plotLine;
            end
            if ~isempty(obj.PlotFunction)
                %check that, just in case--TODO: something better if it's
                %empty
                plotData@DataForAnalysis(obj,plotSettings);
            end 
        end
        
    end
end