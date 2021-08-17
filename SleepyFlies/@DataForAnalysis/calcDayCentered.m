function ctrData = calcDayCentered(obj, dataIn)
% calcDayCentered: Arrange data to be centered on daylight hours
% 
% Usage: (where obj is an object of class SleepyFlies)
%   plotData = obj.calcDayCentered(dataIn);
% 
% Inputs:
%   dataIn ([MxNxP numeric]) - Data to be shifted, where the first column
%               represents data for t=0.
%  
% Outputs:
%   ctrData [MxNxP numeric] - Input dataIn matrix, shifted along the column
%               axis so that daylight hours fall in the center columns
%               (where daylight hours are based on obj.DayStart and 
%               obj.DayLength)
%
% Note: This assumes dataIn is arranged with t=0 in the first column.

% These variables just make the code easier to read
AVG_DAYS = obj.AveragingMode == Averaging.Days;
AVG_BOTH = obj.AveragingMode == Averaging.Both;
AVG_FLIES = obj.AveragingMode == Averaging.Flies;

% To do calculations based on light/dark hours, we need to know when it was
% light and dark. Making a "mask" the same shape as the data with 1s for
% lights-on and 0s for lights-off makes these calculations easier.
if AVG_DAYS || AVG_BOTH
    dayCount = 1;
    mask = obj.makeDayNightMask(1);
else
    dayCount = numel(obj.Days);
    mask = obj.makeDayNightMask(dayCount);
end
mask = obj.reBinData(mask);
colLabels = obj.ColumnLabels;

% Come up with the light start/stop times (in hours) for plotting
if obj.LightHours == 0
    lightStart = obj.DayLength;
    lightStop = 0;
    ctrData = dataIn;
elseif obj.LightHours == obj.DayLength
    lightStart = 0;
    lightStop = obj.DayLength;
    ctrData = dataIn;
else
    % Day centering should happen whenever the output plot will have a
    % single day's worth of data (averaging by days, or by flies on a
    % single day)
    % 
    % AJL: as of 4/2021, don't center data at all (skip this section)
%     if AVG_DAYS || AVG_BOTH || (AVG_FLIES && dayCount==1)
%     % Shift the data around so that the daylight hours are in the middle.
%         halfDarkHours = (obj.DayLength - obj.LightHours)/2;
%         plotStartToExpStartHours = halfDarkHours - obj.LightsOn;
%         plotStartToExpStartBins = floor(plotStartToExpStartHours * 60/obj.BinSize);
%         % Shift by that much along the column axis, but only if we're
%         % averaging by day or both
%         ctrData = circshift(dataIn, plotStartToExpStartBins, 2);
%         mask = circshift(mask, plotStartToExpStartBins, 1);
%         %binCtrs = circshift(obj.BinCenters, plotStartToExpBins, 1);
%         % Shift the column labels too, I think
%         colLabels = circshift(colLabels, plotStartToExpStartBins, 2);
%         
%         %halfDarkBins = floor(halfDarkHours*60 / settings.binSize) * binHours;
%         % Keep track of when light start & stop occur relative to the data,
%         % in hours, because that's how the x-axis of the plots are
%         % displayed.
%         lightStart = halfDarkHours;
%         lightStop = halfDarkHours + obj.LightHours;
%     else
        lightStart = obj.LightsOn;
        lightStop = lightStart + obj.LightHours;
        ctrData = dataIn;
%     end
end

obj.ColumnLabels = colLabels;

% Also save the parameters related to dark/light hours that were calculated
% For bar plots, the bars will be centered on their indices 1,2,3, etc. by
% default. Center them on the middle of the bins instead by making
% an x-axis vector with the bin centers. This is in hours, hence the /60.
obj.AnalysisLightStart = lightStart;
obj.AnalysisLightStop = lightStop;
obj.AnalysisPlotLightMask = mask;
%obj.BinCenters = binCtrs;
obj.AnalysisOutputDays = dayCount;
