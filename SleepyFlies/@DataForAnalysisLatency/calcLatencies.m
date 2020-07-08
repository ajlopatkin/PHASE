function calcLatencies(obj)
% calcLatencies: Calculate latency or anticipation, save to obj.Latencies
%
% This uses the latency intervals calculated by getLatencyIntervals.
% From those, it calculates the latency duration in minutes, the slope and
% area under the curve of the interval, and the start and stop points of
% the interval in a number of different formats for plotting and reporting: 
% index relative to x-axis for plotting, time relative to ZT0, and time in
% minutes.

latencyInts = obj.getLatencyIntervals();
if obj.NormalizeActivity && ~obj.IsSleep
    unsmoothedData = NormalizedAveragedData;
else
    unsmoothedData = AveragedData;
end
if istable(unsmoothedData)
    unsmoothedData = table2array(unsmoothedData);
end
% Calculate latencies for each specified ZT transitions
latencies(size(unsmoothedData,1)).rowLabel = [];
latencies(size(unsmoothedData,1)).latency = [];
latencies(size(unsmoothedData,1)).time = []; % relative to x-axis -- this is used for plotting
latencies(size(unsmoothedData,1)).timeZT = []; % relative to ZT0
latencies(size(unsmoothedData,1)).loc = []; %index in data array
latencies(size(unsmoothedData,1)).auc = []; 
% latencies(size(unsmoothedData,1)).slope = [];
for flyIdx = 1:size(unsmoothedData,1)
    latency = zeros(size(latencyInts,1), 1);
    time = zeros(size(latencyInts,1), 2);
    timeZT = zeros(size(latencyInts,1), 2);
    loc = zeros(size(latencyInts, 1),2);
    auc = zeros(size(latencyInts,1),1);
    % slope = zeros(size(latencyInts,1),1);
    for lIdx = 1:size(latencyInts,1)
        % Get the current latency (or anticipation) window
        winStart = latencyInts(lIdx,1);
        winStop = latencyInts(lIdx,2);
        % Check whether this interval wraps around the ends of the data (if
        % the first index is greater than the second index, it does)
        if winStart > winStop
            smoothData = [obj.SmoothedData(flyIdx, winStart:end) obj.SmoothedData(flyIdx, 1:winStop)];
            rawData = [unsmoothedData(flyIdx, winStart:end) unsmoothedData(flyIdx, 1:winStop)];
        else
            smoothData = obj.SmoothedData(flyIdx, winStart:winStop);
            rawData = unsmoothedData(flyIdx, winStart:winStop);
        end
        % Calculate the slope from the un-smoothed data with a linear regression
        % [a0, a1] = obj.calcSlope(rawData);
        % s = a0;
        % obj.BinSize should be obj.DataInterval here, but just in case it's not, this would more accurately reflect the data. 
        [l, z, a] = intervalLatencyMaxMin(obj.IsSleep, smoothData, latencyInts(lIdx,1), obj.BinSize); 
        if ~isempty(l)
            latency(lIdx) = l;
            loc(lIdx,:) = z.minutes;
            time(lIdx,:) = z.zt; % this is the data for plotting
            auc(lIdx) = a;
            % slope(lIdx) = s;
        end
    end
    % halfDarkHours = (obj.DayLength - obj.LightHours)/2;
    % plotStartToExpStartHours = halfDarkHours - obj.LightsOn;

    latencies(flyIdx).rowLabel = obj.RowLabels{flyIdx};
    latencies(flyIdx).latency = latency;
    latencies(flyIdx).time = time;
    latencies(flyIdx).timeZT = mod(time-obj.AnalysisLightStart, obj.DayLength);
    latencies(flyIdx).auc = auc;
    % latencies(flyIdx).slope = slope;
    latencies(flyIdx).loc = loc;
end

obj.Latencies = latencies;
end

function [latency, time, auc] = intervalLatencyMaxMin(isSleep, dataSmooth, pt1Idx, binSize)

% For sleep, a minimum of 0 is okay; for activity, use non-0 minimums
if isSleep 
    % For sleep, find minimum 
    [minVal, startIdx] = min(dataSmooth);
    [maxVal, endIdx] = max(dataSmooth(startIdx+1:end));
    endIdx = endIdx + startIdx;
else
    % For activity, find maximum and use non-0 minimum
    [maxVal, endIdx] = max(dataSmooth);
    dataSmooth(dataSmooth==0) = inf; % non-0 minimums for activity
    [minVal, startIdx] = min(dataSmooth(1:endIdx-1));
    dataSmooth(dataSmooth==inf) = 0;
end


if isempty(endIdx) || isempty(endIdx)
    % Figure out what to actually do here
    time.minutes = [nan nan]; %[startIdx+pt1Idx nan];
    time.zt = [nan nan]; % [(startIdx + pt1Idx) / (60/binSize) nan];
    latency = nan;
    auc = nan;
else
    % TODO: These probably need to be modified in the case where the
    % specified window wraps around the ends of the data
    time.minutes = [(startIdx+pt1Idx-1) (endIdx+pt1Idx-1)] * binSize;
    time.zt = [startIdx+pt1Idx-1 endIdx+pt1Idx-1] / (60/binSize);

    % Figure out the latency (or anticipation) time in minutes
    latency = (endIdx - startIdx) * binSize;

    % intensity is the area under the curve
    if latency > 0
        auc = trapz(dataSmooth(startIdx:endIdx));
        %intensity = (minVal - maxVal) / latency;
    else
        auc = nan;
    end

    latency = abs(latency); % Latency time should be positive regardless of slope
end
end
