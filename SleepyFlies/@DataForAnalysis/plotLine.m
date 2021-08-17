function [fh, ax, filename] = plotLine(obj, plotSettings)
% This is the line-style plot
% 
% Usage:
%   [fh, ax, filename] = obj.plotLine(plotSettings);
%
% Inputs:
%   plotSettings: struct with the following fields
%                 pIdx: page index of datae to plot 
%                 useErrorBars (optional, default true): plot error bars?
%                 boardAndChannel: string describing the board & channel
%                                  number, for use in plot title
%
% Outputs:
%   fh: figure handle of the created plot
%   ax: axis of created plot
%   filename: suggested filename to save file
%
% Note:
% Because these plots are plotted with points at the start time of a bin,
% plotting 24 hours of data in 30 minute bins doesn't look "right"--the 
% final point is at 23.5 (not 24), so it looks like there's data missing.
% To deal with this visual effect and make the dataset appear complete, the
% first point will be copied and appended to the end of the data, to give a
% full day-length plot. This point won't be included in the Excel output or
% in any other plot or calculation.

darkgray = [.5 .5 .5];
midgray = [.66 .66 .66];
lightgray = [.824 .824 .824];
darkblue = [.17 .4 .6]; % This was the original line color
dimgray = [.4102 .4102 .4102];
linecolor = dimgray;

binCtrs = obj.BinCenters;
binSize = obj.BinSize;
lightStart = obj.AnalysisLightStart;
lightStop = obj.AnalysisLightStop;
dayCount = obj.AnalysisOutputDays;
dayLength = obj.DayLength;
plotTitle = obj.Title;
lightHours = obj.LightHours;

plotData = obj.PlotData(:,:,plotSettings.pIdx);
% Copy the first point to the end of the data, so our line extends the full
% time period.
plotData(:,end+1) = plotData(:,1);

% This is the function to use for calculating error bars
% AJL: add sqrt() to compute proper SEM
errFunc = @(x) obj.DataInterval * std(x,1) / sqrt(size(plotData,1));
% If there's a useErrorBars field in plotSettings, use that to determine
% whether or not to plot error bars. Default to true if not found.
if isfield(plotSettings, 'useErrorBars')
    useErrorBars = plotSettings.useErrorBars;
else
    useErrorBars = true;
end


% In this case, plot on bin edges, not centers
% Add the extra wrapped end point, as described above.
binCtrs = [binCtrs - (binSize/60)/2 binCtrs(end)+(binSize/60)/2];
ymin = 0;

% If we're plotting multiple axes on the same sheet, use the input figure &
% axes--makeAxis handles the overhead of laying out the plots.
[fh, ax] = obj.makeAxis(plotSettings);

% Determine the data range to set the axis
if useErrorBars && size(plotData, 1) > 1
    % ymargin is the gap on to leave above the maximum data point on the y
    % axis. With error bars, the maximum data point is actual the maximum
    % of data + error, and ymax will be that value plus 10% of the data
    % range (0 to ymax).
    ymargin = .05 * max(mean(plotData,1) + errFunc(plotData));
    ymax = max(mean(plotData,1) + errFunc(plotData)) + 2*ymargin;
else
    % Without error bars, just use the data (keeping in mind that we're 
    %actually plotting the mean of the data) maximum as ymax.
    ymargin = .05 * max(mean(plotData,1));
    ymax = max(mean(plotData,1)) + 2*ymargin;
end

% New min/max y axis range as of 2019-01-21
if obj.NormalizeActivity && ~obj.IsSleep
    if obj.BinSize == obj.DataInterval
        % phase/latency analysis
        ymax = 0.01;
        ymin = 0;
    else
        % binned activity analysis
        ymax = 0.25;
        ymin = 0;
    end
elseif ~obj.IsSleep
    % non-normalized activity plots
    ymax = 6;
    ymin = 0;
elseif obj.IsSleep
% As of 2019-04-08, remove this constraint.
%     % Sleep analysis
%     ymax = 30;
%     ymin = 0;
    % As of 2019-04-08, use bin size + 10% for y axis maximum
    ymin = 0;
    ymax = obj.BinSize * 1.1;
end
if ~obj.NormalizeActivity
    ymax = max(ymax, 1);
end
% Manually specified y-axis range overrides all of the above.
if ~isempty(plotSettings.yrange)
    ymin = plotSettings.yrange(1);
    ymax = plotSettings.yrange(2);
end

% Add the light/dark shading and lines
% Add the dashed lines at light/dark boundaries
for d = 0:dayLength:dayLength*dayCount
    if lightStart>= 0
        rectangle(ax, 'Position', [0+d 0 lightStart ymax], 'facecolor',lightgray, 'edgecolor',lightgray);
        rectangle(ax, 'Position', [lightStart+lightHours+d  0 dayLength-lightStop ymax], 'facecolor',lightgray,'edgecolor',lightgray);
        line([lightStart+d lightStart+d], [0 ymax], 'linestyle', ':', 'linewidth', 1.5, 'color', 'k');
        line([lightStop+d lightStop+d], [0 ymax], 'linestyle', ':', 'linewidth', 1.5, 'color', 'k');
    else
        rectangle(ax, 'Position', [lightStart+lightHours+d  0 lightHours ymax], 'facecolor',lightgray,'edgecolor',lightgray);
        line([lightStart+d+dayLength lightStart+d+dayLength], [0 ymax], 'linestyle', ':', 'linewidth', 1.5, 'color', 'k');
        line([lightStop+d lightStop+d], [0 ymax], 'linestyle', ':', 'linewidth', 1.5, 'color', 'k');
    end
end
% Now plot the line, with error bars if requested
if useErrorBars && size(plotData, 1) > 1
    % Use the very nice shadedErrorBar.m from the MATLAB File Exchange
    shadedErrorBar(binCtrs, plotData, {@(x) mean(x,1), errFunc}, 'lineprops', {'color',linecolor,'linewidth',2})
else
    % Just the line
    line(ax, binCtrs, mean(plotData,1), 'linewidth', 2, 'color', linecolor);
end

% Make the figure white
set(gcf, 'Color', [1 1 1]);
hold all;

% Set the y axis as caulcated above.
ylim(ax, [ymin ymax]);

xlim(ax, [0 max(binCtrs)]);
xticklabels(ax, []);
title(plotTitle);

title({obj.Title; plotSettings.boardAndChannel});
if obj.IsSleep
    filePrefix = 'SleepAnalysis_';
    ylabel('Sleep (minutes)');
else
    filePrefix = 'ActivityAnalysis_';
    if obj.NormalizeActivity
        filePrefix = ['Normalized' filePrefix];
        ylabel('Activity (beam crosses/total)');
    else
        ylabel('Activity (beam crosses/min)');
    end
end

filename = replace([filePrefix plotTitle '_' datestr(now, 'yyyymmdd_HHMM') '.fig'], ' ', '_');

