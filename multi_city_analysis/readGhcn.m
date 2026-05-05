function T = readGhcn(path)
% Load a daily TMAX CSV (either Boston-style DATE,TMAX or NCEI v1
% STATION,DATE,TMAX). Returns a table with DATE (datetime) and TMAX
% (deg C, NaN for missing -9999 sentinel rows dropped).
    T = readtable(path);
    if any(strcmp(T.Properties.VariableNames, 'STATION')), T.STATION = []; end
    if ~isdatetime(T.DATE), T.DATE = datetime(T.DATE, 'InputFormat','yyyy-MM-dd'); end
    T.TMAX(T.TMAX == -9999) = NaN;
    T = T(~isnan(T.TMAX), :);
end
