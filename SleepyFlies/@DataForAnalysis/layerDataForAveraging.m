function [plotData, rowLabels, colLabels] = layerDataForAveraging(obj, dataIn, varargin)
% layDataForAveraging: Shape the data into matrices based on averaging type
% 
% Re-arrange the data to prepare for plotting with averaging, where each
% "layer" (3rd dimension) in the matrix represents a single plot, and
% averaging is done for all rows in each column. (That is, the number of
% points plotted will be the number of columns of data.)
% 
% Usage: (where obj is an object of class SleepyFlies)
%   [plotData, rowLabels, colLabels] = obj.layerDataForAveraging(dataIn);
%   [plotData, rowLabels, colLabels] = obj.layerDataForAveraging(dataIn, averagingMode);
% 
% Inputs:
%   dataIn [FxN int] - Raw data from file to be reshaped
%   averagingMode (optional) - Averaging class object indicating what
%       averaging mode to use. If excluded, obj.AveragingMode will be used.
%       This is included to allow more general use, specifically in
%       normalized averaging of activity data.
%  
% Outputs:
%   plotData [MxOxP int] - Data reshaped as described above.
%   rowLabels {} - Labels for rows of data in plotData
%   colLabels {} - Labels for columns of data in plotData

if nargin>2 && isa(varargin{1}, 'Averaging')
    avgMode = varargin{1};
else
    avgMode = obj.AveragingMode;
end
% These variables just make the code easier to read
AVG_NONE = avgMode == Averaging.None;
AVG_DAYS = avgMode == Averaging.Days;
AVG_FLIES = avgMode == Averaging.Flies;
AVG_BOTH = avgMode == Averaging.Both;

binSize = obj.BinSize;

% binData is bins x flies
% See how many intervals, channels, and boards we have
[bins, chans, ~] = size(dataIn);

% Now average it as requested.
% (Note that "flies" and "channels" are used interchangeably here)
% In order to do the plotting and potentially include error bars,
% we need to create a 3-dimensional array whose dimensions depend on averaging type.
% Each layer in the array will represent a single plot, so for averaging on...
%   NONE: [1 x bins x flies], where bins is ALL bins, not combined by day
%   FLY:  [flies x bins x 1], where bins is ALL bins, not combined by day
%   DAY:  [days x bins x flies], where bins is a day worth of bins
%   BOTH: [(daysxflies) x bins x 1], where bins is a day worth of bins
% First reshape to add a dimension for days, so we get
% [bins x days x flies]
binsPerDay = (obj.DayLength*60)/binSize;
% Find the number of bins per day; that's now many points each row
% needs to have, then we'll stick in an extra dimension for days (the
% [] in the reshape statement below)
% Discounting the boards dimension, this results in bins x days x flies
dataByDay = reshape(dataIn, binsPerDay, [], chans);

% Now reshape to the size we need based on averaging type (see above)
if AVG_DAYS
    % Reshape to days x bins x flies
    plotData = permute(dataByDay, [2 1 3]);
    colLabels = 0:binSize:binSize*(binsPerDay-1);
    rowLabels = strcat('M', arrayfun(@(x) sprintf("%03d", x), obj.Boards'), 'C', arrayfun(@(x) sprintf("%02d", x), obj.Channels'));
    rowLabels = cellstr(rowLabels);
elseif AVG_BOTH
    % AJL: this code did the averaging in the wrong order- fixed below
    % --- ORIGINAL CODE --- %
    % First average by flies, and then pass this data in to be averaged by
    % day (so the error function will be calculated on the days, not the
    % flies & days both)
%    plotData = mean(dataByDay, 3);
    % That gave us bins x days; we need to end up with days x bins
%    plotData = plotData';
    
    % Reshape to a single layer (this method results in the flies & days
    % being averaged all at once and the std. error being calculated on
    % that, rather than just on the day average of the averaged flies)
%    colLabels = 0:binSize:binSize*(binsPerDay-1);
%    rowLabels = {'Average Over Flies and Days'};
    % --- END ORIGINAL CODE --- %
    
    plotData = squeeze(mean(dataByDay,2))';
    colLabels = 0:binSize:binSize*(binsPerDay-1);
    rowLabels = {'Average Over Flies and Days'};
    
elseif AVG_FLIES
    % This will give one plot not averaged by days, so we need to use
    % binData, not dataByDay, but flip it so we have one row per fly
    plotData = dataIn';
    colLabels = 0:binSize:(binSize*bins)-1;
    rowLabels = {'Average Over Flies'};
elseif AVG_NONE
    % Again use binData, but reshape it for one layer per fly (instead of
    % one column)
    plotData = permute(dataIn, [3 1 2]);
    colLabels = 0:binSize:(binSize*bins)-1;
    rowLabels = strcat('M', arrayfun(@(x) sprintf("%03d", x), obj.Boards'), 'C', arrayfun(@(x) sprintf("%02d", x), obj.Channels'));
    rowLabels = cellstr(rowLabels);
else
    warning('Invalid option for plot averaging.')
end




