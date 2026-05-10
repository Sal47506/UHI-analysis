function T = readGhcn(path)
% Load a daily TMAX CSV. Accepts either DATE,TMAX or STATION,DATE,TMAX.
% Returns a table with datetime DATE and numeric TMAX (deg C, NaNs dropped).
    T = readtable(path);
    if any(strcmp(T.Properties.VariableNames, 'STATION'))
        T.STATION = [];
    end
    if ~isdatetime(T.DATE)
        T.DATE = datetime(T.DATE, 'InputFormat', 'yyyy-MM-dd');
    end
    T.TMAX(T.TMAX == -9999) = NaN;
    T = T(~isnan(T.TMAX), :);
end
