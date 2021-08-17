function binData = reBinData(obj, dataIn)
% reBinData: Sum the data into bins of the specified size 
% 
% Usage: (where obj is an object of class ExperimentData)
%   plotData = obj.reBinData(dataIn);
% 
% Inputs:
%   dataIn [MxP int] - Data to re-bin
%
% Outputs:
%   binData [MxN int] - Data summed into bins of the specified size.

% Calculate how many bins we're going to have
ptsPerBin = obj.BinSize/obj.DataInterval;
% If points per bin isn't an integer, I'm not sure what to do here...
% Throw a warning for now
if mod(obj.BinSize, obj.DataInterval) ~= 0
    error("Bin size is not evenly divisible by data interval")
end
totalBins = floor(size(dataIn, 1)/ptsPerBin);

% Trim the data to only as much as we need for even bins
% AJL: need to add one extra data point here, since we're looking at
% t+1:t+30, not t:t+29... so replicate the last line.
dataIn = dataIn(1:ptsPerBin*totalBins, :,:);
binData = sum(reshape(dataIn, ptsPerBin, totalBins, size(dataIn,2), []), 1);
binData = squeeze(binData);

%Return a column vector
if size(binData,1) == 1
    binData = binData';
end