function [latencyInts] = getLatencyIntervals(obj)
% getLatencyIntervals: Find the indices of intervals to examine for latency/anticipation
% 
% Usage: (where obj is an object of class DataForAnalysisLatency)
%   plotData = obj.getLatencyIntervals();
% 
% Inputs: 
%   None
%  
% Outputs:
%   latencyIntervals [Nx2 int] - Matrix of interval indices, where each row
%                     represents a single interval. The first column is the
%                     start index of the interval; the second column is the
%                     end index of the interval. 

% Figure out how many data points we need in each latency window 
% based on the specified latency/anticipation
% window length and the file data interval size 
latencyBins = obj.WindowMinutes/obj.DataInterval;

% Adjust window-setting ZTs to account for day-centering of data, so
% windowZTs represents where the desired ZTs fall in the data permutation

windowZTs = obj.WindowZTs + obj.AnalysisLightStart; % plotStartToExpStartHours; 
% Convert that to a data index
ztIdx = (60 / obj.DataInterval) .* windowZTs + 1; 

% This will need to be updated a little to deal with multiple days in data
% Note following Sept. 6 2018 meeting with Jenna:
% No, it won't. Latency/anticipation calculations will always
% average the data across days, effectively leaving only one day's worth of
% data to look at here.
% Convert the index of the anchor ZT(s) to a latency window:
% [ anchor_zt_index end_of_window_index ]
latencyInts = [ztIdx' (ztIdx+latencyBins-1)'];

% For activity, look at the hours BEFORE lights on/off for latency
% We can achieve that by subtracting the number of bins in the latency
% window from both columns, effectively shifting the window left by the
% window length. This also shifts the window so that the bin right AT the
% specified ZT is excldued (excluding the startle effect).
% This gets more complicated if the lights-off period is less than twice
% the latency interval, so the shifted data isn't all right before the first
% lights-on time, but I'm ignoring that and using a naive approach for
% now that assumes we have the full latency window hours before lights on.
if ~obj.IsSleep
    latencyInts = latencyInts - latencyBins;
    % If that put any intervals before the start of the data, shift them
    % around to the end
    latencyInts(latencyInts(:,1)<0, :) = latencyInts(latencyInts(:,1)<0, :) + size(obj.SmoothedData, 2);
end

%Finally, make sure the intervals are within the range of valid indices
latencyInts = mod(latencyInts, size(obj.SmoothedData,2));
%That leaves anything at the very last point in the data with a 0, so replace it if
%that's the case
latencyInts(latencyInts==0) = size(obj.SmoothedData,2);