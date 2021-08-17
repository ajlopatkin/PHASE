function normalizedData = normalizeData(obj, dataIn)
% calcAveragedNormalized: 
% 
% Usage: (where obj is an object of class DataForAnalysis)
%   dayData = obj.normalizeData(dataIn);
% 
% Inputs:
%   dataIn 
%  
% Outputs:
%   averagedData [MxOxP int] 
% 
% Notes:
% This is an averaging method for activity analysis that normalizes
% activity in each bin as a fraction of the entire day's behavior for
% individual flies. Averaging algorithms by averaging type are as follows:
% Flies: 
%    Sum all raw IR beam crosses for individual flies on a given day, and divide 
%    IR beam crosses within each user-defined bin by that sum. Then, average all 
%    indicated flies normalized values together for each individual day indicated 
%    in ?Days to Use"
% Days: 
%    Average all raw IR beam crosses for days in "Days to Use" by individual fly, 
%    then divide the averaged IR beam crosses within each bin by the day-averaged 
%    sum of all IR beam crosses.
% Both: 
%    First, determines the day-averaged sum of all IR beam crosses per individual 
%    fly in the indicated "Days to Use". Then, divides each flies day- averaged 
%    binned IR beam crosses by the average total IR beam crosses for all days. 
%    Finally, averages all indicated flies normalized activity together. 
% None: 
%    Sum all raw IR beam crosses for individual flies on individual days in 
%    "Days to Use", and divide IR beam crosses within each user-defined bin by that sum.
% (The above are as described by Jenna Persons via email, 2018-10-21)
% In order to otherwise maintain the flow of calculations, we're going to
% normalize each bin by the correct value based on averaging type here and
% then proceed as usual.

if obj.IsSleep
    normalizedData = dataIn;
    return
end

if ~obj.NormalizeActivity
    % if normalized analysis isn't selected, do normalization by the bin
    % size.
    normalizedData = dataIn ./ obj.BinSize;
else
    % These variables just make the code easier to read
    AVG_NONE = obj.AveragingMode == Averaging.None;
    AVG_DAYS = obj.AveragingMode == Averaging.Days;
    AVG_FLIES = obj.AveragingMode == Averaging.Flies;
    AVG_BOTH = obj.AveragingMode == Averaging.Both;
    % This is easier for me to visualize with concrete dimensions, so
    % dimensions given below are with 2 days, 3 flies, 30 minute bins (48
    % bins per day by 2 days = 96 bins total)
    % size(dataIn) = [96 3]
    if AVG_FLIES || AVG_NONE
        % We need the sum for each fly for each day, so rearrange
        % the data to make this easier. This is what averaging by day would
        % normally do, so layering data for this will give a [2 48 3] array.
        flyByDay = obj.layerDataForAveraging(dataIn, Averaging.Days);
        % Sum these counts by day to get a [2 1 3] array
        flyTotalByDay = sum(flyByDay, 2);
        % Repeat to get a value for each bin
        flyTotalByDayBins = repmat(flyTotalByDay, 1,size(flyByDay,2), 1);
        % Now divide each fly's value within each bin by the total for that day
        normalizedData = flyByDay./flyTotalByDayBins;
        % And rearrange back to the initial dimension
        % normalizedData = reshape(permute(normalizedData, [3 2 1]), size(dataIn));
        normalizedData = reshape(permute(normalizedData, [2 1 3]), size(dataIn));
    elseif AVG_DAYS || AVG_BOTH
        
        % AJL: changed this to use the individual day totals instead of an
        % averaged version.
        
        % Do the same as for flies, but average the total by day before using
        % for normalization.
        % We need the sum for each fly for each day, so rearrange
        % the data to make this easier. This is what averaging by day would
        % normally do, so layering data for this will give a [2 48 3] array.
        flyByDay = obj.layerDataForAveraging(dataIn, Averaging.Days);
        % Sum these counts by day to get a [2 1 3] array
        flyTotalByDay = sum(flyByDay, 2);
        % Average by day to get a day average per fly, [3 1] array
        % flyDayAverage = squeeze(mean(flyTotalByDay, 1));
        flyDayReshape = reshape(squeeze(flyTotalByDay)',size(dataIn,2),[]);
        % Repeat to get a per-bin value [3 96]
        % flyDayAverageByBins = repmat(flyDayAverage, 1, size(dataIn,1));
        flyDayByBins = repelem(flyDayReshape,1,24*60/obj.BinSize);
        % Divide each fly's value within each bin by the day-averaged total for
        % the fly
        % normalizedData = dataIn./flyDayAverageByBins';
        normalizedData = dataIn./flyDayByBins';
    end
end

