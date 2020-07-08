function outfile = writeLatencyData(obj, varargin)
% Write the latency data from the educer to an Excel file

p = inputParser;
p.addParameter('outfile', []);
p.addParameter('folderOut', []);
p.addParameter('separateSheets',[]);
p.parse(varargin{:});
outfile = p.Results.outfile;
folderOut = p.Results.folderOut;
separateSheets = p.Results.separateSheets;

latencies = obj.Latencies;

title = obj.Title;
if ~isempty(outfile)
    outfile = varargin{1};
else
    if obj.IsSleep
        filename = 'SleepLatency_';
        desc = 'Sleep';
        metric = 'Latency';
    else
        filename = 'ActivityAnticipation_';
        if obj.NormalizeActivity
            filename = ['Normalized'  filename];
        end
        desc = 'Activity';
        metric = 'Anticipation';
    end
    filename = [filename title '_' datestr(now, 'yyyymmdd_HHMM')];

    outfile = fullfile(folderOut, [filename '.xlsx']);
end

if ispc
    xlfunc = @xlswrite;
else
    xlfunc = @xlwrite;
end

dispSettings.days = num2str(obj.Days);
dispSettings.Channels = strcat('M', arrayfun(@(x) sprintf("%03d", x), obj.Boards'), 'C', arrayfun(@(x) sprintf("%02d", x), obj.Channels'));
dispSettings.Channels = strjoin(dispSettings.Channels, ',');
dispSettings.ZeitgeberOn = obj.LightsOn;
dispSettings.ZeitgeberHours = obj.LightHours;
dispSettings.DayLength = obj.DayLength;
dispSettings.ExpStart = datestr(obj.ExpStart, 'yyyy-mmm-dd HH:MMSS');
dispSettings.RunName = obj.RunName;
dispSettings.DataFolder = obj.DataFolder;
dispSettings.LatencyMinutes = obj.WindowMinutes;
dispSettings.LatencyZT = num2str(obj.WindowZTs);
if numel(obj.Days) == 1
    dprefix = ['Day ' num2str(obj.Days(1)) ' '];
else
    dprefix = '';
end

warning('off', 'xlwrite:AddSheet');
warning('off', 'MATLAB:xlswrite:AddSheet');
latency = {};
if separateSheets
    % For each ZT, get the data for each fly.
    % This is structured so there's some unfortunate looping here. It made
    % sense with the original layouts but not so much now.
    for z = 1:numel(obj.WindowZTs)
        zt = obj.WindowZTs(z);
        latency = {};
        for f = 1:numel(latencies) % This is the fly count
            % Build the output data array, one fly at a time
            % Each fly has multiple latencies, which means multiple rows. 
            % Use num2cell to put all the colums together correctly, and then label
            % only the first row of this set with the fly information.
            latency = [latency;
                latencies(f).rowLabel...
                num2cell(latencies(f).timeZT(z,1)) num2cell(latencies(f).timeZT(z,2)) ...
                num2cell(latencies(f).latency(z))...
                num2cell(latencies(f).auc(z))];
                % num2cell(latencies(f).slope(z))
        end
        %Replace infinite values with "Undefined"
       latency(:,2:end) = cleanUndefinedValues(latency(:,2:end));
        % Add column headers
       latency = [{' '} ...
            {['Min ' desc ' Time (ZT)']} ...
            {['Max ' desc ' Time (ZT)']} ...
            {[metric ' (minutes)']} ... % anticpation/latency
            {'Index (AUC)'}; 
            % {'Slope'}; 
            latency];
        % Save to a new sheet
        sheetName = ['ZT' num2str(zt)];
        latency(cellfun(@isempty, latency)) = {' '};
        xlfunc(outfile, latency, sheetName);

    end
else 
    sheetName = [dprefix desc ' in Minutes'];
    for z = 1:numel(latencies)
        % Build the output data array, one fly at a time
        % Each fly has multiple latencies, which means multiple rows. 
        % Use num2cell to put all the colums together correctly, and then label
        % only the first row of this set with the fly information.
        latency = [latency ;...
            cell(size(latencies(z).time,1),1) num2cell(latencies(z).timeZT(:,1)) num2cell(latencies(z).timeZT(:,2)) ...
            num2cell(latencies(z).latency) num2cell(latencies(z).auc)];% num2cell(latencies(z).slope)];
        latency{end-size(latencies(z).latency,1)+1,1} = latencies(z).rowLabel;
    end
    %Replace infinite values with "Undefined"
    latency(:,2:end) = cleanUndefinedValues(latency(:,2:end));
    % replace_inf = cellfun(@isinf, latency(:,2:end)); %2:end because the first column isn't numeric and throws an error
    % replace_inf = [false(size(replace_inf,1),1) replace_inf];
    % latency(replace_inf) = {'Undefined'};

    % Add column headers
    latency = [{' '} ...
        {['Min ' desc ' Time (ZT)']} ...
        {['Max ' desc ' Time (ZT)']} ...
        {[metric ' (minutes)']} ... % anticpation/latency
        {'Index (AUC)'}; 
        % {'Slope'}; 
        latency];
    latency(cellfun(@isempty, latency)) = {' '};
    xlfunc(outfile, latency, sheetName);
end
xlfunc(outfile, [fieldnames(dispSettings) struct2cell(dispSettings)], 'Settings');
warning('on', 'xlwrite:AddSheet');
warning('on', 'MATLAB:xlswrite:AddSheet');
end

function dataOut = cleanUndefinedValues(dataIn)
    %Replace infinite values with "Undefined"
    dataOut = dataIn;
    replace_inf = cellfun(@isinf, dataIn); %2:end because the first column isn't numeric and throws an error
    replace_inf = [false(size(replace_inf,1),1) replace_inf];
    dataOut(replace_inf) = {'Undefined'};
end

