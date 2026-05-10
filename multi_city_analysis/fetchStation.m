function fetchStation(localPath, stationId)
% Download a GHCN-Daily TMAX CSV from NOAA NCEI if not already on disk.
    if isfile(localPath), return; end
    url = sprintf(['https://www.ncei.noaa.gov/access/services/data/v1?' ...
                   'dataset=daily-summaries&stations=%s&' ...
                   'startDate=1985-01-01&endDate=2024-12-31&' ...
                   'dataTypes=TMAX&format=csv&units=metric'], stationId);
    fprintf('Fetching %s -> %s\n', stationId, localPath);
    websave(localPath, url);
end
