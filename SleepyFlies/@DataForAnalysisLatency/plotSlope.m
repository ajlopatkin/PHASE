function [fh, ax, filename] = plotSlope(obj, plotSettings)
% Create a plot of slopes of latencies or anticipations
%
% Usage:
%   [fh, ax, filename] = obj.plotSlope(plotSettings);
%
% Inputs:
%   plotSettings: struct with the following fields
%                 pIdx: page index of datae to plot
%                 boardAndChannel: string describing the board & channel
%                                  number, for use in plot title
%
% Outputs:
%   fh: figure handle of the created plot
%   filename: suggested filename to save file


% Color definitions
darkred = [0.55 0 0];
lightblue = [0.5273 0.8047 0.9792];
lightgreen = [0.5625 0.92975 0.5625];
palegrey = [0.824 .824 .824];
darkgrey = [.41 .41 .41];
indColor = palegrey;
avgColor = darkgrey; % dark blue

% Start a plot area
[fh, ax] = obj.makeAxis(plotSettings);

% Get the currently latency interval
latencyInt = plotSettings.latencyInterval;
latencyInt = latencyInt(1):latencyInt(2);

% Get the data for this latency interval
if ~obj.IsSleep && obj.NormalizeActivity
    yData = obj.NormalizedAveragedData;
else
    yData = obj.AveragedData;
end
if istable(yData)
    y = table2array(yData);
else
    y = ydData;
end

y = y(:,latencyInt);
ymin = min(y(:));
ymax = 0;
yrange = ymax-ymin;

% Get the relevant x values
x = obj.BinCenters(1:numel(latencyInt));

%For activity, bin the points in 15-minute bins so they're easier
%to see.
plotBinMinutes = 30;
ptsPerBin = plotBinMinutes/obj.DataInterval;
binHours=plotBinMinutes/60;

% Plot the points and regression line for each fly
for fIdx = 1:size(y,1)
    dataPts = y(fIdx,:);
    useAverage=true;
    if ~obj.IsSleep && useAverage 
        % Trim the data to only as much as we need for even bins
        totalBins = floor(size(dataPts, 2)/ptsPerBin);
        dataPts = dataPts(1:ptsPerBin*totalBins);
        dataPts = reshape(dataPts, ptsPerBin, totalBins, size(dataPts,1), []);
        dataPts = sum(dataPts, 1); 
        x = binHours/2 : binHours : binHours*size(dataPts,2) ;
    end
    % As of 12/20/201, skip plotting the individual points
    % plot(x, dataPts, 'o', 'markeredgecolor', palegrey);
    
    % AJL: this averaging should be done on binned data and ZT x-axis, not
    % on the raw y data.
    hold on;
    %[a0, a1] = obj.calcSlope(dataPts);
    p = polyfit(x,dataPts,1);
    a0 = p(1); a1 = p(2);
    y_reg = a0+a1*x;
    plot(x, y_reg, 'color', palegrey);
    ymax=max(ymax,max(y_reg));
end

% Calculate the average of all flies & plot
% AJL: This should be done on binned data, as per above
dataPts = mean(y,1);
if ~obj.IsSleep
    totalBins = floor(size(dataPts, 2)/ptsPerBin);
    dataPts = dataPts(1:ptsPerBin*totalBins);
    dataPts = reshape(dataPts, ptsPerBin, totalBins, size(dataPts,1), []);
    dataPts = sum(dataPts, 1); 
end
%[a0, a1] = obj.calcSlope(dataPts);
p = polyfit(x, dataPts, 1);
a0 = p(1); a1 = p(2);
y_reg = a0+a1*x;
plot(x, y_reg, 'color', darkgrey,'linewidth',2);

windowHours = obj.WindowMinutes/60;
xtk = 0:.5:windowHours;
latencyZT = plotSettings.latencyZT;
% Get up some analysis-type-dependent settings:
% file label, analysis description, z tick labels
if obj.IsSleep
    fLabel = 'SleepLatencySlope_';
    desc = ' Sleep Intensity';
    xtkZTs = mod(latencyZT:.5:latencyZT+windowHours, obj.DayLength);
else
    fLabel = 'ActivityAnticipationSlope_';
    if obj.NormalizeActivity
        fLabel = ['Normalized'  fLabel];
        ylim([min(ymin,0) ymax]);
    else 
        ylim([min(ymin,0) ymax]);
    end
    desc = ' Activity Intensity';
    xtkZTs = mod(latencyZT-windowHours:.5:latencyZT, obj.DayLength);
end
% Format the x tick labels
formatSpec = "%.4g";
%formatSpec = "\\sffamily ZT %.4g";
xtlbl = compose(formatSpec, xtkZTs);
xlabel('Time (ZT)');

% New ylimits specified by Jenna, 2019-01-23
% 0-8 for averaged anticipation, 0-0.01 for normalized anticipation
% See above if statement where this is now implemented.
% Set the axis ranges and xtick labels
% ymin = max(ymin-yrange/10, -.5); 
% ylim([ymin ymax+yrange/10]);
xlim([0 windowHours]);
set(ax, 'xtick', xtk, 'xticklabel', xtlbl, 'ticklabelinterpreter', 'latex');

% Label the plot
ax.Title.String = ['ZT' num2str(latencyZT) desc];

% filename = fullfile(obj.folderOut, replace([fLabel plotSettings.boardChanLabel '_' datestr(now, 'yyyymmdd_HHMMSS') '.fig'], ' ', '_'));
filename = replace([fLabel obj.Title '_' datestr(now, 'yyyymmdd_HHMM') '.fig'], ' ', '_');
end

