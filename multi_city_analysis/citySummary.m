function s = citySummary(name, urbanPath, ruralPath, yrs, flag)
% Per-city UHI summary stats. Returns a struct with mean UHI, seasonality,
% yearly series, and a per-decade linear trend.
    if nargin < 5, flag = 'clean'; end
    [~, ~, T] = loadPair(urbanPath, ruralPath, yrs);

    s.name    = name;
    s.flag    = flag;
    s.nDays   = height(T);
    s.meanU   = mean(T.TMAX_U, 'omitnan');
    s.meanR   = mean(T.TMAX_R, 'omitnan');
    s.meanUHI = mean(T.UHI,    'omitnan');

    months         = month(T.DATE);
    s.monthlyUHI   = arrayfun(@(m) mean(T.UHI(months == m), 'omitnan'), 1:12);

    yrs            = unique(year(T.DATE));
    uhiByYear      = arrayfun(@(y) mean(T.UHI(year(T.DATE) == y), 'omitnan'), yrs);
    s.yearly       = table(yrs, uhiByYear, 'VariableNames', {'year', 'uhi'});
    p              = polyfit(yrs, uhiByYear, 1);
    s.trendPerDecade = p(1) * 10;
end
